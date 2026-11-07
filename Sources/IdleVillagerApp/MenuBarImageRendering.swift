import AppKit
import SwiftUI

/// 把選單列內容畫成一張圖片的共用流程，數量模式與少量角色模式共用。
///
/// `MenuBarExtra` 的 label 只可靠地呈現單一圖片或文字，所以整排內容先以 `ImageRenderer` 畫成 `NSImage`。
/// template 圖片會讓系統依選單列外觀自動套用明暗色；含品牌素材時應關閉，避免改動品牌標誌。
@MainActor
enum MenuBarImageRendering {
    /// - Parameters:
    ///   - content: 要畫成圖片的排版內容。
    ///   - scale: 螢幕的 `displayScale`，讓圖片在 Retina 螢幕上清晰。
    ///   - isTemplate: 是否以 template 圖片呈現。
    static func image<Content: View>(of content: Content, scale: CGFloat, isTemplate: Bool = true) -> NSImage {
        let renderer = ImageRenderer(content: content)
        renderer.scale = scale
        let image = renderer.nsImage ?? NSImage()
        image.isTemplate = isTemplate
        return image
    }
}
