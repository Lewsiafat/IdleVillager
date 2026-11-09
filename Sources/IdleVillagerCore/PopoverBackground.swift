/// How the popover (the expanded session list under the menu bar) paints its background.
///
/// The user only chooses on or off (`AppSettings.translucentPopoverBackground`); the style actually used is
/// decided here so the rule stays in one unit-testable place. If an opacity slider is added later, it becomes
/// another input of `resolve` (and an associated value or property of `.translucent`), while the views keep
/// asking this type instead of reading settings directly.
public enum PopoverBackgroundStyle: String, CaseIterable, Hashable, Sendable {
    /// The system's standard popover background, exactly as before translucency existed.
    case opaque
    /// A behind-window material that lets the desktop and other windows show through, blurred.
    case translucent

    /// Picks the style from the user's choice and the system accessibility setting.
    ///
    /// - Parameters:
    ///   - translucentEnabled: The user turned on the translucent background in Settings.
    ///   - reduceTransparency: macOS "Reduce transparency" is on. It always wins, so the popover falls back
    ///     to the opaque look even when the user enabled translucency. (macOS also turns this on whenever
    ///     "Increase contrast" is on.)
    public static func resolve(translucentEnabled: Bool, reduceTransparency: Bool) -> PopoverBackgroundStyle {
        translucentEnabled && !reduceTransparency ? .translucent : .opaque
    }

    /// Opacity of the window-background-colored backing drawn under each Workspace card, so rows, characters
    /// and state capsules sit on a calmer surface than the raw blurred desktop.
    ///
    /// nil means the card keeps its regular subtle fill (the opaque look is unchanged).
    public var workspaceCardBackingOpacity: Double? {
        switch self {
        case .opaque: nil
        case .translucent: 0.5
        }
    }
}

extension AppSettings {
    /// The popover background style for the current settings and the system "Reduce transparency" value.
    ///
    /// Reads `translucentPopoverBackground`, so a view calling this from `body` is redrawn when the toggle changes.
    public func popoverBackgroundStyle(reduceTransparency: Bool) -> PopoverBackgroundStyle {
        PopoverBackgroundStyle.resolve(
            translucentEnabled: translucentPopoverBackground,
            reduceTransparency: reduceTransparency
        )
    }
}
