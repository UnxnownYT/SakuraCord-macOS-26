// Stand-ins for macOS 27 SDK APIs so the app builds with Xcode 26.
// Skipped automatically when building with Xcode 27 (Swift 6.4).
#if !compiler(>=6.4)
import AppKit

extension NSApplication {
    nonisolated struct DidBecomeActiveMessage: NotificationCenter.MainActorMessage {
        typealias Subject = NSApplication
        static var name: Notification.Name { NSApplication.didBecomeActiveNotification }
        static func makeMessage(_ notification: Notification) -> Self? { Self() }
    }
}
#endif
