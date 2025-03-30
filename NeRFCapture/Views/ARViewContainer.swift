//
//  ARView.swift
//  NeRFCapture
//
//  Created by Jad Abou-Chakra on 13/7/2022.
//

import SwiftUI
import RealityKit
import ARKit

struct ARViewContainer: UIViewRepresentable {
    @ObservedObject var viewModel: ARViewModel
    
    init(_ vm: ARViewModel) {
        viewModel = vm
    }
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        let configuration = viewModel.createARConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        configuration.isLightEstimationEnabled = false
        configuration.providesAudioData = false
        if ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth) {
            viewModel.appState.supportsDepth = true
        }
        // arView.debugOptions = [.showWorldOrigin, .showStatistics]
        arView.debugOptions = [.showWorldOrigin]
        #if !targetEnvironment(simulator)
        arView.session.run(configuration)
        #endif
        arView.session.delegate = viewModel
        viewModel.session = arView.session
        viewModel.arView = arView

        let guideAnchors = viewModel.generateGuidePoints(radius: viewModel.guidePointDistance, count: viewModel.numberOfGuidePoints)
        for anchor in guideAnchors {
            arView.scene.addAnchor(anchor)
        }

        // 添加瞄準輔助圓圈
        let crosshairView = UIView(frame: CGRect(x: 0, y: 0, width: 50, height: 50))
        crosshairView.layer.cornerRadius = 25
        crosshairView.layer.borderWidth = 2
        crosshairView.layer.borderColor = UIColor.white.cgColor
        crosshairView.backgroundColor = UIColor.clear
        crosshairView.isUserInteractionEnabled = false
        arView.addSubview(crosshairView)

        // 延遲設置中心點，確保 ARView 的佈局已完成
        DispatchQueue.main.async {
            crosshairView.center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        }

        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}
