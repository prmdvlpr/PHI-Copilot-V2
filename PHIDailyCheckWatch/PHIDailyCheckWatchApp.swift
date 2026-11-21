import SwiftUI
import Combine

@main
struct PHIDailyCheckWatchApp: App {
    var body: some Scene { WindowGroup { WatchDailyCheckView() } }
}

@MainActor
private final class WatchDemoSession: ObservableObject {
    @Published var accepted = false
    @Published var showSettings = false
    @Published var allowRestingHR = true
    @Published var allowHRV = true
    @Published var profile: DemoProfile = .adi
    @Published var replayDay = DemoProfile.adi.defaultReplayDay
    @Published var scenario: DemoScenario = .workshop

    var readings: [DailyReading] {
        if scenario == .workshop {
            return (try? WorkshopDataset.bundled().replay(profile: profile, through: replayDay)) ?? []
        }
        return DailyCheckEngine.demo(scenario)
    }
    var report: DailyCheckReport {
        DailyCheckEngine.report(readings: readings, allowRestingHR: allowRestingHR, allowHRV: allowHRV)
    }
    var source: String {
        scenario == .workshop ? "Workshop \(profile.sourcePersona) · day \(replayDay)" : "Synthetic test fixture"
    }
    func restore() {
        allowRestingHR = true; allowHRV = true
        replayDay = profile.defaultReplayDay; scenario = .workshop
    }
}

struct WatchDailyCheckView: View {
    @StateObject private var session = WatchDemoSession()

    var body: some View {
        NavigationStack {
            Group {
                if session.accepted {
                    GeometryReader { geometry in
                        ViewThatFits(in: .vertical) {
                            compactSummary(ringSize: min(106, max(72, geometry.size.height * 0.42)))
                            ScrollView { compactSummary(ringSize: 80) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            consent
                        }.padding(.horizontal, 5)
                    }
                }
            }
            .navigationTitle("PHI")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { session.showSettings = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Demo settings and consent")
                }
            }
            .sheet(isPresented: $session.showSettings) {
                NavigationStack { settings }
            }
        }
        .tint(.green)
        .environment(\.locale, Locale(identifier: "en"))
        .onChange(of: session.profile) { _, profile in
            session.replayDay = profile.defaultReplayDay
            session.scenario = .workshop
        }
    }

    private var summaryColor: Color {
        guard session.report.canExplain else { return .secondary }
        let changed = session.report.restingHR.isOutsideUsualRange
            || (session.report.usesHRV && session.report.hrv.isOutsideUsualRange)
        return changed ? .orange : .green
    }

    private var summaryTitle: String {
        guard session.report.canExplain else {
            switch session.report.restingHR.availability {
            case .disabled: return "Data access is off"
            case .insufficientHistory: return "Building baseline"
            default: return "No data to show"
            }
        }
        if session.report.restingHR.isOutsideUsualRange {
            return session.report.usesHRV && (session.report.restingHR.delta ?? 0) > 0 && (session.report.hrv.delta ?? 0) < 0
                ? "RHR up · HRV down" : "RHR differs from usual"
        }
        return session.report.usesHRV && session.report.hrv.isOutsideUsualRange
            ? "RHR steady · HRV changed" : "RHR close to usual"
    }

    private func compactSummary(ringSize: CGFloat) -> some View {
        VStack(spacing: 6) {
            Text("\(session.profile.displayName) · SIMULATED")
                .font(.caption2).foregroundStyle(.secondary)
            ZStack {
                // Full ring encodes a labeled state only, never a percentage or health score.
                Circle().stroke(summaryColor.opacity(0.85), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                VStack(spacing: 0) {
                    if session.report.canExplain, let current = session.report.restingHR.current {
                        Text(DailyCheckEngine.number(current))
                            .font(.system(size: ringSize * 0.32, weight: .medium, design: .rounded)).monospacedDigit()
                        Text("Resting HR · bpm").font(.caption2)
                    } else {
                        Image(systemName: session.report.restingHR.availability == .disabled ? "hand.raised" : "hourglass")
                            .font(.title3)
                        if case .insufficientHistory(let count, let required) = session.report.restingHR.availability {
                            Text("\(count)/\(required) days").font(.caption2)
                        } else { Text("No insight yet").font(.caption2) }
                    }
                }.padding(8)
            }
            .frame(width: ringSize, height: ringSize)
            .accessibilityElement(children: .combine)
            Text(summaryTitle).font(.caption.weight(.semibold)).foregroundStyle(summaryColor)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if session.report.canExplain {
                if session.report.usesHRV, let value = session.report.hrv.current {
                    Text("HRV SDNN \(DailyCheckEngine.number(value)) ms")
                        .font(.caption).monospacedDigit()
                } else {
                    Text(session.report.hrv.availability == .disabled ? "HRV not used" : "HRV unavailable")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Text("Details: open iPhone app")
                .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4).padding(.vertical, 4)
    }

    @ViewBuilder private var consent: some View {
        Text("1 / 4 · Consent").font(.caption).foregroundStyle(.secondary)
        Text("Your data. Your choice.").font(.title3.weight(.semibold))
        Text("Compare resting HR and optional HRV SDNN with their own baselines.")
        Toggle("Resting HR", isOn: $session.allowRestingHR)
        Toggle("HRV SDNN", isOn: $session.allowHRV)
        Text("What: workshop samples. Why: demonstrate personal trends. Where: bundled and processed on this Watch. No Health access, cloud calls, or phone sync.")
            .font(.caption).foregroundStyle(.secondary)
        Button("Continue") { session.accepted = true }.buttonStyle(.borderedProminent)
        Button("Without data") {
            session.allowRestingHR = false; session.allowHRV = false; session.accepted = true
        }
    }

    private var settings: some View {
        Form {
            Section("Details on iPhone") {
                Text("Open PHI on your iPhone and choose the same profile and replay day for evidence, charts, and explanation. This demo does not sync or open the phone app automatically.")
                    .font(.caption)
            }
            Section("Profile · simulation") {
                Picker("Profile", selection: $session.profile) {
                    ForEach(DemoProfile.allCases) { Text($0.displayName).tag($0) }
                }
                Text("Adi = Tom; Hanna = Maya. Demo aliases, not personal measurements.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Section("Replay") {
                Picker("Scenario", selection: $session.scenario) {
                    ForEach(DemoScenario.allCases) { Text($0.title).tag($0) }
                }
                if session.scenario == .workshop {
                    Stepper("Day \(session.replayDay) / 60", value: $session.replayDay, in: 1...60)
                }
            }
            Section("Consent · sample data") {
                Toggle("Resting HR", isOn: $session.allowRestingHR)
                Toggle("HRV SDNN", isOn: $session.allowHRV)
                Text("Choices apply immediately on this Watch only. No data is sent to the iPhone.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Button("Review consent") { session.showSettings = false; session.accepted = false }
        }.navigationTitle("Demo & access")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { session.showSettings = false } } }
    }
}
