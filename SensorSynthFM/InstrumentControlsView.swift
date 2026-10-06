// Reachable sound editing controls. The same catalog/bridge drives the live engine and Matrix.
import SwiftUI

struct InstrumentControlsView: View {
    @Bindable var bridge: SensorFMBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("FM", targets: [.carrierFrequency, .modulatorRatio, .modulationIndex, .amplitude])
                Text("Touch pitch stays authoritative. Carrier base drives the legacy Matrix audition note only.")
                    .font(.caption)
                    .foregroundColor(SynthColors.textSecondary)
                section("AMPLITUDE ADSR", targets: [.ampAttack, .ampDecay, .ampSustain, .ampRelease])
                Text("One envelope per note. Release time is captured on note-off; editing a tail never retriggers it.")
                    .font(.caption)
                    .foregroundColor(SynthColors.textSecondary)
                VStack(alignment: .leading, spacing: 10) {
                    Text("PER-NOTE FILTER")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    HStack(spacing: 8) {
                        ForEach(FilterMode.allCases) { mode in
                            Button(mode.rawValue) {
                                bridge.setFilter(mode: mode, bypassed: bridge.filterBypassed)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(bridge.filterMode == mode ? SynthColors.accent : SynthColors.surfaceRaised)
                            .foregroundColor(bridge.filterMode == mode ? SynthColors.background : SynthColors.textPrimary)
                            .cornerRadius(7)
                            .accessibilityIdentifier("instrument.filter.mode.\(mode.rawValue)")
                            .accessibilityLabel(mode == .lowPass ? "Low pass" : mode == .highPass ? "High pass" : "Band pass")
                            .accessibilityValue(bridge.filterMode == mode ? "Selected" : "Not selected")
                        }
                        Button(bridge.filterBypassed ? "BYPASSED" : "ENABLED") {
                            bridge.setFilter(mode: bridge.filterMode, bypassed: !bridge.filterBypassed)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(SynthColors.surfaceRaised)
                        .cornerRadius(7)
                        .accessibilityIdentifier("instrument.filter.bypass")
                        .accessibilityLabel("Filter bypass")
                        .accessibilityValue(bridge.filterBypassed ? "Bypassed" : "Enabled")
                    }
                    .buttonStyle(.plain)
                    parameterGrid([.filterCutoff, .filterResonance])
                    Text("Cutoff is logarithmic (center in BP). Resonance: LP/HP 0…+6 dB; BP bandwidth 2400…300 cents. Bypass leaves routes editable but inaudible.")
                        .font(.caption)
                        .foregroundColor(SynthColors.textSecondary)
                }
                .padding(12)
                .background(SynthColors.surface)
                .cornerRadius(10)
            }
            .padding(12)
        }
        .accessibilityIdentifier("instrument.controls.viewport")
        .foregroundColor(SynthColors.textPrimary)
    }

    private func section(_ title: String, targets: [SensorModulationTarget]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
            parameterGrid(targets)
        }
        .padding(12)
        .background(SynthColors.surface)
        .cornerRadius(10)
    }

    private func parameterGrid(_ targets: [SensorModulationTarget]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 16)], spacing: 12) {
            ForEach(targets) { target in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(target.label)
                        Spacer()
                        Text(target.formatted(bridge.baseValue(for: target)))
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    Slider(value: Binding(
                        get: { target.normalised(bridge.baseValue(for: target)) },
                        set: { bridge.setBaseValue(target.denormalised($0), for: target) }
                    ), in: 0...1)
                    .frame(minHeight: 44)
                    .tint(SynthColors.accent)
                    .accessibilityLabel(target.label)
                    .accessibilityValue(target.formatted(bridge.baseValue(for: target)))
                    .accessibilityIdentifier("instrument.parameter.\(target.rawValue)")
                    Text("BASE \(target.formatted(bridge.baseValue(for: target))) · LIVE \(target.formatted(bridge.outputValue(for: target)))\(bridge.outputIsClamped(target) ? " · CLAMPED" : "")")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .accessibilityIdentifier("instrument.readout.\(target.rawValue)")
                }
            }
        }
    }
}
