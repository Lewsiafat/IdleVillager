import Foundation

extension StoreSnapshot {
    /// 設定視窗「選單列預覽」用的示範快照，內容取自 `SessionSnapshot.demo`，狀態經 `StateNormalizer` 正規化。
    ///
    /// 數量模式使用完整示範（7 個 Session）。少量角色模式只取前幾個 Session，數量低於
    /// `MenuBarCharacterMode.defaultFewCharactersThreshold`，否則預覽會自動退回數量模式，看不到角色。
    ///
    /// - Parameter menuBarMode: 使用者目前選的選單列模式。
    public static func menuBarPreview(for menuBarMode: MenuBarMode) -> StoreSnapshot {
        let allSessions = SessionSnapshot.demo.sessions
        let sessions = switch menuBarMode {
        case .counts: allSessions
        case .fewCharacters: Array(allSessions.prefix(MenuBarCharacterMode.defaultFewCharactersThreshold - 1))
        }
        // 預覽是固定的示範資料，不做過期判定。
        let result = normalizedEntries(from: sessions) { _ in false }
        return StoreSnapshot(
            connectionState: .connected,
            sourceDescription: SourceDescription.demo,
            lastUpdatedAt: result.sessions.map(\.session.updatedAt).max(),
            sessions: result.sessions,
            counts: result.counts
        )
    }
}
