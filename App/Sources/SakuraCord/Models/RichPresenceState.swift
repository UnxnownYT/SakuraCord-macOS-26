import DiscordProtocol
import Observation

/// The activity SakuraCord is sending for the signed-in account. Discord does
/// not echo a client's own activity back, so the profile card reads it here.
@Observable
final class RichPresenceState {
    static let shared = RichPresenceState()
    var activity: RichPresenceActivity?
}
