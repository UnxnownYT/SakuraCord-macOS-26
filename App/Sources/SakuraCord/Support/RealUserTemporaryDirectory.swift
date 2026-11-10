import Foundation

/// Port: the sandbox points TMPDIR into the app container, but games look for
/// discord-ipc-N in the user's real temporary directory under /var/folders.
nonisolated func sakuraRealUserTemporaryDirectory() -> String? {
    let fileManager = FileManager.default
    let root = "/private/var/folders"
    let uid = getuid()
    guard let outer = try? fileManager.contentsOfDirectory(atPath: root) else { return nil }
    for first in outer {
        guard let inner = try? fileManager.contentsOfDirectory(atPath: "\(root)/\(first)") else { continue }
        for second in inner {
            let candidate = "\(root)/\(first)/\(second)/T"
            if let attributes = try? fileManager.attributesOfItem(atPath: candidate),
               (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == uid {
                return candidate
            }
        }
    }
    return nil
}
