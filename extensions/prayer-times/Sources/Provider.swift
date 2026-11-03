import Foundation

/// The network, as much as the domain needs of it. Tests script it.
protocol Fetching: Sendable {
    func get(_ url: URL) async throws -> (status: Int, body: Data)
}

/// The real network, with no URL cache: nothing about where someone is lingers there, and `refresh` means the network.
struct URLSessionFetching: Fetching {
    let timeout: TimeInterval
    private let session: URLSession

    init(timeout: TimeInterval = 20) {
        self.timeout = timeout
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        session = URLSession(configuration: configuration)
    }

    func get(_ url: URL) async throws -> (status: Int, body: Data) {
        let (body, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        return (http.statusCode, body)
    }
}

enum UnavailableReason: Error, Equatable, Sendable {
    case noPlace
    case offline
    /// Seconds Noor will wait before asking again. `Fetching` carries no headers, so this is Noor's own backoff, not the
    /// server's `Retry-After`.
    case rateLimited(retryAfter: TimeInterval)
    case malformed
    case expired
    case noCoverage
}

/// What a load came to. `.cached` is an answer asked for before, with when; only `.fresh` came over the network just now.
enum Outcome<Value: Sendable>: Sendable {
    case fresh(Value)
    case cached(Value, fetchedAt: Date)
    case unavailable(UnavailableReason)

