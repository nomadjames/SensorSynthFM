// FMEngineView.swift
// SensorSynth FM — FM engine editor
// Layout: algorithm panel (left) | operator detail + filter (right)

import SwiftUI

struct FMEngineView: View {
    @State private var selectedAlgorithm = 2
    @State private var selectedOperator  = 0
    @State private var filterType        = 0  // 0=LP 1=HP 2=BP
    @State private var filterCutoff      = 0.68
    @State private var filterResonance   = 0.28
    @State private var filterDrive       = 0.12

    let opNames  = ["A1", "A2", "B1", "B2"]
    let opColors: [Color] = [
        SynthColors.accent,
        SynthColors.accent.opacity(0.55),
        SynthColors.accentBlue,
        SynthColors.accentBlue.opacity(0.55),
    ]

    // ratio, level, feedback, attack, decay, sustain, release — all 0-1 normalised
    @State private var opParams: [[Double]] = [
        [0.14, 0.80, 0.20, 0.02, 0.30, 0.60, 0.40],
        [0.28, 0.60, 0.00, 0.02, 0.50, 0.40, 0.55],
        [0.42, 0.70, 0.12, 0.04, 0.20, 0.70, 0.30],
        [0.57, 0.50, 0.00, 0.08, 0.40, 0.50, 0.45],
    ]
    let paramLabels = ["RATIO", "LEVEL", "FDBK", "ATK", "DEC", "SUS", "REL"]

    // Algorithms encoded as connections: (modulator index, carrier index)
    let algorithms: [[(Int, Int)]] = [
        [(1,0),(2,0),(3,0)],   // 1: all mod A1
        [(1,0),(3,2)],         // 2: A2→A1, B2→B1
        [(2,0),(3,1)],         // 3: B1→A1, B2→A2
        [(1,0),(2,1),(3,2)],   // 4: chain
        [(1,0),(3,2)],         // 5: same as 2 (visual variant)
        [(3,0),(3,1)],         // 6: B2→both carriers
        [(1,0)],               // 7: minimal
        [],                    // 8: all carriers
    ]

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                // Header
                header

                SynthColors.divider.frame(height: 1)

