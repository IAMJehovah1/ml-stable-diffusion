// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2022 Apple Inc. All Rights Reserved.

import XCTest
import CoreML
@testable import StableDiffusion

@available(iOS 16.2, macOS 13.1, *)
final class StableDiffusionTests: XCTestCase {

    var vocabFileInBundleURL: URL {
        let fileName = "vocab"
        guard let url = Bundle.module.url(forResource: fileName, withExtension: "json") else {
            fatalError("BPE tokenizer vocabulary file is missing from bundle")
        }
        return url
    }

    var mergesFileInBundleURL: URL {
        let fileName = "merges"
        guard let url = Bundle.module.url(forResource: fileName, withExtension: "txt") else {
            fatalError("BPE tokenizer merges file is missing from bundle")
        }
        return url
    }

    func testBPETokenizer() throws {

        let tokenizer = try BPETokenizer(mergesAt: mergesFileInBundleURL, vocabularyAt: vocabFileInBundleURL)

        func testPrompt(prompt: String, expectedIds: [Int]) {

            let (tokens, ids) = tokenizer.tokenize(input: prompt)

            print("Tokens          = \(tokens)\n")
            print("Expected tokens = \(expectedIds.map({ tokenizer.token(id: $0) }))")
            print("ids             = \(ids)\n")
            print("Expected Ids    = \(expectedIds)\n")

            XCTAssertEqual(ids,expectedIds)
        }

        testPrompt(prompt: "a photo of an astronaut riding a horse on mars",
                   expectedIds: [49406, 320, 1125, 539, 550, 18376, 6765, 320, 4558, 525, 7496, 49407])

        testPrompt(prompt: "Apple CoreML developer tools on a Macbook Air are fast",
                   expectedIds: [49406,  3055, 19622,  5780, 10929,  5771,   525,   320, 20617,
                                 1922,   631,  1953, 49407])
    }

    func test_randomNormalValues_matchNumPyRandom() {
        var random = NumPyRandomSource(seed: 12345)
        let samples = random.normalArray(count: 10_000)
        let last5 = samples.suffix(5)

        // numpy.random.seed(12345); print(numpy.random.randn(10000)[-5:])
        let expected = [-0.86285345, 2.15229409, -0.00670556, -1.21472309, 0.65498866]

        for (value, expected) in zip(last5, expected) {
            XCTAssertEqual(value, expected, accuracy: .ulpOfOne.squareRoot())
        }
    }

    // MARK: - NeuralEngineDetector Tests

    func test_neuralEngineDetector_hasNeuralEngine_returnsBoolWithoutCrashing() {
        // `hasNeuralEngine` should always return a value without crashing,
        // regardless of the host machine architecture.
        let result = NeuralEngineDetector.hasNeuralEngine
        // On Apple Silicon test machines this must be true; on Intel it must be false.
        #if arch(arm64)
        XCTAssertTrue(result, "hasNeuralEngine must be true on arm64 hardware")
        #else
        XCTAssertFalse(result, "hasNeuralEngine must be false on non-arm64 hardware")
        #endif
    }

    func test_neuralEngineDetector_chipGeneration_returnsValidValue() {
        // chipGeneration must return one of the known enum cases and must not crash.
        let gen = NeuralEngineDetector.chipGeneration
        let validCases: [NeuralEngineDetector.ChipGeneration] = [.m1, .m2, .m3, .m4, .unknown]
        XCTAssertTrue(validCases.contains(gen), "chipGeneration returned an unexpected value: \(gen)")
    }

    func test_neuralEngineDetector_chipGeneration_consistentWithHasNeuralEngine() {
        // When the chip generation is a known M-series chip, hasNeuralEngine must be true.
        let gen = NeuralEngineDetector.chipGeneration
        if gen != .unknown {
            XCTAssertTrue(
                NeuralEngineDetector.hasNeuralEngine,
                "A known M-series chip was detected but hasNeuralEngine returned false"
            )
        }
    }

    func test_neuralEngineDetector_recommendedComputeUnits_matchesHasNeuralEngine() {
        // recommendedComputeUnits should align with hasNeuralEngine.
        let recommended = NeuralEngineDetector.recommendedComputeUnits
        if NeuralEngineDetector.hasNeuralEngine {
            XCTAssertEqual(
                recommended,
                .cpuAndNeuralEngine,
                "Expected cpuAndNeuralEngine when Neural Engine is present"
            )
        } else {
            XCTAssertEqual(
                recommended,
                .cpuAndGPU,
                "Expected cpuAndGPU when Neural Engine is absent"
            )
        }
    }

    func test_neuralEngineDetector_optimizedConfiguration_setsRecommendedComputeUnits() {
        let config = NeuralEngineDetector.optimizedConfiguration()
        XCTAssertEqual(
            config.computeUnits,
            NeuralEngineDetector.recommendedComputeUnits,
            "optimizedConfiguration() must set compute units to the recommended value"
        )
    }

    func test_neuralEngineDetector_isM4OrNewer_consistentWithChipGeneration() {
        let isM4 = NeuralEngineDetector.isM4OrNewer
        let gen = NeuralEngineDetector.chipGeneration
        if gen == .m4 {
            XCTAssertTrue(isM4, "isM4OrNewer must be true when chipGeneration is .m4")
        } else {
            XCTAssertFalse(isM4, "isM4OrNewer must be false when chipGeneration is not .m4")
        }
    }
}
