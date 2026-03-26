import Foundation

enum SelectionMode: String, CaseIterable, Identifiable, Codable {
    case baseline = "Baseline"
    case magray = "MagRay"

    var id: String { rawValue }
}
