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
}

/// 可由 SwiftUI 內建 Shape 畫出的簡單圖形。
public enum CharacterShape: String, CaseIterable, Hashable, Sendable {
    case circle
    case capsule
    case roundedRectangle
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

/// 由正規化狀態推導出的角色呈現：靜態姿勢、圖層與可選的一次性過渡。
///
/// 這是純值；畫面只依它繪製，不自行推論狀態。
public struct CharacterPresentation: Hashable, Sendable {
    public var pose: CharacterPose
    public var layers: CharacterLayers
    /// 一次性過渡；沒有過渡、沒有前一狀態或 Reduce Motion 開啟時為 nil。
    public var transition: CharacterTransition?
    /// 品牌本體；不帶 Agent 種類建立時為 `.generic`。品牌本體存在時取代 `layers.body` 的 Generic 圖形。
    public var brandBody: BrandBody = .generic

    /// - Parameters:
    ///   - state: 目前的正規化狀態。
    ///   - previousState: 前一個正規化狀態；第一次出現的 Session 為 nil，此時不輸出過渡。
    ///   - reduceMotion: 系統 Reduce Motion 是否開啟；開啟時只輸出靜態姿勢，過渡一律為 nil。
    public init(state: NormalizedState, previousState: NormalizedState?, reduceMotion: Bool) {
        let pose = Self.pose(for: state)
        self.pose = pose
        self.layers = Self.layers(for: pose)
        self.transition = reduceMotion ? nil : Self.transition(from: previousState, to: state)
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
