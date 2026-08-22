import SwiftUI
import RealityKit

struct ARViewContainer: UIViewRepresentable {
    let controller: ARSessionController

    func makeUIView(context: Context) -> ARView {
        controller.makeARView()
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

