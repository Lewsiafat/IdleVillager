import Testing
import IdleVillagerCore

struct CharacterMotionTests {
    // MARK: 姿勢對應的循環動作

    @Test(arguments: [
        (CharacterPose.working, CharacterLoop?.some(.workingBob)),
        (.raisingHand, .raisedHandSway),
        (.lyingDown, .idleZzz),
        (.delivering, nil),
        (.alert, nil),
        (.puzzled, nil),
    ])
    func eachPoseHasItsLoop(pose: CharacterPose, expected: CharacterLoop?) {
        #expect(CharacterMotion(pose: pose, reduceMotion: false, animationsEnabled: true).loop == expected)
    }

    @Test(arguments: CharacterPose.allCases)
    func reduceMotionHasNoLoop(pose: CharacterPose) {
        #expect(CharacterMotion(pose: pose, reduceMotion: true, animationsEnabled: true).loop == nil)
    }

    @Test(arguments: CharacterPose.allCases)
    func animationsDisabledHasNoLoop(pose: CharacterPose) {
        #expect(CharacterMotion(pose: pose, reduceMotion: false, animationsEnabled: false).loop == nil)
        #expect(CharacterMotion(pose: pose, reduceMotion: true, animationsEnabled: false).loop == nil)
    }

    // MARK: 過渡

    @Test(arguments: [CharacterTransition.celebrateOnce, .slowToIdle])
    func transitionPassesThroughWhenMotionIsAllowed(transition: CharacterTransition) {
        let motion = CharacterMotion(pose: .delivering, transition: transition, reduceMotion: false, animationsEnabled: true)

        #expect(motion.transition == transition)
    }

    @Test func noTransitionStaysNil() {
        #expect(CharacterMotion(pose: .working, transition: nil, reduceMotion: false, animationsEnabled: true).transition == nil)
        #expect(CharacterMotion(pose: .working, reduceMotion: false, animationsEnabled: true).transition == nil)
    }

    @Test(arguments: [CharacterTransition.celebrateOnce, .slowToIdle], [(true, true), (false, false), (true, false)])
    func transitionIsDroppedWhenMotionIsNotAllowed(transition: CharacterTransition, flags: (Bool, Bool)) {
        let motion = CharacterMotion(pose: .lyingDown, transition: transition, reduceMotion: flags.0, animationsEnabled: flags.1)

        #expect(motion.transition == nil)
        #expect(motion.loop == nil)
    }

    // MARK: 循環參數

    @Test func workingBobIsASteadyLoop() {
        let parameters = CharacterLoop.workingBob.parameters

        #expect(parameters.period == 1.6)
        #expect(parameters.motionDuration == 1.6)
        #expect(parameters.offset == 0.03)
        #expect(parameters.rotationDegrees == 3)
    }

    @Test func raisedHandSwayIsSparse() {
        let parameters = CharacterLoop.raisedHandSway.parameters

        #expect(parameters.period == 4)
        #expect(parameters.motionDuration == 0.6)
        #expect(parameters.offset == 0)
        #expect(parameters.rotationDegrees == 6)
    }

    @Test func raisedHandSwayNeverFlashes() {
        // 不閃爍的量化定義：一個週期至少 3 秒，而且大部分時間靜止。
        let parameters = CharacterLoop.raisedHandSway.parameters

        #expect(parameters.period >= 3)
        #expect(parameters.motionDuration * 2 <= parameters.period)
    }

    @Test func idleZzzIsLowFrequency() {
        let parameters = CharacterLoop.idleZzz.parameters

        #expect(parameters.period == 6)
        #expect(parameters.motionDuration == 1.5)
        #expect(parameters.offset == 0.15)
        #expect(parameters.rotationDegrees == 0)
    }

    @Test(arguments: CharacterLoop.allCases)
    func motionFitsInsideItsPeriod(loop: CharacterLoop) {
        let parameters = loop.parameters

        #expect(parameters.motionDuration > 0)
        #expect(parameters.motionDuration <= parameters.period)
        #expect(parameters.restDuration == parameters.period - parameters.motionDuration)
    }

    // MARK: 過渡參數

    @Test func celebrateOnceJumpsBrieflyOnce() {
        let parameters = CharacterTransition.celebrateOnce.parameters

        #expect(parameters.duration == 0.5)
        #expect(parameters.jumpHeight == 0.15)
        #expect(parameters.startOpacity == 1)
    }

    @Test func slowToIdleSettlesSlowlyWithoutJumping() {
        let parameters = CharacterTransition.slowToIdle.parameters

        #expect(parameters.duration == 0.8)
        #expect(parameters.jumpHeight == 0)
        #expect(parameters.startOpacity == 0.5)
    }
}

// MARK: 過渡參數的不變條件

struct CharacterTransitionParametersTests {
    /// 過渡的長度必須大於 0。SwiftUI 的 keyframe 動畫以「經過時間 ÷ 全長」算進度，全長為 0 會算出 NaN，
    /// 角色的位移與不透明度變成 NaN，AppKit 檢查到 view 高度為 NaN 就會中止程式（issue #55）。
    @Test(arguments: CharacterTransition.allCases)
    func transitionDurationIsPositive(transition: CharacterTransition) {
        #expect(transition.parameters.duration > 0)
    }
}
