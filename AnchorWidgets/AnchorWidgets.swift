import SwiftUI
import WidgetKit
import AppIntents

struct AnchorWidgetEntry: TimelineEntry {
    let date: Date
    let payload: WidgetAffirmationPayload
}

struct AnchorWidgetProvider: TimelineProvider {
    private let store = WidgetPayloadStore()

    func placeholder(in context: Context) -> AnchorWidgetEntry {
        AnchorWidgetEntry(date: .now, payload: fallbackPayload)
    }

    func getSnapshot(in context: Context, completion: @escaping (AnchorWidgetEntry) -> Void) {
        completion(AnchorWidgetEntry(date: .now, payload: store.load() ?? fallbackPayload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AnchorWidgetEntry>) -> Void) {
        let payload = store.load() ?? fallbackPayload
        let entry = AnchorWidgetEntry(date: .now, payload: payload)
        let refresh = Calendar.current.date(byAdding: .hour, value: 1, to: .now) ?? .now.addingTimeInterval(3600)
        completion(Timeline(entries: [entry], policy: .after(refresh)))
    }

    private var fallbackPayload: WidgetAffirmationPayload {
        WidgetAffirmationPayload(
            preferredName: "",
            planTier: .free,
            primaryText: "One line is enough today.",
            secondaryText: "Small, consistent notes build clarity over time.",
            affirmationText: "You are allowed to take this one step at a time.",
            affirmationOptions: ["You are allowed to take this one step at a time."],
            affirmationIndex: 0,
            stylePreset: .minimal,
            accentColor: .green,
            fontStyle: .rounded,
            enabledCategories: WidgetAffirmationCategory.allCases,
            issueContext: "General reflection",
            updatedAt: .now
        )
    }
}

struct AnchorWidgetSmallView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let contentWidth = size.width * 0.8
            let iconSize = min(size.width * 0.14, 28)
            let iconSpacing = max(6, size.width * 0.035)
            let copy = rotatingPrompt

            VStack(spacing: max(10, size.height * 0.06)) {
                Spacer(minLength: 0)
                Text(copy.title)
                    .font(.system(size: smallTitleFontSize(for: copy.title, width: size.width), weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.72)
                    .allowsTightening(true)

                HStack(spacing: iconSpacing) {
                    ForEach(checkInMoods, id: \.label) { mood in
                        checkInMoodFace(mood: mood, size: iconSize)
                    }
                }
                .frame(maxWidth: contentWidth)

                Text(copy.subtitle)
                    .font(.system(size: smallSubtitleFontSize(for: copy.subtitle, width: size.width), weight: .medium))
                    .foregroundStyle(.white.opacity(0.64))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .allowsTightening(true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, size.width * 0.08)
            .background(checkInCardFill)
        }
        .widgetURL(URL(string: "anchor://journal/today"))
    }

    private var checkInCardFill: Color {
        Color(red: 0.13, green: 0.13, blue: 0.15)
    }

    private var rotatingPrompt: (title: String, subtitle: String) {
        let hour = Calendar.current.component(.hour, from: entry.date)
        let issue = entry.payload.issueContext.lowercased()

        if hour < 5 {
            return ("Put one line\ndown", "Clear your head before sleep")
        }
        if hour < 12 {
            if issue.contains("anxiety") {
                return ("Check the tone\nof your morning", "Name the feeling before it runs")
            }
            if issue.contains("focus") || issue.contains("adhd") || issue.contains("attention") {
                return ("Set the tone\nfor today", "Name the one thing to focus on")
            }
            return ("Start with an\nhonest check-in", "Open and set the tone for today")
        }
        if hour < 18 {
            if issue.contains("stress") || issue.contains("burnout") {
                return ("What is pulling\nat you?", "Open and unload the pressure")
            }
            return ("Pause and\ncheck in", "Open and name what is real")
        }
        if issue.contains("sleep") || issue.contains("rest") || issue.contains("energy") {
            return ("How are you\nlanding tonight?", "Open and note what your body needs")
        }
        return ("What stayed\nwith you today?", "Open and clear your head")
    }

    private func smallTitleFontSize(for text: String, width: CGFloat) -> CGFloat {
        switch text.count {
        case 0...18: min(width * 0.12, 21)
        case 19...28: min(width * 0.105, 19)
        default: min(width * 0.095, 17)
        }
    }

    private func smallSubtitleFontSize(for text: String, width: CGFloat) -> CGFloat {
        switch text.count {
        case 0...20: min(width * 0.08, 14)
        case 21...34: min(width * 0.072, 13)
        default: min(width * 0.066, 12)
        }
    }

    private var checkInMoods: [(label: String, color: Color, icon: String)] {
        [
            ("Terrible", Color(red: 0.43, green: 0.45, blue: 0.84), "face.dashed"),
            ("Low", Color(red: 0.37, green: 0.62, blue: 0.95), "face.dashed.fill"),
            ("Okay", Color(red: 0.36, green: 0.71, blue: 0.68), "minus"),
            ("Good", Color(red: 0.68, green: 0.84, blue: 0.42), "face.smiling"),
            ("Great", Color(red: 0.98, green: 0.82, blue: 0.29), "face.smiling.inverse")
        ]
    }

