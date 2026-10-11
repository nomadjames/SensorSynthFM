// Mac-runnable UI tests of the reachable production page. -ui-testing suppresses
// live sensors/session/audio, not page controls or the production parameter sink.
import XCTest

final class InstrumentFoundationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    @MainActor
    func testInstrumentChildrenKeepDistinctAccessibilityIdentifiers() throws {
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.instrument").tap()
        for id in ["instrument.page.title", "instrument.audition.toggle",
                   "instrument.controls.viewport", "performance.active.voice.count"] {
            let child = element(id)
            XCTAssertTrue(child.waitForExistence(timeout: 2), "Child ID must survive Instrument container: \(id)")
            XCTAssertEqual(child.identifier, id)
        }
        XCTAssertGreaterThanOrEqual(element("instrument.audition.toggle").frame.height, 44)
        element("instrument.audition.toggle").tap()
        XCTAssertTrue(app.sliders["instrument.parameter.0"].isHittable)
        XCTAssertTrue(element("instrument.hidden.held.count").exists)
    }

    @MainActor
    func testInstrumentControlsAndAuditionHoldSurviveNavigation() throws {
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.hold").tap()
        let surface = element("performance.note.surface.container")
        surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).press(forDuration: 0.1)
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("performance.instrument").tap()
        XCTAssertTrue(element("instrument.page.title").waitForExistence(timeout: 2))
        XCTAssertTrue(element("performance.note.surface.container").exists)
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("instrument.audition.toggle").tap()
        XCTAssertFalse(element("performance.note.surface.container").exists)
        XCTAssertTrue(contains(element("instrument.hidden.held.count"), "1 HELD"))
        let viewport = element("instrument.controls.viewport")
        let attack = app.sliders["instrument.parameter.4"]
        revealVertical(attack, viewport: viewport)
        XCTAssertTrue(attack.isHittable)
        let old = attack.value as? String
        attack.adjust(toNormalizedSliderPosition: 0.35)
        XCTAssertNotEqual(attack.value as? String, old)
        XCTAssertTrue(contains(element("instrument.readout.4"), "ms"))
        element("instrument.audition.toggle").tap()
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("performance.hand.left").tap()
        XCTAssertLessThan(element("performance.control.rail").frame.minX,
                          element("performance.note.surface.container").frame.minX)
        keepScreenshot("Instrument left-hand audition and retained Hold")
        element("performance.hand.right").tap()
        XCTAssertGreaterThan(element("performance.control.rail").frame.minX,
                             element("performance.note.surface.container").frame.minX)
        keepScreenshot("Instrument right-hand audition and retained Hold")
        element("instrument.performance").tap()
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 2))
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("performance.release.touches").tap()
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 0/10"))
    }

    @MainActor
    func testAllInstrumentParametersAndFilterModesAreEditable() throws {
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.instrument").tap()
        element("instrument.audition.toggle").tap()
        let viewport = element("instrument.controls.viewport")
        for id in 0..<10 {
            let slider = app.sliders["instrument.parameter.\(id)"]
            revealVertical(slider, viewport: viewport)
            XCTAssertTrue(slider.isHittable, "Catalog parameter \(id) should be reachable")
            // Known iPadOS AX frame is 34pt; assert real native hit bounds, not AX repair.
            try assertNativeHitBounds(slider)
            let old = slider.value as? String
            slider.adjust(toNormalizedSliderPosition: 0.4)
            XCTAssertNotEqual(slider.value as? String, old, "Editing parameter \(id) must change base value")
            XCTAssertTrue(contains(element("instrument.readout.\(id)"), "LIVE"))
            XCTAssertTrue(contains(element("instrument.readout.\(id)"), "BASE"))
        }
        let bypass = element("instrument.filter.bypass")
        revealVertical(bypass, viewport: viewport, upward: false)
        XCTAssertTrue(contains(bypass, "Bypassed"))
        XCTAssertGreaterThanOrEqual(bypass.frame.height, 44)
        bypass.tap()
        XCTAssertTrue(contains(bypass, "Enabled"))
        for mode in ["HP", "BP", "LP"] {
            XCTAssertGreaterThanOrEqual(element("instrument.filter.mode.\(mode)").frame.height, 44)
            element("instrument.filter.mode.\(mode)").tap()
            XCTAssertTrue(contains(element("instrument.filter.mode.\(mode)"), "Selected"))
        }
        bypass.tap()
        XCTAssertTrue(contains(bypass, "Bypassed"))
        keepScreenshot("Instrument edited filter and base-live controls")
    }

    @MainActor
    func testExpandedMatrixRouteCanBeRemoved() throws {
        XCTAssertTrue(element("performance.matrix").waitForExistence(timeout: 5))
        element("performance.matrix").tap()
        let viewport = element("modulation.matrix.viewport")
        XCTAssertTrue(viewport.waitForExistence(timeout: 2))
        // Last row AND last source prove both scrolling axes, not only the accepted top four.
        let cell = element("modulation.cell.source.8.target.9")
        let row = element("modulation.target.9")
        revealVertical(row, viewport: viewport)
        for _ in 0..<10 {
            if cell.isHittable { break }
            viewport.swipeLeft()
        }
        XCTAssertTrue(cell.isHittable)
        cell.tap()
        XCTAssertTrue(contains(element("modulation.selected.route.context"), "FILTER RES"))
        XCTAssertTrue(contains(cell, "SELECTED · NEUTRAL"))
        element("modulation.amount.increase").tap()
        XCTAssertTrue(contains(cell, "ACTIVE"))
        let remove = element("modulation.route.remove")
        XCTAssertTrue(remove.isHittable)
        remove.tap()
        XCTAssertTrue(contains(cell, "SELECTED · NEUTRAL"))
        XCTAssertTrue(element("modulation.route.editor").exists)
        keepScreenshot("Expanded Matrix last target route removal")
        element("matrix.instrument").tap()
        XCTAssertTrue(element("instrument.page.title").waitForExistence(timeout: 2))
        element("performance.matrix").tap()
        XCTAssertTrue(element("modulation.matrix.viewport").waitForExistence(timeout: 2))
        element("performance.return").tap()
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 0/10"))
    }

    @MainActor
    func testInstrumentToMatrixKeepsAcceptedReleaseAllPolicy() throws {
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.hold").tap()
        element("performance.note.surface.container")
            .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(forDuration: 0.1)
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("performance.instrument").tap()
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
        element("performance.matrix").tap()
        element("matrix.instrument").tap()
        XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 0/10"))
        XCTAssertTrue(element("performance.release.touches").isHittable)
    }

    // Candidate tests authored on Linux; native execution remains pending.
    @MainActor
    func testResetStartRestoresPatchHoldPitchAndAuditionForBothHands() throws {
        XCTAssertTrue(element("performance.reset.start").waitForExistence(timeout: 5))
        for hand in ["left", "right"] {
            element("performance.hand.\(hand)").tap()
            element("performance.pitch.freehand").tap()
            element("performance.octave.up").tap()
            element("performance.hold").tap()
            element("performance.note.surface.container")
                .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).press(forDuration: 0.1)
            XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 1/10"))
            element("performance.instrument").tap()
            element("instrument.audition.toggle").tap()
            let viewport = element("instrument.controls.viewport")
            let ratio = app.sliders["instrument.parameter.1"]
            revealVertical(ratio, viewport: viewport, upward: false)
            ratio.adjust(toNormalizedSliderPosition: 0.4)
            let bypass = element("instrument.filter.bypass")
            revealVertical(bypass, viewport: viewport)
            bypass.tap()
            XCTAssertTrue(contains(bypass, "Enabled"))
            let reset = element("performance.reset.start")
            XCTAssertTrue(reset.isHittable)
            XCTAssertGreaterThanOrEqual(reset.frame.height, 44)
            XCTAssertGreaterThanOrEqual(reset.frame.width, 44)
            reset.tap()
            XCTAssertTrue(contains(element("performance.hold"), "Disabled"))
            XCTAssertTrue(contains(element("performance.pitch.mode"), "QUANTIZED"))
            XCTAssertTrue(contains(element("performance.pitch.range"), "MIDI 60–72"))
            XCTAssertTrue(contains(element("performance.active.voice.count"), "VOICES 0/10"))
            XCTAssertTrue(contains(element("instrument.audition.toggle"), "Shown"))
            revealVertical(bypass, viewport: viewport)
            XCTAssertTrue(contains(bypass, "Bypassed"))
            XCTAssertTrue(contains(element("instrument.filter.mode.LP"), "Selected"))
            let expected = ["440 Hz", "2.00:1", "1.00", "10%", "20 ms", "150 ms", "70%", "350 ms", "18000 Hz", "0%"]
            for id in 0..<10 {
                let slider = app.sliders["instrument.parameter.\(id)"]
                revealVertical(slider, viewport: viewport, upward: id != 0)
                XCTAssertTrue(contains(slider, expected[id]))
            }
            XCTAssertTrue(element("instrument.page.title").exists, "Reset keeps current page")
            if hand == "left" {
                XCTAssertLessThan(element("performance.control.rail").frame.minX,
                                  element("performance.note.surface.container").frame.minX)
            } else {
                XCTAssertGreaterThan(element("performance.control.rail").frame.minX,
                                     element("performance.note.surface.container").frame.minX)
            }
            element("instrument.performance").tap()
            element("performance.matrix").tap()
            let accel = element("modulation.cell.source.0.target.2")
            XCTAssertTrue(contains(accel, "+10%"))
            let mic = element("modulation.cell.source.1.target.3")
            XCTAssertTrue(contains(mic, "+8%"))
            let gyro = element("modulation.cell.source.2.target.1")
            XCTAssertTrue(contains(gyro, "+3%")) // Existing percent formatter rounds display only.
            element("performance.return").tap()
        }
    }

    @MainActor
    func testRelaunchStartsWithCuratedPatchAndPlainCopy() throws {
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.instrument").tap()
        let ratio = app.sliders["instrument.parameter.1"]
        ratio.adjust(toNormalizedSliderPosition: 0.4)
        app.terminate()
        app.launch()
        XCTAssertTrue(element("performance.instrument").waitForExistence(timeout: 5))
        element("performance.instrument").tap()
        XCTAssertTrue(contains(app.sliders["instrument.parameter.1"], "2.00:1"))
        XCTAssertTrue(app.staticTexts["Your finger sets note pitch. Carrier frequency sets the Matrix test tone."].exists)
        element("performance.matrix").tap()
        XCTAssertTrue(app.staticTexts["ROOM SOUND"].exists)
        XCTAssertTrue(app.buttons["Details"].exists)
    }

    @MainActor
    private func assertNativeHitBounds(_ slider: XCUIElement) throws {
        let value = try XCTUnwrap(slider.value as? String)
        let evidence = try XCTUnwrap(value.components(separatedBy: " | HIT_BOUNDS ").last)
        let fields = evidence.split(separator: " ").map(String.init)
        let heightText = try XCTUnwrap(fields.first { $0.hasPrefix("height=") })
        let widthText = try XCTUnwrap(fields.first { $0.hasPrefix("width=") })
        let height = try XCTUnwrap(Double(heightText.dropFirst("height=".count)))
        let width = try XCTUnwrap(Double(widthText.dropFirst("width=".count)))
        XCTAssertGreaterThanOrEqual(height, 44)
        XCTAssertGreaterThanOrEqual(width, 44)
        XCTAssertTrue(fields.contains("upper=true"))
        XCTAssertTrue(fields.contains("lower=true"))
    }

    @MainActor
    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: id).firstMatch
    }

    @MainActor
    private func revealVertical(_ target: XCUIElement, viewport: XCUIElement, upward: Bool = true) {
        for _ in 0..<12 {
            if target.isHittable { return }
            if upward { viewport.swipeUp() } else { viewport.swipeDown() }
        }
    }

    @MainActor
    private func contains(_ target: XCUIElement, _ expected: String) -> Bool {
        let predicate = NSPredicate { _, _ in
            target.label.contains(expected) || (target.value as? String ?? "").contains(expected)
        }
        return XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: nil)], timeout: 2) == .completed
    }

    @MainActor
    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        // iPadOS27 app-only snapshots can rotate/crop the image. Retain the
        // independent whole-device capture and actual AX hierarchy as well.
        let screen = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screen.name = name + " full device"
        screen.lifetime = .keepAlways
        add(screen)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = name + " AX hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
