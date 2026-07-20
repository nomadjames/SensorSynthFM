//
//  SensorSynthFMTests.swift
//  SensorSynthFMTests
//
//  Created by nomad james on 2/16/26.
//

import Testing
@testable import SensorSynthFM

struct SensorSynthFMTests {

    @Test func audioSampleSnapshotRoundTripsAtomically() {
        let snapshot = AudioSampleSnapshot()
        snapshot.store(rms: 0.1, low: 0.2, mid: 0.3, high: 0.4, tapFrames: 512)
        let sample = snapshot.load()

        #expect(sample.rms == 0.1)
        #expect(sample.low == 0.2)
        #expect(sample.mid == 0.3)
        #expect(sample.high == 0.4)
        #expect(sample.tapFrames == 512)
    }

    @Test func runtimeIsSuppressedForHostedUnitTests() {
        #expect(
            !SensorSynthFMRuntimeMode.shouldStart(
                environment: ["XCTestConfigurationFilePath": "/tmp/tests.xctestconfiguration"]
            )
        )
    }

    @Test func runtimeStartsOutsideHostedUnitTests() {
        #expect(SensorSynthFMRuntimeMode.shouldStart(environment: [:]))
    }

}
