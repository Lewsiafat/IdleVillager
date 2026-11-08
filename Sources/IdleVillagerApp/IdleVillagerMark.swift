import SwiftUI

/// IdleVillager 自有的產品標誌（Issue #40）。
///
/// 兩個形狀都以 18 × 18 的設計格線定義，座標與 `assets/brand/` 下的 SVG 一一對應；改圖時兩邊要一起改。
/// 它們只是產品識別，不代表任何 Session 的狀態，也不含任何第三方品牌或《世紀帝國》的美術元素。
///
/// - `VillagerSymbolShape`：斗笠村民半身（斗笠、頭、肩膀三段分離），用在選單列數量模式最左邊。
///   16 pt 仍看得出是一個人，不會被看成狀態圖示或隱藏狀態的「•」。
/// - `SleepyVillagerMarkShape`：斗笠下一張閉眼打盹的臉，用在 Popover 標題列。
///   閉眼線條在 16 pt 以下太細，所以只用在 24 pt 這類較大的尺寸。
enum IdleVillagerMark {
    /// 選單列標誌的邊長（pt），與少量角色模式的角色同為 16 pt，落在規格的 16 到 18 pt 之間。
    static let menuBarSize: CGFloat = 16
    /// 標誌與第一個狀態圖示之間額外留的間距（pt），加上 `HStack` 本身的 2 pt，共 4 pt，避免黏在一起。
    static let menuBarTrailingGap: CGFloat = 2
    /// Popover 標題列標誌的邊長（pt）。
    static let popoverSize: CGFloat = 24

    /// 設計格線的邊長，SVG 的 viewBox 為 0 0 18 18。
    fileprivate static let grid: CGFloat = 18
}

/// 把 18 × 18 格線上的座標換算到實際繪製範圍（等比例縮放、置中）。
private struct MarkGrid {
    let scale: CGFloat
    let origin: CGPoint

    init(in rect: CGRect) {
        let side = min(rect.width, rect.height)
        scale = side / IdleVillagerMark.grid
        origin = CGPoint(x: rect.midX - side / 2, y: rect.midY - side / 2)
    }

    func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
    }

    func circle(cx: CGFloat, cy: CGFloat, r: CGFloat) -> Path {
        Path(ellipseIn: CGRect(
            x: origin.x + (cx - r) * scale,
            y: origin.y + (cy - r) * scale,
            width: 2 * r * scale,
            height: 2 * r * scale
        ))
    }
}

/// 斗笠村民半身，對應 `assets/brand/idlevillager-menubar-symbol.svg`。
struct VillagerSymbolShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = MarkGrid(in: rect)
        var path = Path()

        // 斗笠：尖頂加兩側微翹的帽簷。
        path.move(to: g.point(9, 0.6))
        path.addLine(to: g.point(12.9, 5.4))
        path.addQuadCurve(to: g.point(17.3, 7.3), control: g.point(16.9, 6.1))
        path.addQuadCurve(to: g.point(16.3, 8.2), control: g.point(17.4, 8.2))
        path.addLine(to: g.point(1.7, 8.2))
        path.addQuadCurve(to: g.point(0.7, 7.3), control: g.point(0.6, 8.2))
        path.addQuadCurve(to: g.point(5.1, 5.4), control: g.point(1.1, 6.1))
        path.closeSubpath()

        // 頭。
        path.addPath(g.circle(cx: 9, cy: 11.1, r: 2.4))

        // 肩膀。
        path.move(to: g.point(2.4, 18))
        path.addQuadCurve(to: g.point(9, 14.2), control: g.point(2.6, 14.5))
        path.addQuadCurve(to: g.point(15.6, 18), control: g.point(15.4, 14.5))
        path.closeSubpath()

        return path
    }
}

/// 斗笠瞇眼臉，對應 `assets/brand/idlevillager-popover-mark.svg`。
struct SleepyVillagerMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let g = MarkGrid(in: rect)

        // 斗笠。
        var hat = Path()
        hat.move(to: g.point(9, 0.5))
        hat.addLine(to: g.point(12.3, 4.6))
        hat.addQuadCurve(to: g.point(16.8, 6.4), control: g.point(16.4, 5.3))
        hat.addQuadCurve(to: g.point(15.9, 7.2), control: g.point(16.9, 7.2))
        hat.addLine(to: g.point(2.1, 7.2))
        hat.addQuadCurve(to: g.point(1.2, 6.4), control: g.point(1.1, 7.2))
        hat.addQuadCurve(to: g.point(5.7, 4.6), control: g.point(1.6, 5.3))
        hat.closeSubpath()

        // 閉眼：兩條向下彎的弧線，轉成筆畫外框後從臉上挖掉。
        var eyes = Path()
        eyes.move(to: g.point(5.5, 12.4))
        eyes.addQuadCurve(to: g.point(7.5, 12.4), control: g.point(6.5, 13.6))
        eyes.move(to: g.point(10.5, 12.4))
        eyes.addQuadCurve(to: g.point(12.5, 12.4), control: g.point(11.5, 13.6))
        let eyeCutout = eyes.strokedPath(StrokeStyle(lineWidth: 1.3 * g.scale, lineCap: .round))

        let face = g.circle(cx: 9, cy: 12.6, r: 4.8).subtracting(eyeCutout)
        return hat.union(face)
    }
}
