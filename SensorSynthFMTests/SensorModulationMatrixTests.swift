// SensorModulationMatrixTests.swift
// SensorSynthFMTests

import Testing
@testable import SensorSynthFM

struct SensorModulationMatrixTests {
    @Test func defaultRoutesMatchOldMappingsAtLowMidHigh() {
        let matrix = SensorModulationMatrix.defaultMatrix()

        for input in [0.0, 0.5, 1.0] {
            var sources = SensorModulationSourceValues()
            sources.accelMagnitude = input
            #expect(close(matrix.evaluate(sources: sources).modulationIndex, input * 4.0))
        }

        for input in [0.0, 0.5, 1.0] {
            var sources = SensorModulationSourceValues()
            sources.micAmplitude = input
            #expect(close(matrix.evaluate(sources: sources).amplitude, 0.1 + input * 0.75))
        }

        for input in [0.0, 0.5, 1.0] {
            var sources = SensorModulationSourceValues()
            sources.gyroY = input
            #expect(close(matrix.evaluate(sources: sources).modulatorRatio, 4.25 + (input - 0.5) * 7.5))
        }
    }

    @Test func nonDefaultSourceCanRouteToEachTarget() {
        for target in SensorModulationTarget.allCases {
            var matrix = SensorModulationMatrix(seedDefaults: false)
            matrix.setBaseValue(target.range.lowerBound, for: target)
            matrix.setAmount(0.25, source: .roomEnergy, target: target)

            var sources = SensorModulationSourceValues()
            sources.roomEnergy = 1.0

            let output = matrix.evaluate(sources: sources)
            #expect(output.value(for: target) > target.range.lowerBound)
        }
    }

    @Test func multipleContributionsSumAndClamp() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        matrix.setBaseValue(0.9, for: .amplitude)
        matrix.setAmount(0.4, source: .micAmplitude, target: .amplitude)
        matrix.setAmount(0.4, source: .roomEnergy, target: .amplitude)

        var sources = SensorModulationSourceValues()
        sources.micAmplitude = 1.0
        sources.roomEnergy = 1.0

        let output = matrix.evaluate(sources: sources)
        #expect(close(output.amplitude, 1.0))
        #expect(output.isClamped(.amplitude))
    }

    @Test func gyroYIsNeutralAtCenter() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        matrix.setBaseValue(4.25, for: .modulatorRatio)
        matrix.setAmount(0.5, source: .gyroY, target: .modulatorRatio)

        var sources = SensorModulationSourceValues()
        sources.gyroY = 0.5

        #expect(close(matrix.evaluate(sources: sources).modulatorRatio, 4.25))
    }

    @Test func negativeAmountInverts() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        matrix.setBaseValue(0.8, for: .amplitude)
        matrix.setAmount(-0.5, source: .micAmplitude, target: .amplitude)

        var sources = SensorModulationSourceValues()
        sources.micAmplitude = 1.0

        #expect(close(matrix.evaluate(sources: sources).amplitude, 0.3))
    }

    @Test func evaluationDoesNotMutateBaseValues() {
        var matrix = SensorModulationMatrix.defaultMatrix()
        matrix.setBaseValue(7.0, for: .modulationIndex)
        let before = matrix.baseValue(for: .modulationIndex)

        var sources = SensorModulationSourceValues()
        sources.accelMagnitude = 1.0
        _ = matrix.evaluate(sources: sources)

        #expect(close(matrix.baseValue(for: .modulationIndex), before))
    }

    @Test func sceneBaseApplicationPreservesMatrixAmounts() {
        var matrix = SensorModulationMatrix(seedDefaults: false)
        matrix.setAmount(0.33, source: .surfaceImpact, target: .carrierFrequency)

        matrix.applyBase(
            carrierFrequency: 330,
            modulatorRatio: 6,
            modulationIndex: 3,
            amplitude: 0.42
        )

        #expect(close(matrix.amount(source: .surfaceImpact, target: .carrierFrequency), 0.33))
        #expect(close(matrix.baseValue(for: .carrierFrequency), 330))
        #expect(close(matrix.baseValue(for: .modulatorRatio), 6))
        #expect(close(matrix.baseValue(for: .modulationIndex), 3))
        #expect(close(matrix.baseValue(for: .amplitude), 0.42))
    }

    private func close(_ lhs: Double, _ rhs: Double, tolerance: Double = 0.000_001) -> Bool {
        abs(lhs - rhs) <= tolerance
    }
}
