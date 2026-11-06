import IdleVillagerCore

extension StoreSnapshot {
    /// 把指定 Session 的正規化狀態改成 Error 並重算計數。
    ///
    /// Herdr 沒有錯誤狀態，`StateNormalizer.rawStateTable` 也沒有任何鍵對應 Error，
    /// 因此經由 Store 無法產生 Error。畫面模型仍要能呈現 Error（保留給日後的其他來源），
    /// 測試以這個 helper 直接在 Store snapshot 上製造 Error。
    func forcingError(for ids: Set<String>) -> StoreSnapshot {
        var copy = self
        copy.sessions = sessions.map { entry in
            var entry = entry
            if ids.contains(entry.id.rawValue) {
                entry.normalizedState = .error
                entry.conflictNote = nil
            }
            return entry
        }
        var counts = StateCounts()
        for entry in copy.sessions { counts[entry.normalizedState] += 1 }
        copy.counts = counts
        return copy
    }
}
