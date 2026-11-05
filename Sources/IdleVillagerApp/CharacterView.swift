import SwiftUI
import IdleVillagerCore

/// Generic 小村民的靜態姿勢，完全依 `CharacterPresentation` 的圖層描述繪製。
///
/// 本體、手、腳、道具、表情、特效各自是一層，用 SF Symbols 與 SwiftUI Shapes 畫出，不使用任何圖片素材。
/// 尺寸限制在 16 到 36 pt；18 pt 以下只畫本體（見 `CharacterDetail`）。
/// 品牌素材存在時，本體換成該 Agent 種類的品牌標誌（見 `BrandBodyView`），否則為 Generic 小村民。
/// 循環動作與一次性過渡照 `CharacterMotion` 的純值套用；
/// 系統 Reduce Motion 開啟或 `animationsEnabled` 為 false 時只畫靜態姿勢。
struct CharacterView: View {
    let state: NormalizedState
    var agentKind: AgentKind = .generic
    var size: CGFloat = 28
    /// 使用者是否開啟動畫（`AppSettings.animationsEnabled`），由 Popover 列從設定傳入。
    var animationsEnabled: Bool = true

    static let sizeRange: ClosedRange<CGFloat> = 16...36

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var previousState: NormalizedState?

    var body: some View {
        let presentation = CharacterPresentation(
            state: state, previousState: previousState, reduceMotion: reduceMotion,
            agentKind: agentKind, isBrandAssetAvailable: BrandAssetCatalog.isAvailable
        )
        let side = min(max(size, Self.sizeRange.lowerBound), Self.sizeRange.upperBound)
        CharacterCanvas(presentation: presentation, side: side, highContrast: contrast == .increased,
                        detail: CharacterDetail(size: Double(side)))
            .characterMotion(
                CharacterMotion(pose: presentation.pose, transition: presentation.transition,
                                reduceMotion: reduceMotion, animationsEnabled: animationsEnabled),
                side: side,
                // previousState 只在狀態轉換當下改變，因此過渡只播一次，其他原因的重繪不會重播。
                transitionTrigger: previousState
            )
            .frame(width: side, height: side)
            .onChange(of: state) { oldValue, _ in
                previousState = oldValue
            }
            .accessibilityHidden(true)
    }
}

/// 把圖層描述排進一個正方形畫布。座標以邊長的比例表示，因此任何尺寸都維持相同構圖。
private struct CharacterCanvas: View {
    let presentation: CharacterPresentation
    let side: CGFloat
    let highContrast: Bool
    let detail: CharacterDetail

    private var layers: CharacterLayers { presentation.layers }
    private var lying: Bool { presentation.pose == .lyingDown }

    var body: some View {
        if detail.drawsOuterLayers {
            fullCharacter
        } else {
            // 小尺寸只畫主標誌（本體），置中放大，讓品牌仍可辨識。
            bodyLayer(diameter: side * 0.84)
                .frame(width: side, height: side)
        }
    }

    /// 本體：品牌標誌或 Generic 圓形。品牌標誌不疊表情，避免改動標誌本身。
    private func bodyLayer(diameter: CGFloat) -> some View {
        BrandBodyView(brandBody: presentation.brandBody, side: diameter) {
            LayerView(layer: layers.body, width: diameter, height: diameter, style: bodyStyle)
        }
    }

    private var fullCharacter: some View {
        ZStack {
            if let prop = layers.prop {
                LayerView(layer: prop, width: propSize.width, height: propSize.height, style: AnyShapeStyle(.secondary))
                    .position(point(propPosition))
            }
            if let feet = layers.feet {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    LayerView(layer: feet, width: self.side * 0.1, height: self.side * 0.14, style: bodyStyle)
                        .position(point(CGPoint(x: 0.4 + side * 0.09, y: 0.82)))
                }
            }
            if let hands = layers.hands {
                handsView(hands)
            }
            ZStack {
                bodyLayer(diameter: side * 0.48)
                if let face = layers.face, presentation.brandBody == .generic {
                    LayerView(layer: face, width: side * 0.26, height: faceHeight(face), style: AnyShapeStyle(.background))
                }
            }
            // 躺平時本體靠在床頭上；本體不旋轉，品牌標誌因此不變形。
            .position(point(lying ? CGPoint(x: 0.3, y: 0.5) : CGPoint(x: 0.4, y: 0.48)))
            if let effect = layers.effect {
                LayerView(layer: effect, width: side * 0.3, height: side * 0.3, style: effectStyle)
                    .position(point(CGPoint(x: 0.8, y: 0.2)))
            }
        }
        .frame(width: side, height: side)
    }

    @ViewBuilder
    private func handsView(_ hands: CharacterLayer) -> some View {
        if case .sfSymbol = hands {
            // 舉手：一隻手高舉在頭的右上方。
            LayerView(layer: hands, width: side * 0.26, height: side * 0.26, style: bodyStyle)
                .position(point(CGPoint(x: 0.66, y: 0.24)))
        } else {
            ForEach([-1.0, 1.0], id: \.self) { side in
                LayerView(layer: hands, width: self.side * 0.08, height: self.side * 0.16, style: bodyStyle)
                    .rotationEffect(.degrees(side * 30))
                    .position(point(CGPoint(x: 0.4 + side * 0.27, y: 0.58)))
            }
        }
    }

    private var propPosition: CGPoint {
        switch presentation.pose {
        case .lyingDown: return CGPoint(x: 0.5, y: 0.78)
        case .delivering: return CGPoint(x: 0.8, y: 0.6)
        default: return CGPoint(x: 0.8, y: 0.62)
        }
    }

    private var propSize: CGSize {
        lying ? CGSize(width: side * 0.9, height: side * 0.42) : CGSize(width: side * 0.34, height: side * 0.34)
    }

    private func faceHeight(_ face: CharacterLayer) -> CGFloat {
        if case .shape = face { return side * 0.05 }
        return side * 0.26
    }

    private func point(_ unit: CGPoint) -> CGPoint {
        CGPoint(x: unit.x * side, y: unit.y * side)
    }

    /// 本體使用主要前景色，在明暗模式下自動反轉。
    private var bodyStyle: AnyShapeStyle { AnyShapeStyle(.primary) }

    /// 特效顏色只是輔助；高對比時一律使用主要前景色。Error 與 Unknown 不用成功類顏色。
    private var effectStyle: AnyShapeStyle {
        if highContrast { return AnyShapeStyle(.primary) }
        switch presentation.pose {
        case .raisingHand: return AnyShapeStyle(.orange)
        case .delivering: return AnyShapeStyle(.yellow)
        case .alert: return AnyShapeStyle(.red)
        case .working, .lyingDown, .puzzled: return AnyShapeStyle(.secondary)
        }
    }
}

/// 畫出單一圖層：SF Symbol 或 SwiftUI Shape。
private struct LayerView: View {
    let layer: CharacterLayer
    let width: CGFloat
    let height: CGFloat
    let style: AnyShapeStyle

    var body: some View {
        switch layer {
        case .sfSymbol(let name):
            Image(systemName: name)
                .resizable()
                .scaledToFit()
                .foregroundStyle(style)
                .frame(width: width, height: height)
        case .shape(let shape):
            shapeView(shape)
                .frame(width: width, height: height)
        }
    }

    @ViewBuilder
    private func shapeView(_ shape: CharacterShape) -> some View {
        switch shape {
        case .circle: Circle().fill(style)
        case .capsule: Capsule().fill(style)
        }
    }
}
