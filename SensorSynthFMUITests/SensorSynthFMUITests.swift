//
//  SensorSynthFMUITests.swift
//  SensorSynthFMUITests
//
//  Bounded Mac-runnable UI coverage. These tests exercise the rendered route
//  and one touch lifecycle. They do not claim simulator multitouch proof.

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
        XCTAssertTrue(element(withIdentifier: "performance.note.surface").waitForExistence(timeout: 5))
        XCTAssertTrue(element(withIdentifier: "performance.control.rail").exists)
        XCTAssertTrue(element(withIdentifier: "performance.pitch.quantized").exists)
        XCTAssertFalse(element(withIdentifier: "modulation.matrix.viewport").exists)
    }

    @MainActor
    func testMatrixRoundTrip() throws {
        let surface = element(withIdentifier: "performance.note.surface")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        element(withIdentifier: "performance.matrix").tap()
        XCTAssertTrue(element(withIdentifier: "modulation.matrix.viewport").waitForExistence(timeout: 2))
        XCTAssertTrue(element(withIdentifier: "modulation.matrix.selection.context").exists)
        element(withIdentifier: "performance.return").tap()
        XCTAssertTrue(element(withIdentifier: "performance.note.surface").waitForExistence(timeout: 2))
    }

    @MainActor
    func testPitchModeAndOctaveControls() throws {
        XCTAssertTrue(element(withIdentifier: "performance.pitch.freehand").waitForExistence(timeout: 5))
        element(withIdentifier: "performance.pitch.freehand").tap()
        XCTAssertTrue(element(withIdentifier: "performance.pitch.quantized").exists)
        element(withIdentifier: "performance.octave.up").tap()
        XCTAssertTrue(element(withIdentifier: "performance.octave.down").exists)
        element(withIdentifier: "performance.octave.down").tap()
    }

    @MainActor
    func testReleaseTouches() throws {
        let surface = element(withIdentifier: "performance.note.surface")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        surface.press(forDuration: 0.15)
        element(withIdentifier: "performance.release.touches").tap()
        XCTAssertTrue(element(withIdentifier: "performance.active.voice.count").exists)
    }

    @MainActor
    func testSingleTouchPressDragReleaseLifecycle() throws {
        let surface = element(withIdentifier: "performance.note.surface")
        XCTAssertTrue(surface.waitForExistence(timeout: 5))
        let destination = surface.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35))
        surface.press(forDuration: 0.1, thenDragTo: destination)
        XCTAssertTrue(element(withIdentifier: "performance.active.voice.count").exists)
        element(withIdentifier: "performance.release.touches").tap()
    }

    @MainActor
    private func element(withIdentifier identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
