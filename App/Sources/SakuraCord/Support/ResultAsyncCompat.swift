#if !compiler(>=6.4)
// Swift 6.4 adds an async Result(catching:); the macOS 26 toolchain only has the sync one.
extension Result where Failure == any Error {
    init(catching body: () async throws -> Success) async {
        do { self = .success(try await body()) } catch { self = .failure(error) }
    }
}
#endif
