import DiscordProtocol
import os

extension AppModel {
    /// Sends a Rich Presence activity with the current account's presence.
    func setRichPresenceActivity(_ activity: RichPresenceActivity?) async {
        let provider = await accountSession().provider
        Logger(subsystem: "dev.sakuracord.SakuraCord", category: "RichPresence")
            .notice("Sending activity to \(String(describing: type(of: provider)), privacy: .public)")
        await provider.setRichPresenceActivity(activity)
    }
}
