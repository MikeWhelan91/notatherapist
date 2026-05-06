import SwiftUI

struct JournalHistoryView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedMood: MoodLevel?
    @State private var selectedEntryType: EntryType?
    @State private var displayedMonthDate = Date()
    @State private var editingEntry: JournalEntry?
    @State private var pendingDeleteEntry: JournalEntry?
    @FocusState private var searchFocused: Bool

    private var selectedEntries: [JournalEntry] {
        appModel.entries(on: appModel.selectedJournalDate)
    }

    private var filteredEntries: [JournalEntry] {
        appModel.searchEntries(query: searchText, mood: selectedMood, entryType: selectedEntryType)
    }

    private var isFiltering: Bool {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false || selectedMood != nil || selectedEntryType != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                historyCalendar

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Search entries, themes, or types", text: $searchText)
                        .focused($searchFocused)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(12)
                        .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip("All moods", selected: selectedMood == nil) { selectedMood = nil }
                            ForEach(MoodLevel.allCases) { mood in
                                filterChip(mood.label, selected: selectedMood == mood) { selectedMood = mood }
                            }
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            filterChip("All types", selected: selectedEntryType == nil) { selectedEntryType = nil }
                            ForEach(EntryType.allCases) { type in
                                filterChip(type.label, selected: selectedEntryType == type) { selectedEntryType = type }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: isFiltering ? "Search results" : appModel.selectedJournalDate.formatted(date: .complete, time: .omitted))
                    let entries = isFiltering ? filteredEntries : selectedEntries
                    if entries.isEmpty {
                        VStack(spacing: 10) {
                            Text(isFiltering ? "No matching entries." : "No entries on this date.")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                            Text(isFiltering ? "Try a different search or clear one filter." : "Pick another day to view entries.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(entries) { entry in
                                NavigationLink {
                                    EntryDetailView(entry: entry)
                                } label: {
                                    ReferenceCard {
                                        EntryRowView(entry: entry)
                                    }
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button("Edit") {
                                        editingEntry = entry
                                    }
                                    Button("Delete", role: .destructive) {
                                        pendingDeleteEntry = entry
                                    }
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button("Delete", role: .destructive) {
                                        pendingDeleteEntry = entry
                                    }
                                    Button("Edit") {
                                        editingEntry = entry
                                    }
                                    .tint(.gray)
                                }
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.page)
        }
        .simultaneousGesture(
            TapGesture().onEnded {
                searchFocused = false
            }
        )
        .navigationTitle("Journal history")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncDisplayedMonthToSelection()
        }
        .onChange(of: appModel.selectedJournalDate) { _, _ in
            syncDisplayedMonthToSelection()
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    searchFocused = false
                }
            }
        }
        .sheet(item: $editingEntry) { entry in
            NavigationStack {
                EntryEditorView(entry: entry)
            }
            .presentationCornerRadius(28)
        }
        .alert("Delete entry?", isPresented: Binding(
            get: { pendingDeleteEntry != nil },
            set: { if $0 == false { pendingDeleteEntry = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let entry = pendingDeleteEntry {
                    appModel.deleteEntry(id: entry.id)
                }
                pendingDeleteEntry = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteEntry = nil
            }
        } message: {
            Text("This removes the journal entry and clears any saved review for that day.")
        }
    }

    private var calendarMonthDate: Date {
        Calendar.current.dateInterval(of: .month, for: displayedMonthDate)?.start ?? displayedMonthDate
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.shortWeekdaySymbols
        let start = max(0, calendar.firstWeekday - 1)
        return Array(symbols[start...] + symbols[..<start]).map { $0.uppercased() }
    }

    private var monthCells: [JournalHistoryCalendarCell] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: calendarMonthDate),
              let dayRange = calendar.range(of: .day, in: .month, for: interval.start) else {
            return []
        }

        let entriesByDay = Dictionary(grouping: appModel.journalEntries) { calendar.startOfDay(for: $0.date) }
        let weekdayOffset = calendar.component(.weekday, from: interval.start) - calendar.firstWeekday
        let leading = (weekdayOffset + 7) % 7
        var cells: [JournalHistoryCalendarCell] = (0..<leading).map { _ in .empty(UUID()) }

        for offset in 0..<dayRange.count {
            guard let date = calendar.date(byAdding: .day, value: offset, to: interval.start) else { continue }
            let dayEntries = entriesByDay[calendar.startOfDay(for: date)] ?? []
            let latest = dayEntries.max { $0.date < $1.date }
            cells.append(.day(date: date, mood: latest?.mood, count: dayEntries.count))
        }

        while cells.count % 7 != 0 {
            cells.append(.empty(UUID()))
        }
        return cells
    }

    private var historyCalendar: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)

                Spacer()

                Text(calendarMonthDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title3.weight(.bold))

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 10) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthCells, id: \.id) { cell in
                    JournalHistoryDayCell(cell: cell, selectedDate: appModel.selectedJournalDate) { selected in
                        guard case .day(let date, _, _) = selected else { return }
                        appModel.selectedJournalDate = date
                    }
                }
            }
        }
    }

    private func shiftMonth(by value: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: value, to: calendarMonthDate) else { return }
        displayedMonthDate = next
    }

    private func syncDisplayedMonthToSelection() {
        displayedMonthDate = calendarMonthDateForSelection(appModel.selectedJournalDate)
    }

    private func calendarMonthDateForSelection(_ date: Date) -> Date {
        Calendar.current.dateInterval(of: .month, for: date)?.start ?? date
    }

    private func filterChip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(selected ? Color(.systemBackground) : .primary)
                .background(selected ? Color.primary : AppSurface.fill, in: Capsule())
                .overlay {
                    Capsule().stroke(AppSurface.stroke, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
    }
}

