//
//  ContentView.swift
//  NeRFCapture
//
//  Created by Jad Abou-Chakra on 13/7/2022.
//

import SwiftUI
import ARKit
import RealityKit
import Combine


struct ContentView : View {
    @EnvironmentObject private var viewModel: ARViewModel

    @State var isPause = false
    @State var framesPerSec = 1.0
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>?
    @State private var zipping = false
    @State private var showAlert = false

    init() {
        _timer = State(initialValue: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            ARViewContainer(viewModel)
                .edgesIgnoringSafeArea(.vertical)

            VStack() {
                HStack() {
                    Stepper("Record \(framesPerSec, specifier: "%.1f") frames/sec", value: $framesPerSec, in: 0...60, step: 0.5) { editing in
                        if !editing {
                            timer?.upstream.connect().cancel()
                            timer = Timer.publish(every: TimeInterval(1.0 / framesPerSec),
                                                  on: .main,
                                                  in: .common).autoconnect()
                        }
                    }
                    .fixedSize()
                    .onReceive(timer ?? Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in
                        if viewModel.appState.writerState == .SessionStarted && !isPause {
                            if let frame = viewModel.session?.currentFrame {
                                viewModel.datasetWriter.writeFrameToDisk(frame: frame)
                            }
                        }
                    }
                    .onDisappear { timer?.upstream.connect().cancel() }
                    .padding(7)
                    .background(.black.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 10))
                    
                    Spacer()

                    VStack(alignment:.leading){
                        Text("\(viewModel.numberOfGuidePointsCaptured)/\(viewModel.numberOfGuidePoints) Points Left")
                    }
                    .padding(7)
                    .background(.black.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 10))

                    Spacer()

                    VStack(alignment:.leading) {
                        Text("\(viewModel.appState.trackingState)")
                        if case .Offline = viewModel.appState.appMode {
                            if case .SessionStarted = viewModel.appState.writerState {
                                Text("\(viewModel.datasetWriter.currentFrameCounter) Frames")
                            }
                        }
                    }
                    .padding(7)
                    .background(.black.opacity(0.4))
                    .clipShape(.rect(cornerRadius: 10))
                }
                .padding()

                Spacer()
                VStack {
                    Spacer()
                    HStack(spacing: 20) {
                        if viewModel.appState.writerState == .SessionNotStarted {
                            Spacer()

                            Button {
                                viewModel.resetWorldOrigin()
                            } label: {
                                Text("Reset")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 10))

                            Button {
                                isPause = false
                                do {
                                    try viewModel.datasetWriter.initializeProject()
                                    viewModel.isCapturing = true
                                }
                                catch {
                                    print("\(error)")
                                }
                            } label: {
                                Text("Start")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                        } else {
                            Spacer()
                            Button {
                                zipping = true
                                viewModel.isCapturing = false
                                viewModel.datasetWriter.finalizeProject {
                                    self.zipping = false
                                    self.showAlert = true
                                }
                                viewModel.resetGuidePoints()
                            } label: {
                                Text("End")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.roundedRectangle(radius: 10))

                            Button {
                                isPause.toggle()
                                viewModel.isCapturing.toggle()
                            } label: {
                                Text(isPause ? "Resume" : "Pause")
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .buttonBorderShape(.roundedRectangle(radius: 10))
                        }
                    }
                    .padding()
                }
                .preferredColorScheme(.dark)
            }
            .overlay(alignment: .center) {
                if zipping {
                    ProgressView("Compressing & Saving")
                        .padding()
                        .background(.black.opacity(0.4))
                        .clipShape(.rect(cornerRadius: 10))
                }
            }
        }
        .alert("Saved Successfully!", isPresented: $showAlert) {
            Button("OK") { showAlert.toggle() }
        } message: {
            Text("Data has been compressed and saved.\nYou may now safely close the app.")
        }

    }
}
