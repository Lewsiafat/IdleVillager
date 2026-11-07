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
        #expect(MenuBarCharacterMode(snapshot: preview, menuBarMode: .counts).display == .counts)
    }

    /// 完整示範有 7 個 Session，超過少量角色門檻會退回數量模式；角色模式的預覽必須真的畫出角色。
    @Test func fewCharactersPreviewStaysBelowThresholdAndShowsCharacters() {
        let preview = StoreSnapshot.menuBarPreview(for: .fewCharacters)

        guard case .characters(let items) = MenuBarCharacterMode(snapshot: preview, menuBarMode: .fewCharacters).display else {
            Issue.record("角色模式預覽退回了數量模式")
            return
        }
        #expect(items.map(\.normalizedState) == [.needsApproval, .working, .idle])
        #expect(preview.counts.total == 3)
    }
}
