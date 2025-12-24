#!/usr/bin/env swift

// Neural Engine Discovery Example
// This script demonstrates how to use the Neural Engine discovery API

import Foundation
import CoreML

#if canImport(StableDiffusion)
import StableDiffusion

@available(iOS 16.2, macOS 13.1, *)
func main() {
    print("🧠 Neural Engine Discovery Example\n")
    print("===================================\n")
    
    // 1. Discover device capabilities
    let discovery = NeuralEngineDiscovery.shared
    let capabilities = discovery.discoverCapabilities()
    
    print("📱 Device Information:")
    print("   Name: \(capabilities.deviceName)")
    print("   Model: \(capabilities.modelIdentifier)")
    print("   Memory: ~\(String(format: "%.1f", capabilities.availableMemoryGB)) GB\n")
    
    print("🔧 Neural Engine Details:")
    print("   Generation: \(capabilities.neuralEngine.description)")
    print("   Cores: \(capabilities.neuralEngine.neuralEngineCores)")
    print("   Performance: \(capabilities.neuralEngine.neuralEngineTOPS) TOPS")
    print("   int8 Support: \(capabilities.neuralEngine.supportsInt8Quantization ? "✅" : "❌")")
    print("   6-bit Compression: \(capabilities.neuralEngine.supports6BitCompression ? "✅" : "❌")\n")
    
    // 2. Get optimized configuration
    let optimizedConfig = NeuralEngineOptimizedConfiguration.optimized(for: capabilities)
    
    print("⚙️  Recommended Configuration:")
    print("   Compute Units: \(computeUnitsName(optimizedConfig.computeUnits))")
    print("   Memory Mode: \(optimizedConfig.reduceMemory ? "Reduced" : "Normal")")
    print("   Attention: \(optimizedConfig.attentionImplementation)")
    
    if let bits = optimizedConfig.recommendedQuantizationBits {
        print("   Quantization: \(bits)-bit")
    }
    print()
    
    // 3. Special notes for M4
    if capabilities.neuralEngine == .m4 {
        print("🎉 iPad Pro M4 Detected!")
        print("   You have the most powerful Neural Engine available!")
        print("   Expected performance for SD 2.1 (512x512, 20 steps): ~5 seconds")
        print("   Recommended model conversion:")
        print("   python -m python_coreml_stable_diffusion.torch2coreml \\")
        print("     --compute-unit CPU_AND_NE \\")
        print("     --attention-implementation SPLIT_EINSUM_V2 \\")
        print("     --quantize-nbits 8 \\")
        print("     --chunk-unet")
        print()
    }
    
    // 4. Print full capabilities report
    print("\n📊 Full Capabilities Report:")
    print("================================")
    discovery.printCapabilitiesReport()
    
    print("\n✅ Discovery complete!")
}

func computeUnitsName(_ units: MLComputeUnits) -> String {
    switch units {
    case .all: return "All (CPU + GPU + Neural Engine)"
    case .cpuAndGPU: return "CPU + GPU"
    case .cpuOnly: return "CPU Only"
    case .cpuAndNeuralEngine: return "CPU + Neural Engine"
    @unknown default: return "Unknown"
    }
}

if #available(iOS 16.2, macOS 13.1, *) {
    main()
} else {
    print("❌ This example requires iOS 16.2+ or macOS 13.1+")
}

#else
print("❌ StableDiffusion module not available")
print("Build the project first: swift build")
#endif
