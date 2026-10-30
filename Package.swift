// swift-tools-version: 6.2
import PackageDescription

/// Sidefolk's extensions in the add-on gallery: one small program each, on the same Kit the app's built-ins use
/// (a copy of sidefolk/extensions/Kit; scripts/check.sh says when they differ).
let extensions = ["git", "currency", "playtime", "images", "pdf", "qr-codes", "archives", "dev-toolbox", "feeds"]

let package = Package(
    name: "SidefolkAddons",
    platforms: [.macOS(.v15)],
    products: extensions.map { .executable(name: "ext-\($0)", targets: ["ext-\($0)"]) },
    targets: [
        .target(name: "SidefolkExtensionKit", path: "Kit"),
        .testTarget(name: "AddonTests", dependencies: extensions.map { .target(name: "ext-\($0)") }, path: "Tests"),
    ] + extensions.map { .executableTarget(name: "ext-\($0)", dependencies: ["SidefolkExtensionKit"], path: "extensions/\($0)/Sources") }
)
