import Foundation

/// Herdr socket 的請求層：每次請求開一條短連線，送一行、讀一行就關閉；
/// 訂閱則開一條專用長連線，訂閱成功後不再送任何東西。
///
/// 見 `docs/adr/0002-herdr-socket-api.md` 決策 1 與 2。
struct HerdrSocketClient: Sendable {
    let socketPath: String
    /// 短連線的讀寫逾時（秒）。
    var requestTimeout: TimeInterval = 5

    /// 預設 session 的 socket：`~/.config/herdr/herdr.sock`。
    /// 環境變數 `IDLEVILLAGER_HERDR_SOCKET` 可改用其他路徑（例如具名 session）。
    static var defaultSocketPath: String {
        if let override = ProcessInfo.processInfo.environment["IDLEVILLAGER_HERDR_SOCKET"], !override.isEmpty {
            return override
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/herdr/herdr.sock").path
    }

    /// 送出一個請求並解碼 `result`。錯誤回應以 `HerdrWire.RPCError` 丟出。
    func request<Result: Decodable & Sendable>(
        _ method: HerdrWire.Method,
        params: [String: any Sendable] = [:],
        as type: Result.Type
    ) async throws -> Result {
        let path = socketPath
        let timeout = requestTimeout
        let line = try HerdrWire.requestLine(id: "idlevillager-\(method.rawValue)", method: method, params: params)
        let responseLine = try await Self.runBlocking {
            let socket = try UnixLineSocket(path: path, timeout: timeout)
            defer { socket.cancel() }
            try socket.send(line)
            guard let response = try socket.readLine() else { throw HerdrTransportError.closedByPeer }
            return response
        }
        let response: HerdrWire.Response<Result>
        do {
            response = try HerdrWire.decode(HerdrWire.Response<Result>.self, from: responseLine)
        } catch {
            throw HerdrTransportError.malformedResponse
        }
        if let error = response.error { throw error }
        guard let result = response.result else { throw HerdrTransportError.malformedResponse }
        return result
    }

    /// 開一條訂閱連線，等到 `subscription_started` 才回傳。之後只讀不寫。
    func openSubscription(_ subscriptions: [HerdrSubscriptionPlan.Subscription]) async throws -> UnixLineSocket {
        let path = socketPath
        let timeout = requestTimeout
        let params: [String: any Sendable] = ["subscriptions": subscriptions.map(\.jsonObject)]
        let line = try HerdrWire.requestLine(id: "idlevillager-subscribe", method: .eventsSubscribe, params: params)
        return try await Self.runBlocking {
            let socket = try UnixLineSocket(path: path, timeout: timeout)
            do {
                try socket.send(line)
                guard let responseLine = try socket.readLine() else { throw HerdrTransportError.closedByPeer }
                let response = try? HerdrWire.decode(HerdrWire.Response<HerdrWire.TypedResult>.self, from: responseLine)
                if let error = response?.error { throw error }
                guard response?.result?.type == "subscription_started" else { throw HerdrTransportError.malformedResponse }
                // 訂閱中的連線不會被伺服器閒置關閉；之後的讀取不設逾時，由定期對帳偵測伺服器失聯。
                socket.setTimeout(0)
                return socket
            } catch {
                socket.cancel()
                throw error
            }
        }
    }

    /// 在背景執行緒執行阻塞的 socket 呼叫。
    static func runBlocking<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                continuation.resume(with: Result { try work() })
            }
        }
    }

    /// 在背景執行緒持續讀取訂閱連線，每一行交給 `stream`；連線關閉或被取消時結束串流。
    static func lines(from socket: UnixLineSocket) -> AsyncStream<Data> {
        AsyncStream { continuation in
            let thread = Thread {
                while true {
                    guard let line = try? socket.readLine() else { break }
                    if !line.isEmpty { continuation.yield(line) }
                }
                continuation.finish()
            }
            thread.name = "IdleVillager.HerdrSubscription"
            continuation.onTermination = { _ in socket.cancel() }
            thread.start()
        }
    }
}
