// Reachable sound editing controls. The same catalog/bridge drives the live engine and Matrix.
import SwiftUI
import UIKit

struct InstrumentControlsView: View {
    @Bindable var bridge: SensorFMBridge

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                section("FM", targets: [.carrierFrequency, .modulatorRatio, .modulationIndex, .amplitude])
                Text("Your finger sets note pitch. Carrier frequency sets the Matrix test tone.")
                    .font(.caption)
                    .foregroundColor(SynthColors.textSecondary)
                section("AMPLITUDE ADSR", targets: [.ampAttack, .ampDecay, .ampSustain, .ampRelease])
                Text("Each note has its own fade in and fade out. Release changes apply to the next note you let go.")
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
                    Text("Lower the low-pass cutoff for a darker sound. Resonance emphasizes the cutoff. Bypass turns the filter off, not its settings.")
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
                    Text("BASE \(target.formatted(bridge.baseValue(for: target))) · LIVE \(target.formatted(bridge.outputValue(for: target)))\(bridge.outputIsClamped(target) ? " · AT LIMIT" : "")")
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
/// hit testing uses the real view bounds. The existing accessibility override
/// requests the same bounds, but iPadOS still reports a 34pt AX frame after three
/// physical repair cycles. This is a known deviation, not VoiceOver qualification.
/// No fourth AX repair, scaled track/thumb or fabricated constant rectangle.
final class InstrumentUISlider: UISlider {
    var reportsHitBoundsForTesting = ProcessInfo.processInfo.arguments.contains("-ui-testing")

    // Test evidence is read from the real view after layout, never cached or an AX repair.
    override var accessibilityValue: String? {
        get {
            guard reportsHitBoundsForTesting else { return super.accessibilityValue }
            let upper = point(inside: CGPoint(x: bounds.midX, y: bounds.minY + 1), with: nil)
            let lower = point(inside: CGPoint(x: bounds.midX, y: bounds.maxY - 1), with: nil)
            return "\(super.accessibilityValue ?? "") | HIT_BOUNDS width=\(bounds.width) height=\(bounds.height) upper=\(upper) lower=\(lower)"
        }
        set { super.accessibilityValue = newValue }
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.contains(point)
    }
    override var accessibilityFrame: CGRect {
        get { UIAccessibility.convertToScreenCoordinates(bounds, in: self) }
        set { super.accessibilityFrame = newValue }
    }
}

private struct InstrumentParameterSlider: UIViewRepresentable {
    @Binding var value: Double
    let label: String
    let valueText: String
    let identifier: String

    func makeUIView(context: Context) -> UISlider {
        let slider = InstrumentUISlider()
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

    // An outer SwiftUI frame doesn't choose the represented UIKit control's size.
    // Supply the layout contract for actual 44pt bounds and hit area; see AX deviation above.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UISlider, context: Context) -> CGSize? {
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil }
            ?? uiView.sizeThatFits(.zero).width
        return CGSize(width: max(0, width), height: 44)
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