    var value: Value? {
        switch self {
        case .fresh(let value), .cached(let value, _): value
        case .unavailable: nil
        }
    }
}

extension Outcome: Equatable where Value: Equatable {}

/// The provider behind a cache. Fetch age and date validity are separate things here: an old cached answer about today
/// still answers for today, and a fresh answer about another date doesn't.
actor Provider {
    static let maximumAttempts = 3
    /// Seconds before the second attempt, doubling. A 429 starts higher: the server asked for less, not for a retry.
    static let backoff: TimeInterval = 1
    /// How long no connection stands for what is asked next, outside a round the model begins itself.
    static let unreachableFor: TimeInterval = 20
    static let rateLimitBackoff: TimeInterval = 4
    static let rateLimitCooldown: TimeInterval = 60
    /// How long a cached answer nobody has refreshed stays on disk.
    static let cacheLifetime: TimeInterval = 400 * 24 * 3600

    private enum Failure: Error { case transport, rateLimited, malformed, noCoverage }

    private let fetching: any Fetching
    private let store: NoorStore
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var coolingUntil: Date?
    private var unreachableUntil: Date?
    /// What went wrong the last time each thing was asked for, whatever a saved answer covered up. Only a real answer takes an entry away.
    private var failures: [String: UnavailableReason] = [:]
    /// The round before this one's: what a new round doesn't ask about is left behind, so a place no longer chosen doesn't speak for this one.
    private var earlier: [String: UnavailableReason] = [:]

    init(fetching: any Fetching, store: NoorStore,
         sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) {
        self.fetching = fetching
        self.store = store
        self.sleep = sleep
    }

    /// The cached answer while it's young, unless `refresh` or the last asking about it failed; otherwise the network, falling back on the cached
    /// answer when that fails. Only a checked answer ever reaches the cache.
    func load<Value>(_ request: AlAdhanRequest<Value>, now: Date, refresh: Bool = false) async -> Outcome<Value> {
        let key = request.cacheKey
        let cached: CacheEntry<Value>? = store.cached(key: key)
        let failedBefore = failures[key] ?? earlier[key] != nil
        if let cached, !refresh, !failedBefore, (0..<request.refreshAfter).contains(now.timeIntervalSince(cached.fetchedAt)) {
            return .cached(cached.value, fetchedAt: cached.fetchedAt)
        }
        if let coolingUntil, now < coolingUntil {
            return failed(key, cached, .rateLimited(retryAfter: coolingUntil.timeIntervalSince(now)))
        }
        // No connection answers for everything asked in the same breath: each asking again would only add its own wait.
        if let unreachableUntil, now < unreachableUntil { return failed(key, cached, .offline) }
        switch await attempt(request, now: now) {
        case .success(let value):
            coolingUntil = nil
            unreachableUntil = nil
            answered(key)
            // A full disk costs the cache, not this answer.
            try? store.cache(value, key: key, fetchedAt: now)
            store.pruneCache(olderThan: now.addingTimeInterval(-Self.cacheLifetime))
            return .fresh(value)
        case .failure where Task.isCancelled:
            // A newer round took over from this one, which says nothing about the network.
            return fallback(cached, .offline)
        case .failure(.rateLimited):
            coolingUntil = now.addingTimeInterval(Self.rateLimitCooldown)
            return failed(key, cached, .rateLimited(retryAfter: Self.rateLimitCooldown))
        case .failure(.transport):
            unreachableUntil = now.addingTimeInterval(Self.unreachableFor)
            return failed(key, cached, .offline)
        case .failure(.malformed): return failed(key, cached, .malformed)
        case .failure(.noCoverage):
            // The provider did answer, only not about this.
            answered(key)
            return fallback(cached, .noCoverage)
        }
    }

    /// A new round of asking tries the network again.
    func beginAsking() {
        unreachableUntil = nil
        earlier = failures
        failures = [:]
    }

    /// Did the last asking find no connection?
    var foundNoConnection: Bool { unreachableUntil != nil }

    /// What the person should still be told: a saved answer hides it from its `Outcome`. It stands until a real answer comes, however many saved ones are read in between.
    var standingFailure: UnavailableReason? {
        if foundNoConnection { return .offline }
        let standing = Array(failures.values)
        return standing.first { $0 == .offline } ?? standing.first { if case .rateLimited = $0 { true } else { false } } ?? standing.first
    }

    private func answered(_ key: String) {
        failures[key] = nil
        earlier[key] = nil
    }

    private func failed<Value>(_ key: String, _ cached: CacheEntry<Value>?, _ reason: UnavailableReason) -> Outcome<Value> {
        failures[key] = reason
        return fallback(cached, reason)
    }

    private func fallback<Value>(_ cached: CacheEntry<Value>?, _ reason: UnavailableReason) -> Outcome<Value> {
        cached.map { .cached($0.value, fetchedAt: $0.fetchedAt) } ?? .unavailable(reason)
    }

    private func attempt<Value>(_ request: AlAdhanRequest<Value>, now: Date) async -> Result<Value, Failure> {
        var last = Failure.transport
        for attempt in 0..<Self.maximumAttempts {
            if attempt > 0 {
                let base = last == .rateLimited ? Self.rateLimitBackoff : Self.backoff
                do { try await sleep(base * pow(2, Double(attempt - 1))) } catch { return .failure(last) }
            }
            do {
                let (status, body) = try await fetching.get(request.url)
                switch status {
                case 200:
                    // An answer that reads wrong will read wrong again, so it isn't retried.
                    do { return .success(try request.decode(body, now)) } catch AlAdhanError.noCoverage {
                        return .failure(.noCoverage)
                    } catch {
                        return .failure(.malformed)
                    }
                case 429: last = .rateLimited
                case 500...: last = .transport
                default: return .failure(.malformed)
                }
            } catch {
                last = .transport
            }
        }
        return .failure(last)
    }

    // MARK: - The calls pages make

    func prayerDay(_ date: CivilDate, place: Place?, convention: PrayerConvention, calendarMethod: CalendarMethod, now: Date, refresh: Bool = false) async -> Outcome<PrayerDay> {
        guard let place else { return .unavailable(.noPlace) }
        return await load(AlAdhan.timings(date, PrayerQuery(place: place, convention: convention, calendarMethod: calendarMethod)), now: now, refresh: refresh)
    }

    func prayerMonth(year: Int, month: Int, place: Place?, convention: PrayerConvention, calendarMethod: CalendarMethod, now: Date, refresh: Bool = false) async -> Outcome<[PrayerDay]> {
        guard let place else { return .unavailable(.noPlace) }
        return await load(AlAdhan.prayerCalendar(year: year, month: month, PrayerQuery(place: place, convention: convention, calendarMethod: calendarMethod)), now: now, refresh: refresh)
    }

    func hijriPrayerMonth(year: Int, month: Int, place: Place?, convention: PrayerConvention, calendarMethod: CalendarMethod, now: Date, refresh: Bool = false) async -> Outcome<[PrayerDay]> {
        guard let place else { return .unavailable(.noPlace) }
        return await load(AlAdhan.hijriPrayerCalendar(year: year, month: month, PrayerQuery(place: place, convention: convention, calendarMethod: calendarMethod)), now: now, refresh: refresh)
    }

    func qibla(place: Place?, now: Date, refresh: Bool = false) async -> Outcome<QiblaBearing> {
        guard let place else { return .unavailable(.noPlace) }
        return await load(AlAdhan.qibla(place), now: now, refresh: refresh)
    }
}
