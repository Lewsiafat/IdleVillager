import SwiftUI
import IdleVillagerCore

/// 角色動作的 SwiftUI 實作，完全照 `CharacterMotion` 的純值播放：loop 為 nil 時不加任何動畫，transition 為 nil 時不播過渡。
///
/// 為了讓多個角色同時顯示時仍然省電，循環一律用 `PhaseAnimator`：靜止的時段以動畫的 delay 表示，
/// 不使用持續 Timer，也不在每一幀重算狀態。過渡用 `keyframeAnimator`，只在 trigger 改變時播一次。
extension View {
    /// 套用 `CharacterMotion`：循環動作加上在 `transitionTrigger` 改變時播一次的過渡。
    func characterMotion<Trigger: Equatable>(_ motion: CharacterMotion, side: CGFloat, transitionTrigger: Trigger) -> some View {
        characterLoop(motion.loop, side: side)
            .characterTransition(motion.transition, side: side, trigger: transitionTrigger)
    }

    /// 套用循環動作。`side` 是角色邊長，位移以它的比例換算。
    func characterLoop(_ loop: CharacterLoop?, side: CGFloat) -> some View {
        modifier(CharacterLoopModifier(loop: loop, side: side))
    }

    /// 在 `trigger` 改變時播放一次 `transition`；transition 為 nil 時不做任何事。
    func characterTransition<Trigger: Equatable>(_ transition: CharacterTransition?, side: CGFloat, trigger: Trigger) -> some View {
        modifier(CharacterTransitionModifier(transition: transition, side: side, trigger: trigger))
    }
}

private struct CharacterLoopModifier: ViewModifier {
    let loop: CharacterLoop?
    let side: CGFloat

    func body(content: Content) -> some View {
        switch loop {
        case .workingBob:
            content.modifier(WorkingBob(parameters: CharacterLoop.workingBob.parameters, side: side))
        case .raisedHandSway:
            content.modifier(RaisedHandSway(parameters: CharacterLoop.raisedHandSway.parameters))
        case .idleZzz:
            content.modifier(IdleZzz(parameters: CharacterLoop.idleZzz.parameters, side: side))
        case nil:
            content
        }
    }
}

/// 幹活：在兩個相位之間平穩來回，微幅上下跳動並左右擺動。每個方向走半個週期。
private struct WorkingBob: ViewModifier {
    let parameters: CharacterLoopParameters
    let side: CGFloat

    func body(content: Content) -> some View {
        content.phaseAnimator([false, true]) { view, up in
            view
                .offset(y: up ? -parameters.offset * side : 0)
                .rotationEffect(.degrees(up ? parameters.rotationDegrees : -parameters.rotationDegrees), anchor: .bottom)
        } animation: { _ in
            .easeInOut(duration: parameters.motionDuration / 2)
        }
    }
}

/// 舉手：靜止一段時間後，左右小幅晃一下再回正。整個週期只有 `motionDuration` 在動。
private struct RaisedHandSway: ViewModifier {
    enum Phase: CaseIterable { case rest, left, right }

    let parameters: CharacterLoopParameters

    func body(content: Content) -> some View {
        content.phaseAnimator(Phase.allCases) { view, phase in
            view.rotationEffect(.degrees(angle(of: phase)), anchor: .bottom)
        } animation: { phase in
            let step = parameters.motionDuration / 3
            // 動畫閉包收到的是「要前往」的相位；從靜止出發的那一步帶著整段靜止時間的 delay。
            return phase == .left ? .easeInOut(duration: step).delay(parameters.restDuration) : .easeInOut(duration: step)
        }
    }

    private func angle(of phase: Phase) -> Double {
        switch phase {
        case .rest: 0
        case .left: -parameters.rotationDegrees
        case .right: parameters.rotationDegrees
        }
    }
}

/// 躺平：靜止一段時間後，從靜態 Zzz 旁浮出一個小 z，往上飄並淡出。角色本身不動。
private struct IdleZzz: ViewModifier {
    enum Phase: CaseIterable { case hidden, shown, floated }

    /// 淡出後回到起點的時間，從靜止時間中扣除，讓整個週期維持 `period`。
    private static let reset: TimeInterval = 0.05

    let parameters: CharacterLoopParameters
    let side: CGFloat

    func body(content: Content) -> some View {
        content.overlay {
            Text("z")
                .font(.system(size: side * 0.22, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .phaseAnimator(Phase.allCases) { view, phase in
                    view
                        .opacity(phase == .shown ? 1 : 0)
                        .offset(y: phase == .floated ? -parameters.offset * side : 0)
                } animation: { phase in
                    switch phase {
                    case .shown: .easeOut(duration: parameters.motionDuration * 0.3).delay(parameters.restDuration - Self.reset)
                    case .floated: .easeIn(duration: parameters.motionDuration * 0.7)
                    // 已經淡出，回到起點時看不見；用極短的動畫而不是 nil，確保相位一定會往下走。
                    case .hidden: .linear(duration: Self.reset)
                    }
                }
                .position(x: side * 0.92, y: side * 0.3)
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

    func body(content: Content) -> some View {
        // transition 為 nil 時參數全為零，keyframe 長度為 0，等同不播放。
        let parameters = transition?.parameters ?? CharacterTransitionParameters(duration: 0, jumpHeight: 0, startOpacity: 1)
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
