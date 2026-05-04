import SwiftUI

struct JournalHistoryView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var selectedMood: MoodLevel?
    @State private var selectedEntryType: EntryType?

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
                DatePicker(
                    "",
                    selection: $appModel.selectedJournalDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(.primary)

                VStack(alignment: .leading, spacing: 10) {
                    TextField("Search entries, themes, or types", text: $searchText)
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
                            }
                        }
                    }
                }
            }
            .padding(AppSpacing.page)
        }
        .navigationTitle("Journal history")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") {
                    dismiss()
                }
            }
        }
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
