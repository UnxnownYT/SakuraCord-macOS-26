import os
import Foundation

/// An activity set by a game or app over Discord's local RPC socket. It is
/// sent with the current user's presence, as the official client does.
public struct RichPresenceActivity: Sendable, Equatable {
    public var applicationID: String
    public var name: String
    public var type: Int
    public var details: String?
    public var state: String?
    public var startMilliseconds: Int64?
    public var endMilliseconds: Int64?
    public var largeImage: String?
    public var largeText: String?
    public var smallImage: String?
    public var smallText: String?
    public var buttonLabels: [String]
    public var buttonURLs: [String]
    public var partyID: String?
    public var partySize: [Int]?

    public init(
        applicationID: String,
        name: String = "",
        type: Int = 0,
        details: String? = nil,
        state: String? = nil,
        startMilliseconds: Int64? = nil,
        endMilliseconds: Int64? = nil,
        largeImage: String? = nil,
        largeText: String? = nil,
        smallImage: String? = nil,
        smallText: String? = nil,
        buttonLabels: [String] = [],
        buttonURLs: [String] = [],
        partyID: String? = nil,
        partySize: [Int]? = nil
    ) {
        self.applicationID = applicationID
        self.name = name
        self.type = type
        self.details = details
        self.state = state
        self.startMilliseconds = startMilliseconds
        self.endMilliseconds = endMilliseconds
        self.largeImage = largeImage
        self.largeText = largeText
        self.smallImage = smallImage
        self.smallText = smallText
        self.buttonLabels = buttonLabels
        self.buttonURLs = buttonURLs
        self.partyID = partyID
        self.partySize = partySize
    }

    /// The activity object of a Gateway opcode 3 presence update.
    var gatewayPayload: [String: Any] {
        var payload: [String: Any] = ["name": name, "type": type, "application_id": applicationID]
        if let details { payload["details"] = details }
        if let state { payload["state"] = state }
        var timestamps: [String: Any] = [:]
        if let startMilliseconds { timestamps["start"] = startMilliseconds }
        if let endMilliseconds { timestamps["end"] = endMilliseconds }
        if !timestamps.isEmpty { payload["timestamps"] = timestamps }
        var assets: [String: Any] = [:]
        if let largeImage { assets["large_image"] = largeImage }
        if let largeText { assets["large_text"] = largeText }
        if let smallImage { assets["small_image"] = smallImage }
        if let smallText { assets["small_text"] = smallText }
        if !assets.isEmpty { payload["assets"] = assets }
        if !buttonLabels.isEmpty {
            payload["buttons"] = buttonLabels
            payload["metadata"] = ["button_urls": buttonURLs]
        }
        if partyID != nil || partySize != nil {
            var party: [String: Any] = [:]
            if let partyID { party["id"] = partyID }
            if let partySize { party["size"] = partySize }
            payload["party"] = party
        }
        return payload
    }
}

public extension ChatProvider {
    /// Providers without a Gateway connection ignore Rich Presence.
    func setRichPresenceActivity(_ activity: RichPresenceActivity?) async {}
}

public extension DiscordRESTProvider {
    func setRichPresenceActivity(_ activity: RichPresenceActivity?) async {
        guard richPresenceActivity != activity else { return }
        richPresenceActivity = activity
        Logger(subsystem: "dev.sakuracord.SakuraCord", category: "RichPresence").notice("Provider received activity, gateway ready: \(self.gatewayReady, privacy: .public)")
        await sendPresenceIfChanged()
    }
}
