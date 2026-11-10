import AppKit
import SwiftUI
import IdleVillagerCore

/// Paints the translucent popover background with AppKit behind-window vibrancy.
///
/// Why `NSVisualEffectView` instead of a SwiftUI `Material` such as `.ultraThinMaterial`:
/// - A SwiftUI material used as `.background` blends *within* the window, i.e. it only blurs what this window
///   already drew underneath (the popover's own background), so the desktop never shows through.
/// - The SwiftUI way to get behind-window blending, `.containerBackground(_:for: .window)`, needs macOS 15.
/// - `NSVisualEffectView` with `.behindWindow` blending samples whatever is behind the window through the
///   window server, independent of what the hosting window draws, and needs no private window access.
///
/// The effect view alone is not enough: `MenuBarExtra` (`.window` style) makes SwiftUI draw its own full-size
/// window background as sibling views *below* the content, one of them fully opaque, so the desktop stays
/// hidden. `TranslucentBackdropView` hides those siblings while it is on screen and restores them when removed.
/// Verified on macOS 14.6 by dumping the view tree of the real popover window.
///
/// `state` is pinned to `.active`: with the default `.followsWindowActiveState` the material turns into a flat
/// inactive gray whenever the panel is not the key window.
struct BehindWindowMaterial: NSViewRepresentable {
    /// `.hudWindow` is clearly more see-through than the standard popover material and follows light and
    /// dark appearance. Visually verify on a real Mac before changing.
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> TranslucentBackdropView {
        let view = TranslucentBackdropView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = material
        return view
    }

    func updateNSView(_ nsView: TranslucentBackdropView, context: Context) {
        nsView.material = material
        nsView.hideHostBackground()
    }

    static func dismantleNSView(_ nsView: TranslucentBackdropView, coordinator: ()) {
        nsView.restoreHostBackground()
    }
}

/// Behind-window effect view that also hides the opaque window background SwiftUI draws under it.
///
/// View tree of the `MenuBarExtra` window (macOS 14.6):
/// `NSHostingView` > [SwiftUI background views..., host of this view, popover content...].
/// Subviews earlier in the array are drawn below later ones, so every full-size sibling before this view's
/// host is window background covering the desktop. Only those are hidden; the popover content after the host
/// is never touched.
final class TranslucentBackdropView: NSVisualEffectView {
    /// Views hidden by this instance, restored when the translucent background is turned off.
    private var hiddenViews: [NSView] = []

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil {
            restoreHostBackground()
        } else {
            hideHostBackground()
        }
    }

    override func layout() {
        super.layout()
        // SwiftUI may rebuild its background views when the popover resizes; catch new ones here.
        hideHostBackground()
    }

    func hideHostBackground() {
        guard let host = superview, let container = host.superview,
              let hostIndex = container.subviews.firstIndex(of: host) else { return }
        for view in container.subviews[..<hostIndex]
        where !view.isHidden && view.frame == container.bounds {
            view.isHidden = true
            hiddenViews.append(view)
        }
    }

    func restoreHostBackground() {
        hiddenViews.forEach { $0.isHidden = false }
        hiddenViews.removeAll()
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
