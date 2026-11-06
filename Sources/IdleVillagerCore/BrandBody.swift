import Foundation

/// 角色本體要畫成哪一種：品牌資產或 Generic 小村民。
///
/// 品牌本體只用來辨識 Agent 種類，不隨狀態改色或變形；狀態只由手、腳、道具、表情與特效圖層表現。
/// 素材檔不隨專案附帶，資產不存在時一律備援為 `.generic`，不顯示破圖。
public enum BrandBody: Hashable, Sendable {
    /// 品牌資產，`name` 是 App bundle 內的資源名稱（不含副檔名），例如 `claude-logo`。
    case asset(name: String)
    /// Generic 小村民本體（圓形），也是素材缺席時的備援。
    case generic

    /// 每種 Agent 種類對應的品牌資源名稱；generic 沒有品牌資源。
    public static func assetName(for agentKind: AgentKind) -> String? {
        switch agentKind {
        case .claude: return "claude-logo"
        case .codex: return "codex-logo"
        case .gemini: return "gemini-logo"
        case .generic: return nil
        }
    }

    /// 決定角色本體：該種類有品牌資源名稱、且 `isAssetAvailable` 回報資源存在時用 `.asset`，否則備援為 `.generic`。
    ///
    /// - Parameters:
    ///   - agentKind: Agent 種類。
    ///   - isAssetAvailable: 查詢某個資源名稱是否存在的函式，由 App 層以 bundle 查找實作，測試可自行注入。
    public static func resolve(agentKind: AgentKind, isAssetAvailable: (String) -> Bool) -> BrandBody {
        guard let name = assetName(for: agentKind), isAssetAvailable(name) else { return .generic }
        return .asset(name: name)
    }
}

/// 依角色尺寸決定要畫多少圖層。
///
/// 16 到 18 pt 的小尺寸只畫主標誌（本體），省略手、腳、道具、表情與特效，讓品牌標誌仍可辨識。
public enum CharacterDetail: Hashable, Sendable {
    /// 畫全部六個圖層。
    case full
    /// 只畫本體。
    case bodyOnly

    /// 只畫本體的最大尺寸（pt，含）。
    public static let bodyOnlyMaxSize: Double = 18

    public init(size: Double) {
        self = size <= Self.bodyOnlyMaxSize ? .bodyOnly : .full
    }

    /// 是否畫本體以外的圖層（手、腳、道具、表情、特效）。
    public var drawsOuterLayers: Bool { self == .full }
}

extension CharacterPresentation {
    /// 帶 Agent 種類的角色呈現：姿勢、圖層與過渡和不帶種類時完全相同，只多決定品牌本體。
    ///
    /// - Parameters:
    ///   - agentKind: Agent 種類。
    ///   - isBrandAssetAvailable: 查詢品牌資源是否存在；不存在時本體備援為 Generic。
    public init(
        state: NormalizedState,
        previousState: NormalizedState?,
        reduceMotion: Bool,
        agentKind: AgentKind,
        isBrandAssetAvailable: (String) -> Bool
    ) {
        self.init(state: state, previousState: previousState, reduceMotion: reduceMotion)
        self.brandBody = BrandBody.resolve(agentKind: agentKind, isAssetAvailable: isBrandAssetAvailable)
    }
}
