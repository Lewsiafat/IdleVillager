import Testing
import IdleVillagerCore

/// 設定視窗「選單列預覽」用的示範快照。
@Suite struct MenuBarPreviewTests {
    @Test func countsPreviewShowsTheFullDemoAsCounts() {
        let preview = StoreSnapshot.menuBarPreview(for: .counts)

        #expect(preview.connectionState == .connected)
        #expect(preview.counts.working == 3)
        #expect(preview.counts.needsApproval == 2)
        #expect(preview.counts.idle == 1)
        #expect(preview.counts.done == 1)
        guard case .counts = MenuBarPresentation(snapshot: preview, menuBarMode: .counts, isBrandAssetAvailable: { _ in false }).content else {
            Issue.record("數量模式預覽沒有畫出數量列")
            return
        }
    }

    /// 完整示範有 7 個 Session，超過少量角色門檻會退回數量模式；角色模式的預覽必須真的畫出角色。
    @Test func fewCharactersPreviewStaysBelowThresholdAndShowsCharacters() {
        let preview = StoreSnapshot.menuBarPreview(for: .fewCharacters)

        let presentation = MenuBarPresentation(snapshot: preview, menuBarMode: .fewCharacters, isBrandAssetAvailable: { _ in false })
        guard case .characters(let items) = presentation.content else {
            Issue.record("角色模式預覽退回了數量模式")
            return
        }
        #expect(items.map(\.normalizedState) == [.needsApproval, .working, .idle])
        #expect(preview.counts.total == 3)
    }
}
