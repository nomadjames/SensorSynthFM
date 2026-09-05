//
//  SensorSynthFMUITests.swift
//  SensorSynthFMUITests
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
    func testNeutralRouteCanActivateAndBeRemovedWithoutCollapsingEditor() throws {
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
        XCTAssertFalse(remove.waitForExistence(timeout: 0.5), "Neutral routes should hide removal")
    }

    @MainActor
    func testMatrixReachesOffscreenSourceAndKeepsContextQueryable() throws {
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
