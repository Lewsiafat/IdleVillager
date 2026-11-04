import AppKit
import SwiftUI
import IdleVillagerCore

/// 少量角色模式的選單列內容：每個 Session 一個靜態小村民，後面接狀態圖示。
///
/// 完全依 `MenuBarCharacterItem` 繪製，不自行推論狀態或排序。角色固定 16 pt（`CharacterDetail` 為只畫本體），
/// 不播放動畫；狀態圖示（⚒ ✋ ✓ 💤 ! ?）與角色並列，因此狀態不只靠角色或顏色辨識。
///
/// `MenuBarExtra` 的 label 只可靠地呈現單一圖片或文字，所以整排內容先以 `ImageRenderer` 畫成一張圖片。
/// 沒有使用品牌素材時以 template 圖片呈現，讓系統依選單列外觀自動套用明暗色；
/// 有品牌素材時保留原色，避免改動品牌標誌。
struct MenuBarCharactersLabel: View {
    let items: [MenuBarCharacterItem]

    /// 選單列角色的邊長（pt），落在規格要求的 16 到 18 pt 之間。
    static let characterSize: CGFloat = 16

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: renderedImage)
            .accessibilityLabel(Self.accessibilityText(for: items))
    }

    private var renderedImage: NSImage {
        let renderer = ImageRenderer(content: MenuBarCharactersRow(items: items))
        renderer.scale = displayScale
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = !usesBrandAsset
        return image
    }

    private var usesBrandAsset: Bool {
        items.contains { item in
            BrandBody.resolve(agentKind: item.agentKind, isAssetAvailable: BrandAssetCatalog.isAvailable) != .generic
        }
    }

    /// 依序列出每個 Agent 的種類與狀態，例如「Codex 等待核准，Claude 工作中」。
    static func accessibilityText(for items: [MenuBarCharacterItem]) -> String {
        items.map { "\(kindName($0.agentKind)) \(stateName($0.normalizedState))" }.joined(separator: "，")
    }

    private static func kindName(_ kind: AgentKind) -> String {
        switch kind {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .generic: "Agent"
        }
    }

    private static func stateName(_ state: NormalizedState) -> String {
        switch state {
        case .working: "工作中"
        case .needsApproval: "等待核准"
        case .done: "已完成"
        case .idle: "閒置"
        case .error: "錯誤"
        case .unknown: "未知"
        }
    }
}

/// 實際排版的一排角色與狀態圖示，只供 `ImageRenderer` 繪製。
private struct MenuBarCharactersRow: View {
    let items: [MenuBarCharacterItem]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 1) {
                    CharacterView(
                        state: item.normalizedState,
                        agentKind: item.agentKind,
                        size: MenuBarCharactersLabel.characterSize,
                        animationsEnabled: false  // 選單列不播動畫
                    )
                    Text(item.icon)
                        .font(.system(size: 12))
                }
            }
        }
        .frame(height: 18)
    }
}
