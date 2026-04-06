import SwiftUI

struct AIChatView: View {
    @EnvironmentObject var appViewModel: AppViewModel
    @State private var inputText: String = ""
    @State private var scrollProxy: ScrollViewProxy? = nil
    @State private var ollamaOnline: Bool = false
    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("AI Spending Advisor")
                        .font(.system(size: 15, weight: .semibold))
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ollamaOnline ? Color.green : Color(red: 0.8, green: 0.4, blue: 0.0))
                            .frame(width: 7, height: 7)
                            .scaleEffect(ollamaOnline ? pulseScale : 1.0)
                            .animation(
                                ollamaOnline
                                    ? .easeInOut(duration: 1.0).repeatForever(autoreverses: true)
                                    : .default,
                                value: pulseScale
                            )
                        Text(ollamaOnline ? "Ollama · gemma4 · Ready" : "Ollama · Offline")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                if !appViewModel.chatMessages.isEmpty {
                    Button(action: { appViewModel.chatMessages = [] }) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Clear conversation")
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(.regularMaterial)
            .task {
                await checkOllamaStatus()
                pulseScale = 1.35
            }

            Divider()

            // Message list
            if appViewModel.chatMessages.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            ForEach(appViewModel.chatMessages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                            if appViewModel.isChatLoading {
                                TypingIndicator()
                                    .id("typing")
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .onChange(of: appViewModel.chatMessages.count) { _ in
                        withAnimation {
                            if let lastID = appViewModel.chatMessages.last?.id {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                    .onChange(of: appViewModel.isChatLoading) { _ in
                        withAnimation {
                            proxy.scrollTo("typing", anchor: .bottom)
                        }
                    }
                }
            }

            Divider()

            // Input bar
            inputBar
        }
        .background(VisualEffectBackground().ignoresSafeArea())
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor.opacity(0.4))

            VStack(spacing: 6) {
                Text("Your AI Financial Advisor")
                    .font(.system(size: 18, weight: .semibold))
                Text("Ask anything about your spending, or let the AI\nproactively review your finances.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button(action: { appViewModel.startProactiveChat() }) {
                HStack(spacing: 6) {
                    if appViewModel.isChatLoading {
                        ProgressView().scaleEffect(0.75)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text("Review My Spending")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.04, green: 0.14, blue: 0.22))
                .padding(.horizontal, 20)
                .padding(.vertical, 11)
                .background(Color(red: 0.28, green: 0.86, blue: 0.76))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(appViewModel.isChatLoading || appViewModel.expenses.isEmpty)

            if appViewModel.expenses.isEmpty {
                Text("Add some expenses first to enable AI analysis.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Suggested prompts
            VStack(alignment: .leading, spacing: 8) {
                Text("Try asking:")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                FlowRow(suggestions: [
                    "Where am I overspending?",
                    "Set a dining budget",
                    "How does this month compare?",
                    "What should I cut back on?",
                    "Show my biggest expenses"
                ]) { suggestion in
                    inputText = suggestion
                }
            }
            .frame(maxWidth: 500)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about your spending...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .lineLimit(1...5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.primary.opacity(0.06))
                )
                .onSubmit { sendMessage() }

            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? .accentColor : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !appViewModel.isChatLoading
    }

    private func sendMessage() {
        guard canSend else { return }
        let text = inputText
        inputText = ""
        appViewModel.sendChatMessage(text)
    }

    private func checkOllamaStatus() async {
        guard let url = URL(string: "http://127.0.0.1:11434") else { return }
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            ollamaOnline = (response as? HTTPURLResponse) != nil
        } catch {
            ollamaOnline = false
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.role == .user { Spacer(minLength: 60) }

            if message.role == .assistant {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 14))
                    .foregroundColor(.accentColor)
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Circle())
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(message.role == .user ? Color(red: 0.04, green: 0.14, blue: 0.22) : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(message.role == .user
                                  ? Color(red: 0.28, green: 0.86, blue: 0.76)
                                  : Color.primary.opacity(0.08))
                    )
                    .textSelection(.enabled)

                Text(dateFormatter.string(from: message.timestamp))
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.horizontal, 4)
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 14))
                .foregroundColor(.accentColor)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1.2 : 0.7)
                        .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animating)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.primary.opacity(0.08)))
            .onAppear { animating = true }

            Spacer(minLength: 60)
        }
    }
}

// MARK: - Flow Row (suggestion chips)

private struct FlowRow: View {
    let suggestions: [String]
    let onTap: (String) -> Void

    var body: some View {
        // Simple wrapping using fixed columns fallback via a VStack of HStacks
        VStack(alignment: .leading, spacing: 6) {
            let chunks = suggestions.chunked(into: 3)
            ForEach(Array(chunks.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 6) {
                    ForEach(row, id: \.self) { s in
                        Button(action: { onTap(s) }) {
                            Text(s)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 9)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Color.accentColor.opacity(0.25), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
