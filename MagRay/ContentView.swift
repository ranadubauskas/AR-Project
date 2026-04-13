import SwiftUI

struct ContentView: View {
    @State private var selectionMode: SelectionMode = .magray
    @StateObject private var experiment = ExperimentManager()

    var effectiveMode: SelectionMode {
        experiment.activeTrial?.mode ?? selectionMode
    }

    private var showInitialStartButton: Bool {
        experiment.completedCount == 0 &&
        (experiment.phase == .idle || experiment.phase == .readyForTrial)
    }

    private var showRestartButton: Bool {
        experiment.phase == .finished
    }

    private var showTopControls: Bool {
        !showInitialStartButton
    }

    private var showSaveButton: Bool {
        experiment.completedCount > 0
    }

    var body: some View {
        ZStack {
            ARViewContainer(
                selectionMode: $selectionMode,
                experiment: experiment
            )
            .ignoresSafeArea()

            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 26, height: 26)
                .allowsHitTesting(false)

            if showTopControls {
                VStack(spacing: 6) {
                    Picker("Selection Mode", selection: $selectionMode) {
                        ForEach(SelectionMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 12)
                    .disabled(experiment.phase == .runningTrial)

                    HStack(spacing: 8) {
                        Text(experiment.currentTrialLabel)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.42))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .allowsHitTesting(false)

                        Spacer()

                        TimelineView(.periodic(from: .now, by: 0.05)) { _ in
                            if let elapsed = experiment.currentElapsedMs() {
                                Text("\(elapsed / 1000.0, specifier: "%.2f") s")
                                    .font(.caption)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(.black.opacity(0.42))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                                    .allowsHitTesting(false)
                            }
                        }

                        Text("\(experiment.completedCount)/\(experiment.totalCount)")
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.42))
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .allowsHitTesting(false)
                    }
                    .padding(.horizontal, 12)

                    Spacer()

                    Text("Yellow = intended • Red = current • Green = confirmed")
                        .font(.caption2)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.42))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(.bottom, 14)
                        .allowsHitTesting(false)
                }
                .padding(.top, 2)
            }

            if showInitialStartButton {
                Button {
                    experiment.startNextTrial()
                } label: {
                    Text("Start Experiment")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.92))
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }

            if showRestartButton {
                Button {
                    experiment.prepareDefaultQueue()
                } label: {
                    Text("Restart Experiment")
                        .font(.title3.weight(.semibold))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 18)
                        .background(.white.opacity(0.92))
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
            }

            if showSaveButton {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()

                        Button("Save Results") {
                            do {
                                let url = try experiment.saveResults()
                                print("Saved results to: \(url)")
                            } catch {
                                print("Failed to save results: \(error)")
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.9))
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                    }
                    .padding(.trailing, 14)
                    .padding(.bottom, 58)
                }
            }
        }
        .onAppear {
            experiment.prepareDefaultQueue()
        }
    }
}
