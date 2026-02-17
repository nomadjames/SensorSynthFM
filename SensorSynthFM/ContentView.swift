// ContentView.swift
// SensorSynth FM — root navigation between the three main screens

import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // Screen content
            Group {
                switch selectedTab {
                case 0:  PerformanceView()
                case 1:  FMEngineView()
                default: SensorModulationView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Custom tab bar pinned to bottom
            HStack(spacing: 0) {
                SynthTabButton(icon: "pianokeys.inverse",        label: "PERFORM",  tag: 0, selected: $selectedTab)
                SynthTabButton(icon: "waveform.circle",          label: "FM ENGINE", tag: 1, selected: $selectedTab)
                SynthTabButton(icon: "sensor.tag.radiowaves.forward.fill", label: "SENSORS",  tag: 2, selected: $selectedTab)
            }
            .background(SynthColors.surface)
            .overlay(alignment: .top) {
                SynthColors.divider.frame(height: 1)
            }
        }
        .background(SynthColors.background)
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
    }
}

struct SynthTabButton: View {
    let icon: String
    let label: String
    let tag: Int
    @Binding var selected: Int

    var isSelected: Bool { selected == tag }

    var body: some View {
        Button { selected = tag } label: {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                Text(label)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .foregroundColor(isSelected ? SynthColors.accent : SynthColors.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
    }
}

#Preview(traits: .landscapeLeft) {
    ContentView()
}
