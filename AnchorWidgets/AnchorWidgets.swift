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
        let refresh = Calendar.current.date(byAdding: .hour, value: 2, to: .now) ?? .now.addingTimeInterval(7200)
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
            enabledCategories: WidgetAffirmationCategory.allCases,
            issueContext: "General reflection",
            updatedAt: .now
        )
    }
}

struct AnchorWidgetSmallView: View {
    let entry: AnchorWidgetEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            AnchorWidgetBackground(style: entry.payload.stylePreset)
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("Anchor")
                        .font(entry.payload.stylePreset.headerFont)
                        .foregroundStyle(.white.opacity(0.78))
                    Spacer()
                    Text(entry.payload.latestMood.capitalized)
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(moodColor.opacity(0.28), in: Capsule())
                }
                Text(entry.payload.averageMood > 0 ? String(format: "%.1f", entry.payload.averageMood) : "-")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Average mood")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                miniBars
                Spacer(minLength: 0)
                Label("\(entry.payload.currentStreak)d streak", systemImage: "flame")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
            }
            .padding(14)
        }
        .widgetURL(URL(string: "anchor://journal/today"))
    }

    private var primaryAffirmation: String {
        let text = entry.payload.affirmationText ?? entry.payload.primaryText
        return text.isEmpty ? entry.payload.primaryText : text
    }

    private var moodColor: Color {
        widgetMoodColor(entry.payload.latestMood)
    }

    private var miniBars: some View {
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index == 6 ? moodColor : .white.opacity(0.28))
                    .frame(width: 8, height: CGFloat(12 + (index % 4) * 6))
            }
        }
        .frame(height: 36, alignment: .bottom)
    }
}

struct AnchorWidgetMediumView: View {
    let entry: AnchorWidgetEntry

    private var nameHeader: String {
        let trimmed = entry.payload.preferredName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Anchor check-in" : "\(trimmed), check in"
    }

    var body: some View {
        ZStack {
            AnchorWidgetBackground(style: entry.payload.stylePreset)
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.12))
                            .frame(width: 22, height: 22)
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    Text(nameHeader)
                        .font(entry.payload.stylePreset.headerFont)
                        .foregroundStyle(.white.opacity(0.82))
                    Spacer()
                    Text(entry.payload.planTier == .premium ? "Premium" : "Anchor")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.12), in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Last 30 days")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(entry.payload.averageMood > 0 ? String(format: "%.1f avg mood", entry.payload.averageMood) : "No mood data yet")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }

                HStack(spacing: 14) {
                    metric("Entries", "\(entry.payload.entryCount)")
                    metric("Streak", "\(entry.payload.currentStreak)")
                    metric("Mood", entry.payload.latestMood.capitalized)
                }

                HStack(alignment: .bottom, spacing: 5) {
                    ForEach(0..<14, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(index > 10 ? moodColor : .white.opacity(0.24))
                            .frame(width: 8, height: CGFloat(10 + ((index * 7) % 28)))
                    }
                }
                .frame(height: 42, alignment: .bottom)

                HStack(spacing: 8) {
                    Button(intent: OpenJournalIntent()) {
                        Label("Journal now", systemImage: "square.and.pencil")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white.opacity(0.17))

                    Button(intent: NextAffirmationIntent()) {
                        Label("Next", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white.opacity(0.6))
                }
                .foregroundStyle(.white)
            }
            .padding(16)
        }
    }

    private var primaryAffirmation: String {
        let text = entry.payload.affirmationText ?? entry.payload.primaryText
        return text.isEmpty ? entry.payload.primaryText : text
    }

    private var moodColor: Color {
        widgetMoodColor(entry.payload.latestMood)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.62))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private func widgetMoodColor(_ raw: String) -> Color {
    switch raw {
    case "terrible": Color(red: 0.82, green: 0.40, blue: 0.39)
    case "low": Color(red: 0.86, green: 0.60, blue: 0.34)
    case "good": Color(red: 0.30, green: 0.61, blue: 0.95)
    case "great": Color(red: 0.36, green: 0.76, blue: 0.56)
    default: .white
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
        .configurationDisplayName("Anchor Reflection")
        .description("Daily reflection lines based on your journal context.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}

private struct AnchorWidgetEntryView: View {
    let entry: AnchorWidgetEntry
    @Environment(\.widgetFamily) private var widgetFamily

    var body: some View {
        content
            .containerBackground(.black, for: .widget)
    }

    @ViewBuilder
    private var content: some View {
        switch widgetFamily {
        case .systemSmall:
            AnchorWidgetSmallView(entry: entry)
        case .accessoryInline:
            AnchorWidgetLockInlineView(entry: entry)
        case .accessoryCircular:
            AnchorWidgetLockCircularView(entry: entry)
        case .accessoryRectangular:
            AnchorWidgetLockRectangularView(entry: entry)
        default:
            AnchorWidgetMediumView(entry: entry)
        }
    }
}

@main
struct AnchorWidgetsBundle: WidgetBundle {
    var body: some Widget {
        AnchorWidget()
    }
}
