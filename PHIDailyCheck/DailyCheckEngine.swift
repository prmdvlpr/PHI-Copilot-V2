import Foundation

// Pure Swift domain logic. No HealthKit writes, network calls, or model inference.
enum DemoScenario: String, CaseIterable, Identifiable {
    case workshop, changed, steady, missingHRV, shortHistory, noData, noAI
    var id: String { rawValue }
    var title: String {
        switch self {
        case .workshop: return "Replay workshop data"
        case .changed: return "Resting HR up, HRV down"
        case .steady: return "A steady day"
        case .missingHRV: return "Resting HR available, HRV missing"
        case .shortHistory: return "Only nine days of history"
        case .noData: return "No data to show"
        case .noAI: return "AI unavailable"
        }
    }
}

enum HealthMetric: String, CaseIterable, Identifiable {
    case restingHR, hrvSDNN
    var id: String { rawValue }
    var title: String { self == .restingHR ? "Resting heart rate" : "HRV · SDNN" }
    var unit: String { self == .restingHR ? "bpm" : "ms" }
    var spreadFloor: Double { self == .restingHR ? 1 : 2 }
}

struct DailyReading: Identifiable, Equatable {
    let day: Int
    let date: Date
    let restingHR: Double?
    let hrvSDNN: Double?
    var id: Int { day }
    func value(for metric: HealthMetric) -> Double? {
        metric == .restingHR ? restingHR : hrvSDNN
    }
}

struct PersonalBaseline: Equatable {
    let median: Double
    let spread: Double
    let validDays: Int
    var lower: Double { median - 1.5 * spread }
    var upper: Double { median + 1.5 * spread }
}

enum EvidenceAvailability: Equatable {
    case disabled
    case noCurrentSample
    case insufficientHistory(validDays: Int, requiredDays: Int)
    case ready
}

struct MetricEvidence {
    let metric: HealthMetric
    let current: Double?
    let baseline: PersonalBaseline?
    let history: [DailyReading]
    let availability: EvidenceAvailability
    var delta: Double? {
        guard availability == .ready, let current, let baseline else { return nil }
        return current - baseline.median
    }
    var isOutsideUsualRange: Bool {
        guard availability == .ready, let current, let baseline else { return false }
        return current < baseline.lower || current > baseline.upper
    }
}

struct DailyCheckReport {
    let restingHR: MetricEvidence
    let hrv: MetricEvidence
    var canExplain: Bool { restingHR.availability == .ready }
    var usesHRV: Bool { hrv.availability == .ready && canExplain }
    var title: String {
        guard canExplain else { return "Not enough evidence" }
        if restingHR.isOutsideUsualRange {
            if usesHRV, let r = restingHR.delta, let h = hrv.delta, r > 0, h < 0 {
                return "Resting HR up, HRV down"
            }
            return "Resting HR differs from your usual"
        }
        return usesHRV && hrv.isOutsideUsualRange
            ? "Resting HR is steady, HRV has changed" : "Resting HR is close to your usual"
    }
    var explanation: String {
        guard canExplain, let value = restingHR.current, let base = restingHR.baseline,
              let delta = restingHR.delta else {
            return "There is not enough resting HR history to explain a change yet."
        }
        var text = "Resting HR today is \(DailyCheckEngine.number(value)) bpm, compared with your historical median of \(DailyCheckEngine.number(base.median)) bpm over \(base.validDays) days. The difference is \(DailyCheckEngine.signed(delta)) bpm."
        if usesHRV, let h = hrv.current, let hb = hrv.baseline, let hd = hrv.delta {
            text += " HRV SDNN today is \(DailyCheckEngine.number(h)) ms, compared with its own baseline of \(DailyCheckEngine.number(hb.median)) ms; the difference is \(DailyCheckEngine.signed(hd)) ms."
        } else {
            text += " HRV is not used; this explanation is based on resting HR alone."
        }
        return text + " This comparison does not establish the cause of a change and is not a diagnosis."
    }
}

enum DailyCheckEngine {
    static let requiredDays = 14 // Teaching parameter, not a clinically validated threshold.
    static let windowDays = 14

