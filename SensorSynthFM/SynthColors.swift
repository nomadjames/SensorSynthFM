// SynthColors.swift
// SensorSynth FM — shared color palette used across all views

import SwiftUI

struct SynthColors {
    // Backgrounds
    static let background     = Color(red: 0.10, green: 0.10, blue: 0.10) // #1A1A1A
    static let surface        = Color(red: 0.16, green: 0.16, blue: 0.16) // slightly lifted surface
    static let surfaceRaised  = Color(red: 0.22, green: 0.22, blue: 0.22) // raised elements

    // Accents
    static let accent         = Color(red: 0.91, green: 0.57, blue: 0.23) // #E8913A warm orange
    static let accentBlue     = Color(red: 0.18, green: 0.42, blue: 0.62) // #2E6B9E blue
    static let sensorGreen    = Color(red: 0.18, green: 0.55, blue: 0.31) // #2D8B4E sensor active

    // Text
    static let textPrimary    = Color(red: 0.88, green: 0.88, blue: 0.88)
    static let textSecondary  = Color(red: 0.50, green: 0.50, blue: 0.50)

    // Structural
    static let divider        = Color(red: 0.26, green: 0.26, blue: 0.26)
}