private enum JournalHistoryCalendarCell {
    case empty(UUID)
    case day(date: Date, mood: MoodLevel?, count: Int)

    var id: String {
        switch self {
        case .empty(let id): id.uuidString
        case .day(let date, _, _): date.ISO8601Format()
        }
    }
}

private struct JournalHistoryDayCell: View {
    let cell: JournalHistoryCalendarCell
    let selectedDate: Date
    let onSelect: (JournalHistoryCalendarCell) -> Void

    var body: some View {
        switch cell {
        case .empty:
            Color.clear
                .aspectRatio(1, contentMode: .fit)
        case .day(let date, let mood, let count):
            Button {
                onSelect(cell)
            } label: {
                dayView(date: date, mood: mood, count: count)
            }
            .buttonStyle(.plain)
        }
    }

    private func dayView(date: Date, mood: MoodLevel?, count: Int) -> some View {
        let selected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let textColor: Color = mood?.interfaceAccentColor ?? .primary
        let background = selected
            ? (mood?.companionColor.opacity(0.28) ?? Color.white.opacity(0.12))
            : Color.clear

        return Text("\(Calendar.current.component(.day, from: date))")
            .font(.title3.weight(.medium))
            .foregroundStyle(textColor)
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(background, in: Circle())
            .overlay {
                if selected {
                    Circle()
                        .stroke((mood?.companionColor ?? Color.white).opacity(0.9), lineWidth: 1.2)
                }
            }
            .opacity(count == 0 ? 0.42 : 1)
            .accessibilityLabel(accessibilityLabel(date: date, mood: mood, count: count))
    }

    private func accessibilityLabel(date: Date, mood: MoodLevel?, count: Int) -> String {
        if let mood {
            return "\(date.formatted(date: .abbreviated, time: .omitted)), latest mood \(mood.label), \(count) \(count == 1 ? "entry" : "entries")"
        }
        return "\(date.formatted(date: .abbreviated, time: .omitted)), no entry"
    }
}
