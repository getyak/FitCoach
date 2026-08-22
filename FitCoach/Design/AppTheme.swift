import SwiftUI

enum AppTheme {
    static let pagePadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let controlHeight: CGFloat = 50

    /// Brand foreground adapts to the canvas. Keep it distinct from the
    /// deeper action fill, which must retain sufficient contrast with white.
    static let brand = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.54, blue: 0.31, alpha: 1)
            : UIColor(red: 0.76, green: 0.27, blue: 0.07, alpha: 1)
    })
    static let primaryAction = Color(
        red: 0.76,
        green: 0.27,
        blue: 0.07
    )
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let success = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1)
            : UIColor(red: 0.10, green: 0.48, blue: 0.20, alpha: 1)
    })
    static let warning = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.62, blue: 0.04, alpha: 1)
            : UIColor(red: 0.62, green: 0.31, blue: 0.00, alpha: 1)
    })
    /// Small supporting copy needs more contrast than the system secondary
    /// label on grouped surfaces while remaining visually quieter than body text.
    static let secondaryText = Color.primary.opacity(0.72)
    static let paper = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.075, green: 0.073, blue: 0.067, alpha: 1)
            : UIColor(red: 0.975, green: 0.969, blue: 0.949, alpha: 1)
    })
    static let inkAction = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.94, green: 0.93, blue: 0.89, alpha: 1)
            : UIColor(red: 0.105, green: 0.10, blue: 0.09, alpha: 1)
    })
    static let hairline = Color.primary.opacity(0.12)
}

struct AppCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .background(AppTheme.surface, in: RoundedRectangle(cornerRadius: AppTheme.cardRadius, style: .continuous))
    }
}

struct PrimaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 18)
            .foregroundStyle(Color.white)
            .background(
                isEnabled ? AppTheme.primaryAction : Color.secondary.opacity(0.35),
                in: Capsule()
            )
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.98 : 1))
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct SecondaryActionButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 18)
            .foregroundStyle(.primary)
            .background(Color.clear, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(
                        Color.primary.opacity(contrast == .increased ? 0.42 : 0.22),
                        lineWidth: contrast == .increased ? 1.5 : 1
                    )
            }
            .contentShape(Capsule())
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .opacity(isEnabled ? (configuration.isPressed ? 0.72 : 1) : 0.38)
            .animation(
                reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.86),
                value: configuration.isPressed
            )
    }
}

struct EditorialPrimaryButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 54)
            .padding(.horizontal, 18)
            .foregroundStyle(AppTheme.paper)
            .background(AppTheme.inkAction, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .scaleEffect(reduceMotion ? 1 : (configuration.isPressed ? 0.985 : 1))
            .animation(
                reduceMotion ? nil : .spring(response: 0.28, dampingFraction: 0.88),
                value: configuration.isPressed
            )
    }
}

struct FloatingTrainingChrome: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .padding(10)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .padding(10)
            .background(
                reduceTransparency ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground).opacity(0.94),
                in: RoundedRectangle(cornerRadius: 30, style: .continuous)
            )
            .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
    }
}

extension View {
    func floatingTrainingChrome() -> some View {
        modifier(FloatingTrainingChrome())
    }

    func minimumTapTarget() -> some View {
        frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }

    /// Keeps scrollable content legible as it approaches system glass chrome.
    /// Older systems already use an opaque tab bar and need no override.
    @ViewBuilder
    func protectedBottomScrollEdge() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectStyle(.hard, for: .bottom)
                .padding(.bottom, 72)
                .background(AppTheme.canvas)
        } else {
            self
        }
    }
}

struct MetricPill: View {
    let label: String
    let value: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
                    .accessibilityHidden(true)
            }
            Text(label)
                .foregroundStyle(AppTheme.secondaryText)
            Text(value)
                .fontWeight(.semibold)
                .monospacedDigit()
        }
        .font(.subheadline)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(AppTheme.elevatedSurface, in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
