import DiscordProtocol
import SwiftUI

/// What the user is playing, on their own profile card, while a game shares
/// its activity through Rich Presence.
struct ProfileRichPresenceSection: View {
    let activity: RichPresenceActivity

    var body: some View {
        VStack(alignment: .leading, spacing: InterfaceScale.metric(6)) {
            Text(heading)
                .font(.interface(.caption).weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: InterfaceScale.metric(10)) {
                artwork
                VStack(alignment: .leading, spacing: InterfaceScale.metric(2)) {
                    Text(activity.name)
                        .font(.interface(.body).weight(.semibold))
                        .foregroundStyle(.primary)
                    if let details = activity.details, !details.isEmpty { Text(details) }
                    if let state = activity.state, !state.isEmpty { Text(state) }
                    if let start = activity.startMilliseconds {
                        Text("\(Text(Date(timeIntervalSince1970: TimeInterval(start) / 1000), style: .timer)) elapsed")
                            .monospacedDigit()
                    }
                }
                .font(.interface(.callout))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heading: String {
        switch activity.type {
        case 1: "Streaming"
        case 2: "Listening to"
        case 3: "Watching"
        case 5: "Competing in"
        default: "Playing"
        }
    }

    /// Discord serves app assets from its CDN and external images ("mp:")
    /// through its media proxy.
    private var imageURL: URL? {
        guard let key = activity.largeImage ?? activity.smallImage, !key.isEmpty else { return nil }
        if key.hasPrefix("mp:") { return URL(string: "https://media.discordapp.net/" + String(key.dropFirst(3))) }
        return URL(string: "https://cdn.discordapp.com/app-assets/\(activity.applicationID)/\(key).png")
    }

    @ViewBuilder private var artwork: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                RoundedRectangle(cornerRadius: InterfaceScale.metric(8), style: .continuous).fill(.quaternary)
            }
            .frame(width: InterfaceScale.metric(56), height: InterfaceScale.metric(56))
            .clipShape(RoundedRectangle(cornerRadius: InterfaceScale.metric(8), style: .continuous))
        }
    }
}
