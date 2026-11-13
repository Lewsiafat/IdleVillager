import AppKit
import QuartzCore
import SwiftUI
import IdleVillagerCore

/// 角色動作的實作，完全照 `CharacterMotion` 的純值播放：loop 為 nil 時不加任何動畫，transition 為 nil 時不播過渡。
///
/// 循環交給 Core Animation 播放（見 `LoopingHostingView`），一個週期的關鍵影格由 Core 的 `CharacterLoop.keyframes` 描述。
/// 過渡用 `keyframeAnimator`，只在 trigger 改變時播一次。
extension View {
    /// 套用 `CharacterMotion`：循環動作加上在 `transitionTrigger` 改變時播一次的過渡。
    func characterMotion<Trigger: Equatable>(_ motion: CharacterMotion, side: CGFloat, transitionTrigger: Trigger) -> some View {
        characterLoop(motion.loop, side: side)
            .characterTransition(motion.transition, side: side, trigger: transitionTrigger)
    }

    /// 套用循環動作。`side` 是角色邊長，位移以它的比例換算。
    func characterLoop(_ loop: CharacterLoop?, side: CGFloat) -> some View {
        CharacterLoopView(loop: loop, side: side, content: self)
    }

    /// 在 `trigger` 改變時播放一次 `transition`；transition 為 nil 時不做任何事。
    func characterTransition<Trigger: Equatable>(_ transition: CharacterTransition?, side: CGFloat, trigger: Trigger) -> some View {
        modifier(CharacterTransitionModifier(transition: transition, side: side, trigger: trigger))
    }
}

/// 依循環的對象，把角色本身或躺平時的小 z 交給 `LoopingLayer` 播放。
private struct CharacterLoopView<Content: View>: View {
    let loop: CharacterLoop?
    let side: CGFloat
    let content: Content

    var body: some View {
        if let loop {
            let keyframes = loop.keyframes
            switch keyframes.target {
            case .character:
                LoopingLayer(keyframes: keyframes, side: side, content: content)
                    .frame(width: side, height: side)
            case .zzzMarker:
                content.overlay {
                    LoopingLayer(keyframes: keyframes, side: side, content: ZzzMarker(side: side))
                        .frame(width: side, height: side)
                }
            }
        } else {
            content
        }
    }
}

/// 躺平角色旁邊浮出的小 z，位置以角色邊長的比例表示。
private struct ZzzMarker: View {
    let side: CGFloat

