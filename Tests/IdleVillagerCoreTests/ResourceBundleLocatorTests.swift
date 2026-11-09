import Foundation
import Testing
import IdleVillagerCore

private let bundleName = "IdleVillager_IdleVillagerApp.bundle"

/// 在暫存目錄建立一個假的 IdleVillager.app 結構，測試結束後刪除。
private func withFakeApp(_ body: (_ app: URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("ResourceBundleLocatorTests-\(UUID().uuidString)", isDirectory: true)
    let app = root.appendingPathComponent("IdleVillager.app", isDirectory: true)
    try FileManager.default.createDirectory(
        at: app.appendingPathComponent("Contents/MacOS"), withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
        at: app.appendingPathComponent("Contents/Resources"), withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: root) }
    try body(app)
}

private func directories(for app: URL) -> [URL] {
    ResourceBundleLocator.candidateDirectories(
        resourceURL: app.appendingPathComponent("Contents/Resources"),
        bundleURL: app,
        executableURL: app.appendingPathComponent("Contents/MacOS/IdleVillager")
    )
}

@Test func 候選目錄依序為Resources_app根目錄_執行檔目錄() throws {
    let app = URL(fileURLWithPath: "/Applications/IdleVillager.app")
    #expect(directories(for: app).map(\.path) == [
        "/Applications/IdleVillager.app/Contents/Resources",
        "/Applications/IdleVillager.app",
        "/Applications/IdleVillager.app/Contents/MacOS",
    ])
}

@Test func swiftRun時三個候選目錄相同只保留一個() {
    let buildDirectory = URL(fileURLWithPath: "/repo/.build/debug")
    let result = ResourceBundleLocator.candidateDirectories(
        resourceURL: buildDirectory,
        bundleURL: buildDirectory,
        executableURL: buildDirectory.appendingPathComponent("IdleVillagerApp")
    )
    #expect(result.map(\.path) == ["/repo/.build/debug"])
}

@Test func 找到放在ContentsResources的bundle() throws {
    try withFakeApp { app in
        let expected = app.appendingPathComponent("Contents/Resources/\(bundleName)")
        try FileManager.default.createDirectory(at: expected, withIntermediateDirectories: true)
        let found = ResourceBundleLocator.locate(bundleName: bundleName, in: directories(for: app))
        #expect(found?.standardizedFileURL == expected.standardizedFileURL)
    }
}

@Test func Resources優先於app根目錄() throws {
    try withFakeApp { app in
        let inResources = app.appendingPathComponent("Contents/Resources/\(bundleName)")
        try FileManager.default.createDirectory(at: inResources, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(
            at: app.appendingPathComponent(bundleName), withIntermediateDirectories: true
        )
        let found = ResourceBundleLocator.locate(bundleName: bundleName, in: directories(for: app))
        #expect(found?.standardizedFileURL == inResources.standardizedFileURL)
    }
}

@Test func 找不到bundle時回傳nil而不是閃退() throws {
    try withFakeApp { app in
        #expect(ResourceBundleLocator.locate(bundleName: bundleName, in: directories(for: app)) == nil)
    }
}

@Test func 同名的一般檔案不算bundle() throws {
    try withFakeApp { app in
        let file = app.appendingPathComponent("Contents/Resources/\(bundleName)")
        try Data().write(to: file)
        #expect(ResourceBundleLocator.locate(bundleName: bundleName, in: directories(for: app)) == nil)
    }
}
