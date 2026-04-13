import Foundation
import UIKit
import RealityKit
import ARKit
import CoreMotion
import QuartzCore
import Combine

struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed == 0 ? 1 : seed))
    }

    mutating func next() -> UInt64 {
        state = 2862933555777941757 &* state &+ 3037000493
        return state
    }
}

@MainActor
final class MagRayController: NSObject {
    private weak var arView: ARView?
    private let motionManager = CMMotionManager()
    private var updateSubscription: (any Cancellable)?

    private var rootAnchor: AnchorEntity?
    private var targets: [ModelEntity] = []

    private let history = TargetHistoryBuffer(windowSeconds: 0.10)

    private var currentCandidate: ModelEntity?
    private var confirmedSelection: ModelEntity?
    private var intendedTarget: ModelEntity?

    var selectionMode: SelectionMode = .magray
    var experiment: ExperimentManager?

    private var lastSceneNonce: UUID?
    private var currentCandidateSwitchCount: Int = 0

    private var currentSnapStrength: Float = 1.0
    private var smoothedMotion: Double = 0.0

    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 30.0

    private let normalMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
    private let candidateMaterial = SimpleMaterial(color: .systemRed, isMetallic: false)
    private let selectedMaterial = SimpleMaterial(color: .systemGreen, isMetallic: false)
    private let targetMaterial = SimpleMaterial(color: .systemYellow, isMetallic: false)

    // Confirmation locking
    private var confirmationPress: UILongPressGestureRecognizer?
    private var isConfirmationLocked = false
    private var lockedCandidate: ModelEntity?
    private var lockStartTime: CFTimeInterval?

    func setup(arView: ARView) {
        self.arView = arView
        setupSession()
        addConfirmationGesture()
        startMotionUpdates()
        subscribeToFrameUpdates()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.buildScene()
        }
    }

    func teardown() {
        updateSubscription?.cancel()
        updateSubscription = nil
        motionManager.stopDeviceMotionUpdates()
        history.clear()
        rootAnchor?.removeFromParent()
        rootAnchor = nil
        targets.removeAll()
        currentCandidate = nil
        confirmedSelection = nil
        intendedTarget = nil
        currentCandidateSwitchCount = 0
        lastSceneNonce = nil

        confirmationPress = nil
        clearConfirmationLock()
    }

    func syncExperimentState() {
        guard let experiment else { return }

        if lastSceneNonce != experiment.sceneNonce {
            lastSceneNonce = experiment.sceneNonce
            currentCandidateSwitchCount = 0
            clearConfirmationLock()

            if experiment.phase == .runningTrial {
                selectionMode = experiment.activeTrial?.mode ?? selectionMode
                buildScene()
            }
        }
    }
}

// MARK: - Session + Scene
extension MagRayController {
    private func setupSession() {
        guard let arView else { return }

        let config = ARWorldTrackingConfiguration()
        config.environmentTexturing = .none

        arView.automaticallyConfigureSession = false
        arView.session.run(config, options: [.resetTracking, .removeExistingAnchors])
    }
    
    private func buildScene() {
        guard let arView else {
            print("buildScene: arView is nil")
            return
        }

        guard let frame = arView.session.currentFrame else {
            print("No ARFrame yet — move the phone a little and try again.")
            return
        }

        print("buildScene: placing spheres")

        rootAnchor?.removeFromParent()
        history.clear()
        targets.removeAll()
        currentCandidate = nil
        confirmedSelection = nil
        intendedTarget = nil

        let cameraMatrix = frame.camera.transform

        let cameraPosition = SIMD3<Float>(
            cameraMatrix.columns.3.x,
            cameraMatrix.columns.3.y,
            cameraMatrix.columns.3.z
        )

        let cameraForward = -SIMD3<Float>(
            cameraMatrix.columns.2.x,
            cameraMatrix.columns.2.y,
            cameraMatrix.columns.2.z
        )

        let cameraRight = SIMD3<Float>(
            cameraMatrix.columns.0.x,
            cameraMatrix.columns.0.y,
            cameraMatrix.columns.0.z
        )

        let cameraUp = SIMD3<Float>(
            cameraMatrix.columns.1.x,
            cameraMatrix.columns.1.y,
            cameraMatrix.columns.1.z
        )

        // Use horizontal forward only for where the cluster center is spawned,
        // so the next scene doesn't drift up toward the ceiling.
        var horizontalForward = SIMD3<Float>(
            cameraForward.x,
            0,
            cameraForward.z
        )

        if simd_length_squared(horizontalForward) < 1e-6 {
            horizontalForward = SIMD3<Float>(0, 0, -1)
        } else {
            horizontalForward = simd_normalize(horizontalForward)
        }

        // Place cluster in front of the user, but not based on current phone pitch.
        // Small downward offset helps keep the cluster centered on screen.
        let clusterCenter =
            cameraPosition +
            horizontalForward * 0.6 +
            SIMD3<Float>(0, -0.05, 0)

        let anchor = AnchorEntity(world: clusterCenter)
        rootAnchor = anchor

        let count = experiment?.activeTrial?.density.targetCount ?? 15
        let seed = experiment?.activeTrial?.layoutSeed ?? 42
        let offsets = generateOffsets(count: count, seed: seed)

        for (i, offset) in offsets.enumerated() {
            let radius: Float = i < min(10, count) ? 0.03 : 0.022
            let sphereMesh = MeshResource.generateSphere(radius: radius)

            let entity = ModelEntity(mesh: sphereMesh, materials: [normalMaterial])
            entity.name = "target_\(i)"

            // Keep the layout screen-facing like before, so lots of spheres stay visible.
            entity.position =
                cameraRight * offset.x +
                cameraUp * offset.y +
                horizontalForward * offset.z

            anchor.addChild(entity)
            targets.append(entity)
        }

        if let trial = experiment?.activeTrial, trial.targetIndex < targets.count {
            intendedTarget = targets[trial.targetIndex]
        } else {
            intendedTarget = targets.first
        }

        arView.scene.addAnchor(anchor)
        refreshMaterials()
    }

