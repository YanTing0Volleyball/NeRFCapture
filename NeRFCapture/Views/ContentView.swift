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
    @StateObject private var viewModel: ARViewModel

    @State var isPause = false
    @State var framesPerSec = 1.0
    @State private var timer: Publishers.Autoconnect<Timer.TimerPublisher>?

    init(viewModel vm: ARViewModel) {
        _viewModel = StateObject(wrappedValue: vm)
        _timer = State(initialValue: Timer.publish(every: 1, on: .main, in: .common).autoconnect())
    }
    
    var body: some View {
        ZStack{
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
                }
            }
            VStack {
                Spacer()
                HStack(spacing: 20) {
                    if viewModel.appState.writerState == .SessionNotStarted {
                        Spacer()

                        Button(action: {
                            viewModel.resetWorldOrigin()
                        }) {
                            Text("Reset")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)

                        Button(action: {
                            isPause = false
                            do {
                                try viewModel.datasetWriter.initializeProject()
                            }
                            catch {
                                print("\(error)")
                            }
                        }) {
                            Text("Start")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    } else {
                        Spacer()
                        Button(action: {
                            viewModel.datasetWriter.finalizeProject()
                        }) {
                            Text("End")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)

                        Button(action: { isPause.toggle() }) {
                            Text(isPause ? "Resume" : "Pause")
                                .padding(.horizontal, 20)
                                .padding(.vertical, 5)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                    }
                }
                .padding()
            }
            .preferredColorScheme(.dark)
        }
    }
}

#if DEBUG
struct ContentView_Previews : PreviewProvider {
    static var previews: some View {
        ContentView(viewModel: ARViewModel(datasetWriter: DatasetWriter(), ddsWriter: DDSWriter()))
            .previewInterfaceOrientation(.portrait)
    }
}
#endif
