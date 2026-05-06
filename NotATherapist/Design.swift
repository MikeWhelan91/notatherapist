import SwiftUI

enum AppTheme {
    static let accent = Color.white
    static let accentSoft = Color(red: 0.88, green: 0.92, blue: 0.98)
}

enum AppSpacing {
    static let page: CGFloat = 18
    static let compact: CGFloat = 8
    static let row: CGFloat = 12
    static let section: CGFloat = 24
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.accent.opacity(isEnabled ? 1 : 0.4))

            configuration.label
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 46)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppSurface.fill)
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(AppSurface.stroke, lineWidth: 0.5)
                }

            configuration.label
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
        }
        .frame(minHeight: 34)
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .scaleEffect(configuration.isPressed ? 0.97 : 1)
        .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

enum AppSurface {
    static var fill: Color { Color(.secondarySystemBackground).opacity(0.72) }
    static var stroke: Color { AppTheme.accent.opacity(0.22) }
}

struct ReferenceCard<Content: View>: View {
    var padding: CGFloat = 15
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppSurface.stroke, lineWidth: 0.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct SectionLabel: View {
    let title: String
    var action: String?
    var onAction: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Spacer()
            if let action {
                Button(action) {
                    onAction?()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
    }
}

struct ExplainerButton: View {
    let title: String
    let message: String
    var bullets: [String] = []
    var symbol: String = "info.circle"
    @State private var isPresented = false

    init(title: String, body: String, bullets: [String] = [], symbol: String = "info.circle") {
        self.title = title
        self.message = body
        self.bullets = bullets
        self.symbol = symbol
    }

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay {
                    Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Explain \(title)")
        .sheet(isPresented: $isPresented) {
            ExplainerSheet(title: title, message: message, bullets: bullets)
                .presentationDetents([.medium])
                .presentationCornerRadius(28)
        }
    }
}

private struct ExplainerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let message: String
    let bullets: [String]

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "sparkle.magnifyingglass")
                        .font(.title3.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .background(AppSurface.fill, in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.title3.weight(.bold))
                        Text("How this works")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }

                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if bullets.isEmpty == false {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(bullets, id: \.self) { bullet in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.accent)
                                    .padding(.top, 3)
                                Text(bullet)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Spacer()

                Button("Got it") {
                    dismiss()
                }
                .buttonStyle(PrimaryCapsuleButtonStyle())
            }
            .padding(AppSpacing.page)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

extension Date {
    var dayTitle: String {
        formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }

    var shortDay: String {
        formatted(.dateTime.weekday(.abbreviated))
    }

    var dayNumber: String {
        formatted(.dateTime.day())
    }

    var compactTime: String {
        formatted(.dateTime.hour().minute())
    }

    var compactDate: String {
        formatted(.dateTime.day().month(.abbreviated))
    }

    var longReadableDate: String {
        let calendar = Calendar.current
        let day = calendar.component(.day, from: self)
        let suffix: String
        switch day {
        case 11, 12, 13:
            suffix = "th"
        default:
            switch day % 10 {
            case 1: suffix = "st"
            case 2: suffix = "nd"
            case 3: suffix = "rd"
            default: suffix = "th"
            }
        }

        let monthYear = formatted(.dateTime.month(.wide).year())
        let weekday = formatted(.dateTime.weekday(.wide))
        return "\(weekday) \(day)\(suffix) \(monthYear)"
    }
}

extension View {
    func listRowSeparatorTint() -> some View {
        listRowSeparatorTint(Color(.separator))
    }
}
