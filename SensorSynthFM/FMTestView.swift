// FMTestView.swift
// SensorSynthFM
//
// Test screen for the AudioKit FM oscillator. Provides sliders for all four
// FM parameters (carrier frequency, modulator ratio, modulation index,
// amplitude) and a play/stop button. Parameters update in real time while
// the oscillator is sounding.
//
// This replaces SineTestView.swift as the active test screen for Session 2.
// Design follows design_guidelines.md: dark background, monospaced numerics,
// orange/blue accents, landscape orientation.

import SwiftUI

struct FMTestView: View {
    @State private var engine = FMEngine()

    var body: some View {
        HStack(spacing: 0) {

            // MARK: - Left panel: status + play/stop
            VStack(spacing: 28) {
                Spacer()

                Text("FM OSCILLATOR")
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.accent)

                // Status indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(engine.isPlaying ? SynthColors.sensorGreen : SynthColors.surfaceRaised)
                        .frame(width: 10, height: 10)
                    Text(engine.isPlaying ? "PLAYING" : "STOPPED")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(engine.isPlaying ? SynthColors.sensorGreen : SynthColors.textSecondary)
                }

                // Play / Stop button
                Button {
                    if engine.isPlaying {
                        engine.noteOff()
                    } else {
                        engine.noteOn()
                    }
                } label: {
                    Text(engine.isPlaying ? "STOP" : "PLAY")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.background)
                        .frame(width: 160, height: 64)
                        .background(engine.isPlaying ? Color.red.opacity(0.8) : SynthColors.accent)
                        .cornerRadius(12)
                }

                // Engine status
                Text(engine.isRunning ? "ENGINE RUNNING" : "ENGINE STOPPED")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(SynthColors.surface)

            SynthColors.divider.frame(width: 1)

            // MARK: - Right panel: FM parameter sliders
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("FM PARAMETERS")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)

                SynthColors.divider.frame(height: 1)

                ScrollView {
                    VStack(spacing: 24) {

                        // Carrier Frequency
                        FMParameterSlider(
                            label: "CARRIER FREQ",
                            value: $engine.carrierFrequency,
                            range: 20...2000,
                            step: 1,
                            displayValue: "\(Int(engine.carrierFrequency)) Hz",
                            color: SynthColors.accent,
                            description: "Base pitch of the carrier oscillator"
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Modulator Ratio
                        FMParameterSlider(
                            label: "MOD RATIO",
                            value: $engine.modulatorRatio,
                            range: 0.1...20.0,
                            step: 0.1,
                            displayValue: String(format: "%.1f:1", engine.modulatorRatio),
                            color: SynthColors.accentBlue,
                            description: "Modulator frequency as ratio to carrier"
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Modulation Index
                        FMParameterSlider(
                            label: "MOD INDEX",
                            value: $engine.modulationIndex,
                            range: 0...10,
                            step: 0.1,
                            displayValue: String(format: "%.1f", engine.modulationIndex),
                            color: SynthColors.accent,
                            description: "FM depth — higher = more harmonics"
                        )

                        SynthColors.divider.opacity(0.4).frame(height: 0.5)

                        // Amplitude
                        FMParameterSlider(
                            label: "AMPLITUDE",
                            value: $engine.amplitude,
                            range: 0...1,
                            step: 0.01,
                            displayValue: String(format: "%d%%", Int(engine.amplitude * 100)),
                            color: SynthColors.sensorGreen,
                            description: "Output volume"
                        )
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .frame(maxWidth: .infinity)
        }
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

// MARK: - FM Parameter Slider Component

/// A labeled slider with monospaced value readout, styled to match the
/// SensorSynth FM design language. Reusable across test views and
/// eventually the full FM engine editor.
struct FMParameterSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let displayValue: String
    var color: Color = SynthColors.accent
    var description: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Label row: parameter name + current value
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)

                Spacer()

                Text(displayValue)
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(SynthColors.textPrimary)
            }

            // Slider
            Slider(value: $value, in: range, step: step)
                .tint(color)

            // Description text
            if !description.isEmpty {
                Text(description)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary.opacity(0.7))
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    FMTestView()
}
