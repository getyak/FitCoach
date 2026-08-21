import SwiftUI

enum AppTheme {
    static let pagePadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 20
    static let controlHeight: CGFloat = 50

    static let brand = Color.accentColor
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let elevatedSurface = Color(uiColor: .tertiarySystemGroupedBackground)
    static let canvas = Color(uiColor: .systemGroupedBackground)
    static let success = Color(uiColor: .systemGreen)
    static let warning = Color(uiColor: .systemOrange)
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

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppTheme.controlHeight)
            .padding(.horizontal, 18)
            .foregroundStyle(Color.white)
            .background(
                isEnabled ? AppTheme.brand : Color.secondary.opacity(0.35),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.82), value: configuration.isPressed)
    }
}

struct FloatingTrainingChrome: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *), !reduceTransparency {
            content
                .padding(10)
                .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        } else {
            content
                .padding(10)
                .background(
                    reduceTransparency ? Color(uiColor: .systemBackground) : Color(uiColor: .secondarySystemBackground).opacity(0.94),
                    in: RoundedRectangle(cornerRadius: 30, style: .continuous)
                )
                .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
        }
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
                .foregroundStyle(.secondary)
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
