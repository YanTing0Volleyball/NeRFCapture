//
//  ARViewModel.swift
//  NeRFCapture
//
//  Created by Jad Abou-Chakra on 13/7/2022.
//

import Foundation
import Zip
import Combine
import ARKit
import RealityKit

enum AppError : Error {
    case projectAlreadyExists
    case manifestInitializationFailed
}

class ARViewModel : NSObject, ARSessionDelegate, ObservableObject {
    @Published var appState = AppState()
    var session: ARSession? = nil
    var arView: ARView? = nil
//    let frameSubject = PassthroughSubject<ARFrame, Never>()
    var cancellables = Set<AnyCancellable>()
    @Published var datasetWriter: DatasetWriter
    let ddsWriter: DDSWriter
    
    // Guide Points Setting
    @Published var isCapturing: Bool = false
    var numberOfGuidePoints = 50
    var guidePointDistance = Float(1.0)
    var numberOfGuidePointsCaptured = 0
    
    init(datasetWriter: DatasetWriter, ddsWriter: DDSWriter) {
        self.datasetWriter = datasetWriter
        self.ddsWriter = ddsWriter
        super.init()
        self.setupObservers()
        self.ddsWriter.setupDDS()
    }
    
    func setupObservers() {
        datasetWriter.$writerState.sink {x in self.appState.writerState = x} .store(in: &cancellables)
        datasetWriter.$currentFrameCounter.sink { x in self.appState.numFrames = x }.store(in: &cancellables)
        ddsWriter.$peers.sink {x in self.appState.ddsPeers = UInt32(x)}.store(in: &cancellables)
        
        $appState
            .map(\.appMode)
            .prepend(appState.appMode)
            .removeDuplicates()
            .sink { x in
                switch x {
                case .Offline:
//                    self.appState.stream = false
                    print("Changed to offline")
                case .Online:
                    print("Changed to online")
                }
            }
            .store(in: &cancellables)
    }
    
    
    func createARConfiguration() -> ARWorldTrackingConfiguration {
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.isAutoFocusEnabled = true
        configuration.isLightEstimationEnabled = false
        configuration.providesAudioData = false
        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            // Activate sceneDepth
            configuration.frameSemantics = .sceneDepth
        }
        return configuration
    }
    
    func resetWorldOrigin() {
        session?.pause()
        let config = createARConfiguration()
        session?.run(config, options: [.resetTracking])

        resetGuidePoints()
    }
    
    func generateGuidePoints(radius: Float, count: Int) -> [AnchorEntity] {
        numberOfGuidePointsCaptured = 0
        var anchors: [AnchorEntity] = []
        let phi = Float((1.0 + sqrt(5.0)) / 2.0) // Golden ratio

        for i in 0..<count {
            let y = 1.0 - (Float(i) / Float(count - 1)) * 2.0 // y ranges from 1 to -1
            let radiusAtY = sqrt(1.0 - y * y) // Radius at y
            let theta = 2.0 * Float.pi * Float(i) / phi
            let x = cos(theta) * radiusAtY
            let z = sin(theta) * radiusAtY

            let position = SIMD3<Float>(x * radius, y * radius, z * radius)
            var sphereMaterial = SimpleMaterial(color: .red, isMetallic: false)
            sphereMaterial.tintColor = UIColor.init(red: 1.0, green: 0.0, blue: 1.0, alpha: 0.9)
            sphereMaterial.baseColor = MaterialColorParameter.color(.purple)
            let sphere = ModelEntity(mesh: .generateSphere(radius: 0.05), materials: [sphereMaterial])
            sphere.position = position
            sphere.name = "guidePoint"

            let anchor = AnchorEntity(world: position)
            anchor.addChild(sphere)
            anchors.append(anchor)
        }

        return anchors
    }

    func resetGuidePoints() {
        guard let arView = self.arView else { return }

        // 移除現有的引導點
        for anchor in arView.scene.anchors {
            for entity in anchor.children where entity.name == "guidePoint" {
                entity.removeFromParent()
            }
        }

        // 重新生成引導點
        let guideAnchors = self.generateGuidePoints(radius: guidePointDistance, count: numberOfGuidePoints)
        for anchor in guideAnchors {
            arView.scene.addAnchor(anchor)
        }
    }
    
    func session(
        _ session: ARSession,
        didUpdate frame: ARFrame
    ) {
        //frameSubject.send(frame)

        guard let arView = self.arView else {return}
        if !isCapturing {return}

        // 獲取相機的當前畫面中心點
        let screenCenter = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let threshold: CGFloat = 10.0 // 判斷是否對齊的距離閾值

        // 遍歷場景中的所有引導點
        for anchor in arView.scene.anchors {
            for entity in anchor.children where entity.name == "guidePoint" {
                if let modelEntity = entity as? ModelEntity {
                    // 將引導點的 3D 世界座標投影到螢幕座標
                    if let projectedPoint = arView.project(modelEntity.position(relativeTo: nil)) {
                        // 計算投影點與螢幕中心的距離
                        let distance = hypot(projectedPoint.x - screenCenter.x, projectedPoint.y - screenCenter.y)
                        
                        // 如果距離小於閾值，隱藏引導點
                        if distance < threshold {
                            numberOfGuidePointsCaptured += 1
                            modelEntity.removeFromParent()
                        }
                    }
                }
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        self.appState.trackingState = trackingStateToString(camera.trackingState)
    }
}
