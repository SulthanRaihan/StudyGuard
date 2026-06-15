//
//  Theme.swift
//  StudyGuard
//
//  "Guri Warm" design system — orange primary, navy text, cream background.
//

import SwiftUI

enum Theme {
    static let orange = Color(red: 0.96, green: 0.51, blue: 0.13)   // #F58220
    static let navy   = Color(red: 0.086, green: 0.161, blue: 0.290) // #16294A
    static let cream  = Color(red: 0.984, green: 0.957, blue: 0.914) // #FBF4E9
    static let green  = Color(red: 0.36, green: 0.55, blue: 0.24)    // #5C8C3D
    static let card   = Color.white

    static var muted: Color { navy.opacity(0.55) }

    /// Score color ramp used by gauges and stats.
    static func score(_ value: Double) -> Color {
        switch value {
        case 80...: return green
        case 50..<80: return orange
        default: return Color(red: 0.85, green: 0.3, blue: 0.2)
        }
    }
}

extension Color {
    static let sgOrange = Theme.orange
    static let sgNavy = Theme.navy
    static let sgCream = Theme.cream
}
