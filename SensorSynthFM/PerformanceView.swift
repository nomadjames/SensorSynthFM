// PerformanceView.swift
// SensorSynth FM — main performance screen
// Layout: transport strip | XY surface (60%) + sequencer (40%) | macro strip

import SwiftUI

// MARK: - Performance View

struct PerformanceView: View {
    @State private var isPlaying   = false
    @State private var selectedTrack = 0
    @State private var currentStep   = 4

    // 4 tracks x 16 steps
    @State private var steps: [[Bool]] = [
        [true,  false, false, false, true,  false, false, false, true,  false, false, false, true,  false, false, false],
        [false, false, true,  false, false, false, true,  false, false, false, true,  false, false, false, true,  false],
        [true,  false, true,  false, false, true,  false, false, true,  false, false, false, false, true,  false, false],
        [false, false, false, true,  false, false, false, false, true,  false, false, true,  false, false, false, false],
    ]

    // Sensor activity: label, level 0-1, color
    let sensors: [(String, Double, Color)] = [
        ("ACC", 0.28, SynthColors.sensorGreen),
        ("GYR", 0.08, SynthColors.sensorGreen),
        ("CAM", 0.61, SynthColors.accentBlue),
        ("MIC", 0.82, SynthColors.accent),
    ]

    // Macro controls
    let macroLabels = ["CUTOFF", "RESO", "MOD", "FDBK", "REVERB", "SENS"]
    @State private var macroValues: [Double] = [0.62, 0.28, 0.55, 0.18, 0.40, 0.70]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                transportStrip
                    .frame(height: 48)

                dividerLine

                HStack(spacing: 0) {
                    xyPerformanceSurface
                        .frame(width: geo.size.width * 0.60)

                    dividerVertical

                    sequencerPanel
                        .frame(maxWidth: .infinity)
                }
                .frame(maxHeight: .infinity)

                dividerLine

