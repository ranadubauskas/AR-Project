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
        case .low: return 30
        case .medium: return 75
        case .high: return 140
        }
    }
    var stableCode: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }
}

struct TrialSpec: Identifiable, Codable {
    let id = UUID()
    let mode: SelectionMode
    let density: DensityLevel
    let trialNumberWithinCondition: Int
    let layoutSeed: Int
    let targetIndex: Int
}

struct TrialResult: Identifiable, Codable {
    let id = UUID()
    let mode: SelectionMode
    let density: DensityLevel
    let layoutSeed: Int
    let targetIndex: Int
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

    func currentElapsedMs(at now: CFTimeInterval = CACurrentMediaTime()) -> Double? {
        guard phase == .runningTrial, let trialStartTime else { return nil }
        return (now - trialStartTime) * 1000.0
    }
    
    private func shuffledWithoutAdjacentMatchedLayouts(_ trials: [TrialSpec]) -> [TrialSpec] {
        guard trials.count > 1 else { return trials }

        func sameLayout(_ a: TrialSpec, _ b: TrialSpec) -> Bool {
            a.density == b.density &&
            a.layoutSeed == b.layoutSeed &&
            a.targetIndex == b.targetIndex
        }

        // Retry shuffling until no identical layouts are adjacent.
        for _ in 0..<500 {
            let shuffled = trials.shuffled()

            var ok = true
            for i in 1..<shuffled.count {
                if sameLayout(shuffled[i - 1], shuffled[i]) {
                    ok = false
                    break
                }
            }

            if ok {
                return shuffled
            }
        }

        // Fallback: greedy construction
        var remaining = trials.shuffled()
        var arranged: [TrialSpec] = []

        while !remaining.isEmpty {
            let last = arranged.last

            if let index = remaining.firstIndex(where: { candidate in
                guard let last else { return true }
                return !(candidate.density == last.density &&
                         candidate.layoutSeed == last.layoutSeed &&
                         candidate.targetIndex == last.targetIndex)
            }) {
                arranged.append(remaining.remove(at: index))
            } else {
                // If somehow unavoidable, just place the next one.
                arranged.append(remaining.removeFirst())
            }
        }

        return arranged
    }

    func prepareDefaultQueue() {
        var queue: [TrialSpec] = []

        let lowSeeds = [10001, 10002, 10003, 10004, 10005, 10006, 10007, 10016, 10009, 10010, 10023, 10012]
        let mediumSeeds = [20001, 20022, 20003, 20004, 20005, 20006, 20007, 20008, 20009, 20010, 20031, 20032]
        let highSeeds = [30001, 30002, 30003, 30014, 30005, 30006, 30007, 30008, 30019, 30010, 30011, 30022]

        let seedTable: [(DensityLevel, [Int])] = [
            (.low, lowSeeds),
            (.medium, mediumSeeds),
            (.high, highSeeds)
        ]

        for (density, seeds) in seedTable {
                for (index, seed) in seeds.enumerated() {
                    let targetIndex = abs(seed) % density.targetCount

                    queue.append(
                        TrialSpec(
                            mode: .baseline,
                            density: density,
                            trialNumberWithinCondition: index + 1,
                            layoutSeed: seed,
                            targetIndex: targetIndex
                        )
                    )

                    queue.append(
                        TrialSpec(
                            mode: .magray,
                            density: density,
                            trialNumberWithinCondition: index + 1,
                            layoutSeed: seed,
                            targetIndex: targetIndex
                        )
                    )
                }
            }

            trialQueue = shuffledWithoutAdjacentMatchedLayouts(queue)
            currentTrialIndex = 0
            results = []
            activeTrial = nil
            trialStartTime = nil
            phase = .readyForTrial
            currentTrialLabel = "Ready: 0/\(trialQueue.count)"
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
            layoutSeed: activeTrial.layoutSeed,
            targetIndex: activeTrial.targetIndex,
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
          layoutSeed = \(result.layoutSeed)
          targetIndex = \(result.targetIndex)
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
            currentTrialLabel = "Recorded \(results.count)/\(trialQueue.count)"
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
