import Testing
import IdleVillagerCore

/// 循環動作本身的節奏與幅度。哪個狀態播哪種循環、何時不播，見 `CharacterPresentationTests`。
struct CharacterLoopTests {
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
}
