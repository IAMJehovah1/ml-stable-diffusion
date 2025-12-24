// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2022 Apple Inc. All Rights Reserved.

import Foundation
import CoreML

#if canImport(UIKit)
import UIKit
#endif

/// Neural Engine hardware generation and capabilities
@available(iOS 16.2, macOS 13.1, *)
public enum NeuralEngineGeneration: Comparable {
    case a14      // iPhone 12, iPad Air 4th gen
    case a15      // iPhone 13
    case a16      // iPhone 14, iPhone 15
    case a17Pro   // iPhone 15 Pro, iPhone 16 Pro (supports int8)
    case m1       // MacBook Air/Pro M1, iPad Pro M1, Mac Mini M1
    case m2       // MacBook Air/Pro M2, iPad Pro M2, Mac Mini M2
    case m3       // MacBook Pro M3, iMac M3
    case m4       // iPad Pro M4, MacBook Pro M4 (enhanced Neural Engine)
    case unknown
    
    /// Number of Neural Engine cores
    public var neuralEngineCores: Int {
        switch self {
        case .a14, .a15, .a16:
            return 16
        case .a17Pro:
            return 16  // Enhanced performance with int8 support
        case .m1, .m2:
            return 16
        case .m3:
            return 16  // Enhanced architecture
        case .m4:
            return 16  // Next-gen architecture with advanced capabilities
        case .unknown:
            return 0
        }
    }
    
    /// Supports int8 quantization on Neural Engine
    public var supportsInt8Quantization: Bool {
        switch self {
        case .a17Pro, .m4:
            return true
        default:
            return false
        }
    }
    
    /// Supports 6-bit compression
    public var supports6BitCompression: Bool {
        return self != .unknown
    }
    
    /// Optimal compute unit configuration
    public var optimalComputeUnits: MLComputeUnits {
        switch self {
        case .unknown:
            return .all
        default:
            return .cpuAndNeuralEngine
        }
    }
    
    /// Theoretical Neural Engine TOPS (Trillions of Operations Per Second)
    public var neuralEngineTOPS: Double {
        switch self {
        case .a14:
            return 11.0
        case .a15:
            return 15.8
        case .a16:
            return 17.0
        case .a17Pro:
            return 35.0  // Significantly enhanced
        case .m1:
            return 11.0
        case .m2:
            return 15.8
        case .m3:
            return 18.0
        case .m4:
            return 38.0  // Most powerful Neural Engine to date
        case .unknown:
            return 0.0
        }
    }
    
    /// Description of the Neural Engine generation
    public var description: String {
        switch self {
        case .a14: return "A14 Bionic"
        case .a15: return "A15 Bionic"
        case .a16: return "A16 Bionic"
        case .a17Pro: return "A17 Pro"
        case .m1: return "Apple M1"
        case .m2: return "Apple M2"
        case .m3: return "Apple M3"
        case .m4: return "Apple M4"
        case .unknown: return "Unknown"
        }
    }
}

/// Device capability information including Neural Engine details
@available(iOS 16.2, macOS 13.1, *)
public struct DeviceCapabilities {
    /// Neural Engine generation
    public let neuralEngine: NeuralEngineGeneration
    
    /// Device model identifier (e.g., "iPad14,5")
    public let modelIdentifier: String
    
    /// User-friendly device name
    public let deviceName: String
    
    /// Available system memory in GB (approximate)
    public let availableMemoryGB: Double
    
    /// Recommended compute units for this device
    public var recommendedComputeUnits: MLComputeUnits {
        return neuralEngine.optimalComputeUnits
    }
    
    /// Whether device supports advanced Neural Engine features
    public var supportsAdvancedNeuralEngine: Bool {
        return neuralEngine.supportsInt8Quantization
    }
}

/// Neural Engine discovery and device capability detection
@available(iOS 16.2, macOS 13.1, *)
public class NeuralEngineDiscovery {
    
    /// Shared singleton instance
    public static let shared = NeuralEngineDiscovery()
    
    private var cachedCapabilities: DeviceCapabilities?
    
    private init() {}
    
    /// Discover and return device capabilities
    public func discoverCapabilities() -> DeviceCapabilities {
        if let cached = cachedCapabilities {
            return cached
        }
        
        let modelIdentifier = getModelIdentifier()
        let neuralEngine = detectNeuralEngineGeneration(from: modelIdentifier)
        let deviceName = getDeviceName()
        let availableMemory = getAvailableMemoryGB()
        
        let capabilities = DeviceCapabilities(
            neuralEngine: neuralEngine,
            modelIdentifier: modelIdentifier,
            deviceName: deviceName,
            availableMemoryGB: availableMemory
        )
        
        cachedCapabilities = capabilities
        return capabilities
    }
    
    /// Print detailed capabilities report
    public func printCapabilitiesReport() {
        let capabilities = discoverCapabilities()
        print("=== Neural Engine Discovery Report ===")
        print("Device: \(capabilities.deviceName)")
        print("Model: \(capabilities.modelIdentifier)")
        print("Neural Engine: \(capabilities.neuralEngine.description)")
        print("Neural Engine Cores: \(capabilities.neuralEngine.neuralEngineCores)")
        print("Neural Engine TOPS: \(capabilities.neuralEngine.neuralEngineTOPS)")
        print("Available Memory: ~\(String(format: "%.1f", capabilities.availableMemoryGB)) GB")
        print("Supports int8 Quantization: \(capabilities.neuralEngine.supportsInt8Quantization)")
        print("Supports 6-bit Compression: \(capabilities.neuralEngine.supports6BitCompression)")
        print("Recommended Compute Units: \(NeuralEngineDiscovery.computeUnitsDescription(capabilities.recommendedComputeUnits))")
        print("======================================")
    }
    
