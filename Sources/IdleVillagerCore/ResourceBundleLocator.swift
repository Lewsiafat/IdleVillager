import Foundation

/// 尋找 SwiftPM 的 resource bundle，取代 SwiftPM 自動產生的 `Bundle.module`。
///
/// 自動產生的 `Bundle.module` 只查 `.app` 根目錄與寫死的本機建置路徑，兩處都找不到就 `fatalError`。
/// 打包成 `.app` 時，resource bundle 必須放在 `Contents/Resources` 才能通過 codesign，
/// 而別人的電腦上沒有本機建置路徑，所以 `Bundle.module` 一定會閃退（見 `docs/08-distribution.md`）。
/// 這裡依序查 `Contents/Resources`、`.app` 根目錄與執行檔所在目錄（`swift run` 時 resource bundle 就在這裡），
/// 找不到時回傳 nil，由呼叫端改用不需要資源的備援畫面。
public enum ResourceBundleLocator {
    /// 依查找優先順序排列的候選目錄。
    public static func candidateDirectories(
        resourceURL: URL?,
        bundleURL: URL,
        executableURL: URL?
    ) -> [URL] {
        var directories: [URL] = []
        for url in [resourceURL, bundleURL, executableURL?.deletingLastPathComponent()] {
            guard let url else { continue }
            // 以 path 比較：`deletingLastPathComponent()` 產生的 URL 帶結尾斜線，URL 相等比較會當成不同目錄。
            let standardized = URL(fileURLWithPath: url.standardizedFileURL.path, isDirectory: true)
            if !directories.contains(where: { $0.path == standardized.path }) {
                directories.append(standardized)
            }
        }
        return directories
    }

    /// 回傳第一個存在名為 `bundleName` 之目錄的位置；都不存在時回傳 nil。
    public static func locate(
        bundleName: String,
        in directories: [URL],
        fileManager: FileManager = .default
    ) -> URL? {
        for directory in directories {
            let candidate = directory.appendingPathComponent(bundleName, isDirectory: true)
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: candidate.path, isDirectory: &isDirectory), isDirectory.boolValue {
                return candidate
            }
        }
        return nil
    }

    /// 在 `bundle`（預設為主程式）周圍尋找名為 `bundleName` 的 resource bundle。
    public static func bundle(named bundleName: String, around bundle: Bundle = .main) -> Bundle? {
        let directories = candidateDirectories(
            resourceURL: bundle.resourceURL,
            bundleURL: bundle.bundleURL,
            executableURL: bundle.executableURL
        )
        return locate(bundleName: bundleName, in: directories).flatMap(Bundle.init(url:))
    }
}
