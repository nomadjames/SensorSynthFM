// SensorModulationView.swift
// SensorSynth FM — sensor routing and modulation capture screen
// Layout: live sensor readouts (left) | modulation matrix (center) | capture loops (right)

import SwiftUI

struct SensorModulationView: View {
    @State private var isCapturing = false

    // Sensor sources
    let sources: [(String, Double, Color)] = [
        ("ACCEL X",    0.22, SynthColors.sensorGreen),
        ("ACCEL Y",    0.14, SynthColors.sensorGreen),
        ("ACCEL Z",    0.31, SynthColors.sensorGreen),
        ("GYRO X",     0.10, SynthColors.sensorGreen),
        ("GYRO Y",     0.06, SynthColors.sensorGreen),
        ("GYRO Z",     0.09, SynthColors.sensorGreen),
        ("CAM MOTION", 0.64, SynthColors.accentBlue),
        ("MIC AMP",    0.41, SynthColors.accent),
        ("MIC LOW",    0.28, SynthColors.accent),
        ("MIC MID",    0.52, SynthColors.accent),
        ("MIC HI",     0.19, SynthColors.accent),
    ]

    // Modulation destinations
    let destinations = ["MOD IDX", "CARRIER", "FDBK", "CUTOFF", "RESO", "LEVEL"]

    // Active mappings: [sourceIndex: [destinationIndex]]
    @State private var matrix: [[Bool]] = {
        var m = Array(repeating: Array(repeating: false, count: 6), count: 11)
        m[0][0] = true   // Accel X → Mod Index
        m[6][1] = true   // Cam Motion → Carrier
        m[7][3] = true   // Mic Amp → Cutoff
        m[10][5] = true  // Mic Hi → Level
        return m
    }()

