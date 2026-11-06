import Foundation
import os

/// 透過 Herdr 本機 Unix domain socket 取得 Agent Session 的真實 Adapter。
///
/// 依 `docs/adr/0002-herdr-socket-api.md` 實作，該紀錄的驗證結果是本 Adapter 回報 `SourceDescription.herdr` 的依據。
///
/// - 請求連線：`ping`、`session.snapshot`、`agent.get`、`agent.focus` 各開一條短連線，送完即關。
/// - 訂閱連線：一條專用長連線，訂閱全部生命週期事件與每個已知 Agent Pane 的 `pane.agent_status_changed`；
///   訂閱成功後不再送任何請求。Agent Pane 集合改變時開新連線，成功後才關閉舊的。
/// - 對帳快照：每 30 秒、收到生命週期事件或訂閱連線中斷時重新取快照，與前一份比對後合成事件。
///   訂閱連線中斷時只靠對帳快照，並以 1、2、4、8、16、30 秒退避重試訂閱。
/// - 只讀 metadata；不呼叫 `agent.read`、`pane.read`、`agent.prompt`、`pane.send_*`。日誌只記事件種類、連線狀態與 ID。
public actor HerdrSocketAdapter: HerdrAdapter {
    public nonisolated let sourceDescription = SourceDescription.herdr
    public nonisolated let events: AsyncStream<AdapterEvent>
    private nonisolated let continuation: AsyncStream<AdapterEvent>.Continuation

    /// 對帳快照的間隔（秒）。
    public static let reconcileInterval: TimeInterval = 30
    /// 本 Adapter 驗證時的 Herdr protocol 版本。
    public static let verifiedProtocol = 22

    private let client: HerdrSocketClient
    private let activator: any TerminalActivator
    private let logger = Logger(subsystem: "IdleVillager", category: "HerdrAdapter")

    /// 最近一次送給上層（快照或事件）的 Session，對帳比對的基準。nil 表示還沒有成功取得過快照。
    private var known: [AgentSession]?
    /// 最近一次回報的連線狀態。nil 表示還沒回報過。
    private var reportedState: ConnectionState?
    private var lastReconcileAt: Date?

    private var subscription: UnixLineSocket?
    private var subscribedPanes: Set<PaneID> = []
    private var subscriptionGeneration = 0
    private var subscriptionBackoff = HerdrBackoff()
    private var nextSubscriptionAttempt: Date = .distantPast

    private var connectionBackoff = HerdrBackoff()
    private var reconcileRequested = false
    private var runTask: Task<Void, Never>?
    private var wakeContinuation: CheckedContinuation<Void, Never>?
    private var sleepToken = 0

    /// - Parameters:
    ///   - socketPath: Herdr socket 路徑，預設 `~/.config/herdr/herdr.sock`。
    ///   - activator: 聚焦成功後把終端機 App 帶到前景的實作。
    public init(socketPath: String? = nil, activator: any TerminalActivator) {
        self.client = HerdrSocketClient(socketPath: socketPath ?? HerdrSocketClient.defaultSocketPath)
        self.activator = activator
        (events, continuation) = AsyncStream.makeStream(of: AdapterEvent.self)
    }

    // MARK: - HerdrAdapter

    public func snapshot() async throws -> SessionSnapshot {
        startIfNeeded()
        do {
            let sessions = try await fetchSessions()
            known = sessions
            lastReconcileAt = Date()
            markReachable(emitConnected: false)
            wake()
            return SessionSnapshot(sessions: sessions)
        } catch {
            handleFailure(error)
            throw error
        }
    }

    public func focus(sessionID: AgentSessionID, paneID: PaneID) async -> FocusResult {
        let target: [String: any Sendable] = ["target": paneID.rawValue]
        do {
            let current = try await client.request(.agentGet, params: target, as: HerdrWire.AgentResult.self)
            // Pane id 關閉後不重用；若同一 Pane 上已是別的終端，視為原目標不存在。
            guard current.agent.terminalID == sessionID.rawValue else {
                logger.info("focus target mismatch pane=\(paneID.rawValue, privacy: .public)")
                return .failure(.targetNotFound)
            }
            let focused = try await client.request(.agentFocus, params: target, as: HerdrWire.AgentResult.self)
            guard focused.agent.focused else {
                logger.info("focus not confirmed pane=\(paneID.rawValue, privacy: .public)")
                return .failure(.unsupported)
            }
        } catch let error as HerdrWire.RPCError where error.code == HerdrWire.RPCError.agentNotFound {
            logger.info("focus target not found pane=\(paneID.rawValue, privacy: .public)")
            return .failure(.targetNotFound)
        } catch HerdrTransportError.unreachable {
            handleFailure(HerdrTransportError.unreachable)
            return .failure(.disconnected)
        } catch {
            logger.error("focus request failed pane=\(paneID.rawValue, privacy: .public) error=\(Self.describe(error), privacy: .public)")
            return .failure(.disconnected)
        }

        let ancestries = HerdrClientProcessLocator.clientAncestries()
        guard !ancestries.isEmpty, await activator.activate(processAncestries: ancestries) else {
            logger.info("terminal app not brought to front clients=\(ancestries.count, privacy: .public)")
            return .failure(.windowNotBroughtToFront)
        }
        logger.info("focused pane=\(paneID.rawValue, privacy: .public)")
        return .success
    }

    // MARK: - 主迴圈

    private func startIfNeeded() {
        guard runTask == nil else { return }
        runTask = Task { [weak self] in await self?.run() }
    }

    /// 停止背景迴圈並關閉訂閱連線。App 結束時不需要呼叫；主要給測試或替換 Adapter 時使用。
    public func stop() {
        runTask?.cancel()
        runTask = nil
        closeSubscription()
        wake()
        continuation.finish()
    }

    private func run() async {
        while !Task.isCancelled {
            let now = Date()
            let reconcileDue = lastReconcileAt.map { now.timeIntervalSince($0) >= Self.reconcileInterval } ?? true
            if reconcileRequested || reconcileDue || reportedState != .connected {
                reconcileRequested = false
                await reconcile()
            }

            var wait: TimeInterval
            if reportedState == .connected {
                connectionBackoff.reset()
                await ensureSubscription()
                let untilReconcile = max(0.1, Self.reconcileInterval - Date().timeIntervalSince(lastReconcileAt ?? Date()))
                wait = untilReconcile
                if subscription == nil {
                    wait = min(wait, max(0.1, nextSubscriptionAttempt.timeIntervalSinceNow))
                }
            } else {
                wait = connectionBackoff.next()
            }
            await sleep(seconds: wait)
        }
    }

    /// 對帳快照：重新取快照並與基準比對，送出合成事件。
    private func reconcile() async {
        do {
            let sessions = try await fetchSessions()
            lastReconcileAt = Date()
            let wasConnected = reportedState == .connected
            if wasConnected, let known {
                let diff = HerdrSnapshotDiff.events(from: known, to: sessions)
                for event in diff { continuation.yield(event) }
                logDiff(diff)
            }
            self.known = sessions
            if !wasConnected { await checkProtocol() }
            // 從斷線恢復時送 connected，Store 會自己重新讀一次完整快照。
            markReachable(emitConnected: true)
        } catch {
            handleFailure(error)
        }
    }

    private func fetchSessions() async throws -> [AgentSession] {
        let result = try await client.request(.sessionSnapshot, as: HerdrWire.SnapshotResult.self)
        return HerdrSnapshotMapper.sessions(from: result.snapshot, receivedAt: Date())
    }

    private func checkProtocol() async {
        guard let pong = try? await client.request(.ping, as: HerdrWire.PingResult.self) else { return }
        if let version = pong.protocol, version != Self.verifiedProtocol {
            logger.warning("herdr protocol \(version, privacy: .public) differs from verified \(Self.verifiedProtocol, privacy: .public)")
        }
    }

    // MARK: - 連線狀態

    private func markReachable(emitConnected: Bool) {
        let previous = reportedState
        reportedState = .connected
        guard previous != .connected else { return }
        logger.info("connection connected")
        if emitConnected, previous != nil { continuation.yield(.connectionChanged(.connected)) }
    }

    /// Socket 不存在或被拒為 disconnected；曾經連上後的其他失敗（逾時、意外關閉）為 reconnecting。
    private func handleFailure(_ error: any Error) {
        let state: ConnectionState
        if case HerdrTransportError.unreachable = error {
            state = .disconnected
        } else {
            state = reportedState == nil || reportedState == .disconnected ? .disconnected : .reconnecting
        }
        closeSubscription()
        guard reportedState != state else { return }
        reportedState = state
        logger.info("connection \(String(describing: state), privacy: .public) error=\(Self.describe(error), privacy: .public)")
        continuation.yield(.connectionChanged(state))
    }

    // MARK: - 訂閱連線

    private func ensureSubscription() async {
        guard let known else { return }
        let panes = HerdrSnapshotMapper.agentPaneIDs(in: known)
        if subscription != nil, panes == subscribedPanes { return }
        guard Date() >= nextSubscriptionAttempt || subscription != nil else { return }

        do {
            let socket = try await client.openSubscription(HerdrSubscriptionPlan.subscriptions(agentPaneIDs: panes))
            // 新連線訂閱成功後才關閉舊連線，避免中間漏接事件。
            let old = subscription
            subscriptionGeneration += 1
            subscription = socket
            subscribedPanes = panes
            subscriptionBackoff.reset()
            old?.cancel()
            logger.info("subscription started panes=\(panes.map(\.rawValue).sorted().joined(separator: ","), privacy: .public)")
            consume(socket, generation: subscriptionGeneration)
        } catch {
            let delay = subscriptionBackoff.next()
            nextSubscriptionAttempt = Date().addingTimeInterval(delay)
            logger.info("subscription failed retry=\(delay, privacy: .public)s error=\(Self.describe(error), privacy: .public)")
            if case HerdrTransportError.unreachable = error { handleFailure(error) }
        }
    }

    private func consume(_ socket: UnixLineSocket, generation: Int) {
        let lines = HerdrSocketClient.lines(from: socket)
        Task { [weak self] in
            for await line in lines {
                await self?.handleSubscriptionLine(line, generation: generation)
            }
            await self?.subscriptionEnded(generation: generation)
        }
    }

    private func handleSubscriptionLine(_ line: Data, generation: Int) {
        guard generation == subscriptionGeneration else { return }
        guard let envelope = try? HerdrWire.decode(HerdrWire.EventEnvelope.self, from: line) else { return }
        let knownPanes = known.map(HerdrSnapshotMapper.agentPaneIDs(in:)) ?? []
        switch HerdrEventAction.classify(envelope, knownAgentPanes: knownPanes) {
        case .stateChanged(let paneID, let rawState):
            guard var sessions = known, let index = sessions.firstIndex(where: { $0.paneID == paneID }) else {
                requestReconcile()
                return
            }
            let now = Date()
            sessions[index].rawState = rawState
            sessions[index].updatedAt = now
            known = sessions
            let id = sessions[index].agentSessionID
            logger.info("event \(envelope.event, privacy: .public) pane=\(paneID.rawValue, privacy: .public) status=\(rawState, privacy: .public)")
            continuation.yield(.sessionStateChanged(id, rawState: rawState, stateSource: .explicitEvent, updatedAt: now))
        case .resnapshot:
            logger.info("event \(envelope.event, privacy: .public) pane=\(envelope.data.paneID ?? "-", privacy: .public)")
            requestReconcile()
        case .ignore:
            break
        }
    }

    private func subscriptionEnded(generation: Int) {
        guard generation == subscriptionGeneration, subscription != nil else { return }
        logger.info("subscription closed by server")
        subscription = nil
        subscribedPanes = []
        nextSubscriptionAttempt = Date().addingTimeInterval(subscriptionBackoff.next())
        // 立刻對帳，確認伺服器是否還在，並補上可能漏掉的變更。
        requestReconcile()
    }

    private func closeSubscription() {
        guard let socket = subscription else { return }
        subscriptionGeneration += 1
        subscription = nil
        subscribedPanes = []
        socket.cancel()
    }

    // MARK: - 睡眠與喚醒

    private func requestReconcile() {
        reconcileRequested = true
        wake()
    }

    private func sleep(seconds: TimeInterval) async {
        if reconcileRequested || Task.isCancelled { return }
        sleepToken += 1
        let token = sleepToken
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            wakeContinuation = continuation
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(seconds))
                await self?.wake(token: token)
            }
        }
    }

    /// 喚醒主迴圈。帶 `token` 時只在它仍是目前這次睡眠才生效，避免舊計時器提早喚醒下一次睡眠。
    private func wake(token: Int? = nil) {
        if let token, token != sleepToken { return }
        guard let wakeContinuation else { return }
        self.wakeContinuation = nil
        wakeContinuation.resume()
    }

    // MARK: - 日誌

    private func logDiff(_ events: [AdapterEvent]) {
        for event in events {
            switch event {
            case .sessionAdded(let session):
                logger.info("session added or updated id=\(session.agentSessionID.rawValue, privacy: .public) pane=\(session.paneID.rawValue, privacy: .public)")
            case .sessionRemoved(let id):
                logger.info("session removed id=\(id.rawValue, privacy: .public)")
            default:
                break
            }
        }
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case let rpc as HerdrWire.RPCError: "rpc:\(rpc.code)"
        case let transport as HerdrTransportError: "transport:\(transport)"
        default: "other"
        }
    }
}
