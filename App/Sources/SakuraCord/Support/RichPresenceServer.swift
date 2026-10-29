import Darwin
import DiscordProtocol
import Foundation
import os

/// Listens on `discord-ipc-N` like the official client, so games and apps that
/// support Discord Rich Presence can set the current user's activity.
nonisolated final class RichPresenceServer: @unchecked Sendable {
    static let shared = RichPresenceServer()
    static let enabledKey = "dev.sakuracord.richPresence.enabled"

    private let queue = DispatchQueue(label: "dev.sakuracord.rich-presence")
    private let logger = Logger(subsystem: "dev.sakuracord.SakuraCord", category: "RichPresence")
    private var listenFD: Int32 = -1
    private var listenSource: DispatchSourceRead?
    private var socketPath: String?
    private var clients: [Int32: Client] = [:]
    private var activeFD: Int32?
    private var sink: (@Sendable (RichPresenceActivity?) -> Void)?
    private var lastPublished: RichPresenceActivity?
    private var applicationNames: [String: String] = [:]
    private var applicationAssets: [String: [String: String]] = [:]

    private nonisolated final class Client {
        let source: DispatchSourceRead
        var buffer = Data()
        var clientID: String?
        var activity: RichPresenceActivity?
        var generation = 0
        init(source: DispatchSourceRead) { self.source = source }
    }

    /// Sends activities to `model`'s current account and starts listening if enabled.
    func attach(_ model: AppModel) {
        let sink: @Sendable (RichPresenceActivity?) -> Void = { activity in
            Task { @MainActor in await model.setRichPresenceActivity(activity) }
        }
        queue.async {
            self.sink = sink
            if UserDefaults.standard.bool(forKey: Self.enabledKey) { self.startOnQueue() }
            if let lastPublished = self.lastPublished { sink(lastPublished) }
        }
    }

    func start() { queue.async { self.startOnQueue() } }
    func stop() { queue.async { self.stopOnQueue() } }

    // MARK: - Listening socket

    private func startOnQueue() {
        guard listenFD < 0 else { return }
        let directory = Self.userTemporaryDirectory()
        for index in 0 ..< 10 {
            let path = directory + "discord-ipc-\(index)"
            // The official client, or another instance, already owns this one.
            if Self.isSocketInUse(path) { continue }
            unlink(path)
            guard let fd = Self.makeListeningSocket(path: path) else { continue }
            listenFD = fd
            socketPath = path
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.acceptClients() }
            source.setCancelHandler { close(fd) }
            source.resume()
            listenSource = source
            logger.notice("Rich Presence listening at \(path, privacy: .public)")
            return
        }
        logger.error("Rich Presence could not listen in \(directory, privacy: .public)")
    }

    private func stopOnQueue() {
        for fd in Array(clients.keys) { closeClient(fd) }
        listenSource?.cancel()
        listenSource = nil
        listenFD = -1
        if let socketPath { unlink(socketPath) }
        socketPath = nil
        publish(nil)
    }

    private func acceptClients() {
        while true {
            let fd = accept(listenFD, nil, nil)
            guard fd >= 0 else { return }
            _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
            var noSigPipe: Int32 = 1
            _ = setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))
            let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: queue)
            source.setEventHandler { [weak self] in self?.readClient(fd) }
            source.setCancelHandler { close(fd) }
            clients[fd] = Client(source: source)
            source.resume()
        }
    }

    // MARK: - Framing (8-byte little-endian header: opcode, length; then JSON)

    private func readClient(_ fd: Int32) {
        guard let client = clients[fd] else { return }
        var chunk = [UInt8](repeating: 0, count: 65_536)
        let count = read(fd, &chunk, chunk.count)
        if count <= 0 {
            if count < 0, errno == EAGAIN { return }
            closeClient(fd)
            return
        }
        client.buffer.append(contentsOf: chunk[0 ..< count])
        while client.buffer.count >= 8 {
            let opcode = Self.uint32(client.buffer, at: 0)
            let length = Int(Self.uint32(client.buffer, at: 4))
            guard length <= 1_048_576 else { closeClient(fd); return }
            guard client.buffer.count >= 8 + length else { break }
            let start = client.buffer.startIndex + 8
            let payload = client.buffer.subdata(in: start ..< start + length)
            client.buffer = Data(client.buffer.dropFirst(8 + length))
            handle(opcode: opcode, payload: payload, from: fd)
            guard clients[fd] != nil else { return }
        }
    }

    private func handle(opcode: UInt32, payload: Data, from fd: Int32) {
        let json = (try? JSONSerialization.jsonObject(with: payload)) as? [String: Any] ?? [:]
        switch opcode {
        case 0: // Handshake
            guard let clientID = json["client_id"] as? String ?? (json["client_id"] as? NSNumber)?.stringValue
            else { closeClient(fd); return }
            clients[fd]?.clientID = clientID
            let user: [String: Any] = [
                "id": "0", "username": "SakuraCord", "discriminator": "0",
                "global_name": "SakuraCord", "avatar": NSNull(), "bot": false, "flags": 0, "premium_type": 0,
            ]
            let config: [String: Any] = [
                "cdn_host": "cdn.discordapp.com", "api_endpoint": "//discord.com/api", "environment": "production",
            ]
            send(opcode: 1, [
                "cmd": "DISPATCH", "evt": "READY", "nonce": NSNull(),
                "data": ["v": 1, "config": config, "user": user] as [String: Any],
            ], to: fd)
        case 1: // Frame
            handleCommand(json, from: fd)
        case 2: // Close
            closeClient(fd)
        case 3: // Ping
            sendRaw(opcode: 4, payload, to: fd)
        default:
            break
        }
    }

    private func handleCommand(_ json: [String: Any], from fd: Int32) {
        let command = json["cmd"] as? String ?? ""
        let nonce: Any = json["nonce"] ?? NSNull()
        guard command == "SET_ACTIVITY" else {
            // Answer other commands so clients waiting on a reply carry on.
            send(opcode: 1, ["cmd": command, "data": NSNull(), "evt": NSNull(), "nonce": nonce], to: fd)
            return
        }
        let args = json["args"] as? [String: Any] ?? [:]
        let activityJSON = args["activity"] as? [String: Any]
        send(opcode: 1, [
            "cmd": command, "data": activityJSON.map { $0 as Any } ?? NSNull(), "evt": NSNull(), "nonce": nonce,
        ], to: fd)
        guard let client = clients[fd], let clientID = client.clientID else { return }
        client.generation += 1
        let generation = client.generation
        guard let activityJSON else {
            client.activity = nil
            publishCurrent()
            return
        }
        resolve(Self.activity(from: activityJSON, applicationID: clientID)) { [weak self] resolved in
            guard let self, let client = self.clients[fd], client.generation == generation else { return }
            client.activity = resolved
            self.activeFD = fd
            self.publishCurrent()
        }
    }

    // MARK: - Activities

    private static func activity(from json: [String: Any], applicationID: String) -> RichPresenceActivity {
        let timestamps = json["timestamps"] as? [String: Any]
        let assets = json["assets"] as? [String: Any]
        let party = json["party"] as? [String: Any]
        let buttons = json["buttons"] as? [[String: Any]] ?? []
        return RichPresenceActivity(
            applicationID: applicationID,
            type: (json["type"] as? NSNumber)?.intValue ?? 0,
            details: json["details"] as? String,
            state: json["state"] as? String,
            startMilliseconds: milliseconds(timestamps?["start"]),
            endMilliseconds: milliseconds(timestamps?["end"]),
            largeImage: assets?["large_image"] as? String,
            largeText: assets?["large_text"] as? String,
            smallImage: assets?["small_image"] as? String,
            smallText: assets?["small_text"] as? String,
            buttonLabels: buttons.compactMap { $0["label"] as? String },
            buttonURLs: buttons.compactMap { $0["url"] as? String },
            partyID: party?["id"] as? String,
            partySize: (party?["size"] as? [NSNumber])?.map(\.intValue)
        )
    }

    /// RPC clients send seconds or milliseconds; the Gateway wants milliseconds.
    private static func milliseconds(_ value: Any?) -> Int64? {
        guard let number = (value as? NSNumber)?.int64Value, number > 0 else { return nil }
        return number < 100_000_000_000 ? number * 1000 : number
    }

    /// Fills in the application's name and turns asset keys into asset IDs,
    /// using Discord's public application endpoints.
    private func resolve(
        _ activity: RichPresenceActivity,
        completion: @escaping @Sendable (RichPresenceActivity) -> Void
    ) {
        let id = activity.applicationID
        if let name = applicationNames[id], let assets = applicationAssets[id] {
            completion(Self.applying(name: name, assets: assets, to: activity))
            return
        }
        fetchData("https://discord.com/api/v9/applications/\(id)/rpc") { [weak self] nameData in
            guard let self else { return }
            let name = (nameData.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any])?["name"] as? String
            self.fetchData("https://discord.com/api/v9/oauth2/applications/\(id)/assets") { [weak self] assetData in
                guard let self else { return }
                var assets: [String: String] = [:]
                let list = assetData.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [[String: Any]] ?? []
                for asset in list {
                    if let key = asset["name"] as? String, let assetID = asset["id"] as? String { assets[key] = assetID }
                }
                if let name {
                    self.applicationNames[id] = name
                    self.applicationAssets[id] = assets
                }
                completion(Self.applying(name: name ?? "Game", assets: assets, to: activity))
            }
        }
    }

    private static func applying(
        name: String,
        assets: [String: String],
        to activity: RichPresenceActivity
    ) -> RichPresenceActivity {
        var activity = activity
        activity.name = name
        activity.largeImage = imageID(activity.largeImage, assets: assets)
        activity.smallImage = imageID(activity.smallImage, assets: assets)
        return activity
    }

    /// Asset keys become IDs. External image URLs need an authenticated proxy
    /// request, so they are left out for now.
    private static func imageID(_ key: String?, assets: [String: String]) -> String? {
        guard let key, !key.isEmpty else { return nil }
        if key.hasPrefix("mp:") || key.allSatisfy(\.isNumber) { return key }
        return assets[key]
    }

    private func fetchData(_ urlString: String, completion: @escaping @Sendable (Data?) -> Void) {
        guard let url = URL(string: urlString) else {
            queue.async { completion(nil) }
            return
        }
        let queue = queue
        URLSession.shared.dataTask(with: url) { data, response, _ in
            let succeeded = (response as? HTTPURLResponse).map { (200 ..< 300).contains($0.statusCode) } ?? false
            queue.async { completion(succeeded ? data : nil) }
        }.resume()
    }

    private func publishCurrent() {
        if let activeFD, let activity = clients[activeFD]?.activity {
            publish(activity)
        } else {
            publish(clients.values.lazy.compactMap(\.activity).first)
        }
    }

    private func publish(_ activity: RichPresenceActivity?) {
        guard activity != lastPublished else { return }
        lastPublished = activity
        logger.notice("Rich Presence activity: \(activity?.name ?? "none", privacy: .public) / \(activity?.details ?? "", privacy: .public)")
        sink?(activity)
    }

    private func closeClient(_ fd: Int32) {
        guard let client = clients.removeValue(forKey: fd) else { return }
        client.source.cancel()
        if activeFD == fd { activeFD = nil }
        publishCurrent()
    }

    // MARK: - Sending

    private func send(opcode: UInt32, _ object: [String: Any], to fd: Int32) {
        guard let data = try? JSONSerialization.data(withJSONObject: object) else { return }
        sendRaw(opcode: opcode, data, to: fd)
    }

    private func sendRaw(opcode: UInt32, _ payload: Data, to fd: Int32) {
        var frame = Data()
        withUnsafeBytes(of: opcode.littleEndian) { frame.append(contentsOf: $0) }
        withUnsafeBytes(of: UInt32(payload.count).littleEndian) { frame.append(contentsOf: $0) }
        frame.append(payload)
        frame.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let written = write(fd, base.advanced(by: offset), raw.count - offset)
                guard written > 0 else { return }
                offset += written
            }
        }
    }

    // MARK: - Helpers

    private static func uint32(_ data: Data, at offset: Int) -> UInt32 {
        let start = data.startIndex + offset
        let b0 = UInt32(data[start])
        let b1 = UInt32(data[start + 1]) << 8
        let b2 = UInt32(data[start + 2]) << 16
        let b3 = UInt32(data[start + 3]) << 24
        return b0 | b1 | b2 | b3
    }

    /// The per-user temporary folder games use (`/var/folders/…/T/`), not the
    /// sandbox container's own temporary folder.
    private static func userTemporaryDirectory() -> String {
        var buffer = [CChar](repeating: 0, count: Int(PATH_MAX))
        var path = confstr(_CS_DARWIN_USER_TEMP_DIR, &buffer, buffer.count) > 0
            ? String(cString: buffer) : "/tmp/"
        if !path.hasSuffix("/") { path += "/" }
        if let bundleID = Bundle.main.bundleIdentifier, path.hasSuffix("/\(bundleID)/") {
            path = String(path.dropLast(bundleID.count + 1))
        }
        if path.contains("/Library/Containers/"), let real = realUserTemporaryDirectory() {
            return real
        }
        return path
    }

    /// Inside the sandbox the system reports the container's folder, so find
    /// this user's `/var/folders/xx/…/T/` by ownership instead.
    private static func realUserTemporaryDirectory() -> String? {
        let fileManager = FileManager.default
        let root = "/private/var/folders/"
        let uid = getuid()
        guard let buckets = try? fileManager.contentsOfDirectory(atPath: root) else { return nil }
        var best: (path: String, modified: Int)?
        for bucket in buckets {
            guard let entries = try? fileManager.contentsOfDirectory(atPath: root + bucket) else { continue }
            for entry in entries {
                let temporary = root + bucket + "/" + entry + "/T/"
                var info = stat()
                guard stat(temporary, &info) == 0, info.st_uid == uid else { continue }
                let modified = Int(info.st_mtimespec.tv_sec)
                if best == nil || modified > best!.modified { best = (temporary, modified) }
            }
        }
        return best?.path
    }

    private static func socketAddress(_ path: String) -> sockaddr_un? {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { return nil }
        withUnsafeMutableBytes(of: &address.sun_path) { $0.copyBytes(from: bytes) }
        return address
    }

    private static func makeListeningSocket(path: String) -> Int32? {
        guard var address = socketAddress(path) else { return nil }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return nil }
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, listen(fd, 8) == 0 else {
            close(fd)
            return nil
        }
        _ = fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK)
        return fd
    }

    private static func isSocketInUse(_ path: String) -> Bool {
        guard var address = socketAddress(path) else { return false }
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        return withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size)) == 0
            }
        }
    }
}
