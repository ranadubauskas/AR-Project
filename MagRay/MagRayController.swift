import Foundation
import UIKit
import RealityKit
import ARKit
import CoreMotion
import QuartzCore
import Combine

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

    private var currentSnapStrength: Float = 1.0
    private var smoothedMotion: Double = 0.0

    private var lastUpdateTime: CFTimeInterval = 0
    private let updateInterval: CFTimeInterval = 1.0 / 30.0

    private let normalMaterial = SimpleMaterial(color: .systemBlue, isMetallic: false)
    private let candidateMaterial = SimpleMaterial(color: .systemRed, isMetallic: false)
    private let selectedMaterial = SimpleMaterial(color: .systemGreen, isMetallic: false)
    private let targetMaterial = SimpleMaterial(color: .systemYellow, isMetallic: false)
    
    private var rayAnchor: AnchorEntity?
    private var rayEntity: ModelEntity?

    private let rayLength: Float = 1.6
    private let rayRadius: Float = 0.0008

    private let baselineRayMaterial = UnlitMaterial(color: .white)
    private let magrayRayMaterial = UnlitMaterial(color: .black)
    private let confirmedRayMaterial = UnlitMaterial(color: .green)

    func setup(arView: ARView) {
        self.arView = arView
        setupSession()
        addTapGesture()
        startMotionUpdates()
        subscribeToFrameUpdates()
        

        // Give ARKit a moment to produce a valid frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.buildScene()
            self?.buildVisibleRay()
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
        rayAnchor?.removeFromParent()
        rayAnchor = nil
        rayEntity = nil
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

        // Clear old scene state
        rootAnchor?.removeFromParent()
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

        let forward = -SIMD3<Float>(
            cameraMatrix.columns.2.x,
            cameraMatrix.columns.2.y,
            cameraMatrix.columns.2.z
        )

        let right = SIMD3<Float>(
            cameraMatrix.columns.0.x,
            cameraMatrix.columns.0.y,
            cameraMatrix.columns.0.z
        )

        let up = SIMD3<Float>(
            cameraMatrix.columns.1.x,
            cameraMatrix.columns.1.y,
            cameraMatrix.columns.1.z
        )

        // Put the cluster about 60 cm in front of the user, fixed in world space
        let clusterCenter = cameraPosition + forward * 0.6

        let anchor = AnchorEntity(world: clusterCenter)
        rootAnchor = anchor

        let sphereMesh = MeshResource.generateSphere(radius: 0.03)

        // No sphere at exact center
        let offsets: [SIMD3<Float>] = [
            SIMD3<Float>( 0.05,  0.00,  0.00),
            SIMD3<Float>( 0.08,  0.02,  0.00),
            SIMD3<Float>( 0.07, -0.03,  0.00),
            SIMD3<Float>(-0.06,  0.03,  0.00), // intended target
            SIMD3<Float>(-0.08, -0.02,  0.00),
            SIMD3<Float>( 0.02,  0.07,  0.00),
            SIMD3<Float>(-0.03, -0.07,  0.00),
            
            // Outer spheres farther from the center cluster
            SIMD3<Float>( 0.16,  0.00,  0.00),
            SIMD3<Float>(-0.16,  0.00,  0.00),
            SIMD3<Float>( 0.00,  0.16,  0.00),
            SIMD3<Float>( 0.00, -0.16,  0.00),
            SIMD3<Float>( 0.13,  0.11,  0.00),
            SIMD3<Float>(-0.13,  0.11,  0.00),
            SIMD3<Float>( 0.13, -0.11,  0.00),
            SIMD3<Float>(-0.13, -0.11,  0.00)
        ]

        for (i, offset) in offsets.enumerated() {
            let entity = ModelEntity(mesh: sphereMesh, materials: [normalMaterial])
            entity.name = "target_\(i)"

            entity.position =
                right * offset.x +
                up * offset.y +
                forward * offset.z

            anchor.addChild(entity)
            targets.append(entity)
        }

        intendedTarget = targets[3]

        arView.scene.addAnchor(anchor)
        refreshMaterials()
    }
    private func buildVisibleRay() {
        guard let arView else { return }

        rayAnchor?.removeFromParent()

        let anchor = AnchorEntity(.camera)

        let rayMesh = MeshResource.generateCylinder(
            height: rayLength,
            radius: rayRadius
        )

        let ray = ModelEntity(mesh: rayMesh, materials: [baselineRayMaterial])

        ray.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3<Float>(1, 0, 0))

        // Start the ray much closer to the camera so it appears longer on screen.
        ray.position = SIMD3<Float>(0, -0.003, -0.025 - rayLength / 2)

        anchor.addChild(ray)
        arView.scene.addAnchor(anchor)

        rayAnchor = anchor
        rayEntity = ray

        print("buildVisibleRay: added ray")
        refreshRayAppearance()
    }
    
    private func refreshRayAppearance() {
        guard let rayEntity else { return }

        if confirmedSelection != nil {
            rayEntity.model?.materials = [confirmedRayMaterial]
        } else {
            switch selectionMode {
            case .baseline:
                rayEntity.model?.materials = [baselineRayMaterial]
            case .magray:
                rayEntity.model?.materials = [magrayRayMaterial]
            }
        }
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

        // Still => stronger snap, moving fast => weaker snap
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
                // Strict: only almost exact aim counts.
                if rayDistance > 0.02 { continue }

                let score = -rayDistance
                if score > bestScore {
                    bestScore = score
                    bestEntity = target
                }

            case .magray:
                // Forgiving: nearby targets can snap to the ray.
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

        refreshRayAppearance()
    }
}

// MARK: - Tap confirmation
extension MagRayController {
    private func addTapGesture() {
        guard let arView else { return }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        arView.addGestureRecognizer(tap)
    }

    @objc private func handleTap() {
        let chosen: ModelEntity?

        switch selectionMode {
        case .baseline:
            chosen = currentCandidate
        case .magray:
            chosen = history.mostStableCandidate(now: CACurrentMediaTime()) ?? currentCandidate
        }

        guard let chosen else {
            print("No candidate selected in mode \(selectionMode.rawValue)")
            return
        }

        // If you tap the already-confirmed target again, unselect it.
        if chosen === confirmedSelection {
            confirmedSelection = nil
            refreshMaterials()
            print("Unselected: \(chosen.name)")
            return
        }

        confirmedSelection = chosen
        refreshMaterials()

        let correct = (chosen === intendedTarget)
        print("Selected: \(chosen.name) in mode \(selectionMode.rawValue) | correct: \(correct)")
    }
}