                macroStrip
                    .frame(height: 84)
            }
            .background(SynthColors.background)
        }
        .background(SynthColors.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Transport Strip

    var transportStrip: some View {
        HStack(spacing: 14) {
            // Play/Stop
            Button { isPlaying.toggle() } label: {
                Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 17))
                    .foregroundColor(isPlaying ? SynthColors.accent : SynthColors.textPrimary)
                    .frame(width: 38, height: 38)
                    .background(SynthColors.surfaceRaised)
                    .cornerRadius(5)
            }

            // BPM
            labeledValue(top: "BPM", bottom: "124")

            dividerVertical.frame(width: 1, height: 28)

            // Patch name
            VStack(alignment: .leading, spacing: 1) {
                Text("PATCH").font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                Text("Passive Field 01").font(.system(size: 14, weight: .medium)).foregroundColor(SynthColors.textPrimary)
            }

            Spacer()

            // Sensor activity bars
            HStack(spacing: 10) {
                ForEach(sensors, id: \.0) { label, level, color in
                    VStack(spacing: 3) {
                        // Activity bar
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2).fill(SynthColors.surfaceRaised).frame(width: 18, height: 20)
                            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 18, height: max(3, 20 * level))
                        }
                        Text(label).font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                    }
                }
            }
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 14)
        .background(SynthColors.surface)
    }

    // MARK: - XY Performance Surface

    var xyPerformanceSurface: some View {
        GeometryReader { geo in
            ZStack {
                SynthColors.background

                // Grid lines drawn via Canvas
                Canvas { ctx, size in
                    // Horizontal pitch lines — 24 semitones
                    for i in 0...24 {
                        let y = size.height * CGFloat(i) / 24
                        let isOctave = i % 12 == 0
                        var p = Path(); p.move(to: .init(x: 0, y: y)); p.addLine(to: .init(x: size.width, y: y))
                        ctx.stroke(p, with: .color(SynthColors.divider.opacity(isOctave ? 0.7 : 0.25)), lineWidth: isOctave ? 0.8 : 0.4)
                    }
                    // Vertical time lines — 16 subdivisions
                    for i in 0...16 {
                        let x = size.width * CGFloat(i) / 16
                        var p = Path(); p.move(to: .init(x: x, y: 0)); p.addLine(to: .init(x: x, y: size.height))
                        ctx.stroke(p, with: .color(SynthColors.divider.opacity(0.3)), lineWidth: 0.4)
                    }
                }

                // Axis labels
                VStack {
                    HStack {
                        Text("PITCH ↑").font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary.opacity(0.5))
                            .rotationEffect(.degrees(-90)).fixedSize()
                        Spacer()
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("TIME →").font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary.opacity(0.5))
                    }
                }
                .padding(10)

                // Mock MPE touch points — 3 independent voices
                let touches: [(CGFloat, CGFloat, CGFloat, Color, String)] = [
                    (0.22, 0.38, 0.75, SynthColors.accent,      "1"),
                    (0.50, 0.62, 0.42, SynthColors.accentBlue,  "2"),
                    (0.74, 0.28, 0.90, SynthColors.sensorGreen, "3"),
                ]
                ForEach(touches.indices, id: \.self) { i in
                    let t = touches[i]
                    ZStack {
                        Circle().stroke(t.3.opacity(0.25), lineWidth: 1).frame(width: 56 * t.2, height: 56 * t.2)
                        Circle().fill(t.3.opacity(0.85)).frame(width: 11, height: 11)
                        Text(t.4).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundColor(.white)
                    }
                    .position(x: geo.size.width * t.0, y: geo.size.height * t.1)
                }

                // MPE badge
                VStack {
                    HStack {
                        Spacer()
                        Text("MPE")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(SynthColors.accent)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(SynthColors.accent.opacity(0.12))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(10)
            }
        }
    }

    // MARK: - Sequencer Panel

    var sequencerPanel: some View {
        VStack(spacing: 0) {
            // Track selector
            HStack(spacing: 3) {
                ForEach(0..<4) { t in
                    Button { selectedTrack = t } label: {
                        Text("T\(t + 1)")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(selectedTrack == t ? SynthColors.background : SynthColors.textSecondary)
                            .frame(maxWidth: .infinity).frame(height: 30)
                            .background(selectedTrack == t ? SynthColors.accent : SynthColors.surfaceRaised)
                            .cornerRadius(4)
                    }
                }
            }
            .padding(8)

            dividerLine

            // Step grid — all 4 tracks visible
            VStack(spacing: 5) {
                // Step numbers
                HStack(spacing: 2) {
                    ForEach(0..<16) { s in
                        Text("\(s + 1)").font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 8)

                ForEach(0..<4) { t in
                    HStack(spacing: 2) {
                        ForEach(0..<16) { s in
                            StepCell(
                                active: steps[t][s],
                                playing: t == selectedTrack && s == currentStep,
                                highlighted: t == selectedTrack
                            ) { steps[t][s].toggle() }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.vertical, 8)

            dividerLine

            // Parameter locks row
            VStack(alignment: .leading, spacing: 5) {
                Text("PARAM LOCKS").font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                HStack(spacing: 4) {
                    ForEach(["NOTE", "VEL", "MOD", "FILT"], id: \.self) { p in
                        Text(p).font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(SynthColors.surfaceRaised).cornerRadius(3)
                    }
                    Spacer()
                }
            }
            .padding(8)

            Spacer()
        }
    }

    // MARK: - Macro Strip

    var macroStrip: some View {
        HStack(spacing: 0) {
            ForEach(macroValues.indices, id: \.self) { i in
                VStack(spacing: 3) {
                    Text(macroLabels[i]).font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)

                    ZStack {
                        Circle().stroke(SynthColors.surfaceRaised, lineWidth: 4).frame(width: 38, height: 38)
                        Circle()
                            .trim(from: 0.1, to: 0.1 + 0.8 * macroValues[i])
                            .stroke(i == 5 ? SynthColors.sensorGreen : SynthColors.accent,
                                    style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .frame(width: 38, height: 38)
                            .rotationEffect(.degrees(-90))
                        Text(String(format: "%d", Int(macroValues[i] * 127)))
                            .font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)

                if i < macroValues.count - 1 { dividerVertical }
            }

            dividerVertical

            // Randomize
            Button {} label: {
                VStack(spacing: 3) {
                    Image(systemName: "dice").font(.system(size: 18)).foregroundColor(SynthColors.accent)
                    Text("RND").font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                }
                .frame(width: 60)
            }
        }
        .padding(.horizontal, 8)
        .background(SynthColors.surface)
    }

    // MARK: - Helpers

    func labeledValue(top: String, bottom: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(top).font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
            Text(bottom).font(.system(size: 16, weight: .medium, design: .monospaced)).foregroundColor(SynthColors.textPrimary)
        }
    }

    var dividerLine: some View { SynthColors.divider.frame(height: 1) }
    var dividerVertical: some View { SynthColors.divider.frame(width: 1) }
}

// MARK: - Step Cell

struct StepCell: View {
    let active: Bool
    let playing: Bool
    let highlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            RoundedRectangle(cornerRadius: 2)
                .fill(fillColor)
                .frame(height: 22)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(playing ? SynthColors.accent : Color.clear, lineWidth: 1.5)
                )
        }
    }

    var fillColor: Color {
        if playing             { return SynthColors.accent }
        if active && highlighted { return SynthColors.accentBlue }
        if active              { return SynthColors.divider }
        return SynthColors.surfaceRaised
    }
}

#Preview(traits: .landscapeLeft) {
    PerformanceView()
}