    private func checkInMoodFace(mood: (label: String, color: Color, icon: String), size: CGFloat) -> some View {
        ZStack {
            Circle()
                .fill(mood.color)
                .frame(width: size, height: size)
            Image(systemName: mood.icon)
                .font(.system(size: size * 0.46, weight: .semibold))
                .foregroundStyle(.black.opacity(0.9))
        }
        .accessibilityLabel(mood.label)
    }
}

struct AnchorAffirmationSmallView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            VStack {
                Spacer(minLength: 0)
                Text(primaryAffirmation)
                    .font(.system(size: affirmationSmallFontSize(for: primaryAffirmation, width: size.width), weight: .bold, design: widgetFontDesign(entry.payload.fontStyle)))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .lineLimit(5)
                    .minimumScaleFactor(0.68)
                    .allowsTightening(true)
                    .frame(maxWidth: size.width * 0.8)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, size.width * 0.08)
            .background(affirmationCardFill)
        }
        .widgetURL(URL(string: "anchor://journal/today"))
    }

    private var primaryAffirmation: String {
        let text = entry.payload.affirmationText ?? entry.payload.primaryText
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "One steady thought is enough today." : text
    }

    private var affirmationCardFill: Color {
        Color(red: 0.13, green: 0.13, blue: 0.15)
    }

    private func affirmationSmallFontSize(for text: String, width: CGFloat) -> CGFloat {
        switch text.count {
        case 0...36: min(width * 0.105, 18)
        case 37...60: min(width * 0.09, 16)
        default: min(width * 0.08, 14)
        }
    }
}

struct AnchorAffirmationMediumView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            VStack(spacing: max(10, size.height * 0.05)) {
                Spacer(minLength: 0)
                Text(primaryAffirmation)
                    .font(.system(size: affirmationMediumFontSize(for: primaryAffirmation, width: size.width), weight: widgetFontWeight(entry.payload.fontStyle), design: widgetFontDesign(entry.payload.fontStyle)))
                    .italic(entry.payload.fontStyle == .serif)
                    .foregroundStyle(.white.opacity(0.96))
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .lineLimit(5)
                    .minimumScaleFactor(0.62)
                    .allowsTightening(true)
                    .frame(maxWidth: size.width * 0.78)

                if contextualHint.isEmpty == false {
                    Text(contextualHint)
                        .font(.system(size: min(size.width * 0.028, 10.5), weight: .semibold, design: .rounded))
                        .foregroundStyle(accentColor.opacity(0.78))
                        .multilineTextAlignment(.center)
                        .textCase(.uppercase)
                        .tracking(1.1)
                }

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accentColor.opacity(0.18), accentColor.opacity(0.85), accentColor.opacity(0.18)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size.width * 0.26, height: 3)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, size.width * 0.08)
            .background(
                LinearGradient(
                    colors: [gradientTop, gradientBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor.opacity(0.22), .clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: max(28, size.height * 0.2))
                }
            )
            .overlay {
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .strokeBorder(.white.opacity(0.05), lineWidth: 1)
            }
        }
        .widgetURL(URL(string: "anchor://journal/today"))
    }

    private var primaryAffirmation: String {
        let text = entry.payload.affirmationText ?? entry.payload.primaryText
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "You are allowed to take this one step at a time." : text
    }

    private var contextualHint: String {
        entry.payload.issueContext
            .split(separator: "·")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first ?? ""
    }

    private var accentColor: Color {
        widgetAccentColor(entry.payload.accentColor)
    }

    private var gradientTop: Color {
        Color(red: 0.10, green: 0.10, blue: 0.12)
    }

    private var gradientBottom: Color {
        switch entry.payload.accentColor {
        case .green:
            return Color(red: 0.10, green: 0.16, blue: 0.12)
        case .blue:
            return Color(red: 0.10, green: 0.13, blue: 0.18)
        case .copper:
            return Color(red: 0.18, green: 0.14, blue: 0.11)
        case .purple:
            return Color(red: 0.14, green: 0.12, blue: 0.18)
        case .rose:
            return Color(red: 0.18, green: 0.12, blue: 0.15)
        }
    }

    private func affirmationMediumFontSize(for text: String, width: CGFloat) -> CGFloat {
        switch text.count {
        case 0...42: min(width * 0.06, 23)
        case 43...70: min(width * 0.053, 21)
        case 71...100: min(width * 0.047, 19)
        default: min(width * 0.042, 17)
        }
    }
}

private func widgetAccentColor(_ accent: WidgetAccentColor) -> Color {
    switch accent {
    case .green:
        return Color(red: 0.44, green: 0.80, blue: 0.52)
    case .blue:
        return Color(red: 0.44, green: 0.67, blue: 0.96)
    case .copper:
        return Color(red: 0.86, green: 0.60, blue: 0.34)
    case .purple:
        return Color(red: 0.68, green: 0.55, blue: 0.94)
    case .rose:
        return Color(red: 0.90, green: 0.48, blue: 0.65)
    }
}

