import Foundation
import SidefolkExtensionKit

/// What the sources copied from Miraya's Mac app (`Miraya/`) say went wrong, in the person's language (Sidefolk D76).
/// Those files stay as Miraya's app has them, in English; a message reaches the person through `Session.failed`, which
/// passes it here. One this doesn't know (an error macOS words itself) is shown as it came.
enum Said {
    static func shown(_ message: String) -> String {
        if let known = whole[message] { return known() }
        // Messages that end with what macOS said, kept as macOS said it.
        for (start, end, sentence) in withError {
            guard message.hasPrefix(start), message.hasSuffix(end), message.count >= start.count + end.count else { continue }
            return sentence(String(message.dropFirst(start.count).dropLast(end.count)))
        }
        return message
    }

    private static let whole: [String: () -> String] = [
        "The saved TV identity is invalid. Forget this TV and pair again.": { L("The saved TV identity is invalid. Forget this TV and pair again.") },
        "The saved TV credentials are incomplete. Forget this TV and pair again.": { L("The saved TV credentials are incomplete. Forget this TV and pair again.") },
        "The TV's identity didn't match. If the TV was reset, forget it here and pair again.":
            { L("The TV's identity didn't match. If the TV was reset, forget it here and pair again.") },
        "The pairing codes don't match. Nothing was shared.": { L("The pairing codes don't match. Nothing was shared.") },
        "The TV closed the connection. Make sure Miraya is still open on the TV.": { L("The TV closed the connection. Make sure Miraya is still open on the TV.") },
        "Pairing timed out. Try again and compare the new six-digit code.": { L("Pairing timed out. Try again and compare the new six-digit code.") },
        "The TV didn't answer. Check its address and that both are on the same network.":
            { L("The TV didn't answer. Check its address and that both are on the same network.") },
        "The TV stopped answering. Check that it's on and connected.": { L("The TV stopped answering. Check that it's on and connected.") },
        "Could not initialize the Wi-Fi media engine.": { L("Couldn't start the Wi-Fi video engine.") },
        "The TV stopped presenting video. Reconnecting Wi-Fi sharing…": { L("The TV stopped showing the video. Reconnecting…") },
        "Invalid Wi-Fi media negotiation. Update both Miraya apps.": { L("The TV and this Mac couldn't agree on the video. Update Miraya on the TV.") },
        "Could not create the Wi-Fi media offer.": { L("Couldn't prepare the video for the TV.") },
        "Could not prepare Wi-Fi media.": { L("Couldn't prepare the video for the TV.") },
        "The TV could not establish direct UDP media. Check local-network permission, VPN and Wi-Fi client isolation.":
            { L("The TV couldn't open a direct video connection. Check the local network permission, any VPN, and Wi-Fi client isolation.") },
        "The screen encoder stopped making progress. Reconnecting Wi-Fi sharing…": { L("The screen encoder stopped. Reconnecting…") },
        "Wi-Fi media connection failed. Check the TV and network.": { L("The video connection failed. Check the TV and the network.") },
        "Wi-Fi media did not recover. Check the TV and network.": { L("The video connection didn't come back. Check the TV and the network.") },
        "The encrypted Wi-Fi media connection failed.": { L("The encrypted video connection failed.") },
        "The receiver sent an invalid protocol packet. Update both Miraya apps.": { L("The TV sent something this version doesn't know. Update Miraya on the TV.") },
        "The receiver exceeded Miraya's packet size limit.": { L("The TV sent something this version doesn't know. Update Miraya on the TV.") },
        "The receiver sent an invalid control message.": { L("The TV sent something this version doesn't know. Update Miraya on the TV.") },
        // Why sharing ended, kept in English by the session (the heads-up tells "You stopped it." apart).
        "You stopped it.": { L("You stopped it.") },
        "Sharing ended on the TV.": { L("Sharing ended on the TV.") },
        "Replaced by a new video.": { L("Replaced by a new video.") },
        "That screen or window isn't available any more. Choose another and share again.":
            { L("That screen or window isn't available any more. Choose another and share again.") },
    ]

    private static let withError: [(String, String, (String) -> String)] = [
        ("Couldn't reach the TV: ", ". Check that Miraya is open on it and both are on the same network.",
         { L("Couldn't reach the TV: {error}. Check that Miraya is open on it and both are on the same network.", ["error": $0]) }),
        ("The connection to the TV ended: ", "", { L("The connection to the TV ended: {error}", ["error": $0]) }),
        ("The connection was interrupted: ", "", { L("The connection was interrupted: {error}", ["error": $0]) }),
        ("The TV rejected media negotiation: ", "", { L("The TV refused the video: {error}", ["error": $0]) }),
        ("The Mac's sound couldn't be captured: ", ". Try sharing without sound.",
         { L("The Mac's sound couldn't be captured: {error}. Try sharing without sound.", ["error": $0]) }),
    ]
}
