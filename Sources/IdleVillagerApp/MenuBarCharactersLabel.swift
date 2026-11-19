import AppKit
import SwiftUI
import IdleVillagerCore

/// 少量角色模式的選單列內容：每個 Session 一個靜態小村民，後面接狀態圖示。
///
/// 完全依 `MenuBarPresentation.CharacterCell` 繪製，不自行推論狀態、排序或強調。角色固定 16 pt（`CharacterDetail` 為只畫本體），
/// 不播放動畫；狀態圖示（⚒ ✋ ✓ 💤 ! ?）與角色並列，因此狀態不只靠角色或顏色辨識。無障礙文字由外層 `MenuBarLabel` 提供。
///
/// `MenuBarExtra` 的 label 只可靠地呈現單一圖片或文字，所以整排內容先以 `MenuBarImageRendering` 畫成一張圖片。
/// 是否使用 template 圖片由 `MenuBarPresentation.usesTemplateImage` 決定：沒有品牌素材時使用，讓系統依選單列外觀自動套用明暗色；
/// 有品牌素材時保留原色，避免改動品牌標誌。
///
/// 低干擾提醒進行中時，強調的角色（待核准）在產圖時加上圓角底色（`menuBarEmphasisBackground`，與數量模式共用）、
/// 狀態圖示改為粗體。底色只是額外提示，狀態仍由 ✋ 圖示表達。
struct MenuBarCharactersLabel: View {
    let cells: [MenuBarPresentation.CharacterCell]
    let usesTemplateImage: Bool

    /// 選單列角色的邊長（pt），落在規格要求的 16 到 18 pt 之間。
    static let characterSize: CGFloat = 16

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Image(nsImage: renderedImage)
    }

    private var renderedImage: NSImage {
        MenuBarImageRendering.image(
            of: MenuBarCharactersRow(cells: cells),
            scale: displayScale,
            isTemplate: usesTemplateImage
        )
    }
}

/// 實際排版的一排角色與狀態圖示，只供 `ImageRenderer` 繪製。
private struct MenuBarCharactersRow: View {
    let cells: [MenuBarPresentation.CharacterCell]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(cells) { cell in
                HStack(spacing: 1) {
                    CharacterView(
                        state: cell.normalizedState,
                        agentKind: cell.agentKind,
                        size: MenuBarCharactersLabel.characterSize,
                        animationsEnabled: false  // 選單列不播動畫
                    )
                    Text(cell.icon)
                        .font(.system(size: 12, weight: cell.isHighlighted ? .bold : .regular))
                }
                .menuBarEmphasisBackground(cell.isHighlighted)
            }
        }
        .frame(height: 18)
    }
}
