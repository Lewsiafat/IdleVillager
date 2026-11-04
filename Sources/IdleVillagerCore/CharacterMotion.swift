import Foundation

/// 角色在某個姿勢下持續播放的循環動作。只描述「要播什麼、節奏多快」，動畫本身由 App 層實作。
public enum CharacterLoop: String, CaseIterable, Hashable, Sendable {
    /// 幹活：微幅上下跳動並左右擺動，像在敲鍵盤或揮工具。平穩循環。
    case workingBob
    /// 舉手：每隔一段時間小幅晃一下，大部分時間靜止。稀疏節奏、不閃爍。
    case raisedHandSway
    /// 躺平：偶爾浮出一個 Zzz 再淡出。低頻率。
    case idleZzz

    /// 這種循環的節奏與幅度。
    public var parameters: CharacterLoopParameters {
        switch self {
        case .workingBob:
            return CharacterLoopParameters(period: 1.2, motionDuration: 1.2, offset: 0.03, rotationDegrees: 4)
        case .raisedHandSway:
            return CharacterLoopParameters(period: 4, motionDuration: 0.6, offset: 0, rotationDegrees: 6)
        case .idleZzz:
            return CharacterLoopParameters(period: 6, motionDuration: 1.5, offset: 0.2, rotationDegrees: 0)
        }
    }
}

/// 循環動作的參數。時間以秒為單位，位移以角色邊長的比例表示，因此任何尺寸都維持相同比例。
public struct CharacterLoopParameters: Hashable, Sendable {
    /// 一個完整週期的長度。
    public var period: TimeInterval
    /// 一個週期中實際在動的時間；其餘時間靜止。
    public var motionDuration: TimeInterval
    /// 位移幅度（角色邊長的比例）：幹活時的上下跳動、躺平時 Zzz 往上飄的距離。
    public var offset: Double
    /// 擺動角度（度）。
    public var rotationDegrees: Double

    public init(period: TimeInterval, motionDuration: TimeInterval, offset: Double, rotationDegrees: Double) {
        self.period = period
        self.motionDuration = motionDuration
        self.offset = offset
        self.rotationDegrees = rotationDegrees
    }

    /// 一個週期中靜止的時間。
    public var restDuration: TimeInterval { period - motionDuration }
}

/// 一次性過渡的動畫參數。
public struct CharacterTransitionParameters: Hashable, Sendable {
    /// 過渡全長（秒），只播一次。
    public var duration: TimeInterval
    /// 跳起的高度（角色邊長的比例）；0 表示不跳。
    public var jumpHeight: Double
    /// 過渡開始時新姿勢的不透明度，之後在 `duration` 內回到 1；1 表示不淡入。
    public var startOpacity: Double

    public init(duration: TimeInterval, jumpHeight: Double, startOpacity: Double) {
        self.duration = duration
        self.jumpHeight = jumpHeight
        self.startOpacity = startOpacity
    }
}

extension CharacterTransition {
    /// 這種過渡的動畫參數。
    public var parameters: CharacterTransitionParameters {
        switch self {
        case .celebrateOnce:
            // 跳一下約 0.5 秒，播完維持交工姿勢。
            return CharacterTransitionParameters(duration: 0.5, jumpHeight: 0.15, startOpacity: 1)
        case .slowToIdle:
            // 約 0.8 秒緩慢淡入躺平姿勢，不跳、不閃動。
            return CharacterTransitionParameters(duration: 0.8, jumpHeight: 0, startOpacity: 0.5)
        }
    }
}

/// 角色的動作描述：姿勢的循環動作與可選的一次性過渡。
///
/// 這是純值。系統 Reduce Motion 開啟或使用者關閉動畫時，循環與過渡一律為 nil，畫面只照它繪製靜態姿勢。
public struct CharacterMotion: Hashable, Sendable {
    /// 持續播放的循環動作；交工、警示、疑惑沒有循環。
    public var loop: CharacterLoop?
    /// 要播放一次的過渡，來自 `CharacterPresentation.transition`。
    public var transition: CharacterTransition?

    /// - Parameters:
    ///   - pose: 目前的靜態姿勢。
    ///   - transition: `CharacterPresentation` 輸出的過渡；沒有時為 nil。
    ///   - reduceMotion: 系統 Reduce Motion 是否開啟。
    ///   - animationsEnabled: 使用者是否開啟動畫（`AppSettings.animationsEnabled`）。
    public init(
        pose: CharacterPose,
        transition: CharacterTransition? = nil,
        reduceMotion: Bool,
        animationsEnabled: Bool
    ) {
        let allowsMotion = animationsEnabled && !reduceMotion
        self.loop = allowsMotion ? Self.loop(for: pose) : nil
        self.transition = allowsMotion ? transition : nil
    }

    private static func loop(for pose: CharacterPose) -> CharacterLoop? {
        switch pose {
        case .working: return .workingBob
        case .raisingHand: return .raisedHandSway
        case .lyingDown: return .idleZzz
        // Error 為靜態警示，不永久閃動；Unknown 不需動畫；交工只在過渡時跳一次。
        case .delivering, .alert, .puzzled: return nil
        }
    }
}
