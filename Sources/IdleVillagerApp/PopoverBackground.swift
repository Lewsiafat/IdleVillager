import AppKit
import SwiftUI
import IdleVillagerCore

/// Paints the translucent popover background with AppKit behind-window vibrancy.
///
/// Why `NSVisualEffectView` instead of a SwiftUI `Material` such as `.ultraThinMaterial`:
/// - A SwiftUI material used as `.background` blends *within* the window, i.e. it only blurs what this window
///   already drew underneath (the popover's own background), so the desktop never shows through.
/// - The SwiftUI way to get behind-window blending, `.containerBackground(_:for: .window)`, needs macOS 15,
///   and `MenuBarExtra` does not expose its window, so we cannot clear the window background either.
/// - `NSVisualEffectView` with `.behindWindow` blending samples whatever is behind the window through the
///   window server, independent of what the hosting window draws, and needs no private window access.
///
/// `state` is pinned to `.active`: with the default `.followsWindowActiveState` the material turns into a flat
/// inactive gray whenever the panel is not the key window.
struct BehindWindowMaterial: NSViewRepresentable {
    /// `.hudWindow` is clearly more see-through than the standard popover material and follows light and
    /// dark appearance. Visually verify on a real Mac before changing.
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
    }
}

private struct PopoverBackgroundStyleKey: EnvironmentKey {
    static let defaultValue: PopoverBackgroundStyle = .opaque
}

extension EnvironmentValues {
    /// The resolved popover background style, set by `popoverBackground(settings:)` on the popover root and read
    /// by the Workspace cards to strengthen their backing on the translucent background.
    var popoverBackgroundStyle: PopoverBackgroundStyle {
        get { self[PopoverBackgroundStyleKey.self] }
        set { self[PopoverBackgroundStyleKey.self] = newValue }
    }
}

/// Applies the popover background chosen by `AppSettings.popoverBackgroundStyle(reduceTransparency:)`.
///
/// The decision lives in Core; this modifier only reads the system "Reduce transparency" value and draws.
/// Because `body` reads `settings` (an `@Observable` model) and the environment value, toggling the setting
/// or the system accessibility option redraws the open popover immediately.
private struct PopoverBackgroundModifier: ViewModifier {
    let settings: AppSettings
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        let style = settings.popoverBackgroundStyle(reduceTransparency: reduceTransparency)
        content
            // The condition stays inside `background`, so switching styles never changes the identity of the
            // list itself (collapsed Tabs and the measured list height are kept).
            .background {
                if style == .translucent {
                    BehindWindowMaterial()
                        .ignoresSafeArea()
                }
            }
            .environment(\.popoverBackgroundStyle, style)
    }
}

extension View {
    /// Paints the popover background for the current settings; opaque leaves the system background untouched.
    func popoverBackground(settings: AppSettings) -> some View {
        modifier(PopoverBackgroundModifier(settings: settings))
    }
}
