import Foundation

/// 角色在某個姿勢下持續播放的循環動作。只描述「要播什麼、節奏多快」，動畫本身由 App 層實作。
///
/// 哪個姿勢播哪種循環、什麼時候不播，由 `CharacterPresentation.loop` 決定。
public enum CharacterLoop: String, CaseIterable, Hashable, Sendable {
    /// 幹活：微幅上下跳動並左右擺動，像在敲鍵盤或揮工具。平穩循環，整個週期都在動（motionDuration 等於 period）。
    case workingBob
    /// 舉手：每隔一段時間小幅晃一下，大部分時間靜止。稀疏節奏、不閃爍。
    case raisedHandSway
    /// 躺平：偶爾浮出一個 Zzz 再淡出。低頻率。
    case idleZzz

    /// 這種循環的節奏與幅度。
    public var parameters: CharacterLoopParameters {
        switch self {
        case .workingBob:
            return CharacterLoopParameters(period: 1.6, motionDuration: 1.6, offset: 0.03, rotationDegrees: 3)
        case .raisedHandSway:
            return CharacterLoopParameters(period: 4, motionDuration: 0.6, offset: 0, rotationDegrees: 6)
        case .idleZzz:
            return CharacterLoopParameters(period: 6, motionDuration: 1.5, offset: 0.15, rotationDegrees: 0)
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
