import Foundation
import Darwin

/// 與 Herdr socket 通訊時的傳輸層錯誤。
public enum HerdrTransportError: Error, Hashable, Sendable {
    /// Socket 檔案不存在或連線被拒：Herdr 伺服器沒有在執行。
    case unreachable
    /// 讀寫逾時。
    case timedOut
    /// 伺服器在回應前關閉連線。
    case closedByPeer
    /// 其他系統呼叫錯誤（errno）。
    case system(Int32)
    /// 回應不是預期的 JSON。
    case malformedResponse
}

/// 一條 Unix domain socket 連線，以換行切分訊息（newline-delimited JSON）。
///
/// 使用阻塞式系統呼叫，呼叫端必須在背景執行緒上使用。`cancel()` 可從任何執行緒呼叫，
/// 用 `shutdown` 讓阻塞中的讀取立刻返回；檔案描述子只在 `deinit` 關閉，避免另一條執行緒讀到被重用的描述子。
final class UnixLineSocket: @unchecked Sendable {
    private let fd: Int32
    private var buffer = Data()
    private let lock = NSLock()
    private var cancelled = false

    /// 連到指定路徑。`timeout` 套用到之後每一次讀寫。
    init(path: String, timeout: TimeInterval) throws {
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw HerdrTransportError.system(errno) }

        var noSigPipe: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &noSigPipe, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let pathBytes = Array(path.utf8)
        let capacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count < capacity else {
            Darwin.close(fd)
            throw HerdrTransportError.system(ENAMETOOLONG)
        }
        withUnsafeMutableBytes(of: &address.sun_path) { raw in
            raw.copyBytes(from: pathBytes)
            raw[pathBytes.count] = 0
        }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)

        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.connect(fd, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        if result != 0 {
            let code = errno
            Darwin.close(fd)
            switch code {
            case ENOENT, ECONNREFUSED, ENOTDIR: throw HerdrTransportError.unreachable
            default: throw HerdrTransportError.system(code)
            }
        }
        self.fd = fd
        setTimeout(timeout)
    }

    deinit {
        Darwin.close(fd)
    }

    /// 設定讀寫逾時；0 代表不逾時（訂閱連線使用）。
    func setTimeout(_ seconds: TimeInterval) {
        var value = timeval(tv_sec: Int(seconds), tv_usec: Int32((seconds - floor(seconds)) * 1_000_000))
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &value, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &value, socklen_t(MemoryLayout<timeval>.size))
    }

    /// 送出一整行（呼叫端負責結尾換行）。
    func send(_ data: Data) throws {
        try data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            var offset = 0
            while offset < raw.count {
                let written = Darwin.send(fd, base + offset, raw.count - offset, 0)
                if written < 0 {
                    if errno == EINTR { continue }
                    throw errno == EAGAIN ? HerdrTransportError.timedOut : HerdrTransportError.system(errno)
                }
                offset += written
            }
        }
    }

    /// 讀取下一行（不含換行）。連線關閉時回傳 nil。
    func readLine() throws -> Data? {
        while true {
            if let newline = buffer.firstIndex(of: 0x0A) {
                let line = buffer[buffer.startIndex..<newline]
                buffer.removeSubrange(buffer.startIndex...newline)
                return Data(line)
            }
            var chunk = [UInt8](repeating: 0, count: 65_536)
            let count = chunk.withUnsafeMutableBytes { Darwin.recv(fd, $0.baseAddress, $0.count, 0) }
            if count == 0 { return nil }
            if count < 0 {
                if errno == EINTR { continue }
                if isCancelled { return nil }
                throw errno == EAGAIN ? HerdrTransportError.timedOut : HerdrTransportError.system(errno)
            }
            buffer.append(contentsOf: chunk[0..<count])
        }
    }

    /// 中止連線。阻塞中的 `readLine()` 會回傳 nil。可重複呼叫。
    func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return }
        cancelled = true
        Darwin.shutdown(fd, SHUT_RDWR)
    }

    private var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
}
