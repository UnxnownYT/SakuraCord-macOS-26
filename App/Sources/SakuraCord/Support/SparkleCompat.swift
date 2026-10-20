import Sparkle

// SakuraCord's Sparkle fork can install a specific build version. Upstream
// Sparkle 2.9.6 can't, so fall back to a normal update check. Updates are
// disabled in macOS 26 builds, so this path is not normally reached.
extension SPUUpdater {
    func checkForUpdates<Version>(forVersion version: Version) throws {
        checkForUpdates()
    }
}