private func widgetFontDesign(_ style: WidgetFontStyle) -> Font.Design {
    switch style {
    case .rounded:
        return .rounded
    case .serif:
        return .serif
    case .clean:
        return .default
    }
}

private func widgetFontWeight(_ style: WidgetFontStyle) -> Font.Weight {
    switch style {
    case .rounded:
        return .medium
    case .serif:
        return .medium
    case .clean:
        return .semibold
    }
}

struct AnchorWidgetLockInlineView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
            Text(lockInlineText)
                .minimumScaleFactor(0.85)
            Text("·")
            Text("Log")
        }
    }

    private var lockInlineText: String {
        shortLockPhrase(from: entry.payload.affirmationText ?? entry.payload.primaryText, maxCharacters: 24)
    }
}

struct AnchorWidgetLockCircularView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 3) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                Text("AI")
                    .font(.system(size: 8, weight: .bold))
            }
        }
    }
}

struct AnchorWidgetLockRectangularView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Anchor")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button(intent: OpenJournalIntent()) {
                    Image(systemName: "square.and.pencil")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
            }
            Text(shortLockPhrase(from: entry.payload.affirmationText ?? entry.payload.primaryText, maxCharacters: 46))
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
            Text("Open journal and capture one clear line.")
                .font(.caption2)
                .lineLimit(1)
                .foregroundStyle(.secondary)
        }
        .widgetURL(URL(string: "anchor://journal/today"))
    }
}

private func shortLockPhrase(from source: String, maxCharacters: Int) -> String {
    let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isEmpty == false else { return "One grounded step." }
    if trimmed.count <= maxCharacters {
        return trimmed
    }

    let words = trimmed.split(separator: " ")
    var result = ""
    for word in words {
        let candidate = result.isEmpty ? String(word) : "\(result) \(word)"
        if candidate.count > maxCharacters {
            break
        }
        result = candidate
    }
    if result.isEmpty {
        return String(trimmed.prefix(maxCharacters))
    }
    return result
}

private struct AnchorWidgetBackground: View {
    let style: WidgetStylePreset

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay(.black.opacity(0.24))
            Circle()
                .fill(.white.opacity(0.09))
                .blur(radius: 32)
                .offset(x: 42, y: -38)
        }
    }

    private var gradientColors: [Color] {
        switch style {
        case .minimal:
            [Color.black, Color(red: 0.12, green: 0.12, blue: 0.15)]
        case .bold:
            [Color(red: 0.08, green: 0.10, blue: 0.18), Color(red: 0.15, green: 0.09, blue: 0.20)]
        case .calm:
            [Color(red: 0.07, green: 0.12, blue: 0.15), Color(red: 0.10, green: 0.15, blue: 0.20)]
        }
    }
}

private extension WidgetStylePreset {
    var headerFont: Font {
        switch self {
        case .minimal: .caption.weight(.semibold)
        case .bold: .subheadline.weight(.bold)
        case .calm: .caption.weight(.medium)
        }
    }

    var primaryFont: Font {
        switch self {
        case .minimal: .headline.weight(.semibold)
        case .bold: .title3.weight(.black)
        case .calm: .headline.weight(.medium)
        }
    }

    var secondaryFont: Font {
        switch self {
        case .minimal: .caption
        case .bold: .caption.weight(.medium)
        case .calm: .caption2.weight(.medium)
        }
    }
}

struct NextAffirmationIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Affirmation"

    func perform() async throws -> some IntentResult {
        let store = WidgetPayloadStore()
        _ = store.cycleAffirmation()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}

struct OpenJournalIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Journal"
    static var description = IntentDescription("Open Anchor directly to journal entry.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        AppCommandStore().set(.newQuickThought)
        return .result()
    }
}

struct AnchorWidget: Widget {
    let kind = "AnchorWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorWidgetProvider()) { entry in
            AnchorWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Check In")
        .description("A simple shortcut into your check-in.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct AnchorAffirmationWidget: Widget {
    let kind = "AnchorAffirmationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AnchorWidgetProvider()) { entry in
            AnchorAffirmationEntryView(entry: entry)
        }
        .configurationDisplayName("Affirmation of the Day")
        .description("A single affirmation card.")
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}

private struct AnchorWidgetEntryView: View {
    let entry: AnchorWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        content
            .containerBackground(for: .widget) {
                Color.black
            }
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .systemSmall:
            AnchorWidgetSmallView(entry: entry)
        default:
            AnchorWidgetSmallView(entry: entry)
        }
    }
}

private struct AnchorAffirmationEntryView: View {
    let entry: AnchorWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        AnchorAffirmationMediumView(entry: entry)
            .containerBackground(for: .widget) {
                Color.black
            }
    }
}

@main
struct AnchorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AnchorWidget()
        AnchorAffirmationWidget()
    }
}