    static func number(_ value: Double) -> String {
        value == value.rounded() ? String(format: "%.0f", value) : String(format: "%.1f", value)
    }
    static func signed(_ value: Double) -> String {
        (value > 0 ? "+" : "") + number(value)
    }
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    static func evidence(metric: HealthMetric, readings: [DailyReading], enabled: Bool) -> MetricEvidence {
        guard enabled else {
            return MetricEvidence(metric: metric, current: nil, baseline: nil, history: [], availability: .disabled)
        }
        // One reading per UTC day; duplicate days are treated as invalid input, not double counted.
        let grouped = Dictionary(grouping: readings, by: \.day)
        guard let latestDay = readings.map(\.day).max(), grouped[latestDay]?.count == 1 else {
            return MetricEvidence(metric: metric, current: nil, baseline: nil, history: [], availability: .noCurrentSample)
        }
        let unique = grouped.values.compactMap { $0.count == 1 ? $0.first : nil }.sorted { $0.day < $1.day }
        guard let today = unique.last else {
            return MetricEvidence(metric: metric, current: nil, baseline: nil, history: [], availability: .noCurrentSample)
        }
        let earliestDay = today.day - windowDays
        let history = unique.filter { $0.day >= earliestDay && $0.day < today.day }
        let values = history.compactMap { $0.value(for: metric) }.filter { $0.isFinite && $0 > 0 }
        let candidate = today.value(for: metric)
        let current = candidate.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let baseline: PersonalBaseline?
        if values.count >= requiredDays, let middle = median(values),
           let mad = median(values.map({ abs($0 - middle) })) {
            baseline = PersonalBaseline(median: middle, spread: max(1.4826 * mad, metric.spreadFloor), validDays: values.count)
        } else {
            baseline = nil
        }
        let availability: EvidenceAvailability
        if current == nil { availability = .noCurrentSample }
        else if baseline == nil { availability = .insufficientHistory(validDays: values.count, requiredDays: requiredDays) }
        else { availability = .ready }
        return MetricEvidence(metric: metric, current: current, baseline: baseline, history: history, availability: availability)
    }

    static func report(readings: [DailyReading], allowRestingHR: Bool, allowHRV: Bool) -> DailyCheckReport {
        DailyCheckReport(
            restingHR: evidence(metric: .restingHR, readings: readings, enabled: allowRestingHR),
            hrv: evidence(metric: .hrvSDNN, readings: readings, enabled: allowHRV)
        )
    }

    static func demo(_ scenario: DemoScenario) -> [DailyReading] {
        guard scenario != .noData && scenario != .workshop else { return [] }
        let hr: [Double] = [59, 60, 61, 60, 59, 60, 62, 58, 60, 61, 59, 60, 61, 60]
        let hrv: [Double] = [51, 52, 53, 52, 51, 52, 54, 50, 52, 53, 51, 52, 53, 52]
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let today = calendar.date(from: DateComponents(year: 2026, month: 11, day: 14))!
        let days = scenario == .shortHistory ? 9 : 14
        var rows = (0..<days).map { i in
            DailyReading(day: i, date: calendar.date(byAdding: .day, value: i - days, to: today)!,
                         restingHR: hr[i], hrvSDNN: scenario == .missingHRV ? nil : hrv[i])
        }
        rows.append(DailyReading(day: days, date: today,
                                 restingHR: scenario == .steady ? 60 : 67,
                                 hrvSDNN: scenario == .missingHRV ? nil : scenario == .steady ? 52 : 42))
        return rows
    }
}

// Aliases for the team demo. No demographic/clinical attributes of Adi or Hanna are inferred.
enum DemoProfile: String, CaseIterable, Identifiable {
    case adi, hanna
    var id: String { rawValue }
    var displayName: String { self == .adi ? "Adi" : "Hanna" }
    var sourcePersona: String { self == .adi ? "tom" : "maya" }
    var defaultReplayDay: Int { self == .adi ? 44 : 30 }
}

struct WorkshopDataset: Decodable {
    struct Profile: Decodable {
        let id: String
        let displayName: String
        let sourcePersona: String
        let defaultReplayDay: Int
        let readings: [Record]
    }
    struct Record: Decodable {
        let day: Int
        let date: Date
        let restingHR: Double?
        let hrvSDNN: Double?
        var reading: DailyReading { DailyReading(day: day, date: date, restingHR: restingHR, hrvSDNN: hrvSDNN) }
    }
    let disclaimer: String
    let sourceFile: String
    let sourceSHA256: String
    let profiles: [Profile]

    static func load(from url: URL) throws -> WorkshopDataset {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WorkshopDataset.self, from: Data(contentsOf: url))
    }
    static func bundled() throws -> WorkshopDataset {
        guard let url = Bundle.main.url(forResource: "WorkshopDailySamples", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try load(from: url)
    }
    func replay(profile: DemoProfile, through day: Int) -> [DailyReading] {
        guard (1...60).contains(day), let match = profiles.first(where: { $0.id == profile.rawValue }) else { return [] }
        return match.readings.filter { $0.day <= day }.map(\.reading).sorted { $0.day < $1.day }
    }
}
