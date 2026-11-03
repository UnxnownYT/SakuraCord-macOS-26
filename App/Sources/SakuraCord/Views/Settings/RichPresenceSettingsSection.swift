import SwiftUI

struct RichPresenceSettingsSection: View {
    @AppStorage(RichPresenceServer.enabledKey) private var isEnabled = false

    var body: some View {
        Section {
            Toggle("Discord Rich Presence", isOn: $isEnabled)
                .onChange(of: isEnabled) { _, enabled in
                    if enabled {
                        RichPresenceServer.shared.start()
                    } else {
                        RichPresenceServer.shared.stop()
                    }
                }
        } footer: {
            Text("Lets games and apps that support Discord Rich Presence show what you're doing on your profile. If the official Discord app is also open, games connect to it instead.")
        }
    }
}
