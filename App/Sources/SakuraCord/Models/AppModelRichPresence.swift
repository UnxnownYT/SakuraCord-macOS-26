import DiscordProtocol

extension AppModel {
    /// Sends a Rich Presence activity with the current account's presence.
    func setRichPresenceActivity(_ activity: RichPresenceActivity?) async {
        RichPresenceState.shared.activity = activity
        await accountSession().provider.setRichPresenceActivity(activity)
    }
}
