//
//  SensorSynthFMApp.swift
//  SensorSynthFM
//
//  Created by nomad james on 2/16/26.
//

import Foundation
import SwiftUI

nonisolated enum SensorSynthFMRuntimeMode {
    static let uiTestingLaunchArgument = "-ui-testing"

    static func isUITesting(arguments: [String]) -> Bool {
        arguments.contains(uiTestingLaunchArgument)
    }

    static func shouldStart(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }

    static func shouldRenderSurface(environment: [String: String], arguments: [String]) -> Bool {
        isUITesting(arguments: arguments) || shouldStart(environment: environment)
    }

    static func shouldStartLiveRuntime(environment: [String: String], arguments: [String]) -> Bool {
        shouldStart(environment: environment) && !isUITesting(arguments: arguments)
    }
}

@main
struct SensorSynthFMApp: App {
    var body: some Scene {
        WindowGroup {
            if SensorSynthFMRuntimeMode.shouldRenderSurface(environment: ProcessInfo.processInfo.environment, arguments: ProcessInfo.processInfo.arguments) {
                SensorFMTestView(startLiveRuntime: SensorSynthFMRuntimeMode.shouldStartLiveRuntime(environment: ProcessInfo.processInfo.environment, arguments: ProcessInfo.processInfo.arguments))
            } else {
                Color.clear
            }
        }
    }
}
