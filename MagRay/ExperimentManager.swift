import Foundation
import Combine
import QuartzCore

enum DensityLevel: String, CaseIterable, Identifiable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    var id: String { rawValue }

    var targetCount: Int {
        switch self {
        case .low: return 10
        case .medium: return 30
        case .high: return 60
        }
    }
}

struct TrialSpec: Identifiable, Codable {
    let id = UUID()
    let mode: SelectionMode
    let density: DensityLevel
    let trialNumberWithinCondition: Int
}

struct TrialResult: Identifiable, Codable {
    let id = UUID()
    let mode: SelectionMode
    let density: DensityLevel
    let targetID: String
    let selectedID: String?
    let correct: Bool
    let selectionTimeMs: Double
    let candidateSwitchCount: Int
    let timestamp: Date
}

@MainActor
final class ExperimentManager: ObservableObject {
    enum Phase {
        case idle
        case readyForTrial
        case runningTrial
        case finished
    }

    @Published var phase: Phase = .idle
    @Published var currentTrialLabel: String = "Experiment not started"
    @Published var results: [TrialResult] = []
    @Published var sceneNonce = UUID()

    var trialQueue: [TrialSpec] = []
    var currentTrialIndex: Int = 0
    var activeTrial: TrialSpec?
    var trialStartTime: CFTimeInterval?

    var completedCount: Int { results.count }
    var totalCount: Int { trialQueue.count }

    var latestResult: TrialResult? {
        results.last
    }

    func prepareDefaultQueue(trialsPerCondition: Int = 12) {
        var queue: [TrialSpec] = []

        for mode in SelectionMode.allCases {
            for density in DensityLevel.allCases {
                for n in 1...trialsPerCondition {
                    queue.append(
                        TrialSpec(
                            mode: mode,
                            density: density,
                            trialNumberWithinCondition: n
                        )
                    )
                }
            }
        }

        queue.shuffle()
        trialQueue = queue
        currentTrialIndex = 0
        results = []
        activeTrial = nil
        trialStartTime = nil
        phase = .readyForTrial
        currentTrialLabel = "Ready: 0/\(trialQueue.count) completed"
    }

    func startNextTrial() {
        if trialQueue.isEmpty {
            prepareDefaultQueue()
        }

        guard currentTrialIndex < trialQueue.count else {
            phase = .finished
            currentTrialLabel = "Finished: \(results.count)/\(trialQueue.count)"
            return
        }

        activeTrial = trialQueue[currentTrialIndex]
        trialStartTime = CACurrentMediaTime()
        phase = .runningTrial
        sceneNonce = UUID()

        if let trial = activeTrial {
            currentTrialLabel =
                "Trial \(currentTrialIndex + 1)/\(trialQueue.count) • \(trial.mode.rawValue) • \(trial.density.rawValue)"
        }
    }

    func recordSelection(
        selectedID: String?,
        targetID: String,
        candidateSwitchCount: Int
    ) {
        guard let activeTrial, let trialStartTime else { return }

        let elapsedMs = (CACurrentMediaTime() - trialStartTime) * 1000.0
        let correct = (selectedID == targetID)

        let result = TrialResult(
            mode: activeTrial.mode,
            density: activeTrial.density,
            targetID: targetID,
            selectedID: selectedID,
            correct: correct,
            selectionTimeMs: elapsedMs,
            candidateSwitchCount: candidateSwitchCount,
            timestamp: Date()
        )

        results.append(result)

        print("""
        Recorded trial \(results.count):
          mode = \(result.mode.rawValue)
          density = \(result.density.rawValue)
          targetID = \(result.targetID)
          selectedID = \(result.selectedID ?? "nil")
          correct = \(result.correct)
          selectionTimeMs = \(String(format: "%.1f", result.selectionTimeMs))
          candidateSwitchCount = \(result.candidateSwitchCount)
        """)

        currentTrialIndex += 1
        self.activeTrial = nil
        self.trialStartTime = nil

        if currentTrialIndex >= trialQueue.count {
            phase = .finished
            currentTrialLabel = "Finished: \(results.count)/\(trialQueue.count)"
        } else {
            phase = .readyForTrial
            currentTrialLabel = "Recorded \(results.count)/\(trialQueue.count). Tap Next Trial."
        }
    }

    func saveResults() throws -> URL {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let data = try encoder.encode(results)

        let fileURL = URL.documentsDirectory.appending(
            path: "magray-results-\(Int(Date().timeIntervalSince1970)).json"
        )

        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }
}