    private func generateOffsets(count: Int, seed: Int) -> [SIMD3<Float>] {
        var offsets: [SIMD3<Float>] = []
        var attempts = 0
        var rng = SeededGenerator(seed: seed)

        let radius: Float
        let minSpacing: Float
        let zSpread: Float

        switch count {
        case 0...20:
            radius = 0.08
            minSpacing = 0.018
            zSpread = 0.01
        case 21...50:
            radius = 0.11
            minSpacing = 0.014
            zSpread = 0.012
        default:
            radius = 0.14
            minSpacing = 0.010
            zSpread = 0.015
        }

        while offsets.count < count && attempts < count * 500 {
            attempts += 1

            let x = Float.random(in: -radius...radius, using: &rng)
            let y = Float.random(in: -radius...radius, using: &rng)
            let z = Float.random(in: -zSpread...zSpread, using: &rng)

            let candidate = SIMD3<Float>(x, y, z)

            let tooClose = offsets.contains { existing in
                simd_length(candidate - existing) < minSpacing
            }

            if !tooClose {
                offsets.append(candidate)
            }
        }

        return offsets
    }
}

// MARK: - Motion
extension MagRayController {
    private func startMotionUpdates() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let self, let motion else { return }
            self.updateMotion(using: motion)
        }
    }

    private func updateMotion(using motion: CMDeviceMotion) {
        let rot = motion.rotationRate
        let acc = motion.userAcceleration

        let rotationMagnitude = sqrt(rot.x * rot.x + rot.y * rot.y + rot.z * rot.z)
        let accelerationMagnitude = sqrt(acc.x * acc.x + acc.y * acc.y + acc.z * acc.z)

        let rawMotion = rotationMagnitude + accelerationMagnitude
        smoothedMotion = 0.85 * smoothedMotion + 0.15 * rawMotion

        let low: Double = 0.08
        let high: Double = 0.70
        let normalized = max(0.0, min(1.0, (smoothedMotion - low) / (high - low)))

        currentSnapStrength = Float(1.0 - 0.75 * normalized)
    }
}

// MARK: - Frame updates
extension MagRayController {
    private func subscribeToFrameUpdates() {
        guard let arView else { return }

        updateSubscription = arView.scene.subscribe(to: SceneEvents.Update.self) { [weak self] _ in
            self?.updateFrame()
        }
    }

    private func updateFrame() {
        guard let arView else { return }

        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= updateInterval else { return }
        lastUpdateTime = now

        // Freeze candidate switching during confirmation lock.
        if isConfirmationLocked {
            return
        }

        let screenPoint = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)

        guard let ray = arView.ray(through: screenPoint) else {
            setCurrentCandidate(nil)
            return
        }

        let best = bestCandidate(
            rayOrigin: ray.origin,
            rayDirection: simd_normalize(ray.direction)
        )

