import SwiftUI

struct JournalHistoryView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    private var selectedEntries: [JournalEntry] {
        appModel.entries(on: appModel.selectedJournalDate)
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

                VStack(alignment: .leading, spacing: 8) {
                    SectionLabel(title: appModel.selectedJournalDate.formatted(date: .complete, time: .omitted))
                    if selectedEntries.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("No entries on this date.")
                                .font(.headline)
                            Text("Pick another day to view entries.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
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
    }
}
