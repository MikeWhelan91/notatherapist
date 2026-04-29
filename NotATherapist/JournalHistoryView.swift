import SwiftUI

struct JournalHistoryView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingNewEntry = false

    private var selectedEntries: [JournalEntry] {
        appModel.entries(on: appModel.selectedJournalDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.section) {
                WeekCalendarStripView(
                    selectedDate: $appModel.selectedJournalDate,
                    dates: appModel.currentWeekDates,
                    hasEntry: { date in
                        appModel.entries(on: date).isEmpty == false
                    }
                )
                .padding(.horizontal, -AppSpacing.page)

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: appModel.selectedJournalDate.formatted(date: .complete, time: .omitted))
                    if selectedEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No entries on this date.")
                                .font(.headline)
                            Text("Pick another day or add one note.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Button {
                                showingNewEntry = true
                            } label: {
                                Label("Add entry", systemImage: "plus")
                            }
                            .buttonStyle(PrimaryCapsuleButtonStyle())
                        }
                    } else {
                        VStack(spacing: 10) {
                            ForEach(selectedEntries) { entry in
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
        .sheet(isPresented: $showingNewEntry) {
            NewEntryView(initialMood: appModel.selectedMood, date: appModel.selectedJournalDate)
                .presentationCornerRadius(28)
        }
    }
}
