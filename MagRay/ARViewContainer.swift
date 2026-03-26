import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @Binding var selectionMode: SelectionMode

    func makeCoordinator() -> MagRayController {
        let controller = MagRayController()
        controller.selectionMode = selectionMode
        return controller
    }

    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        context.coordinator.setup(arView: arView)
        return arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {
        context.coordinator.selectionMode = selectionMode
    }

    static func dismantleUIView(_ uiView: ARView, coordinator: MagRayController) {
        coordinator.teardown()
    }
}
