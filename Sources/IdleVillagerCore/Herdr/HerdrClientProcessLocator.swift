import Foundation
import Darwin

/// 把終端機 App 帶到 macOS 前景的介面。
///
/// Herdr 的聚焦只作用在 TUI 內部，前景切換要由本專案自己做（見 `docs/adr/0002-herdr-socket-api.md`「聚焦與前景」）。
/// 實作需要 AppKit，因此放在 App target；Core 只定義介面，保持不依賴 AppKit。
public protocol TerminalActivator: Sendable {
    /// - Parameter processAncestries: 每個 Herdr 客戶端程序各一條 pid 鏈，從客戶端本身往上到 launchd。
    ///   實作沿鏈往上找第一個有 bundle identifier 的 App 並帶到前景。
    /// - Returns: 是否成功帶到前景。
    func activate(processAncestries: [[pid_t]]) async -> Bool
}

/// 以 `sysctl` 找出執行 Herdr 客戶端（TUI）的程序與它的父程序鏈。
///
/// Herdr 客戶端是執行檔名稱為 `herdr`、且第一個參數不是 `server` 的程序。
public enum HerdrClientProcessLocator {
    /// 目前所有 Herdr 客戶端程序的 pid 鏈（客戶端在前，往上到 pid 1 為止）。
    public static func clientAncestries() -> [[pid_t]] {
        allProcesses()
            .filter { $0.name == "herdr" && isClient(arguments: arguments(of: $0.pid)) }
            .map { ancestry(of: $0.pid) }
    }

    /// 參數清單（含 argv[0]）是否代表 Herdr 客戶端。讀不到參數時保守地視為客戶端，交給前景切換步驟再確認。
    public static func isClient(arguments: [String]?) -> Bool {
        guard let arguments else { return true }
        return arguments.dropFirst().first != "server"
    }

    struct ProcessEntry {
        var pid: pid_t
        var parentPID: pid_t
        var name: String
    }

    static func allProcesses() -> [ProcessEntry] {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else { return [] }
        // 兩次呼叫之間程序可能增加，多留一些空間。
        size += size / 8
        let stride = MemoryLayout<kinfo_proc>.stride
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
        guard sysctl(&mib, u_int(mib.count), &procs, &size, nil, 0) == 0 else { return [] }
        return procs.prefix(size / stride).map(entry(from:))
    }

    static func process(_ pid: pid_t) -> ProcessEntry? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        guard sysctl(&mib, u_int(mib.count), &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return entry(from: info)
    }

    /// 從 `pid` 往上的父程序鏈，包含 `pid` 本身，到 pid 1 或找不到父程序為止。
    static func ancestry(of pid: pid_t) -> [pid_t] {
        var chain: [pid_t] = []
        var current = pid
        while current > 0, !chain.contains(current), chain.count < 64 {
            chain.append(current)
            guard current != 1, let parent = process(current)?.parentPID else { break }
            current = parent
        }
        return chain
    }

    /// 讀取程序的參數（`KERN_PROCARGS2`）。只用來判斷是否為 `herdr server`，不保存也不記錄。
    static func arguments(of pid: pid_t) -> [String]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROCARGS2, pid]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > MemoryLayout<Int32>.size else { return nil }
        var buffer = [UInt8](repeating: 0, count: size)
        guard sysctl(&mib, u_int(mib.count), &buffer, &size, nil, 0) == 0 else { return nil }
        let argc = buffer.withUnsafeBytes { $0.load(as: Int32.self) }
        var index = MemoryLayout<Int32>.size
        // 跳過執行檔路徑與其後的補白 NUL。
        while index < size, buffer[index] != 0 { index += 1 }
        while index < size, buffer[index] == 0 { index += 1 }
        var arguments: [String] = []
        while arguments.count < Int(argc), index < size {
            let start = index
            while index < size, buffer[index] != 0 { index += 1 }
            arguments.append(String(decoding: buffer[start..<index], as: UTF8.self))
            index += 1
        }
        return arguments
    }

    private static func entry(from info: kinfo_proc) -> ProcessEntry {
        var comm = info.kp_proc.p_comm
        let name = withUnsafeBytes(of: &comm) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
        return ProcessEntry(pid: info.kp_proc.p_pid, parentPID: info.kp_eproc.e_ppid, name: name)
    }
}
