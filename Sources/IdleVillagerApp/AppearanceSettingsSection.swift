import SwiftUI
import IdleVillagerCore

/// The "Appearance" section of the Settings window: the interface language and the translucent popover background toggle.
///
/// On/off only for now. An opacity slider, if added later, belongs in this section and feeds
/// `PopoverBackgroundStyle.resolve` in Core.
struct AppearanceSettingsSection: View {
    @Bindable var settings: AppSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Section(L10n.text(.settingsAppearanceSection)) {
            Picker(L10n.text(.settingsLanguage), selection: languageSelection) {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Text(language.nativeName).tag(language)
                }
            }
            Toggle(isOn: $settings.translucentPopoverBackground) {
                Text(L10n.text(.settingsTranslucentPopover))
                // Tell the user why turning it on changes nothing while the system setting overrides it.
                Text(L10n.text(showsSystemOverride ? .settingsTranslucentPopoverReduced : .settingsTranslucentPopoverDetail))
                    .font(.caption)
            }
        }
    }

    /// Switches the process-wide strings before storing the choice, so the views rebuilt by
    /// `.id(settings.language)` already read the new language.
    private var languageSelection: Binding<AppLanguage> {
        Binding(
            get: { settings.language },
            set: { language in
                L10n.use(language)
                settings.language = language
            }
        )
    }

    private var showsSystemOverride: Bool {
        settings.translucentPopoverBackground
            && settings.popoverBackgroundStyle(reduceTransparency: reduceTransparency) == .opaque
    }
}
