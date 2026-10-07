// Reachable sound editing controls. The same catalog/bridge drives the live engine and Matrix.
import SwiftUI
import UIKit

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
                            Button {
                                bridge.setFilter(mode: mode, bypassed: bridge.filterBypassed)
                            } label: {
                                Text(mode.rawValue)
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                            .background(bridge.filterMode == mode ? SynthColors.accent : SynthColors.surfaceRaised)
                            .foregroundColor(bridge.filterMode == mode ? SynthColors.background : SynthColors.textPrimary)
                            .cornerRadius(7)
                            .accessibilityIdentifier("instrument.filter.mode.\(mode.rawValue)")
                            .accessibilityLabel(mode == .lowPass ? "Low pass" : mode == .highPass ? "High pass" : "Band pass")
                            .accessibilityValue(bridge.filterMode == mode ? "Selected" : "Not selected")
                        }
                        Button {
                            bridge.setFilter(mode: bridge.filterMode, bypassed: !bridge.filterBypassed)
                        } label: {
                            Text(bridge.filterBypassed ? "BYPASSED" : "ENABLED")
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
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
                    InstrumentParameterSlider(value: Binding(
                        get: { target.normalised(bridge.baseValue(for: target)) },
                        set: { bridge.setBaseValue(target.denormalised($0), for: target) }
                    ), label: target.label,
                       valueText: target.formatted(bridge.baseValue(for: target)),
                       identifier: "instrument.parameter.\(target.rawValue)")
                    .frame(height: 44)
                    Text("BASE \(target.formatted(bridge.baseValue(for: target))) · LIVE \(target.formatted(bridge.outputValue(for: target)))\(bridge.outputIsClamped(target) ? " · CLAMPED" : "")")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(SynthColors.textSecondary)
                        .accessibilityIdentifier("instrument.readout.\(target.rawValue)")
                }
            }
        }
    }
}

/// Give the native control itself 44-point bounds, not a 31-point SwiftUI Slider
/// inside a larger layout frame. Track/thumb keep their standard UIKit sizes;
/// hit testing and accessibility both use the real view bounds.
private struct InstrumentParameterSlider: UIViewRepresentable {
    @Binding var value: Double
    let label: String
    let valueText: String
    let identifier: String

    func makeUIView(context: Context) -> UISlider {
        let slider = UISlider()
        slider.minimumValue = 0
        slider.maximumValue = 1
        slider.minimumTrackTintColor = UIColor(SynthColors.accent)
        slider.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .valueChanged)
        return slider
    }

    func updateUIView(_ slider: UISlider, context: Context) {
        context.coordinator.owner = self
        slider.setValue(Float(value), animated: false)
        slider.accessibilityLabel = label
        slider.accessibilityValue = valueText
        slider.accessibilityIdentifier = identifier
    }

    func makeCoordinator() -> Coordinator { Coordinator(owner: self) }

    final class Coordinator: NSObject {
        var owner: InstrumentParameterSlider
        init(owner: InstrumentParameterSlider) { self.owner = owner }
        @objc func changed(_ slider: UISlider) {
            owner.value = Double(slider.value)
        }
    }
}
