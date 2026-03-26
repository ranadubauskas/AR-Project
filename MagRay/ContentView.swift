import SwiftUI

struct ContentView: View {
    @State private var selectionMode: SelectionMode = .magray

    var body: some View {
        ZStack {
            ARViewContainer(selectionMode: $selectionMode)
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

                Text("Mode: \(selectionMode.rawValue)")
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())

                Spacer()

                Text("Red = current candidate   Green = confirmed")
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
    }
}
