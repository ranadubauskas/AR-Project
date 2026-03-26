import SwiftUI

struct ContentView: View {
    @State private var selectionMode: SelectionMode = .magray
    @StateObject private var experiment = ExperimentManager()

    var effectiveMode: SelectionMode {
        experiment.activeTrial?.mode ?? selectionMode
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

            VStack(spacing: 12) {
                Picker("Selection Mode", selection: $selectionMode) {
                    ForEach(SelectionMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .disabled(experiment.phase == .runningTrial)

                Text("Mode: \(effectiveMode.rawValue)")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                Text(experiment.currentTrialLabel)
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                if let latest = experiment.latestResult {
                    VStack(spacing: 4) {
                        Text("Last Trial")
                            .font(.caption.bold())

                        Text("Correct: \(latest.correct ? "Yes" : "No")")
                        Text("Time: \(latest.selectionTimeMs, specifier: "%.1f") ms")
                        Text("Switches: \(latest.candidateSwitchCount)")
                        Text("Mode: \(latest.mode.rawValue) • \(latest.density.rawValue)")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Completed: \(experiment.completedCount)/\(experiment.totalCount)")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                HStack(spacing: 12) {
                    Button(action: handleTrialButton) {
                        Text(buttonTitle)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.85))
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    .disabled(experiment.phase == .runningTrial || (experiment.phase == .readyForTrial && experiment.completedCount > 0))

                    Button("Save Results") {
                        do {
                            let url = try experiment.saveResults()
                            print("Saved results to: \(url)")
                        } catch {
                            print("Failed to save results: \(error)")
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(.white.opacity(0.85))
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
                }

                Spacer()

                Text("Yellow = intended • Red = current • Green = confirmed")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .padding(.bottom, 24)
            }
            .padding(.top, 60)
        }
        .onAppear {
            experiment.prepareDefaultQueue()
        }
    }

    private var buttonTitle: String {
        switch experiment.phase {
        case .idle:
            return "Prepare Trials"
        case .readyForTrial:
            return experiment.completedCount == 0 ? "Start Experiment" : "Running Automatically"
        case .runningTrial:
            return "Trial Running"
        case .finished:
            return "Restart Experiment"
        }
    }

    private func handleTrialButton() {
        switch experiment.phase {
        case .idle:
            experiment.prepareDefaultQueue()
        case .readyForTrial:
            if experiment.completedCount == 0 {
                experiment.startNextTrial()
            }
        case .runningTrial:
            break
        case .finished:
            experiment.prepareDefaultQueue()
            experiment.startNextTrial()
        }
    }
}
