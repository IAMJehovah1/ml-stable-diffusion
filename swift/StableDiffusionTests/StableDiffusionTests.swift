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
    
    // MARK: - Neural Engine Discovery Tests
    
    func testNeuralEngineDiscovery() throws {
        let discovery = NeuralEngineDiscovery.shared
        let capabilities = discovery.discoverCapabilities()
        
        // Verify we get valid capabilities
        XCTAssertNotEqual(capabilities.modelIdentifier, "Unknown")
        XCTAssertNotEqual(capabilities.deviceName, "Unknown Device")
        XCTAssertGreaterThan(capabilities.availableMemoryGB, 0.0)
        
        print("Detected device: \(capabilities.deviceName)")
        print("Model identifier: \(capabilities.modelIdentifier)")
        print("Neural Engine: \(capabilities.neuralEngine.description)")
    }
    
    func testNeuralEngineGenerationComparison() throws {
        // Test ordering of Neural Engine generations
        XCTAssertLessThan(NeuralEngineGeneration.a14, NeuralEngineGeneration.a15)
        XCTAssertLessThan(NeuralEngineGeneration.a15, NeuralEngineGeneration.a16)
        XCTAssertLessThan(NeuralEngineGeneration.a16, NeuralEngineGeneration.a17Pro)
        XCTAssertLessThan(NeuralEngineGeneration.m1, NeuralEngineGeneration.m2)
        XCTAssertLessThan(NeuralEngineGeneration.m2, NeuralEngineGeneration.m3)
        XCTAssertLessThan(NeuralEngineGeneration.m3, NeuralEngineGeneration.m4)
    }
    
    func testNeuralEngineCapabilities() throws {
        // Test M4 capabilities
        let m4 = NeuralEngineGeneration.m4
        XCTAssertEqual(m4.neuralEngineCores, 16)
        XCTAssertEqual(m4.neuralEngineTOPS, 38.0)
        XCTAssertTrue(m4.supportsInt8Quantization)
        XCTAssertTrue(m4.supports6BitCompression)
        XCTAssertEqual(m4.optimalComputeUnits, .cpuAndNeuralEngine)
        
        // Test A17 Pro capabilities
        let a17Pro = NeuralEngineGeneration.a17Pro
        XCTAssertTrue(a17Pro.supportsInt8Quantization)
        XCTAssertEqual(a17Pro.neuralEngineTOPS, 35.0)
        
        // Test older generations don't support int8
        let m2 = NeuralEngineGeneration.m2
        XCTAssertFalse(m2.supportsInt8Quantization)
        XCTAssertTrue(m2.supports6BitCompression)
    }
    
    func testOptimizedConfiguration() throws {
        // Test M4 optimization
        let m4Capabilities = DeviceCapabilities(
            neuralEngine: .m4,
            modelIdentifier: "iPad16,3",
            deviceName: "iPad Pro M4",
            availableMemoryGB: 8.0
        )
        
        let m4Config = NeuralEngineOptimizedConfiguration.optimized(for: m4Capabilities)
        XCTAssertEqual(m4Config.computeUnits, .cpuAndNeuralEngine)
        XCTAssertFalse(m4Config.reduceMemory)
        XCTAssertEqual(m4Config.recommendedQuantizationBits, 8)
        XCTAssertEqual(m4Config.attentionImplementation, "SPLIT_EINSUM_V2")
        
        // Test low memory device
        let lowMemCapabilities = DeviceCapabilities(
            neuralEngine: .a14,
            modelIdentifier: "iPhone13,2",
            deviceName: "iPhone 12",
            availableMemoryGB: 4.0
        )
        
        let lowMemConfig = NeuralEngineOptimizedConfiguration.optimized(for: lowMemCapabilities)
        XCTAssertTrue(lowMemConfig.reduceMemory)
        XCTAssertEqual(lowMemConfig.recommendedQuantizationBits, 6)
    }
    
    func testComputeUnitsRecommendations() throws {
        // Test that all Neural Engine generations recommend appropriate compute units
        let generations: [NeuralEngineGeneration] = [.a14, .a15, .a16, .a17Pro, .m1, .m2, .m3, .m4]
        
        for generation in generations {
            let units = generation.optimalComputeUnits
            XCTAssertEqual(units, .cpuAndNeuralEngine, "Generation \(generation.description) should recommend CPU+NE")
        }
        
        let unknown = NeuralEngineGeneration.unknown
        XCTAssertEqual(unknown.optimalComputeUnits, .all)
    }
    
    func testDeviceCapabilityPrinting() throws {
        // Test that printing capabilities doesn't crash
        let discovery = NeuralEngineDiscovery.shared
        discovery.printCapabilitiesReport()
        
        // This should succeed without throwing
        XCTAssertTrue(true)
    }
}
