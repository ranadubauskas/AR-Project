import Foundation
import RealityKit

final class TargetHistoryBuffer {
    struct Sample {
        let entity: ModelEntity
        let timestamp: CFTimeInterval
    }

    private let windowSeconds: CFTimeInterval
    private var samples: [Sample] = []

    init(windowSeconds: CFTimeInterval = 0.10) {
        self.windowSeconds = windowSeconds
    }

    func add(entity: ModelEntity, at timestamp: CFTimeInterval) {
        samples.append(Sample(entity: entity, timestamp: timestamp))
        prune(now: timestamp)
    }

    func mostStableCandidate(now: CFTimeInterval) -> ModelEntity? {
        prune(now: now)

        var counts: [ObjectIdentifier: Int] = [:]
        var entities: [ObjectIdentifier: ModelEntity] = [:]

        for sample in samples {
            let id = ObjectIdentifier(sample.entity)
            counts[id, default: 0] += 1
            entities[id] = sample.entity
        }

        guard let bestID = counts.max(by: { $0.value < $1.value })?.key else {
            return nil
        }

        return entities[bestID]
    }

    func clear() {
        samples.removeAll()
    }

    private func prune(now: CFTimeInterval) {
        samples.removeAll { now - $0.timestamp > windowSeconds }
    }
}
