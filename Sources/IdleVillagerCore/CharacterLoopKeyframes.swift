import Foundation

/// 循環動作在某一刻的樣子。數值與畫面座標無關，由 App 層換算。
public struct CharacterLoopPose: Hashable, Sendable {
    /// 以底部中央為軸的旋轉角度。正值是順時針。
    public var rotationDegrees: Double
    /// 往上抬起的距離（角色邊長的比例）。0 是原位，正值往上。
    public var lift: Double
    /// 不透明度，0 到 1。
    public var opacity: Double

    public init(rotationDegrees: Double = 0, lift: Double = 0, opacity: Double = 1) {
        self.rotationDegrees = rotationDegrees
        self.lift = lift
        self.opacity = opacity
    }

    /// 原位、不旋轉、完全不透明。
    public static let neutral = CharacterLoopPose()
}

/// 兩個關鍵影格之間的速度曲線。
public enum CharacterLoopCurve: Hashable, Sendable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
}

/// 循環動作中的一格：在週期內的時間點、當下的樣子，以及從上一格走到這一格用的曲線。
public struct CharacterLoopKeyframe: Hashable, Sendable {
    /// 從週期開始算起的秒數。
    public var time: TimeInterval
    public var pose: CharacterLoopPose
    /// 從上一格走到這一格的曲線；第一格沒有上一格，這個值不會用到。
    public var curve: CharacterLoopCurve

    public init(time: TimeInterval, pose: CharacterLoopPose, curve: CharacterLoopCurve = .linear) {
        self.time = time
        self.pose = pose
        self.curve = curve
    }
}

/// 一個完整週期的關鍵影格。App 層把它交給 Core Animation 無限重複播放。
///
/// 整個週期（包括靜止時段）一次描述完，播放時主執行緒不用每一幀更新。
/// 原本用 SwiftUI `PhaseAnimator` 時，即使在靜止時段，每一幀也都要重做整個清單視窗的版面配置。
public struct CharacterLoopKeyframes: Hashable, Sendable {
    /// 動的是哪個部分。
    public enum Target: Hashable, Sendable {
        /// 角色本身。
        case character
        /// 躺平角色旁邊浮出的小 z。
        case zzzMarker
    }

    public var target: Target
    /// 一個週期的秒數。
    public var period: TimeInterval
    /// 第一格在時間 0，最後一格在 `period`，而且頭尾的樣子相同，重複播放時不會跳動。
    public var frames: [CharacterLoopKeyframe]
}

extension CharacterLoop {
    /// 這種循環一個週期的關鍵影格，依 `parameters` 的節奏與幅度產生。
    public var keyframes: CharacterLoopKeyframes {
        let p = parameters
        switch self {
        case .workingBob:
            // 平穩來回：每個方向走半個週期，左右擺動並微幅上下跳動。
            let down = CharacterLoopPose(rotationDegrees: -p.rotationDegrees)
            let up = CharacterLoopPose(rotationDegrees: p.rotationDegrees, lift: p.offset)
            return CharacterLoopKeyframes(target: .character, period: p.period, frames: [
                CharacterLoopKeyframe(time: 0, pose: down),
                CharacterLoopKeyframe(time: p.period / 2, pose: up, curve: .easeInOut),
                CharacterLoopKeyframe(time: p.period, pose: down, curve: .easeInOut),
            ])

        case .raisedHandSway:
            // 靜止一段時間後，往左、往右各晃一下再回正，三步平分 motionDuration。
            let step = p.motionDuration / 3
            let rest = p.restDuration
            return CharacterLoopKeyframes(target: .character, period: p.period, frames: [
                CharacterLoopKeyframe(time: 0, pose: .neutral),
                CharacterLoopKeyframe(time: rest, pose: .neutral),
                CharacterLoopKeyframe(time: rest + step, pose: CharacterLoopPose(rotationDegrees: -p.rotationDegrees), curve: .easeInOut),
                CharacterLoopKeyframe(time: rest + 2 * step, pose: CharacterLoopPose(rotationDegrees: p.rotationDegrees), curve: .easeInOut),
                CharacterLoopKeyframe(time: p.period, pose: .neutral, curve: .easeInOut),
            ])

        case .idleZzz:
            // 靜止一段時間後，小 z 淡入，再往上飄並淡出，最後在看不見的狀態下回到起點。
            let reset: TimeInterval = 0.05
            let appear = p.restDuration - reset
            let fadeIn = p.motionDuration * 0.3
            let float = p.motionDuration * 0.7
            let hidden = CharacterLoopPose(opacity: 0)
            return CharacterLoopKeyframes(target: .zzzMarker, period: p.period, frames: [
                CharacterLoopKeyframe(time: 0, pose: hidden),
                CharacterLoopKeyframe(time: appear, pose: hidden),
                CharacterLoopKeyframe(time: appear + fadeIn, pose: .neutral, curve: .easeOut),
                CharacterLoopKeyframe(time: appear + fadeIn + float, pose: CharacterLoopPose(lift: p.offset, opacity: 0), curve: .easeIn),
                CharacterLoopKeyframe(time: p.period, pose: hidden),
            ])
        }
    }
}
