import SwiftUI

struct PHIChatView: View {
    @ObservedObject var controller: PHIChatController
    let canUseModel: Bool
    let evidence: PHIChatEvidence
    let sessionKey: String
    @State private var draft = ""

    private var budgetStatus: String {
        let used = controller.budget.used
        if used >= PHISimulatedBudget.limit {
            return "Simulated limit reached. Swift replies remain available. Start a new chat to reset the estimate."
        }
        return "Estimates visible chat text at roughly one token per four UTF-8 bytes."
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Demo Mode · simulated data", systemImage: "testtube.2")
                    .font(.subheadline.weight(.semibold))
                Text(evidence.input.source).font(.caption).foregroundStyle(.secondary)
                if !canUseModel {
                    Text("Replies use Swift rules for this session.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if !AIExplanationController.availability.canGenerate {
                    Text(AIExplanationController.availability.message)
                        .font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: Double(min(controller.budget.used, PHISimulatedBudget.limit)),
                             total: Double(PHISimulatedBudget.limit)) {
                    Text("Simulated token budget")
                } currentValueLabel: {
                    Text("\(controller.budget.used) / \(PHISimulatedBudget.limit)").monospacedDigit()
                }
                .font(.caption)
                Text(budgetStatus)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            Divider()

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if controller.messages.isEmpty {
                            Text("Ask about this demo day").font(.headline)
                            ForEach(["What are today’s metrics?", "What does the recovery comparison show?", "How is my baseline calculated?"], id: \.self) { question in
                                Button(question) { send(question) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        ForEach(controller.messages) { message in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(message.source ?? "You")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Text(message.text).textSelection(.enabled)
                            }
                            .padding(12)
                            .background(message.source == nil ? PHIStyle.green.opacity(0.12) : Color(uiColor: .secondarySystemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 14))
                            .frame(maxWidth: .infinity, alignment: message.source == nil ? .trailing : .leading)
                        }
                        if controller.isResponding {
                            ProgressView("Responding on device…")
                        }
                        Color.clear.frame(height: 1).id("chatEnd").accessibilityHidden(true)
                    }
                    .frame(maxWidth: 560, alignment: .leading)
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: controller.messages.count) { _, _ in
                    withAnimation { proxy.scrollTo("chatEnd", anchor: .bottom) }
                }
                .onChange(of: controller.isResponding) { _, responding in
                    if responding { withAnimation { proxy.scrollTo("chatEnd", anchor: .bottom) } }
                }
            }
            Divider()
            HStack(alignment: .bottom, spacing: 10) {
                TextField("Ask about demo data", text: $draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                Button { send(draft) } label: {
                    Image(systemName: "arrow.up").font(.headline).padding(3)
                }
                .buttonStyle(.borderedProminent)
                .tint(PHIStyle.prominentGreen)
                .accessibilityLabel("Send message")
                .disabled(controller.isResponding || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("New chat", systemImage: "square.and.pencil") {
                    controller.reset()
                    draft = ""
                }
                .labelStyle(.iconOnly)
                .disabled(controller.messages.isEmpty)
            }
        }
        .onChange(of: sessionKey) { _, _ in draft = "" }
    }

    private func send(_ question: String) {
        controller.send(question, evidence: evidence, useModel: canUseModel)
        draft = ""
    }
}
