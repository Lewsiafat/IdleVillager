import SwiftUI
import IdleVillagerCore

/// The "Appearance" section of the Settings window: the translucent popover background toggle.
///
/// On/off only for now. An opacity slider, if added later, belongs in this section and feeds
/// `PopoverBackgroundStyle.resolve` in Core.
struct AppearanceSettingsSection: View {
    @Bindable var settings: AppSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Section(L10n.text(.settingsAppearanceSection)) {
            Toggle(isOn: $settings.translucentPopoverBackground) {
                Text(L10n.text(.settingsTranslucentPopover))
                // Tell the user why turning it on changes nothing while the system setting overrides it.
                Text(L10n.text(showsSystemOverride ? .settingsTranslucentPopoverReduced : .settingsTranslucentPopoverDetail))
                    .font(.caption)
            }
        }
    }

    private var showsSystemOverride: Bool {
        settings.translucentPopoverBackground
            && settings.popoverBackgroundStyle(reduceTransparency: reduceTransparency) == .opaque
    }
}
