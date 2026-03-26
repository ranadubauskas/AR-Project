import Foundation

enum SelectionMode: String, CaseIterable, Identifiable {
    case baseline = "Baseline"
    case magray = "MagRay"

    var id: String { rawValue }
}
