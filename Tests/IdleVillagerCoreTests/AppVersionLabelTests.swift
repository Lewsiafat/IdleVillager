import Testing
import IdleVillagerCore

@Test func 有版號時加上v前綴() {
    #expect(AppVersionLabel.text(shortVersion: "0.1.0") == "v0.1.0")
}

@Test func 讀不到版號時顯示開發版() {
    #expect(AppVersionLabel.text(shortVersion: nil) == "開發版")
}

@Test func 空白版號視為讀不到() {
    #expect(AppVersionLabel.text(shortVersion: "") == "開發版")
    #expect(AppVersionLabel.text(shortVersion: "  ") == "開發版")
}

@Test func 版號前後空白會被去掉() {
    #expect(AppVersionLabel.text(shortVersion: " 0.1.0\n") == "v0.1.0")
}

@Test func 無障礙文字說明版本() {
    #expect(AppVersionLabel.accessibilityText(shortVersion: "0.1.0") == "IdleVillager 版本 0.1.0")
    #expect(AppVersionLabel.accessibilityText(shortVersion: nil) == "IdleVillager 開發版")
}
