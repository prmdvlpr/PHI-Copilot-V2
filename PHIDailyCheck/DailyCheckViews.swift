import SwiftUI
import Charts
import Combine

private enum PHIStyle {
    static let green = Color(red: 0.16, green: 0.39, blue: 0.29)
    static let warm = Color.orange.opacity(0.13)
}

private enum AppTab: Hashable { case today, ask, insights, settings }
private enum DayContext: String, CaseIterable, Identifiable {
    case none = "Not sure", exercise = "Hard workout yesterday"
    var id: String { rawValue }
}

@MainActor
private final class DemoSession: ObservableObject {
    @Published var accepted = false
    @Published var enableAI = false
    @Published var allowRestingHR = true
    @Published var allowHRV = true
    @Published var scenario: DemoScenario = .workshop
    @Published var profile: DemoProfile = .adi
    @Published var replayDay = DemoProfile.adi.defaultReplayDay
    @Published var tab: AppTab = .today
    @Published var context: DayContext = .none
}

struct DailyCheckRootView: View {
    @StateObject private var session = DemoSession()
    @StateObject private var ai = AIExplanationController()
    @StateObject private var chat = PHIChatController()
    @Environment(\.scenePhase) private var scenePhase

    private var readings: [DailyReading] {
        if session.scenario == .workshop {
            return (try? WorkshopDataset.bundled().replay(profile: session.profile, through: session.replayDay)) ?? []
        }
        return DailyCheckEngine.demo(session.scenario)
    }
    private var sourceLabel: String {
        session.scenario == .workshop
            ? "Workshop · \(session.profile.sourcePersona) → alias \(session.profile.displayName)"
            : "Synthetic test data · not measurements from \(session.profile.displayName)"
    }
    private var replayDate: String {
        guard let date = readings.last?.date else { return "No samples yet" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateStyle = .long
        return formatter.string(from: date)
    }
    private var report: DailyCheckReport {
        DailyCheckEngine.report(readings: readings, allowRestingHR: session.allowRestingHR, allowHRV: session.allowHRV)
    }

    private var explanationKey: String {
        [session.profile.rawValue, String(session.replayDay), session.scenario.rawValue,
         String(session.accepted), String(session.allowRestingHR), String(session.allowHRV),
         String(session.enableAI), session.context.rawValue].joined(separator: "|")
    }

    private var chatEvidence: PHIChatEvidence {
        PHIChatEvidence(input: AIExplanationInput(
            report: report, source: sourceLabel, exerciseContext: session.context == .exercise
        ))
    }

    var body: some View {
        Group {
            if session.accepted {
                TabView(selection: $session.tab) {
                    NavigationStack {
                        page {
                            if report.canExplain {
                                insight
                            } else {
                                FullFallbackView(evidence: report.restingHR, restoreDemo: restoreDemo, reviewAccess: { session.tab = .settings })
                            }
                        }
                        .navigationTitle("Today")
                        .toolbar { demoToolbar }
                    }
                    .tabItem { Label("Today", systemImage: "sun.max") }.tag(AppTab.today)
                    NavigationStack {
                        PHIChatView(
                            controller: chat,
                            canUseModel: session.enableAI && session.scenario != .noAI,
                            evidence: chatEvidence,
                            sessionKey: explanationKey
                        )
                        .navigationTitle("Ask PHI")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar { demoToolbar }
                    }
                    .tabItem { Label("Ask PHI", systemImage: "text.bubble") }.tag(AppTab.ask)
                    NavigationStack {
                        page {
                            if report.canExplain { explanation }
                            else { FullFallbackView(evidence: report.restingHR, restoreDemo: restoreDemo, reviewAccess: { session.tab = .settings }) }
                        }
                        .navigationTitle("Insights")
                        .toolbar { demoToolbar }
                    }
                    .tabItem { Label("Insights", systemImage: "chart.xyaxis.line") }.tag(AppTab.insights)
                    NavigationStack {
                        page { consent(isFirstVisit: false) }
                            .navigationTitle("Settings")
                            .toolbar { demoToolbar }
                    }
                    .tabItem { Label("Settings", systemImage: "gearshape") }.tag(AppTab.settings)
                }
            } else {
                NavigationStack {
                    page { consent(isFirstVisit: true) }
                        .navigationTitle("PHI Daily Check")
                        .toolbar { demoToolbar }
                }
            }
        }
        .tint(PHIStyle.green)
        .environment(\.locale, Locale(identifier: "en"))
        .onChange(of: explanationKey) { _, _ in
            ai.invalidate()
            chat.reset()
        }
        .onChange(of: scenePhase) { _, _ in ai.invalidate() }
        .onChange(of: session.scenario) { _, _ in session.context = .none }
        .onChange(of: session.profile) { _, profile in
            session.replayDay = profile.defaultReplayDay
            session.scenario = .workshop
            session.context = .none
        }
    }

    @ToolbarContentBuilder private var demoToolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker("Demo scenarios", selection: $session.scenario) {
                    ForEach(DemoScenario.allCases) { item in Text(item.title).tag(item) }
                }
                Button("Restart consent", systemImage: "arrow.counterclockwise") {
                    session.accepted = false; session.enableAI = false; session.allowRestingHR = true; session.allowHRV = true
                    session.scenario = .workshop; session.tab = .today; session.context = .none
                    session.profile = .adi; session.replayDay = DemoProfile.adi.defaultReplayDay
                }
            } label: { Label("Demo scenarios", systemImage: "slider.horizontal.3") }
            .accessibilityIdentifier("demoScenarios")
        }
    }

    private func page<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("PHI.").font(.title2.weight(.semibold))
                    Spacer()
                    Label("Demo Mode · \(session.profile.displayName)", systemImage: "testtube.2")
                        .font(.caption).padding(.horizontal, 10).padding(.vertical, 6)
                        .background(PHIStyle.green.opacity(0.10), in: Capsule())
                }
                PHICard {
                    Picker("Demo profile", selection: $session.profile) {
                        ForEach(DemoProfile.allCases) { Text($0.displayName).tag($0) }
                    }.pickerStyle(.segmented)
                    Text(sourceLabel).font(.caption).foregroundStyle(.secondary)
                    if session.scenario == .workshop {
                        Stepper("Replay day \(session.replayDay) / 60", value: $session.replayDay, in: 1...60)
                        Text("Recorded date: \(replayDate). The selected replay day is “today” in this demo, not the actual date.")
                            .font(.caption).foregroundStyle(.secondary)
                        if readings.isEmpty {
                            Text("The workshop dataset could not be loaded or is empty. No substitute readings have been generated.").foregroundStyle(.red)
                        }
                    }
                }
                content()
                Text("Capstone prototype · simulated data, not personal health records. No Apple Health access. Optional Apple Intelligence runs on device when available. Adi and Hanna are demo aliases for Tom and Maya. Data is bundled in the app; choices are kept only for this session.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(20)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    @ViewBuilder private func consent(isFirstVisit: Bool) -> some View {
        ScreenHeading(step: "Data access", title: "Your data.\nYour choice.", subtitle: "Resting heart rate is the primary insight. HRV SDNN adds supporting evidence against its own baseline.")
        PHICard {
            Toggle(isOn: $session.allowRestingHR) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Resting heart rate").font(.headline)
                    Text("For daily readings and your personal baseline").font(.caption).foregroundStyle(.secondary)
                }
            }.accessibilityIdentifier("restingHRConsent")
            Divider()
            Toggle(isOn: $session.allowHRV) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("HRV · SDNN").font(.headline)
                    Text("Optional · not RMSSD or a stress score").font(.caption).foregroundStyle(.secondary)
                }
            }.accessibilityIdentifier("hrvConsent")
        }
        PHICard {
            Label("What data?", systemImage: "heart.text.square").font(.headline)
            Text("Resting HR and HRV SDNN from simulated workshop profiles or test fixtures. Each baseline uses the fourteen calendar days before the selected replay day.")
            Divider()
            Label("Why use it?", systemImage: "chart.xyaxis.line").font(.headline)
            Text("To compare each metric with its own historical baseline, without assuming the cause of a change.")
            Divider()
            Label("Where is it processed?", systemImage: "iphone").font(.headline)
            Text("The sample data stays in this app. There is no HealthKit connection, server, or analytics. If enabled, selected evidence is passed to the on-device Apple Intelligence model. This app does not call a cloud AI service.")
        }
        PHICard {
            Toggle("Apple Intelligence (optional)", isOn: $session.enableAI)
            Text("Swift still calculates the baselines. When enabled, the on-device model can use consent-enabled demo evidence, selected context, and messages you send in Ask PHI. Rule-based explanations and chat replies remain available.")
                .font(.caption).foregroundStyle(.secondary)
            Text(AIExplanationController.availability.message).font(.caption).foregroundStyle(.secondary)
        }
        if isFirstVisit {
            Button {
                session.accepted = true; session.tab = .today
            } label: { Text("Continue with these choices").frame(maxWidth: .infinity) }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .accessibilityIdentifier("continueConsent")
            Button("Continue without data") {
                session.allowRestingHR = false; session.allowHRV = false; session.enableAI = false; session.accepted = true; session.tab = .today
            }.frame(maxWidth: .infinity)
        } else {
            Text("Changes take effect immediately. Changing data or AI access clears the Ask PHI conversation.")
                .font(.caption).foregroundStyle(.secondary)
            Button("View my results") { session.tab = .today }
                .buttonStyle(.borderedProminent).controlSize(.large)
        }
        Text("These choices apply to simulated data, not Apple Health permissions. A future HealthKit integration will require a separate system authorization request.")
            .font(.caption).foregroundStyle(.secondary)
    }

    private var insight: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeading(step: "Daily check", title: "Good morning, \(session.profile.displayName).", subtitle: "Demo data date: \(replayDate)")
            MetricEvidenceCard(evidence: report.restingHR, readings: readings, showChart: true, sourceLabel: sourceLabel)
            PHICard {
                Text(report.title).font(.headline)
                Text(report.usesHRV
                     ? "Both metrics are checked against their own baselines. They are not combined into a health score."
                     : "This insight uses resting HR only. Missing HRV values are not estimated.")
            }
            MetricEvidenceCard(evidence: report.hrv, readings: readings, showChart: false, sourceLabel: sourceLabel)
            if !report.usesHRV {
                Button("Review HRV access") { session.tab = .settings }.buttonStyle(.bordered)
            }
            if session.scenario == .noAI { aiFallback }
            Button { session.tab = .insights } label: {
                Label("Why am I seeing this?", systemImage: "arrow.right").frame(maxWidth: .infinity)
            }.buttonStyle(.borderedProminent).controlSize(.large)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeading(step: "Evidence", title: "Here is the evidence.", subtitle: "Swift calculates the facts. Optional AI helps summarize them.")
            PHICard {
                Text("Facts & rule-based explanation").font(.headline)
                Text(report.explanation).accessibilityIdentifier("groundedExplanation")
            }
            appleIntelligenceCard
            PHICard {
                Label("Evidence used", systemImage: "checkmark.seal").font(.headline)
                evidenceRow(report.restingHR)
                if report.usesHRV { Divider(); evidenceRow(report.hrv) }
                Divider()
                Text("Baseline: median of the fourteen calendar days before the replay day. Illustrative range = median ± 1.5 × spread. Spread is the larger of 1.4826 × MAD and the metric floor. The replay day is excluded.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("The fourteen-day minimum and this range are teaching parameters, not validated health decision thresholds.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if !report.usesHRV {
                PHICard {
                    Label("Partial-data fallback", systemImage: "info.circle").font(.headline)
                    Text(report.hrv.availability == .disabled
                         ? "HRV is disabled by your choice. The explanation still works using resting HR alone."
                         : "HRV data is not sufficient. No claim is made about its direction of change.")
                }
            }
            PHICard {
                Text("Any additional context?").font(.headline)
                Picker("Context", selection: $session.context) {
                    ForEach(DayContext.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
                Text(session.context == .exercise
                     ? "Your exercise context is noted for this session. It does not establish a cause or change the measurements."
                     : "That is fine. The cause remains unknown.")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if session.scenario == .noAI { aiFallback }
            Button("Back to evidence") { session.tab = .today }.buttonStyle(.bordered)
        }
    }

    private var appleIntelligenceCard: some View {
        let status = AIExplanationController.availability
        let matches = ai.resultKey == explanationKey
        return PHICard {
            Label("Apple Intelligence explanation", systemImage: "sparkles").font(.headline)
            if !session.enableAI {
                Text("Not enabled. The rule-based explanation above still works.")
                Button("Review AI settings") { session.tab = .settings }.buttonStyle(.bordered)
            } else if session.scenario == .noAI {
                Text("Fallback demo mode is active. No AI request will be made.")
            } else if !status.canGenerate {
                Text(status.message)
                Text("Explanation source: Swift rules").font(.caption).foregroundStyle(.secondary)
            } else {
                if matches, ai.isLoading {
                    ProgressView("Writing an explanation on device…")
                    Button("Cancel") { ai.invalidate() }.buttonStyle(.bordered)
                } else {
                    if matches, let text = ai.text {
                        Text(text).accessibilityIdentifier("appleIntelligenceExplanation")
                        Text("Source: Apple Intelligence · on-device · \(ai.language ?? "")")
                            .font(.caption).foregroundStyle(.secondary)
                        Text("AI drafts can be wrong. Compare the explanation with the evidence. Format screening is not clinical validation.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if matches, let note = ai.note {
                        Text(note)
                        Text("Explanation source: Swift rules").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("The model is ready. Generate a summary of the evidence shown here.")
                    }
                    Button(matches && ai.text != nil ? "Regenerate AI explanation" : "Generate AI explanation") {
                        ai.generate(input: AIExplanationInput(report: report, source: session.scenario == .workshop
                                                            ? "Simulated workshop daily data; source persona \(session.profile.sourcePersona); alias \(session.profile.displayName)"
                                                            : "Synthetic UI test fixture",
                                                            exerciseContext: session.context == .exercise), key: explanationKey)
                    }.buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("generateAppleIntelligence")
                }
            }
            Text("AI summaries, evidence, and rule-based explanations use English. If the model cannot generate in English, the rule-based fallback remains available.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var aiFallback: some View {
        PHICard {
            Label("AI unavailable", systemImage: "bubble.left.and.exclamationmark.bubble.right").font(.headline)
            Text("Readings, charts, and rule-based explanations still work. This demo mode deliberately skips Apple Intelligence to test the fallback, even on a supported device.")
        }
    }

    private func evidenceRow(_ evidence: MetricEvidence) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(evidence.metric.title).font(.subheadline.weight(.medium))
            if let current = evidence.current, let baseline = evidence.baseline {
                Text("Today \(DailyCheckEngine.number(current)) \(evidence.metric.unit) · median \(DailyCheckEngine.number(baseline.median)) \(evidence.metric.unit)")
                Text("\(baseline.validDays) valid days · simulated daily summary · \(sourceLabel)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func restoreDemo() {
        session.scenario = .changed
        session.tab = .today
    }
}

private struct ScreenHeading: View {
    let step: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(step.uppercased()).font(.caption.weight(.medium)).foregroundStyle(.secondary)
            Text(title).font(.largeTitle.weight(.semibold)).fixedSize(horizontal: false, vertical: true)
            Text(subtitle).foregroundStyle(.secondary)
        }
    }
}

private struct PHICard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct MetricEvidenceCard: View {
    let evidence: MetricEvidence
    let readings: [DailyReading]
    let showChart: Bool
    var sourceLabel: String = "PHI demo data"
    private var metric: HealthMetric { evidence.metric }
    var body: some View {
        PHICard {
            HStack {
                Text(metric == .hrvSDNN ? "Supporting evidence · HRV SDNN" : metric.title).font(.headline)
                Spacer()
                Image(systemName: metric == .restingHR ? "heart" : "waveform.path.ecg").foregroundStyle(PHIStyle.green)
            }
            switch evidence.availability {
            case .ready:
                if let current = evidence.current, let baseline = evidence.baseline {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(DailyCheckEngine.number(current)).font(.system(size: showChart ? 46 : 32, weight: .medium, design: .rounded)).monospacedDigit()
                        Text("\(metric.unit) · today").foregroundStyle(.secondary)
                    }
                    Text("Own baseline: \(DailyCheckEngine.number(baseline.median)) \(metric.unit) · \(baseline.validDays) days")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let delta = evidence.delta {
                        Text("Difference \(DailyCheckEngine.signed(delta)) \(metric.unit)")
                            .font(.subheadline.weight(.medium)).foregroundStyle(PHIStyle.green)
                    }
                    if showChart { evidenceChart(baseline) }
                    Text(metric == .hrvSDNN ? "Daily SDNN from the dataset; the original sampling context is unavailable. Not interchangeable with RMSSD." : "Source: \(sourceLabel) · not personal health data.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            case .disabled:
                Text("Not used").font(.title3)
                Text("This metric is disabled. Its readings and baseline are not shown.").foregroundStyle(.secondary)
            case .noCurrentSample:
                Text("Data unavailable").font(.title3)
                Text("There is no valid sample for this day. An empty result alone does not tell us whether data is missing or access is limited.").foregroundStyle(.secondary)
            case .insufficientHistory(let count, let required):
                Text("Not enough history yet").font(.title3)
                if let current = evidence.current {
                    Text("Today's sample: \(DailyCheckEngine.number(current)) \(metric.unit). It is not yet compared with a baseline.")
                }
                ProgressView(value: Double(count), total: Double(required))
                Text("\(count) of \(required) valid days before this day").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func evidenceChart(_ baseline: PersonalBaseline) -> some View {
        let today = readings.last?.day ?? 0
        let chartRows = readings.filter { $0.day >= today - DailyCheckEngine.windowDays && $0.value(for: metric) != nil }
        let values = chartRows.compactMap { $0.value(for: metric) }
        let low = min(values.min() ?? baseline.lower, baseline.lower) - 2
        let high = max(values.max() ?? baseline.upper, baseline.upper) + 2
        return VStack(alignment: .leading, spacing: 8) {
            Chart {
                ForEach(chartRows) { row in
                    RectangleMark(x: .value("Day", row.day), yStart: .value("Lower", baseline.lower), yEnd: .value("Upper", baseline.upper), width: .ratio(1))
                        .foregroundStyle(PHIStyle.green.opacity(0.10))
                    if let value = row.value(for: metric) {
                        LineMark(x: .value("Day", row.day), y: .value(metric.unit, value))
                            .foregroundStyle(PHIStyle.green)
                        PointMark(x: .value("Day", row.day), y: .value(metric.unit, value))
                            .foregroundStyle(PHIStyle.green).symbolSize(row.day == readings.last?.day ? 45 : 10)
                    }
                }
                RuleMark(y: .value("Median", baseline.median)).foregroundStyle(.secondary).lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .chartYScale(domain: low...high)
            .chartXAxis {
                AxisMarks(values: [chartRows.first?.day ?? 0, readings.last?.day ?? 14]) { axis in
                    AxisValueLabel { Text(axis.as(Int.self) == readings.last?.day ? "Today" : "History starts") }
                }
            }
            .chartYAxisLabel(metric.unit)
            .frame(height: 170)
            .accessibilityLabel("Chart: \(metric.title). Baseline \(DailyCheckEngine.number(baseline.median)) \(metric.unit). Today \(DailyCheckEngine.number(evidence.current ?? 0)) \(metric.unit).")
            Text("Green band: illustrative range \(DailyCheckEngine.number(baseline.lower))–\(DailyCheckEngine.number(baseline.upper)) \(metric.unit). Not a medical threshold.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct FullFallbackView: View {
    let evidence: MetricEvidence
    let restoreDemo: () -> Void
    let reviewAccess: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenHeading(step: "Fallback", title: title, subtitle: "No conclusions without enough evidence.")
            MetricEvidenceCard(evidence: evidence, readings: [], showChart: false)
            PHICard {
                Text("You still have choices").font(.headline)
                Text("Review access or try a complete sample dataset. HRV does not replace resting HR when the primary metric is unavailable.")
            }
            if evidence.availability != .disabled {
                Button(action: restoreDemo) { Text("Try the complete demo").frame(maxWidth: .infinity) }
                    .buttonStyle(.borderedProminent).controlSize(.large)
            }
            Button("Review data access", action: reviewAccess).buttonStyle(.bordered)
        }
    }
    private var title: String {
        switch evidence.availability {
        case .disabled: return "Your choice is respected."
        case .noCurrentSample: return "No data to show yet."
        default: return "Learning your usual patterns."
        }
    }
}

struct DailyCheckPreviews: PreviewProvider {
    static var previews: some View { DailyCheckRootView() }
}
