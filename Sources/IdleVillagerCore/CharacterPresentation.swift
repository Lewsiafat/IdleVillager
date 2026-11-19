import Foundation

/// Agent 的品牌種類，決定角色本體要用哪個品牌圖層。
///
/// 品牌素材取得前，所有種類都以 Generic 小村民呈現；種類本身仍先辨識出來，留給品牌圖層使用。
public enum AgentKind: String, CaseIterable, Hashable, Sendable {
    case claude
    case codex
    case gemini
    case generic

    /// 由 Adapter 提供的 agentKind 原始字串對應。比對時大小寫不敏感，底線與連字號視為相同；無法對應者為 generic。
    public init(rawAgentKind: String) {
        let key = rawAgentKind.lowercased().replacingOccurrences(of: "_", with: "-")
        self = Self.rawAgentKindTable[key] ?? .generic
    }

    /// agentKind 原始字串到 Agent 種類的對應表（鍵為小寫、以連字號分隔）。
    private static let rawAgentKindTable: [String: AgentKind] = [
        "claude": .claude,
        "claude-code": .claude,
        "codex": .codex,
        "openai-codex": .codex,
        "gemini": .gemini,
        "gemini-cli": .gemini,
        "codex-cli": .codex,
    ]
}

/// 角色的靜態姿勢，每種正規化狀態恰好對應一種。
public enum CharacterPose: String, CaseIterable, Hashable, Sendable {
    /// 幹活：Working。
    case working
    /// 舉手：Needs Approval。
    case raisingHand
    /// 交工：Done。
    case delivering
    /// 躺平：Idle。
    case lyingDown
    /// 警示：Error。
    case alert
    /// 疑惑：Unknown。
    case puzzled
}

/// 狀態轉換時可選的一次性過渡。只描述「要播什麼」，動畫本身由 App 層實作。
public enum CharacterTransition: String, CaseIterable, Hashable, Sendable {
    /// Working 轉 Done 時慶祝一次，之後維持交工姿勢。
    case celebrateOnce
    /// 其他狀態轉 Idle 時緩慢過渡，不突然閃動。
    case slowToIdle

    /// 這種過渡的動畫參數。
    public var parameters: CharacterTransitionParameters {
        switch self {
        case .celebrateOnce:
            // 跳一下約 0.5 秒，播完維持交工姿勢。
            return CharacterTransitionParameters(duration: 0.5, jumpHeight: 0.15, startOpacity: 1)
        case .slowToIdle:
            // 約 0.8 秒緩慢淡入躺平姿勢，不跳、不閃動。
            return CharacterTransitionParameters(duration: 0.8, jumpHeight: 0, startOpacity: 0.5)
        }
    }
}

/// 一次性過渡的動畫參數。
public struct CharacterTransitionParameters: Hashable, Sendable {
    /// 過渡全長（秒），只播一次。一定大於 0，見 `noTransition`。
    public var duration: TimeInterval
    /// 跳起的高度（角色邊長的比例）；0 表示不跳。
    public var jumpHeight: Double
    /// 過渡開始時新姿勢的不透明度，之後在 `duration` 內回到 1；1 表示不淡入。
    public var startOpacity: Double

    public init(duration: TimeInterval, jumpHeight: Double, startOpacity: Double) {
        self.duration = duration
        self.jumpHeight = jumpHeight
        self.startOpacity = startOpacity
    }

    /// 沒有過渡時要播的那一段：不跳、不淡入，長度是很短的非零值。
    ///
    /// App 層的過渡動畫必須一直套著：如果沒有過渡時改成不套，view 結構會隨過渡有無而切換，
    /// 狀態改變當下新插入的動畫不會播放，Done 的慶祝跳躍就看不到。所以沒有過渡時也要播一段，只是看不出變化。
    ///
    /// 長度不能是 0：SwiftUI 的 keyframe 動畫以「經過時間 ÷ 全長」算進度，全長為 0 時進度是 NaN，
    /// 位移與不透明度跟著變成 NaN，清單列裡的 AppKit view 收到高度為 NaN 的 frame 就會讓整個 App 中止（issue #55）。
    public static let noTransition = CharacterTransitionParameters(duration: 0.001, jumpHeight: 0, startOpacity: 1)
}

/// 可由 SwiftUI 內建 Shape 畫出的簡單圖形。
public enum CharacterShape: String, CaseIterable, Hashable, Sendable {
    case circle
    case capsule
}

/// 單一圖層的圖形描述：SF Symbol 名稱或 SwiftUI Shape。
public enum CharacterLayer: Hashable, Sendable {
    case sfSymbol(String)
    case shape(CharacterShape)
}

/// 角色的六個圖層。`body` 一定存在；其他圖層為 nil 時表示該姿勢不畫這一層。
public struct CharacterLayers: Hashable, Sendable {
    /// 本體：品牌標誌，Generic 角色為圓形。不改色、不扭曲。
    public var body: CharacterLayer
    public var hands: CharacterLayer?
    public var feet: CharacterLayer?
    public var prop: CharacterLayer?
    public var face: CharacterLayer?
    public var effect: CharacterLayer?

    public init(
        body: CharacterLayer,
        hands: CharacterLayer?,
        feet: CharacterLayer?,
        prop: CharacterLayer?,
        face: CharacterLayer?,
        effect: CharacterLayer?
    ) {
        self.body = body
        self.hands = hands
        self.feet = feet
        self.prop = prop
        self.face = face
        self.effect = effect
    }
}