                HStack(spacing: 0) {
                    // Left panel: algorithm + operator picker
                    VStack(spacing: 0) {
                        algorithmPanel
                        SynthColors.divider.frame(height: 1)
                        operatorPicker
                    }
                    .frame(width: geo.size.width * 0.36)

                    SynthColors.divider.frame(width: 1)

                    // Right panel: operator params + filter
                    VStack(spacing: 0) {
                        operatorDetailPanel
                        SynthColors.divider.frame(height: 1)
                        filterPanel
                    }
                    .frame(maxWidth: .infinity)
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
            Text("FM ENGINE").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(SynthColors.accent)
            Text("·").foregroundColor(SynthColors.divider)
            Text("Passive Field 01").font(.system(size: 11)).foregroundColor(SynthColors.textSecondary)
            Spacer()
        }
        .padding(.horizontal, 16).frame(height: 48).background(SynthColors.surface)
    }

    // MARK: - Algorithm Panel

    var algorithmPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ALGORITHM").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                Spacer()
                Text("\(selectedAlgorithm + 1) of 8").font(.system(size: 9, design: .monospaced)).foregroundColor(SynthColors.accent)
            }

            // Node diagram
            algorithmDiagram.frame(height: 130)

            // Algorithm selector buttons
            HStack(spacing: 3) {
                chevronButton(left: true)  { if selectedAlgorithm > 0 { selectedAlgorithm -= 1 } }
                ForEach(0..<8) { alg in
                    Button { selectedAlgorithm = alg } label: {
                        Text("\(alg + 1)").font(.system(size: 10, design: .monospaced))
                            .foregroundColor(selectedAlgorithm == alg ? SynthColors.background : SynthColors.textSecondary)
                            .frame(maxWidth: .infinity).frame(height: 28)
                            .background(selectedAlgorithm == alg ? SynthColors.accent : SynthColors.surfaceRaised)
                            .cornerRadius(3)
                    }
                }
                chevronButton(left: false) { if selectedAlgorithm < 7 { selectedAlgorithm += 1 } }
            }
        }
        .padding(12)
    }

    func chevronButton(left: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: left ? "chevron.left" : "chevron.right")
                .foregroundColor(SynthColors.textSecondary)
                .frame(width: 26, height: 28)
                .background(SynthColors.surfaceRaised)
                .cornerRadius(3)
        }
    }

    // MARK: - Algorithm Diagram

    var algorithmDiagram: some View {
        GeometryReader { geo in
            Canvas { ctx, size in
                // Operator node positions: A1 top-left, B1 top-right, A2 bottom-left, B2 bottom-right
                let positions: [CGPoint] = [
                    CGPoint(x: size.width * 0.25, y: size.height * 0.22),  // A1
                    CGPoint(x: size.width * 0.75, y: size.height * 0.22),  // B1
                    CGPoint(x: size.width * 0.25, y: size.height * 0.62),  // A2
                    CGPoint(x: size.width * 0.75, y: size.height * 0.62),  // B2
                ]

                let connections = algorithms[selectedAlgorithm]

                // Draw modulation arrows
                for (mod, carrier) in connections {
                    let from = positions[mod]
                    let to   = positions[carrier]
                    var p = Path()
                    p.move(to: CGPoint(x: from.x, y: from.y + 16))
                    p.addLine(to: CGPoint(x: to.x, y: to.y - 16))
                    ctx.stroke(p, with: .color(SynthColors.divider), lineWidth: 1.5)
                }

                // Draw output arrows from carriers (ops not acting as modulators)
                let modulators = Set(connections.map { $0.0 })
                for i in 0..<4 {
                    if !modulators.contains(i) {
                        let pos = positions[i]
                        var p = Path()
                        p.move(to: CGPoint(x: pos.x, y: pos.y + 16))
                        p.addLine(to: CGPoint(x: pos.x, y: size.height - 14))
                        ctx.stroke(p, with: .color(SynthColors.sensorGreen.opacity(0.7)), lineWidth: 2)
                    }
                }

                // Output label
                ctx.draw(
                    Text("OUT").font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.sensorGreen),
                    at: CGPoint(x: size.width * 0.5, y: size.height - 8)
                )

                // Draw operator nodes
                // Note: position array order is A1, B1, A2, B2
                let drawOrder: [(Int, String, Color)] = [
                    (0, "A1", SynthColors.accent),
                    (1, "B1", SynthColors.accentBlue),
                    (2, "A2", SynthColors.accent.opacity(0.6)),
                    (3, "B2", SynthColors.accentBlue.opacity(0.6)),
                ]
                for (idx, name, color) in drawOrder {
                    let pos  = positions[idx]
                    let rect = CGRect(x: pos.x - 22, y: pos.y - 14, width: 44, height: 28)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 5), with: .color(color))
                    ctx.draw(
                        Text(name).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(.white),
                        at: pos
                    )
                }
            }
        }
    }

    // MARK: - Operator Picker

    var operatorPicker: some View {
        HStack(spacing: 0) {
            ForEach(0..<4) { op in
                Button { selectedOperator = op } label: {
                    VStack(spacing: 3) {
                        Circle().fill(opColors[op]).frame(width: 8, height: 8)
                        Text(opNames[op])
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(selectedOperator == op ? SynthColors.textPrimary : SynthColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(selectedOperator == op ? SynthColors.surfaceRaised : Color.clear)
                }
                if op < 3 { SynthColors.divider.frame(width: 1) }
            }
        }
    }

    // MARK: - Operator Detail Panel

    var operatorDetailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Operator header
            HStack {
                Circle().fill(opColors[selectedOperator]).frame(width: 9, height: 9)
                Text("OPERATOR \(opNames[selectedOperator])")
                    .font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundColor(SynthColors.textPrimary)
                Spacer()
                // Waveform indicator
                HStack(spacing: 5) {
                    Image(systemName: "waveform").foregroundColor(SynthColors.accent)
                    Text("SIN").font(.system(size: 9, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(SynthColors.surfaceRaised).cornerRadius(4)
            }

            // Knob grid — ratio, level, feedback + envelope
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(0..<7) { p in
                    OperatorKnob(
                        label: paramLabels[p],
                        value: opParams[selectedOperator][p],
                        displayText: formatParam(index: p, value: opParams[selectedOperator][p]),
                        color: p < 3 ? SynthColors.accent : SynthColors.accentBlue
                    )
                }
            }

            // ADSR visual bar
            HStack(alignment: .bottom, spacing: 6) {
                Text("ENV").font(.system(size: 8, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                    .frame(width: 28)
                ForEach(zip(["ATK","DEC","SUS","REL"], [3,4,5,6]).map { $0 }, id: \.0) { label, pIdx in
                    VStack(spacing: 3) {
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 2).fill(SynthColors.surfaceRaised).frame(width: 26, height: 52)
                            RoundedRectangle(cornerRadius: 2).fill(SynthColors.accentBlue)
                                .frame(width: 26, height: max(4, 52 * opParams[selectedOperator][pIdx]))
                        }
                        Text(label).font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                    }
                }
                Spacer()
            }
        }
        .padding(14)
    }

    func formatParam(index: Int, value: Double) -> String {
        switch index {
        case 0: return String(format: "%.2f", value * 15 + 0.5)   // ratio 0.5–16
        case 1: return String(format: "%d",   Int(value * 99))     // level 0–99
        case 2: return String(format: "%d",   Int(value * 7))      // feedback 0–7
        default: return String(format: "%.2f", value)
        }
    }

    // MARK: - Filter Panel

    var filterPanel: some View {
        HStack(spacing: 20) {
            // Type selector
            VStack(alignment: .leading, spacing: 6) {
                Text("FILTER").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
                HStack(spacing: 3) {
                    ForEach(["LP","HP","BP"].indices, id: \.self) { i in
                        let label = ["LP","HP","BP"][i]
                        Button { filterType = i } label: {
                            Text(label).font(.system(size: 10, design: .monospaced))
                                .foregroundColor(filterType == i ? SynthColors.background : SynthColors.textSecondary)
                                .frame(width: 34, height: 26)
                                .background(filterType == i ? SynthColors.accent : SynthColors.surfaceRaised)
                                .cornerRadius(3)
                        }
                    }
                }
            }

            OperatorKnob(label: "CUTOFF",  value: filterCutoff,    displayText: String(format: "%dk", Int(filterCutoff * 18) + 1), color: SynthColors.accent)
            OperatorKnob(label: "RESO",    value: filterResonance,  displayText: String(format: "%.2f", filterResonance),           color: SynthColors.accent)
            OperatorKnob(label: "DRIVE",   value: filterDrive,      displayText: String(format: "%.2f", filterDrive),               color: SynthColors.accent)

            Spacer()
        }
        .padding(12)
        .background(SynthColors.surface)
    }
}

// MARK: - Operator Knob

struct OperatorKnob: View {
    let label: String
    let value: Double
    let displayText: String
    var color: Color = SynthColors.accentBlue

    var body: some View {
        VStack(spacing: 3) {
            Text(label).font(.system(size: 7, design: .monospaced)).foregroundColor(SynthColors.textSecondary)
            ZStack {
                Circle().stroke(SynthColors.surfaceRaised, lineWidth: 4).frame(width: 42, height: 42)
                Circle()
                    .trim(from: 0.1, to: 0.1 + 0.8 * value)
                    .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 42, height: 42)
                    .rotationEffect(.degrees(-90))
                Text(displayText)
                    .font(.system(size: 7, design: .monospaced))
                    .foregroundColor(SynthColors.textSecondary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    FMEngineView()
}