    // Captured sensor loops (mock data)
    let loops: [(String, String, String)] = [
        ("Loop 1", "4.2s", "ACCEL X"),
        ("Loop 2", "2.8s", "CAM MOTION"),
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                header

                SynthColors.divider.frame(height: 1)

                HStack(spacing: 0) {
                    sensorReadouts
                        .frame(width: geo.size.width * 0.28)

                    SynthColors.divider.frame(width: 1)

                    modulationMatrix

                    SynthColors.divider.frame(width: 1)

                    capturePanel
                        .frame(width: geo.size.width * 0.22)
                }
                .frame(maxHeight: .infinity)
            }
            .background(SynthColors.background)
        }
        .background(SynthColors.background)
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    var header: some View {
        HStack {
            Text("SENSOR MODULATION")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.sensorGreen)

            Spacer()

            // Passive sensing indicator
            HStack(spacing: 5) {
                Circle().fill(SynthColors.sensorGreen).frame(width: 7, height: 7)
                Text("PASSIVE SENSING ACTIVE")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(SynthColors.sensorGreen)
            }
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(SynthColors.sensorGreen.opacity(0.10))
            .cornerRadius(4)
        }
        .padding(.horizontal, 16).frame(height: 48).background(SynthColors.surface)
    }

    // MARK: - Sensor Readouts

    var sensorReadouts: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SOURCES")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .padding(.horizontal, 12).padding(.vertical, 8)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sources.indices, id: \.self) { i in
                        let (label, level, color) = sources[i]
                        HStack(spacing: 6) {
                            // Active dot
                            Circle()
                                .fill(level > 0.12 ? color : SynthColors.surfaceRaised)
                                .frame(width: 5, height: 5)

                            Text(label)
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(SynthColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // Level bar
                            GeometryReader { g in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(SynthColors.surfaceRaised)
                                    RoundedRectangle(cornerRadius: 2).fill(color.opacity(0.85))
                                        .frame(width: max(3, g.size.width * level))
                                }
                            }
                            .frame(width: 48, height: 10)

                            Text(String(format: "%.2f", level))
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(SynthColors.textSecondary)
                                .frame(width: 28, alignment: .trailing)
                        }
                        .padding(.horizontal, 12).padding(.vertical, 5)

                        if i < sources.count - 1 {
                            SynthColors.divider.opacity(0.4).frame(height: 0.5)
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Modulation Matrix

    var modulationMatrix: some View {
        VStack(spacing: 0) {
            // Column headers (destinations)
            HStack(spacing: 0) {
                Text("").frame(width: 82)
                ForEach(destinations, id: \.self) { dest in
                    Text(dest)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(SynthColors.surface)

            SynthColors.divider.frame(height: 1)

            // Matrix rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(sources.indices, id: \.self) { si in
                        let (label, _, color) = sources[si]
                        HStack(spacing: 0) {
                            // Row label
                            Text(label)
                                .font(.system(size: 8, design: .monospaced))
                                .foregroundColor(SynthColors.textSecondary)
                                .lineLimit(1)
                                .frame(width: 82, alignment: .leading)
                                .padding(.leading, 8)

                            // Cells
                            ForEach(destinations.indices, id: \.self) { di in
                                let active = matrix[si][di]
                                Button {
                                    matrix[si][di].toggle()
                                } label: {
                                    ZStack {
                                        Rectangle()
                                            .fill(active ? color.opacity(0.25) : SynthColors.surfaceRaised.opacity(0.4))
                                            .frame(maxWidth: .infinity).frame(height: 30)

                                        if active {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(color.opacity(0.9))
                                                .frame(width: 10, height: 10)
                                        }
                                    }
                                }
                                .border(SynthColors.divider.opacity(0.4), width: 0.5)
                            }
                        }

                        SynthColors.divider.opacity(0.3).frame(height: 0.5)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }

    // MARK: - Capture Panel

    var capturePanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("CAPTURE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(SynthColors.textSecondary)
                .padding(12)

            // Record button
            Button { isCapturing.toggle() } label: {
                HStack(spacing: 8) {
                    Circle()
                        .fill(isCapturing ? Color.red : SynthColors.divider)
                        .frame(width: 12, height: 12)
                    Text(isCapturing ? "STOP" : "RECORD")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(isCapturing ? Color.red : SynthColors.textSecondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 10)
                .background(isCapturing ? Color.red.opacity(0.08) : SynthColors.surfaceRaised)
                .cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(isCapturing ? Color.red.opacity(0.4) : SynthColors.divider, lineWidth: 1))
            }
            .padding(.horizontal, 12)

            SynthColors.divider.frame(height: 1).padding(.top, 12)

            // Captured loops
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LOOPS (\(loops.count))")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .padding(.top, 10)

                    ForEach(loops.indices, id: \.self) { i in
                        let (name, duration, source) = loops[i]
                        LoopCard(name: name, duration: duration, source: source, index: i)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            Spacer()
        }
    }
}

// MARK: - Loop Card

struct LoopCard: View {
    let name: String
    let duration: String
    let source: String
    let index: Int
    @State private var looping = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundColor(SynthColors.textPrimary)
                Spacer()
                Text(duration).font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
            }

            Text(source).font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.accentBlue)

            // Waveform thumbnail (deterministic shape)
            Canvas { ctx, size in
                var path = Path()
                path.move(to: CGPoint(x: 0, y: size.height / 2))
                for xi in stride(from: 0.0, to: size.width, by: 1.5) {
                    let phase = Double(index) * 1.3
                    let env   = sin(xi / size.width * .pi)
                    let y     = size.height / 2 + sin(xi * 0.13 + phase) * size.height * 0.38 * env
                    path.addLine(to: CGPoint(x: xi, y: y))
                }
                ctx.stroke(path, with: .color(SynthColors.accentBlue.opacity(0.85)), lineWidth: 1.5)
            }
            .frame(height: 28)
            .background(SynthColors.surfaceRaised)
            .cornerRadius(3)

            // Controls
            HStack(spacing: 5) {
                Button { looping.toggle() } label: {
                    Text(looping ? "LOOP ✓" : "LOOP")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundColor(looping ? SynthColors.sensorGreen : SynthColors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background((looping ? SynthColors.sensorGreen : SynthColors.surfaceRaised).opacity(looping ? 0.15 : 1))
                        .cornerRadius(3)
                }
                Button {} label: {
                    Text("ONCE")
                        .font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(SynthColors.surfaceRaised).cornerRadius(3)
                }
                Spacer()
                Button {} label: {
                    Image(systemName: "trash").font(.system(size: 9)).foregroundColor(SynthColors.textSecondary.opacity(0.6))
                }
            }
        }
        .padding(8)
        .background(SynthColors.surface)
        .cornerRadius(6)
    }
}

#Preview(traits: .landscapeLeft) {
    SensorModulationView()
}
