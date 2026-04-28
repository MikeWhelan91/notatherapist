import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @EnvironmentObject private var router: AppRouter
    @State private var path: [Conversation] = []
    @State private var isStartingConversation = false

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.section) {
                    ReferenceCard {
                        HStack(spacing: 14) {
                            AICircleView(state: .idle, size: 48, strokeWidth: 2.2)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Not a Therapist")
                                    .font(.headline)
                                Text("A guided space to reflect")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Weekly check-in")
                        ReferenceCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(appModel.hasWeeklyReview ? "I reviewed your entries this week and noticed a few patterns." : "Weekly check-ins appear after a few days or several entries.")
                                    .font(.subheadline)
                                Text(appModel.hasWeeklyReview ? "Start a limited check-in when you are ready." : "Keep writing. Nothing is inferred yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if appModel.hasWeeklyReview {
                                    Button {
                                        startConversation()
                                    } label: {
                                        Text(isStartingConversation ? "Starting" : "Start conversation")
                                    }
                                    .buttonStyle(PrimaryCapsuleButtonStyle())
                                    .disabled(isStartingConversation)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        SectionLabel(title: "Recent conversations")
                        VStack(spacing: 10) {
                            ForEach(appModel.conversations) { conversation in
                                NavigationLink(value: conversation) {
                                    ReferenceCard {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(conversation.date.compactDate)
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text(conversation.title)
                                                    .font(.subheadline.weight(.semibold))
                                                Text(conversation.preview)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(AppSpacing.page)
            }
            .navigationTitle("Messages")
            .navigationDestination(for: Conversation.self) { conversation in
                ConversationView(conversation: conversation)
            }
        }
        .onAppear {
            openPendingWeeklyCheckInIfNeeded()
        }
        .onChange(of: router.pendingWeeklyCheckIn) { _, _ in
            openPendingWeeklyCheckInIfNeeded()
        }
    }

    private func openPendingWeeklyCheckInIfNeeded() {
        guard router.pendingWeeklyCheckIn else { return }
        guard appModel.hasWeeklyReview else {
            router.consumeWeeklyCheckIn()
            return
        }
        Task {
            let conversation = await appModel.startWeeklyConversation()
            path = [conversation]
            router.consumeWeeklyCheckIn()
        }
    }

    private func startConversation() {
        guard isStartingConversation == false else { return }
        isStartingConversation = true
        Task {
            let conversation = await appModel.startWeeklyConversation()
            path.append(conversation)
            isStartingConversation = false
        }
    }
}

struct ConversationView: View {
    @EnvironmentObject private var appModel: AppViewModel
    @State var conversation: Conversation
    @State private var text = ""
    @State private var circleState: AICircleState = .idle
    @State private var isGenerating = false

    private let actions = ["Break this down", "Reframe it", "Give me one action", "End for today"]

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, AppSpacing.page)
                .padding(.vertical, 10)
                .background(Color(.systemBackground))

            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(conversation.messages) { message in
                            ConversationBubbleView(message: message)
                                .id(message.id)
                        }
                    }
                    .padding(AppSpacing.page)
                }
                .onChange(of: conversation.messages.count) {
                    if let id = conversation.messages.last?.id {
                        withAnimation(.easeOut(duration: 0.25)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
            }

            if shouldShowActions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.self) { action in
                            Button(action) {
                                send(action: action)
                            }
                            .buttonStyle(CompactIconButtonStyle())
                            .disabled(isGenerating || conversation.status == .ended)
                        }
                    }
                    .padding(.horizontal, AppSpacing.page)
                    .padding(.vertical, 8)
                }
            }

            composer
                .padding(AppSpacing.page)
                .background(Color(.systemBackground))
        }
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            circleState = conversation.status == .ended ? .settled : .idle
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            AICircleView(state: circleState, size: 36, strokeWidth: 2)
            VStack(alignment: .leading, spacing: 2) {
                Text("Not a Therapist")
                    .font(.subheadline.weight(.semibold))
                Text(conversation.status == .ended ? "Settled" : "\(conversation.remainingTurns) replies left today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var composer: some View {
        VStack(spacing: 8) {
            if conversation.status == .ended {
                Text("That's enough for today. Let it sit.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack(spacing: 10) {
                TextField("Reply briefly", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(conversation.status == .ended || isGenerating)
                    .onChange(of: text) { _, value in
                        guard conversation.status == .active, isGenerating == false else { return }
                        circleState = value.isEmpty ? .idle : .typing
                    }

                Button {
                    send()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || conversation.status == .ended || isGenerating)
            }
        }
    }

    private var shouldShowActions: Bool {
        conversation.messages.count >= 2 && conversation.status == .active
    }

    private func send(action: String? = nil) {
        let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard action != nil || rawText.isEmpty == false else { return }
        text = ""
        isGenerating = true
        circleState = .thinking

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            conversation = await appModel.sendMessage(rawText, in: conversation, action: action)
            circleState = conversation.status == .ended ? .settled : .responding
            isGenerating = false
            if conversation.status == .active {
                try? await Task.sleep(for: .milliseconds(450))
                circleState = .idle
            }
        }
    }
}

#Preview {
    MessagesView()
        .environmentObject(AppViewModel())
        .environmentObject(AppRouter.shared)
}