        setCurrentCandidate(best)
    }

    private func bestCandidate(
        rayOrigin: SIMD3<Float>,
        rayDirection: SIMD3<Float>
    ) -> ModelEntity? {
        var bestEntity: ModelEntity?
        var bestScore: Float = -.greatestFiniteMagnitude

        for target in targets {
            let center = target.position(relativeTo: nil)
            let forwardDepth = simd_dot(center - rayOrigin, rayDirection)
            if forwardDepth <= 0 { continue }

            let rayDistance = shortestDistanceFromRayToPoint(
                rayOrigin: rayOrigin,
                rayDirection: rayDirection,
                point: center
            )

            switch selectionMode {
            case .baseline:
                if rayDistance > 0.02 { continue }

                let score = -rayDistance
                if score > bestScore {
                    bestScore = score
                    bestEntity = target
                }

            case .magray:
                if rayDistance > 0.16 { continue }

                let proximityScore = 1.0 / (rayDistance + 0.01)
                let depthBias = 1.0 / (forwardDepth + 0.25)
                let score = currentSnapStrength * proximityScore + 0.15 * depthBias

                if score > bestScore {
                    bestScore = score
                    bestEntity = target
                }
            }
        }

        if let bestEntity, selectionMode == .magray {
            history.add(entity: bestEntity, at: CACurrentMediaTime())
        }

        return bestEntity
    }

    private func setCurrentCandidate(_ entity: ModelEntity?) {
        if experiment?.phase == .runningTrial, currentCandidate !== entity {
            currentCandidateSwitchCount += 1
        }

        currentCandidate = entity
        refreshMaterials()
    }

    private func refreshMaterials() {
        for target in targets {
            if target === confirmedSelection {
                target.model?.materials = [selectedMaterial]
                target.scale = SIMD3<Float>(repeating: 1.15)
            } else if target === currentCandidate {
                target.model?.materials = [candidateMaterial]
                target.scale = SIMD3<Float>(repeating: 1.12)
            } else if target === intendedTarget {
                target.model?.materials = [targetMaterial]
                target.scale = SIMD3<Float>(repeating: 1.0)
            } else {
                target.model?.materials = [normalMaterial]
                target.scale = SIMD3<Float>(repeating: 1.0)
            }
        }
    }
}

// MARK: - Confirmation locking
extension MagRayController {
    private func addConfirmationGesture() {
        guard let arView else { return }

        let press = UILongPressGestureRecognizer(
            target: self,
            action: #selector(handleConfirmationPress(_:))
        )
        press.minimumPressDuration = 0.0
        press.allowableMovement = 20
        press.cancelsTouchesInView = false

        arView.addGestureRecognizer(press)
        confirmationPress = press
    }

    private func candidateForConfirmationLock() -> ModelEntity? {
        switch selectionMode {
        case .baseline:
            return currentCandidate
        case .magray:
            return history.mostStableCandidate(now: CACurrentMediaTime()) ?? currentCandidate
        }
    }

    @objc private func handleConfirmationPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            lockedCandidate = candidateForConfirmationLock()
            isConfirmationLocked = (lockedCandidate != nil)
            lockStartTime = CACurrentMediaTime()

            if let lockedCandidate {
                currentCandidate = lockedCandidate
                refreshMaterials()
                print("Locked candidate: \(lockedCandidate.name)")
            } else {
                print("No candidate to lock")
            }

        case .ended:
            guard isConfirmationLocked, let chosen = lockedCandidate else {
                clearConfirmationLock()
                return
            }

            finalizeSelection(chosen)
            clearConfirmationLock()

        case .cancelled, .failed:
            clearConfirmationLock()

        default:
            break
        }
    }

    private func clearConfirmationLock() {
        isConfirmationLocked = false
        lockedCandidate = nil
        lockStartTime = nil
    }
    
    private func finalizeSelection(_ chosen: ModelEntity) {
        let correct = (chosen === intendedTarget)

        // Non-experiment behavior stays the same
        if experiment?.phase != .runningTrial {
            if chosen === confirmedSelection {
                confirmedSelection = nil
                refreshMaterials()
                print("Unselected: \(chosen.name)")
                return
            }

            confirmedSelection = chosen
            refreshMaterials()
            print("Selected: \(chosen.name) in mode \(selectionMode.rawValue) | correct: \(correct)")
            return
        }

        // During experiment trials:
        // end the trial on the FIRST confirmed selection, whether right or wrong.
        confirmedSelection = chosen
        refreshMaterials()

        print("Selected: \(chosen.name) in mode \(selectionMode.rawValue) | correct: \(correct)")

        if let targetID = intendedTarget?.name {
            experiment?.recordSelection(
                selectedID: chosen.name,
                targetID: targetID,
                candidateSwitchCount: currentCandidateSwitchCount
            )
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self, let experiment = self.experiment else { return }
            guard experiment.phase != .finished else { return }
            experiment.startNextTrial()
        }
    }
}
