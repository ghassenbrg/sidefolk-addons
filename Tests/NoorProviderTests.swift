import Foundation
import Testing
@testable import ext_prayer_times

/// The cache and the retries, on a scripted network and an instant that only moves when a test moves it.
struct NoorProviderTests {
    typealias S = NoorSupport

    let now = S.instant("2026-11-02T08:00:00+09:00")
    let date = S.date("2026-11-02")
    let folder = S.temporaryFolder()

    private func provider(_ replies: [ScriptedFetch.Reply], log: SleepLog = SleepLog()) -> (Provider, ScriptedFetch) {
        let fetch = ScriptedFetch(replies)
        return (Provider(fetching: fetch, store: NoorStore(folder: folder), sleep: { await log.record($0) }), fetch)
    }

    private func load(_ provider: Provider, at instant: Date? = nil, refresh: Bool = false) async -> Outcome<PrayerDay> {
        await provider.prayerDay(date, place: S.tokyo, convention: S.mwl, calendarMethod: .uaq, now: instant ?? now, refresh: refresh)
    }

    @Test func aFreshAnswerIsCachedAndServedWhileYoung() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, fetch) = provider([.answer(200, try S.fixture("prayer-day"))])
        let first = await load(provider)
        guard case .fresh(let day) = first else { Issue.record("Expected fresh, got \(first)"); return }
        #expect(day.date == date)
        #expect(await load(provider) == .cached(day, fetchedAt: now))
        #expect(await fetch.asked.count == 1, "no second call while the answer is young")
        #expect(await fetch.asked.first?.absoluteString.contains("iso8601=true") == true)
    }

    @Test func aBadAnswerNeverReplacesAGoodOne() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, fetch) = provider([.answer(200, try S.fixture("prayer-day")), .answer(200, Data("<html>oops</html>".utf8)),
                                          .answer(200, try S.edited("prayer-day", ["data", "timings", "Fajr"], nil))])
        let good = try #require(await load(provider).value)
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
        #expect(await fetch.asked.count == 3, "a malformed answer isn't retried on the spot")
        let later = now.addingTimeInterval(3600)
        #expect(await load(provider, at: later) == .cached(good, fetchedAt: now), "the good one is still the one on disk")
    }

    @Test func anOldCacheStillCoversItsDateAndAFreshOtherDateDoesNot() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // Fetched long ago, yet about the date being asked for: it answers for that date while the network is down.
        let longAgo = now.addingTimeInterval(-300 * 24 * 3600)
        let store = NoorStore(folder: folder)
        let old = try AlAdhanDecoder.timings(S.fixture("prayer-day"), date: date, query: S.query)
        try store.cache(old, key: AlAdhan.timings(date, S.query).cacheKey, fetchedAt: longAgo)
        let (offline, _) = provider([.failure, .failure, .failure])
        #expect(await load(offline) == .cached(old, fetchedAt: longAgo))

        // Just fetched, but about another date: it can't stand in for tomorrow, and it isn't saved as tomorrow.
        let tomorrow = date.next
        let (wrong, _) = provider([.answer(200, try S.fixture("prayer-day"))])
        let outcome = await wrong.prayerDay(tomorrow, place: S.tokyo, convention: S.mwl, calendarMethod: .uaq, now: now)
        #expect(outcome == .unavailable(.noCoverage))
        let saved: CacheEntry<PrayerDay>? = store.cached(key: AlAdhan.timings(tomorrow, S.query).cacheKey)
        #expect(saved == nil)
    }

    @Test func aRateLimitBacksOffThenCoolsDown() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = SleepLog()
        let busy = Data(#"{"code":429,"data":"slow"}"#.utf8)
        let (provider, fetch) = provider([.answer(429, busy), .answer(429, busy), .answer(429, busy), .answer(200, try S.fixture("prayer-day"))], log: log)
        #expect(await load(provider) == .unavailable(.rateLimited(retryAfter: 60)))
        #expect(await log.delays == [4, 8])
        #expect(await fetch.asked.count == 3)

        // While cooling down nothing goes out, and the wait left is what it reports.
        #expect(await load(provider, at: now.addingTimeInterval(45), refresh: true) == .unavailable(.rateLimited(retryAfter: 15)))
        #expect(await fetch.asked.count == 3)

        let after = now.addingTimeInterval(61)
        guard case .fresh = await load(provider, at: after) else { Issue.record("Expected fresh after the cooldown"); return }
        #expect(await fetch.asked.count == 4)
    }

    @Test func aRateLimitThatClearsOnRetryCounts() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, _) = provider([.answer(429, Data()), .answer(200, try S.fixture("prayer-day"))])
        guard case .fresh = await load(provider) else { Issue.record("Expected fresh on the second try"); return }
    }

    @Test func aRateLimitFallsBackOnTheCache() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, _) = provider([.answer(200, try S.fixture("prayer-day")), .answer(429, Data()), .answer(429, Data()), .answer(429, Data())])
        let good = try #require(await load(provider).value)
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
    }

    @Test func offlineRetriesWithBackoffThenSaysSo() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = SleepLog()
        let (provider, fetch) = provider([.failure, .answer(503, Data()), .failure], log: log)
        #expect(await load(provider) == .unavailable(.offline))
        #expect(await log.delays == [1, 2])
        #expect(await fetch.asked.count == 3)
    }

    @Test func aClientErrorIsNotRetried() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = SleepLog()
        let (provider, fetch) = provider([.answer(400, Data(#"{"code":400,"data":"Bad"}"#.utf8))], log: log)
        #expect(await load(provider) == .unavailable(.malformed))
        #expect(await log.delays.isEmpty)
        #expect(await fetch.asked.count == 1)
    }

    @Test func noPlaceAsksNothing() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, fetch) = provider([])
        #expect(await provider.prayerDay(date, place: nil, convention: S.mwl, calendarMethod: .uaq, now: now) == .unavailable(.noPlace))
        #expect(await provider.prayerMonth(year: 2026, month: 11, place: nil, convention: S.mwl, calendarMethod: .uaq, now: now) == .unavailable(.noPlace))
        #expect(await provider.hijriPrayerMonth(year: 1448, month: 9, place: nil, convention: S.mwl, calendarMethod: .uaq, now: now) == .unavailable(.noPlace))
        #expect(await provider.qibla(place: nil, now: now) == .unavailable(.noPlace))
        #expect(await fetch.asked.isEmpty)
    }

    @Test func anotherConventionIsNotServedFromThisOnesCache() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, fetch) = provider([.answer(200, try S.fixture("prayer-day"))])
        _ = await load(provider)
        let other = await provider.prayerDay(date, place: S.tokyo, convention: try PrayerConvention(method: 3, school: 1), calendarMethod: .uaq, now: now)
        #expect(other == .unavailable(.offline))
        #expect(await fetch.asked.count == 4)
    }

    @Test func aDamagedCacheFileIsJustAMissOne() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, _) = provider([.answer(200, try S.fixture("names")), .answer(200, try S.fixture("names"))])
        let first = await provider.load(AlAdhan.names(), now: now)
        #expect(first.value?.count == 99)
        let shelf = folder.appending(path: "cache")
        for file in try FileManager.default.contentsOfDirectory(at: shelf, includingPropertiesForKeys: nil) { try Data("{".utf8).write(to: file) }
        guard case .fresh = await provider.load(AlAdhan.names(), now: now) else { Issue.record("Expected a new fetch"); return }
    }

    @Test func theOtherLoadsGoThroughTheSameCache() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, fetch) = provider([.answer(200, try S.fixture("ramadan-month")), .answer(200, try S.fixture("qibla-tokyo")), .answer(200, try S.fixture("names")),
                                          .answer(200, try S.fixture("listed-occasions")), .answer(200, try S.fixture("hijri-to-gregorian"))])
        let month = await provider.hijriPrayerMonth(year: 1448, month: 9, place: S.tokyo, convention: S.mwl, calendarMethod: .uaq, now: now)
        #expect(month.value.flatMap { RamadanMonth(days: $0) }?.dayCount == 29)
        let qibla = await provider.qibla(place: S.tokyo, now: now)
        let bearing = try #require(qibla.value)
        #expect(bearing.rounded == 293 && bearing.fetched == now)
        let later = now.addingTimeInterval(3600)
        #expect(await provider.qibla(place: S.tokyo, now: later) == .cached(bearing, fetchedAt: now), "the saved bearing keeps its fetched time")
        #expect(await provider.load(AlAdhan.names(), now: now).value?.count == 99)
        #expect(await provider.load(AlAdhan.occasions(hijriYear: 1448, method: .uaq), now: now).value?.count == 77)
        let back = await provider.load(AlAdhan.hijriToGregorian(HijriDate(year: 1448, month: 5, day: 22)!, method: .uaq), now: now)
        #expect(back.value?.gregorian == S.date("2026-11-02"))
        #expect(await fetch.asked.count == 5)
    }

    /// No network: a file URL only shows it refuses what isn't an HTTP answer.
    @Test func theRealFetcherHasItsTimeoutAndWantsHTTP() async throws {
        #expect(URLSessionFetching().timeout == 20)
        await #expect(throws: (any Error).self) {
            _ = try await URLSessionFetching().get(S.fixtures.appending(path: "qibla-tokyo.json"))
        }
    }

    @Test func aCacheFromTheFutureIsAskedAgain() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        // A clock moved back makes every cached answer look brand new for as long as it stays wrong.
        let (provider, fetch) = provider([.answer(200, try S.fixture("prayer-day")), .answer(200, try S.fixture("prayer-day"))])
        _ = await load(provider)
        guard case .fresh = await load(provider, at: now.addingTimeInterval(-3600)) else { Issue.record("Expected a new fetch"); return }
        #expect(await fetch.asked.count == 2)
    }

    @Test func noConnectionIsFoundOnceInARound() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let log = SleepLog()
        let (provider, fetch) = provider([], log: log)
        #expect(await load(provider) == .unavailable(.offline))
        let tries = await fetch.asked.count
        let waits = await log.delays.count
        let found = await provider.foundNoConnection
        #expect(tries > 1 && waits > 0 && found)
        #expect(await load(provider, at: now.addingTimeInterval(1)) == .unavailable(.offline))
        let triesAfter = await fetch.asked.count
        let waitsAfter = await log.delays.count
        #expect(triesAfter == tries && waitsAfter == waits, "the next thing asked doesn't wait all over again")
        await provider.beginAsking()
        let forgotten = await provider.foundNoConnection
        #expect(!forgotten)
        _ = await load(provider, at: now.addingTimeInterval(2))
        #expect(await fetch.asked.count > tries, "a new round tries again")
    }

    @Test func aFailedRefreshWithASavedAnswerReportsItsReason() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let busy = Data(#"{"code":429,"data":"slow"}"#.utf8)
        let (provider, _) = provider([.answer(200, try S.fixture("prayer-day")), .answer(200, Data("<html>oops</html>".utf8)),
                                      .answer(429, busy), .answer(429, busy), .answer(429, busy), .failure, .failure, .failure])
        let good = try #require(await load(provider).value)
        #expect(await provider.standingFailure == nil, "nothing has failed yet")

        // Each time the times stay, and the reason doesn't hide behind them.
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
        #expect(await provider.standingFailure == .malformed)
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
        #expect(await provider.standingFailure == .rateLimited(retryAfter: 60))

        let afterCooling = now.addingTimeInterval(61)
        #expect(await load(provider, at: afterCooling, refresh: true) == .cached(good, fetchedAt: now))
        #expect(await provider.standingFailure == .offline)
    }

    @Test func aFailureStaysUntilARealFetchSucceeds() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let busy = Data(#"{"code":429,"data":"slow"}"#.utf8)
        let (provider, fetch) = provider([.answer(200, try S.fixture("prayer-day")), .answer(429, busy), .answer(429, busy), .answer(429, busy), .answer(200, try S.fixture("prayer-day"))])
        let good = try #require(await load(provider).value)
        #expect(await load(provider, refresh: true) == .cached(good, fetchedAt: now))
        let asked = await fetch.asked.count

        // Another round, a page opened or a tab changed, reads the young saved answer: that isn't the network saying yes.
        await provider.beginAsking()
        #expect(await load(provider, at: now.addingTimeInterval(10)) == .cached(good, fetchedAt: now))
        #expect(await fetch.asked.count == asked, "still cooling down")
        #expect(await provider.standingFailure == .rateLimited(retryAfter: 50))

        // It tries again by itself once it may, though the saved answer is young, and a real answer ends it.
        await provider.beginAsking()
        let after = now.addingTimeInterval(61)
        guard case .fresh = await load(provider, at: after) else { Issue.record("Expected fresh after the cooldown"); return }
        #expect(await provider.standingFailure == nil)
    }

    @Test func anotherAnswerDoesNotClearAFailureAboutSomethingElse() async throws {
        defer { try? FileManager.default.removeItem(at: folder) }
        let (provider, _) = provider([.answer(200, try S.fixture("prayer-day")), .answer(200, Data("<html>oops</html>".utf8)), .answer(200, try S.fixture("qibla-tokyo"))])
        _ = await load(provider)
        _ = await load(provider, refresh: true)
        guard case .fresh = await provider.qibla(place: S.tokyo, now: now) else { Issue.record("Expected fresh"); return }
        #expect(await provider.standingFailure == .malformed)

        // A round that no longer asks about it has left it behind: a place no longer chosen doesn't speak for this one.
        await provider.beginAsking()
        _ = await provider.qibla(place: S.tokyo, now: now)
        #expect(await provider.standingFailure == nil)
    }
}
