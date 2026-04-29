import SwiftUI

enum AppSpacing {
    static let page: CGFloat = 18
    static let compact: CGFloat = 8
    static let row: CGFloat = 12
    static let section: CGFloat = 24
}

struct PrimaryCapsuleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(Color(.systemBackground))
            .background(Color.primary.opacity(isEnabled ? 1 : 0.35), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

struct CompactIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppSurface.stroke, lineWidth: 0.5)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.14), value: configuration.isPressed)
    }
}

enum AppSurface {
    static var fill: Color { Color(.tertiarySystemBackground) }
    static var stroke: Color { Color(.separator).opacity(0.55) }
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
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 2)
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
}

extension View {
    func listRowSeparatorTint() -> some View {
        listRowSeparatorTint(Color(.separator))
    }
}