/// 角色的播放計畫：由正規化狀態推導出的靜態姿勢、圖層、品牌本體、循環動作與一次性過渡。
///
/// 這是純值，「角色該怎麼動」的判斷都在這裡；畫面只把它翻譯成動畫，不自行推論狀態或決定動畫參數。
/// 系統 Reduce Motion 開啟、使用者關閉動畫或角色不可見時，沒有循環也沒有過渡，畫面只畫靜態姿勢。
public struct CharacterPresentation: Hashable, Sendable {
    public var pose: CharacterPose
    public var layers: CharacterLayers
    /// 品牌本體；Agent 種類沒有品牌素材或素材不存在時為 `.generic`。品牌本體存在時取代 `layers.body` 的 Generic 圖形。
    public var brandBody: BrandBody
    /// 持續播放的循環動作；交工、警示、疑惑沒有循環，不允許動作時也為 nil。
    public var loop: CharacterLoop?
    /// 要播放一次的過渡；沒有過渡、沒有前一狀態或不允許動作時為 nil。
    public var transition: CharacterTransition?

    /// 一定合法的過渡參數：有過渡時是它的參數，沒有過渡時是不跳、不淡入、長度非零的 `noTransition`。
    /// App 層每次狀態改變都照這份參數播一次，不需要自己準備備援值。
    public var transitionParameters: CharacterTransitionParameters {
        transition?.parameters ?? .noTransition
    }

    /// - Parameters:
    ///   - state: 目前的正規化狀態。
    ///   - previousState: 前一個正規化狀態；第一次出現的 Session 為 nil，此時沒有過渡。
    ///   - reduceMotion: 系統 Reduce Motion 是否開啟。
    ///   - animationsEnabled: 使用者是否開啟動畫（`AppSettings.animationsEnabled`）；選單列的角色一律傳 false。
    ///   - isVisible: 角色目前是否看得到，例如 Popover 是否開著。看不到時不播動畫，避免在背景耗用 CPU。
    ///   - agentKind: Agent 種類，決定品牌本體。
    ///   - isBrandAssetAvailable: 查詢品牌資源是否存在；不存在時本體備援為 Generic。
    public init(
        state: NormalizedState,
        previousState: NormalizedState?,
        reduceMotion: Bool,
        animationsEnabled: Bool,
        isVisible: Bool,
        agentKind: AgentKind = .generic,
        isBrandAssetAvailable: (String) -> Bool = { _ in false }
    ) {
        let pose = Self.pose(for: state)
        let allowsMotion = animationsEnabled && isVisible && !reduceMotion
        self.pose = pose
        self.layers = Self.layers(for: pose)
        self.brandBody = BrandBody.resolve(agentKind: agentKind, isAssetAvailable: isBrandAssetAvailable)
        self.loop = allowsMotion ? Self.loop(for: pose) : nil
        self.transition = allowsMotion ? Self.transition(from: previousState, to: state) : nil
    }

    private static func pose(for state: NormalizedState) -> CharacterPose {
        switch state {
        case .working: return .working
        case .needsApproval: return .raisingHand
        case .done: return .delivering
        case .idle: return .lyingDown
        case .error: return .alert
        case .unknown: return .puzzled
        }
    }

    private static func transition(from previous: NormalizedState?, to state: NormalizedState) -> CharacterTransition? {
        guard let previous, previous != state else { return nil }
        if previous == .working && state == .done { return .celebrateOnce }
        if state == .idle { return .slowToIdle }
        return nil
    }

    private static func loop(for pose: CharacterPose) -> CharacterLoop? {
        switch pose {
        case .working: return .workingBob
        case .raisingHand: return .raisedHandSway
        case .lyingDown: return .idleZzz
        // Error 為靜態警示，不永久閃動；Unknown 不需動畫；交工只在過渡時跳一次。
        case .delivering, .alert, .puzzled: return nil
        }
    }

    /// 每種姿勢的完整靜態圖層。Error 與 Unknown 不使用旗子、星光等成功類圖像。
    private static func layers(for pose: CharacterPose) -> CharacterLayers {
        let body = CharacterLayer.shape(.circle)
        let hands = CharacterLayer.shape(.capsule)
        let feet = CharacterLayer.shape(.capsule)
        let eyes = CharacterLayer.sfSymbol("eyes")
        switch pose {
        case .working:
            return CharacterLayers(body: body, hands: hands, feet: feet,
                                   prop: .sfSymbol("hammer.fill"), face: eyes, effect: nil)
        case .raisingHand:
            return CharacterLayers(body: body, hands: .sfSymbol("hand.raised.fill"), feet: feet,
                                   prop: nil, face: eyes, effect: .sfSymbol("exclamationmark.bubble.fill"))
        case .delivering:
            return CharacterLayers(body: body, hands: hands, feet: feet,
                                   prop: .sfSymbol("flag.fill"), face: .sfSymbol("face.smiling"), effect: .sfSymbol("sparkles"))
        case .lyingDown:
            return CharacterLayers(body: body, hands: nil, feet: nil,
                                   prop: .sfSymbol("bed.double.fill"), face: .shape(.capsule), effect: .sfSymbol("zzz"))
        case .alert:
            return CharacterLayers(body: body, hands: hands, feet: feet,
                                   prop: nil, face: eyes, effect: .sfSymbol("exclamationmark.triangle.fill"))
        case .puzzled:
            return CharacterLayers(body: body, hands: hands, feet: feet,
                                   prop: nil, face: eyes, effect: .sfSymbol("questionmark"))
        }
    }
}
