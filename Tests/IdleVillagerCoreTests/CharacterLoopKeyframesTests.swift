import Testing
import IdleVillagerCore

struct CharacterLoopKeyframesTests {
    // MARK: 所有循環共通

    @Test(arguments: CharacterLoop.allCases)
    func coversExactlyOnePeriod(loop: CharacterLoop) {
        let keyframes = loop.keyframes

        #expect(keyframes.period == loop.parameters.period)
        #expect(keyframes.frames.first?.time == 0)
        #expect(keyframes.frames.last?.time == loop.parameters.period)
    }

    @Test(arguments: CharacterLoop.allCases)
    func timesStrictlyIncrease(loop: CharacterLoop) {
        let times = loop.keyframes.frames.map(\.time)

        #expect(times.count >= 2)
        #expect(zip(times, times.dropFirst()).allSatisfy { $0 < $1 })
    }

    /// 重複播放時從最後一格直接跳回第一格，兩者不同就會看到跳動。
    @Test(arguments: CharacterLoop.allCases)
    func endsWhereItStartsSoRepeatingIsSeamless(loop: CharacterLoop) {
        let frames = loop.keyframes.frames

        #expect(frames.first?.pose == frames.last?.pose)
    }

    // MARK: 幹活

    @Test func workingBobMovesTheCharacterThroughoutThePeriod() {
        let keyframes = CharacterLoop.workingBob.keyframes
        let poses = keyframes.frames.map(\.pose)

        #expect(keyframes.target == .character)
        // 沒有任何一段是靜止的。
        #expect(zip(poses, poses.dropFirst()).allSatisfy { $0 != $1 })
    }

    @Test func workingBobBobsUpAndSwaysBothWays() {
        let parameters = CharacterLoop.workingBob.parameters
        let poses = CharacterLoop.workingBob.keyframes.frames.map(\.pose)

        #expect(poses.map(\.lift).max() == parameters.offset)
        #expect(poses.map(\.lift).min() == 0)
        #expect(poses.map(\.rotationDegrees).max() == parameters.rotationDegrees)
        #expect(poses.map(\.rotationDegrees).min() == -parameters.rotationDegrees)
        #expect(poses.allSatisfy { $0.opacity == 1 })
    }

    // MARK: 舉手

    @Test func raisedHandSwayStaysStillForTheRestDuration() {
        let parameters = CharacterLoop.raisedHandSway.parameters
        let keyframes = CharacterLoop.raisedHandSway.keyframes
        let rest = keyframes.frames.filter { $0.time <= parameters.restDuration }

        #expect(keyframes.target == .character)
        #expect(rest.last?.time == parameters.restDuration)
        #expect(Set(rest.map(\.pose)) == [CharacterLoopPose.neutral])
    }

    @Test func raisedHandSwaySwaysBothWaysDuringTheMotion() {
        let parameters = CharacterLoop.raisedHandSway.parameters
        let rotations = CharacterLoop.raisedHandSway.keyframes.frames.map(\.pose.rotationDegrees)

        #expect(rotations.max() == parameters.rotationDegrees)
        #expect(rotations.min() == -parameters.rotationDegrees)
    }

    // MARK: 躺平

    @Test func idleZzzAnimatesTheMarkerNotTheCharacter() {
        #expect(CharacterLoop.idleZzz.keyframes.target == .zzzMarker)
    }

    @Test func idleZzzMarkerIsHiddenWhileResting() {
        let parameters = CharacterLoop.idleZzz.parameters
        let frames = CharacterLoop.idleZzz.keyframes.frames
        // 靜止時段內最後一格之前都看不見；之後才開始浮現。
        let resting = frames.filter { $0.time < parameters.restDuration - 0.1 }

        #expect(!resting.isEmpty)
        #expect(resting.allSatisfy { $0.pose.opacity == 0 })
    }

    @Test func idleZzzMarkerAppearsThenFloatsUpAndFades() {
        let parameters = CharacterLoop.idleZzz.parameters
        let poses = CharacterLoop.idleZzz.keyframes.frames.map(\.pose)
        let shown = poses.firstIndex { $0.opacity == 1 }
        let floated = poses.firstIndex { $0.lift == parameters.offset }

        #expect(shown != nil)
        #expect(floated != nil)
        if let shown, let floated {
            #expect(shown < floated)
            #expect(poses[floated].opacity == 0)
        }
    }

    @Test func idleZzzMotionFitsInTheMotionDuration() {
        let parameters = CharacterLoop.idleZzz.parameters
        let frames = CharacterLoop.idleZzz.keyframes.frames
        let moving = frames.filter { $0.pose != frames[0].pose }

        #expect((moving.first?.time ?? 0) >= parameters.restDuration - 0.1)
    }
}
