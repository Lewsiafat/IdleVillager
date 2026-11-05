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
///
/// 低干擾提醒進行中時（`menuBarAlertEmphasis` 為 `.emphasized`），待核准的角色在產圖時加上圓角外框、
/// 狀態圖示改為粗體；哪些角色要強調由 `MenuBarCharacterItem.isHighlighted(during:)` 決定。
/// 外框只是額外提示，狀態仍由 ✋ 圖示表達。
struct MenuBarCharactersLabel: View {
    let items: [MenuBarCharacterItem]

    /// 選單列角色的邊長（pt），落在規格要求的 16 到 18 pt 之間。
    static let characterSize: CGFloat = 16

    @Environment(\.displayScale) private var displayScale
    @Environment(\.menuBarAlertEmphasis) private var emphasis

    var body: some View {
        Image(nsImage: renderedImage)
            .accessibilityLabel(Self.accessibilityText(for: items))
    }

    private var renderedImage: NSImage {
        let renderer = ImageRenderer(content: MenuBarCharactersRow(items: items, emphasis: emphasis))
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

    /// 依序列出每個 Agent 的種類與狀態，例如「Codex 等核准，Claude 幹活中」。狀態用字與清單相同（`NormalizedState.shortText`）。
    static func accessibilityText(for items: [MenuBarCharacterItem]) -> String {
        items.map { "\(kindName($0.agentKind)) \($0.normalizedState.shortText)" }.joined(separator: "，")
    }

    private static func kindName(_ kind: AgentKind) -> String {
        switch kind {
        case .claude: "Claude"
        case .codex: "Codex"
        case .gemini: "Gemini"
        case .generic: "Agent"
        }
    }
}

/// 實際排版的一排角色與狀態圖示，只供 `ImageRenderer` 繪製。
private struct MenuBarCharactersRow: View {
    let items: [MenuBarCharacterItem]
    let emphasis: MenuBarAlertEmphasis

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let highlighted = item.isHighlighted(during: emphasis)
                HStack(spacing: 1) {
                    CharacterView(
                        state: item.normalizedState,
                        agentKind: item.agentKind,
                        size: MenuBarCharactersLabel.characterSize,
                        animationsEnabled: false  // 選單列不播動畫
                    )
                    Text(item.icon)
                        .font(.system(size: 12, weight: highlighted ? .bold : .regular))
                }
                // 固定保留外框的空間，強調開始與結束時寬度不變，選單列不會跳動。
                .padding(.horizontal, 2)
                .overlay {
                    if highlighted {
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(.primary, lineWidth: 1.5)
                    }
                }
            }
        }
        .frame(height: 18)
    }
}
