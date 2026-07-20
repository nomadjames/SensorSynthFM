//
//  SensorSynthFMApp.swift
//  SensorSynthFM
//
//  Created by nomad james on 2/16/26.
//

import Foundation
import SwiftUI

nonisolated enum SensorSynthFMRuntimeMode {
    static func shouldStart(environment: [String: String]) -> Bool {
        environment["XCTestConfigurationFilePath"] == nil
    }
}

@main
struct SensorSynthFMApp: App {
    var body: some Scene {
        WindowGroup {
            if SensorSynthFMRuntimeMode.shouldStart(environment: ProcessInfo.processInfo.environment) {
                SensorFMTestView()
            } else {
                Color.clear
            }
        }
    }
}
