import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var selectionMode: SelectionMode
    @ObservedObject var experiment: ExperimentManager

    func makeCoordinator() -> MagRayController {
        let controller = MagRayController()
        controller.selectionMode = selectionMode
        controller.experiment = experiment
        return controller
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.setup(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.selectionMode = experiment.activeTrial?.mode ?? selectionMode
        context.coordinator.experiment = experiment
        context.coordinator.syncExperimentState()
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: MagRayController) {
        coordinator.teardown()
    }
}
