import SwiftUI

struct HealthConnectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var isConnecting = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Spacer()
                    AICircleView(state: isConnecting ? .thinking : .idle, size: 62, strokeWidth: 2.5)
                    Spacer()
                }
                .padding(.top, 28)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Optional: connect Apple Health")
                        .font(.title.weight(.semibold))
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Connect Apple Health to help spot patterns between your day and how you feel.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                ReferenceCard {
                    VStack(spacing: 0) {
                        healthContextRow(symbol: "moon", title: "Sleep", body: "Used as quiet context for reflection.")
                        Divider()
                        healthContextRow(symbol: "figure.walk", title: "Steps", body: "Used to notice simple movement patterns.")
                    }
                }

                Text("No health data is shown as a dashboard. The app works normally without access.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                VStack(spacing: 10) {
                    Button {
                        connect()
                    } label: {
                        Text(isConnecting ? "Connecting" : "Connect Health")
                    }
                    .buttonStyle(PrimaryCapsuleButtonStyle())
                    .disabled(isConnecting)

                    Button {
                        healthKitManager.markSkipped()
                        dismiss()
                    } label: {
                        Text("Continue without Health")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .foregroundStyle(.primary)
                    .background(AppSurface.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppSurface.stroke, lineWidth: 0.5)
                    }
                    .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .buttonStyle(.plain)
                    .disabled(isConnecting)
                }
            }
            .padding(AppSpacing.page)
            .navigationTitle("Apple Health")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func healthContextRow(symbol: String, title: String, body: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private func connect() {
        isConnecting = true
        Task {
            await healthKitManager.requestPermissionsAndRefresh()
            appModel.updateHealthSummary(healthKitManager.summary)
            isConnecting = false
            dismiss()
        }
    }
}

#Preview {
    HealthConnectView()
        .environmentObject(AppViewModel())
        .environmentObject(HealthKitManager.shared)
}
