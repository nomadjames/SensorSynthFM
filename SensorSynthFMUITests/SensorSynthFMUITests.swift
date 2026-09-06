//
//  SensorSynthFMUITests.swift
//  SensorSynthFMUITests
//
//  Bounded Mac-runnable UI coverage. These tests exercise the rendered route
//  and one touch lifecycle. They do not claim simulator multitouch proof.
//

import Foundation
import XCTest

final class SensorSynthFMUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()
    }

    @MainActor
    func testDefaultSurfaceIsPerformance() throws {
        let surface = element(withIdentifier: "performance.note.surface.container")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        XCTAssertTrue(element(withIdentifier: "performance.control.rail").exists)
        XCTAssertTrue(element(withIdentifier: "performance.pitch.quantized").exists)
        XCTAssertTrue(element(withIdentifier: "performance.pitch.mode").exists)
        XCTAssertTrue(element(withIdentifier: "performance.pitch.range").exists)
        XCTAssertTrue(
            waitForValueContaining(element(withIdentifier: "performance.active.voice.count"), "VOICES 0/10")
        )
        XCTAssertFalse(element(withIdentifier: "modulation.matrix.viewport").exists)
    }

    @MainActor
    func testNeutralRouteCanActivateAndBeRemovedWithoutCollapsingEditor() throws {
        openMatrix()
        XCTAssertTrue(
            element(withIdentifier: "modulation.matrix.viewport").waitForExistence(timeout: 5),
            "The landscape modulation surface should render in UI-test mode"
        )
        let neutralCell = element(withIdentifier: "modulation.cell.source.3.target.0")
        reveal(neutralCell)
        XCTAssertTrue(neutralCell.isHittable, "The neutral route cell should be reachable")

        neutralCell.tap()
        XCTAssertTrue(
            waitForValueContaining(neutralCell, "SELECTED · NEUTRAL"),
            "Selecting an unused route should expose neutral state"
        )

        let editor = element(withIdentifier: "modulation.route.editor")
        let amountControl = element(withIdentifier: "modulation.amount.slider")
        XCTAssertTrue(editor.exists)
        XCTAssertTrue(amountControl.exists)
        XCTAssertTrue(element(withIdentifier: "modulation.selected.route.context").exists)

        element(withIdentifier: "modulation.amount.increase").tap()
        XCTAssertTrue(
            waitForValueContaining(neutralCell, "ACTIVE"),
            "Adjusting a neutral route should activate it"
        )

        let remove = element(withIdentifier: "modulation.route.remove")
        XCTAssertTrue(remove.waitForExistence(timeout: 2), "Active routes should expose removal")
        remove.tap()

        XCTAssertTrue(
            waitForValueContaining(neutralCell, "SELECTED · NEUTRAL"),
            "Removing a route should return the selected cell to neutral"
        )
        XCTAssertTrue(editor.exists, "Removing a route must not remove the editor")
        XCTAssertTrue(amountControl.exists, "Removing a route must not remove amount control")
        XCTAssertFalse(remove.isEnabled, "Neutral routes should disable removal without collapsing its layout slot")
    }

    @MainActor
    func testMatrixReachesOffscreenSourceAndKeepsContextQueryable() throws {
        openMatrix()
        let viewport = element(withIdentifier: "modulation.matrix.viewport")
        XCTAssertTrue(viewport.waitForExistence(timeout: 5))

        let offscreenCell = element(withIdentifier: "modulation.cell.source.8.target.0")
        reveal(offscreenCell)
        XCTAssertTrue(offscreenCell.isHittable, "The ninth source should be reachable by horizontal scrolling")
        XCTAssertTrue(element(withIdentifier: "modulation.source.8").isHittable)

        XCTAssertTrue(element(withIdentifier: "modulation.target.0").exists, "Target labels remain queryable")
        XCTAssertTrue(element(withIdentifier: "modulation.matrix.selection.context").exists)
        XCTAssertTrue(element(withIdentifier: "modulation.selected.route.context").exists)

        offscreenCell.tap()
        XCTAssertTrue(element(withIdentifier: "modulation.selected.route.context").exists)
        XCTAssertTrue(element(withIdentifier: "modulation.route.editor").exists)
    }

    @MainActor
    func testMatrixRoundTripReleasesPerformanceVoices() throws {
        let surface = element(withIdentifier: "performance.note.surface.container")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        element(withIdentifier: "performance.matrix").tap()
        XCTAssertTrue(element(withIdentifier: "modulation.matrix.viewport").waitForExistence(timeout: 2))
        XCTAssertTrue(element(withIdentifier: "modulation.matrix.selection.context").exists)
        element(withIdentifier: "performance.return").tap()
        XCTAssertTrue(element(withIdentifier: "performance.note.surface.container").waitForExistence(timeout: 2))
        XCTAssertTrue(
            waitForValueContaining(element(withIdentifier: "performance.active.voice.count"), "VOICES 0/10")
        )
    }

    @MainActor
    func testPitchModeAndOctaveControls() throws {
        let mode = element(withIdentifier: "performance.pitch.mode")
        let range = element(withIdentifier: "performance.pitch.range")
        XCTAssertTrue(mode.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForValueContaining(mode, "QUANTIZED"))
        XCTAssertTrue(waitForValueContaining(range, "MIDI 60–72"))

        element(withIdentifier: "performance.pitch.freehand").tap()
        XCTAssertTrue(waitForValueContaining(mode, "FREEHAND"))

        element(withIdentifier: "performance.octave.up").tap()
        XCTAssertTrue(waitForValueContaining(range, "MIDI 72–84"))
        element(withIdentifier: "performance.octave.down").tap()
        XCTAssertTrue(waitForValueContaining(range, "MIDI 60–72"))

        element(withIdentifier: "performance.pitch.quantized").tap()
        XCTAssertTrue(waitForValueContaining(mode, "QUANTIZED"))
    }


    @MainActor
    func testSingleTouchPressDragReleaseLifecycle() throws {
        let surface = element(withIdentifier: "performance.note.surface.container")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        let start = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.65))
        let destination = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        start.press(forDuration: 0.1, thenDragTo: destination)

        let lifecycle = element(withIdentifier: "performance.touch.lifecycle")
        XCTAssertTrue(waitForValueContaining(lifecycle, "TOUCH B1 M"))
        XCTAssertTrue(waitForValueContaining(lifecycle, "R1"))
        XCTAssertTrue(waitForValueContaining(lifecycle, "PITCH CHANGED YES"))
        XCTAssertTrue(
            waitForValueContaining(element(withIdentifier: "performance.active.voice.count"), "VOICES 0/10")
        )
    }

    @MainActor
    private func openMatrix() {
        XCTAssertTrue(
            element(withIdentifier: "performance.note.surface.container").waitForExistence(timeout: 5)
        )
        element(withIdentifier: "performance.matrix").tap()
        XCTAssertTrue(
            element(withIdentifier: "modulation.matrix.viewport").waitForExistence(timeout: 2)
        )
    }

    @MainActor
    private func element(withIdentifier identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    @MainActor
    private func reveal(_ target: XCUIElement) {
        let viewport = element(withIdentifier: "modulation.matrix.viewport")
        for _ in 0..<8 {
            if target.isHittable { return }
            viewport.swipeLeft()
        }
    }

    @MainActor
    private func waitForValueContaining(
        _ element: XCUIElement,
        _ expected: String,
        timeout: TimeInterval = 2
    ) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if (element.value as? String)?.contains(expected) == true {
                return true
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return false
    }
}
