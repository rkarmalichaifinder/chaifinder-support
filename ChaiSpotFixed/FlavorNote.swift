import SwiftUI

// MARK: - Flavor Note Structure
struct FlavorNote: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let color: Color
    let symbol: String
    
    static func == (lhs: FlavorNote, rhs: FlavorNote) -> Bool {
        return lhs.name == rhs.name
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
} 