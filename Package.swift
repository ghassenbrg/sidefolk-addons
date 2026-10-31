// swift-tools-version: 6.2
import PackageDescription

/// Sidefolk's extensions in the add-on gallery: one small program each, on the same Kit the app's built-ins use
/// (a copy of sidefolk/extensions/Kit; scripts/check.sh says when they differ).
let extensions = ["git", "currency", "playtime", "images", "pdf", "qr-codes", "archives", "dev-toolbox", "feeds", "system-vitals-plus", "clipboard", "keep-awake"]

let package = Package(
    name: "SidefolkAddons",
    platforms: [.macOS(.v15)],
    products: (extensions + ["miraya"]).map { .executable(name: "ext-\($0)", targets: ["ext-\($0)"]) },
    // Miraya's native WebRTC, the build its Mac app pins (checksum included), so both send the same media.
    dependencies: [.package(url: "https://github.com/stasel/WebRTC.git", exact: "150.0.0")],
    targets: [
        .target(name: "SidefolkExtensionKit", path: "Kit"),
        .testTarget(name: "AddonTests", dependencies: (extensions + ["miraya"]).map { .target(name: "ext-\($0)") }, path: "Tests"),
        // Miraya's audio device for WebRTC, in Objective-C as in its Mac app: captured system sound in, no microphone.
        .target(name: "MirayaRTCBridge", dependencies: [.product(name: "WebRTC", package: "WebRTC")], path: "extensions/miraya/Bridge",
                cSettings: [.unsafeFlags(["-fobjc-arc"])], linkerSettings: [.linkedFramework("AudioToolbox")]),
        // WebRTC ships beside the program, in lib/ (scripts/build.py puts it there): the sandbox reads the extension's folder.
        .executableTarget(name: "ext-miraya", dependencies: ["SidefolkExtensionKit", "MirayaRTCBridge", .product(name: "WebRTC", package: "WebRTC")],
                          path: "extensions/miraya/Sources", swiftSettings: [.swiftLanguageMode(.v5)],
                          linkerSettings: [.unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../lib"])]),
    ] + extensions.map { .executableTarget(name: "ext-\($0)", dependencies: ["SidefolkExtensionKit"], path: "extensions/\($0)/Sources") }
)
