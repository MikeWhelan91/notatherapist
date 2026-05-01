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
                            AICircleView(state: .attentive, size: 50, strokeWidth: 2.2, tint: appModel.companionTint)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Anchor")
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
                        if appModel.hasWeeklyReview {
                            ReferenceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("I reviewed your entries and noticed a few patterns.")
                                        .font(.subheadline)
                                    Text(appModel.weeklyCheckInAvailabilityText)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Button {
                                        startConversation()
                                    } label: {
                                        Text(isStartingConversation ? "Starting" : (appModel.isWeeklyCheckInAvailableNow ? "Start check-in" : "Not available yet"))
                                    }
                                    .buttonStyle(PrimaryCapsuleButtonStyle())
                                    .disabled(isStartingConversation || appModel.isWeeklyCheckInAvailableNow == false)
                                }
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Weekly check-ins appear automatically.")
                                    .font(.headline.weight(.semibold))
                                Text("They unlock after enough activity. \(appModel.weeklyUnlockProgressText)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
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
            .scrollIndicators(.hidden)
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
        guard appModel.hasWeeklyReview, appModel.isWeeklyCheckInAvailableNow else {
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
    @FocusState private var composerFocused: Bool
    @State private var pendingUserMessage: String?

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
                        if let pendingUserMessage {
                            ConversationBubbleView(
                                message: ConversationMessage(
                                    id: UUID(),
                                    sender: .user,
                                    text: pendingUserMessage,
                                    date: Date()
                                )
                            )
                            .id("pending-user")
                        }
                        if isGenerating, conversation.status == .active {
                            ConversationTypingBubbleView()
                                .id("typing-bubble")
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
                .onChange(of: isGenerating) { _, generating in
                    if generating {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo("typing-bubble", anchor: .bottom)
                        }
                    }
                }
            }

            if shouldShowActions {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(actions, id: \.value) { action in
                            Button(action.label) {
                                send(action: action.value)
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
                .padding(.horizontal, AppSpacing.page)
                .padding(.top, 10)
                .padding(.bottom, 10)
                .background(.ultraThinMaterial)
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .navigationTitle("Check-in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            circleState = conversation.status == .ended ? .settled : .idle
        }
        .animation(.smooth(duration: 0.2), value: conversation.messages.count)
    }

    private var header: some View {
        HStack(spacing: 12) {
            AICircleView(state: circleState, size: 36, strokeWidth: 2, tint: appModel.companionTint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Anchor")
                    .font(.subheadline.weight(.semibold))
                Text(statusLine)
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
                    .focused($composerFocused)
                    .textFieldStyle(.plain)
                    .lineLimit(1...3)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .disabled(conversation.status == .ended || isGenerating)
                    .onChange(of: text) { _, value in
                        guard conversation.status == .active, isGenerating == false else { return }
                        circleState = value.isEmpty ? .listening : .typing
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
        let hasPendingSuggestedGoal = conversation.contextHints.contains(where: { $0.hasPrefix("suggested_goal::") })
        return conversation.messages.count >= 2 && (conversation.status == .active || hasPendingSuggestedGoal)
    }

    private var actions: [(value: String, label: String)] {
        var chips: [(String, String)] = [
            ("Break this down", "Break this down"),
            ("Reframe it", "Reframe it"),
            ("Give me one action", "Give me one action"),
            ("End for today", "End for today")
        ]
        if conversation.status == .ended && conversation.contextHints.contains(where: { $0.hasPrefix("suggested_goal::") }) {
            chips.insert(("Save suggested step", "Save suggested step"), at: 3)
        }
        if appModel.isPremium && conversation.deepeningUsed == false {
            chips.insert(("Go deeper", "Go deeper (+5)"), at: 3)
        }
        return chips
    }

    private var statusLine: String {
        guard conversation.status == .active else { return "Settled" }
        let phasePrefix = conversation.phase == .deeper ? "Deeper mode" : "Check-in"
        return "\(phasePrefix) · \(conversation.remainingTurns) replies left"
    }

    private func send(action: String? = nil) {
        let rawText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard action != nil || rawText.isEmpty == false else { return }
        let baseConversation = conversation
        let displayText = action ?? rawText
        pendingUserMessage = displayText
        text = ""
        isGenerating = true
        circleState = .thinking

        Task {
            try? await Task.sleep(for: .milliseconds(450))
            conversation = await appModel.sendMessage(rawText, in: baseConversation, action: action)
            pendingUserMessage = nil
            circleState = conversation.status == .ended ? .settled : .responding
            isGenerating = false
            if conversation.status == .active {
                try? await Task.sleep(for: .milliseconds(450))
                circleState = .attentive
            }
        }
    }
}

private struct ConversationTypingBubbleView: View {
    @State private var phase = 0

    var body: some View {
        HStack {
            HStack(spacing: 6) {
                dot(0)
                dot(1)
                dot(2)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
            Spacer(minLength: 42)
        }
        .task {
            while !Task.isCancelled {
                phase = (phase + 1) % 3
                try? await Task.sleep(for: .milliseconds(280))
            }
        }
    }

    private func dot(_ index: Int) -> some View {
        Circle()
            .fill(Color.secondary.opacity(phase == index ? 0.95 : 0.35))
            .frame(width: 6, height: 6)
    }
}

#Preview {
    MessagesView()
        .environmentObject(AppViewModel())
        .environmentObject(AppRouter.shared)
}