    var body: some View {
        Text("z")
            .font(.system(size: side * 0.22, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .position(x: side * 0.92, y: side * 0.3)
    }
}

/// 把 SwiftUI 內容放進 `LoopingHostingView`，讓 Core Animation 重複播放關鍵影格。
private struct LoopingLayer<Content: View>: NSViewRepresentable {
    let keyframes: CharacterLoopKeyframes
    let side: CGFloat
    let content: Content

    func makeNSView(context: Context) -> LoopingHostingView<Content> {
        let view = LoopingHostingView(rootView: content)
        view.sizingOptions = []
        view.update(keyframes: keyframes, side: side)
        return view
    }

    func updateNSView(_ nsView: LoopingHostingView<Content>, context: Context) {
        nsView.rootView = content
        nsView.update(keyframes: keyframes, side: side)
    }
}

/// 在自己的圖層上無限重複播放一個週期的關鍵影格。
///
/// 為什麼不用 SwiftUI 的 `PhaseAnimator`：它每一幀都要在主執行緒更新 view graph，並重做整個清單視窗的版面配置，
/// 連用 delay 表示的靜止時段也一樣（2026-11-12 實測，清單開著時 CPU 約 10%）。
/// Core Animation 的動畫由系統的繪圖程序播放，加上去之後主執行緒每一幀都不用做事。
private final class LoopingHostingView<Content: View>: NSHostingView<Content> {
    private static var animationKey: String { "characterLoop" }

    private var keyframes: CharacterLoopKeyframes?
    private var side: CGFloat = 0
    private var needsNewAnimation = true

    required init(rootView: Content) {
        super.init(rootView: rootView)
        wantsLayer = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    // 只負責畫面，點擊與 hover 交給清單列上方的 `ClickableRowArea`。
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(keyframes: CharacterLoopKeyframes, side: CGFloat) {
        guard keyframes != self.keyframes || side != self.side else { return }
        self.keyframes = keyframes
        self.side = side
        needsNewAnimation = true
        needsLayout = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        needsLayout = true
    }

    // 圖層的大小與上層座標要等版面配置完成才確定，所以在這裡加動畫。
    // AppKit 有時會移除圖層上的動畫（例如視窗重新建立圖層時），發現不見了就再加回去。
    override func layout() {
        super.layout()
        guard let layer, let keyframes, window != nil, bounds.width > 0 else { return }
        guard needsNewAnimation || layer.animation(forKey: Self.animationKey) == nil else { return }
        layer.removeAnimation(forKey: Self.animationKey)
        layer.add(Self.animation(for: keyframes, side: side, in: layer), forKey: Self.animationKey)
        needsNewAnimation = false
    }

    private static func animation(for keyframes: CharacterLoopKeyframes, side: CGFloat, in layer: CALayer) -> CAAnimation {
        let frames = keyframes.frames
        let keyTimes = frames.map { NSNumber(value: $0.time / keyframes.period) }
        let timingFunctions = frames.dropFirst().map { timingFunction(for: $0.curve) }

        var animations: [CAAnimation] = []
        if frames.contains(where: { $0.pose.rotationDegrees != 0 || $0.pose.lift != 0 }) {
            let transform = CAKeyframeAnimation(keyPath: "transform")
            transform.values = frames.map { NSValue(caTransform3D: self.transform(for: $0.pose, side: side, in: layer)) }
            transform.keyTimes = keyTimes
            transform.timingFunctions = timingFunctions
            animations.append(transform)
        }
        if frames.contains(where: { $0.pose.opacity != 1 }) {
            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            opacity.values = frames.map { $0.pose.opacity }
            opacity.keyTimes = keyTimes
            opacity.timingFunctions = timingFunctions
            animations.append(opacity)
        }

        let group = CAAnimationGroup()
        group.animations = animations
        group.duration = keyframes.period
        group.repeatCount = .infinity
        return group
    }

    /// 以角色底部中央為軸旋轉，再往上抬起。
    ///
    /// 圖層的 transform 以 `anchorPoint` 為原點，方向跟著上層圖層的座標系：上層翻轉時 y 軸朝下，
    /// 所以「底部」「往上」與「順時針」的正負號都要依此換算。
    private static func transform(for pose: CharacterLoopPose, side: CGFloat, in layer: CALayer) -> CATransform3D {
        let yDown = layer.superlayer?.contentsAreFlipped() ?? false
        let bounds = layer.bounds
        let pivotX = bounds.width / 2 - layer.anchorPoint.x * bounds.width
        let pivotY = (yDown ? bounds.height : 0) - layer.anchorPoint.y * bounds.height
        let lift = CGFloat(pose.lift) * side * (yDown ? -1 : 1)
        let clockwise = CGFloat(pose.rotationDegrees) * .pi / 180
        let angle = yDown ? clockwise : -clockwise

        var transform = CATransform3DMakeTranslation(pivotX, pivotY + lift, 0)
        transform = CATransform3DRotate(transform, angle, 0, 0, 1)
        transform = CATransform3DTranslate(transform, -pivotX, -pivotY, 0)
        return transform
    }

    private static func timingFunction(for curve: CharacterLoopCurve) -> CAMediaTimingFunction {
        switch curve {
        case .linear: CAMediaTimingFunction(name: .linear)
        case .easeIn: CAMediaTimingFunction(name: .easeIn)
        case .easeOut: CAMediaTimingFunction(name: .easeOut)
        case .easeInOut: CAMediaTimingFunction(name: .easeInEaseOut)
        }
    }
}

/// 一次性過渡：celebrateOnce 跳起再落下；slowToIdle 從半透明緩慢淡入。最後都回到原位、完全不透明。
private struct CharacterTransitionModifier<Trigger: Equatable>: ViewModifier {
    struct Value {
        var offsetY: CGFloat = 0
        var opacity: Double = 1
    }

    let transition: CharacterTransition?
    let side: CGFloat
    let trigger: Trigger

    /// 沒有過渡時使用的參數：不跳、不淡入，長度是很短的非零值。
    ///
    /// 長度不能是 0：SwiftUI 以「經過時間 ÷ 全長」算進度，全長為 0 時進度是 NaN，位移與不透明度跟著變成 NaN，
    /// 清單列裡的 AppKit view 收到高度為 NaN 的 frame 就會讓整個 App 中止（issue #55）。
    /// 任何狀態改變都會更新 trigger，所以動畫關閉、Reduce Motion，或 Working 轉 Needs Approval 這類
    /// 沒有過渡的轉換，只要清單曾經打開過，就會踩到這條路。
    ///
    /// 也不能在沒有過渡時改成不套 keyframeAnimator：那樣 view 結構會隨過渡有無而切換，
    /// 狀態改變當下新插入的 animator 不會播放（它只在 trigger 改變時播放），Done 的慶祝跳躍就看不到。
    private static var noTransition: CharacterTransitionParameters {
        CharacterTransitionParameters(duration: 0.001, jumpHeight: 0, startOpacity: 1)
    }

    func body(content: Content) -> some View {
        let parameters = transition?.parameters ?? Self.noTransition
        content.keyframeAnimator(initialValue: Value(), trigger: trigger) { view, value in
            view
                .offset(y: value.offsetY)
                .opacity(value.opacity)
        } keyframes: { _ in
            KeyframeTrack(\.offsetY) {
                CubicKeyframe(-parameters.jumpHeight * side, duration: parameters.duration / 2)
                CubicKeyframe(0, duration: parameters.duration / 2)
            }
            KeyframeTrack(\.opacity) {
                MoveKeyframe(parameters.startOpacity)
                CubicKeyframe(1, duration: parameters.duration)
            }
        }
    }
}