    // MARK: - Private Detection Methods
    
    /// Memory threshold below which reduced memory mode is recommended
    private static let lowMemoryThresholdGB: Double = 6.0
    
    /// Success code for sysctl system calls
    private static let sysctlSuccess: Int32 = 0
    
    private func getModelIdentifier() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
        #elseif os(macOS)
        // For macOS, use sysctl to get hardware model
        var size = 0
        guard sysctlbyname("hw.model", nil, &size, nil, 0) == Self.sysctlSuccess else {
            return "Unknown-Mac"
        }
        var model = [CChar](repeating: 0, count: size)
        guard sysctlbyname("hw.model", &model, &size, nil, 0) == Self.sysctlSuccess else {
            return "Unknown-Mac"
        }
        return String(cString: model)
        #else
        return "Unknown"
        #endif
    }
    
    private func detectNeuralEngineGeneration(from modelIdentifier: String) -> NeuralEngineGeneration {
        // Device model prefixes mapped to Neural Engine generations
        // This mapping needs updates when new devices are released
        let deviceMapping: [(prefix: String, generation: NeuralEngineGeneration)] = [
            // iPad Pro with M4 (latest)
            ("iPad16,", .m4),
            
            // iPad Pro with M2
            ("iPad14,5", .m2),
            ("iPad14,6", .m2),
            
            // iPad Pro with M1
            ("iPad13,", .m1),
            
            // iPhone 15 Pro (A17 Pro)
            ("iPhone16,1", .a17Pro),
            ("iPhone16,2", .a17Pro),
            
            // iPhone 15 (A16)
            ("iPhone15,4", .a16),
            ("iPhone15,5", .a16),
            
            // iPhone 14 Pro (A16)
            ("iPhone15,2", .a16),
            ("iPhone15,3", .a16),
            
            // iPhone 14 (A15)
            ("iPhone14,7", .a15),
            ("iPhone14,8", .a15),
            
            // iPhone 13 series (A15)
            ("iPhone14,", .a15),
            
            // iPhone 12 series (A14)
            ("iPhone13,", .a14),
            
            // MacBook with M4
            ("Mac16,", .m4),
            
            // Mac with M3
            ("Mac15,", .m3),
            
            // Mac with M2
            ("Mac14,", .m2),
            
            // Mac with M1
            ("Mac13,", .m1),
            ("Macmini9,", .m1),
        ]
        
        // Check each mapping in order
        for mapping in deviceMapping {
            if modelIdentifier.hasPrefix(mapping.prefix) || modelIdentifier.contains(mapping.prefix) {
                return mapping.generation
            }
        }
        
        return .unknown
    }
    
    private func getDeviceName() -> String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        let host = ProcessInfo.processInfo.hostName
        return host.isEmpty ? "Mac" : host
        #else
        return "Unknown Device"
        #endif
    }
    
    private func getAvailableMemoryGB() -> Double {
        let physicalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        return physicalMemory / (1024 * 1024 * 1024)  // Convert to GB
    }
    
    /// Public utility function for describing compute units
    public static func computeUnitsDescription(_ units: MLComputeUnits) -> String {
        switch units {
        case .all: return "All (CPU, GPU, Neural Engine)"
        case .cpuAndGPU: return "CPU and GPU"
        case .cpuOnly: return "CPU Only"
        case .cpuAndNeuralEngine: return "CPU and Neural Engine"
        @unknown default: return "Unknown"
        }
    }
}

/// Configuration optimized for specific Neural Engine generations
@available(iOS 16.2, macOS 13.1, *)
public struct NeuralEngineOptimizedConfiguration {
    /// Compute units to use
    public let computeUnits: MLComputeUnits
    
    /// Whether to enable reduced memory mode
    public let reduceMemory: Bool
    
    /// Recommended quantization bits (if applicable)
    public let recommendedQuantizationBits: Int?
    
    /// Recommended attention implementation
    public let attentionImplementation: String
    
    /// Create optimized configuration for detected device
    public static func optimizedForCurrentDevice() -> NeuralEngineOptimizedConfiguration {
        let capabilities = NeuralEngineDiscovery.shared.discoverCapabilities()
        return optimized(for: capabilities)
    }
    
    /// Create optimized configuration for specific capabilities
    public static func optimized(for capabilities: DeviceCapabilities) -> NeuralEngineOptimizedConfiguration {
        let neuralEngine = capabilities.neuralEngine
        
        // Determine if we should reduce memory based on available RAM
        let reduceMemory = capabilities.availableMemoryGB < NeuralEngineDiscovery.lowMemoryThresholdGB
        
        // Determine optimal quantization
        let quantizationBits: Int?
        if neuralEngine.supportsInt8Quantization {
            // M4 and A17 Pro can leverage int8 for better performance
            quantizationBits = 8
        } else if neuralEngine.supports6BitCompression {
            // Other Neural Engines benefit from 6-bit compression
            quantizationBits = 6
        } else {
            quantizationBits = nil
        }
        
        // Determine optimal attention implementation
        let attentionImplementation: String
        switch neuralEngine {
        case .m4, .a17Pro:
            // Use latest optimized implementation for newest hardware
            attentionImplementation = "SPLIT_EINSUM_V2"
        case .m3, .m2, .a16, .a15:
            attentionImplementation = "SPLIT_EINSUM_V2"
        default:
            attentionImplementation = "SPLIT_EINSUM"
        }
        
        return NeuralEngineOptimizedConfiguration(
            computeUnits: neuralEngine.optimalComputeUnits,
            reduceMemory: reduceMemory,
            recommendedQuantizationBits: quantizationBits,
            attentionImplementation: attentionImplementation
        )
    }
}
