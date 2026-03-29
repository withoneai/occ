import Foundation

enum PillPosition: String, CaseIterable {
    case bottomLeft
    case bottomRight
    case bottomCenter

    private static let key = "occ.pill.position"

    static var current: PillPosition {
        get {
            guard let raw = UserDefaults.standard.string(forKey: key),
                  let pos = PillPosition(rawValue: raw) else {
                return .bottomRight
            }
            return pos
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: key)
        }
    }

    var label: String {
        switch self {
        case .bottomLeft: return "Left"
        case .bottomRight: return "Right"
        case .bottomCenter: return "Center"
        }
    }
}
