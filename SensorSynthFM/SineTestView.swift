// SineTestView.swift
// SensorSynthFM
//
// Temporary test screen to verify AudioKit is working.
// Shows a play/stop button, frequency slider, and volume slider.
// Delete this file once the FM engine is wired up.

import SwiftUI

struct SineTestView: View {
    @State private var engine = SynthEngine()

    var body: some View {
        VStack(spacing: 40) {

            Text("AudioKit Test")
                .font(.system(.title, design: .monospaced))
                .foregroundColor(SynthColors.textPrimary)

            // Status
            Text(engine.isPlaying ? "PLAYING" : "STOPPED")
                .font(.system(.headline, design: .monospaced))
                .foregroundColor(engine.isPlaying ? SynthColors.sensorGreen : SynthColors.textSecondary)

            // Play / Stop button
            Button {
                if engine.isPlaying {
                    engine.noteOff()
                } else {
                    engine.noteOn()
                }
            } label: {
                Text(engine.isPlaying ? "STOP" : "PLAY")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                    .foregroundColor(SynthColors.background)
                    .frame(width: 200, height: 80)
                    .background(engine.isPlaying ? Color.red.opacity(0.8) : SynthColors.accent)
                    .cornerRadius(16)
            }

            // Frequency slider
            VStack(spacing: 8) {
                Text("FREQUENCY: \(Int(engine.frequency)) Hz")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                Slider(value: $engine.frequency, in: 60...2000, step: 1)
                    .tint(SynthColors.accent)
                    .frame(width: 400)
            }

            // Volume slider
            VStack(spacing: 8) {
                Text("VOLUME: \(Int(engine.amplitude * 100))%")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                Slider(value: $engine.amplitude, in: 0...1, step: 0.01)
                    .tint(SynthColors.accentBlue)
                    .frame(width: 400)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SynthColors.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .onAppear {
            engine.start()
        }
        .onDisappear {
            engine.stop()
        }
    }
}

#Preview(traits: .landscapeLeft) {
    SineTestView()
}
