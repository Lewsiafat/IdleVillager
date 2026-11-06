import AppKit
import SwiftUI
import IdleVillagerCore

/// 在 App 的 resource bundle 裡查找品牌本體素材（見 `Resources/Brands/README.md`）。
///
/// 載入結果會快取，同時顯示多個角色時不重複讀檔；找不到或無法載入的名稱也會記住，之後直接回傳 nil。
@MainActor
enum BrandAssetCatalog {
    /// 查找順序：向量 PDF 優先，其次 SVG，最後 PNG。
    private static let extensions = ["pdf", "svg", "png"]
    private static var cache: [String: NSImage?] = [:]

    /// 該名稱的素材是否存在且能載入；供 `BrandBody.resolve(agentKind:isAssetAvailable:)` 使用。
    static func isAvailable(_ name: String) -> Bool {
        image(named: name) != nil
    }

    static func image(named name: String) -> NSImage? {
        if let cached = cache[name] { return cached }
        let image = url(named: name).flatMap { NSImage(contentsOf: $0) }
        cache[name] = .some(image)
        return image
    }

    /// `.process` 規則可能把子目錄攤平，因此先找 bundle 根目錄，再找 `Brands` 子目錄。
    private static func url(named name: String) -> URL? {
        for ext in extensions {
            for subdirectory in [nil, "Brands"] {
                if let url = Bundle.module.url(forResource: name, withExtension: ext, subdirectory: subdirectory) {
                    return url
                }
            }
        }
        return nil
    }
}

/// 角色本體：品牌素材存在時以原色畫出品牌圖片，否則畫 `generic` 提供的 Generic 本體。
///
/// 品牌圖片不套 tint、不改 rendering mode、只等比例縮放進正方形，不拉伸也不旋轉，因此在深色與淺色模式下都維持原貌。
struct BrandBodyView<Generic: View>: View {
    let brandBody: BrandBody
    let side: CGFloat
    @ViewBuilder let generic: () -> Generic

    var body: some View {
        if case .asset(let name) = brandBody, let image = BrandAssetCatalog.image(named: name) {
            Image(nsImage: image)
                .renderingMode(.original)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .frame(width: side, height: side)
        } else {
            generic()
        }
    }
}
