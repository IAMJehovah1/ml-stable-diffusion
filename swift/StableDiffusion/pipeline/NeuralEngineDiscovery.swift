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
        print("Recommended Compute Units: \(computeUnitsDescription(capabilities.recommendedComputeUnits))")
        print("======================================")
    }
    
    // MARK: - Private Detection Methods
    
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
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        return String(cString: model)
        #else
        return "Unknown"
        #endif
    }
    
    private func detectNeuralEngineGeneration(from modelIdentifier: String) -> NeuralEngineGeneration {
        // iPad Pro with M4
        if modelIdentifier.hasPrefix("iPad16,") {
            return .m4
        }
        
        // iPad Pro with M2
        if modelIdentifier.hasPrefix("iPad14,5") || modelIdentifier.hasPrefix("iPad14,6") {
            return .m2
        }
        
        // iPad Pro with M1
        if modelIdentifier.hasPrefix("iPad13,") {
            return .m1
        }
        
        // iPhone 15 Pro (A17 Pro)
        if modelIdentifier.hasPrefix("iPhone16,1") || modelIdentifier.hasPrefix("iPhone16,2") {
            return .a17Pro
        }
        
        // iPhone 15 (A16)
        if modelIdentifier.hasPrefix("iPhone15,4") || modelIdentifier.hasPrefix("iPhone15,5") {
            return .a16
        }
        
        // iPhone 14 Pro (A16)
        if modelIdentifier.hasPrefix("iPhone15,2") || modelIdentifier.hasPrefix("iPhone15,3") {
            return .a16
        }
        
        // iPhone 14 (A15)
        if modelIdentifier.hasPrefix("iPhone14,7") || modelIdentifier.hasPrefix("iPhone14,8") {
            return .a15
        }
        
        // iPhone 13 series (A15)
        if modelIdentifier.hasPrefix("iPhone14,") {
            return .a15
        }
        
        // iPhone 12 series (A14)
        if modelIdentifier.hasPrefix("iPhone13,") {
            return .a14
        }
        
        // MacBook with M4
        if modelIdentifier.contains("Mac16,") {
            return .m4
        }
        
        // Mac with M3
        if modelIdentifier.contains("Mac15,") {
            return .m3
        }
        
        // Mac with M2
        if modelIdentifier.contains("Mac14,") {
            return .m2
        }
        
        // Mac with M1
        if modelIdentifier.contains("Mac13,") || modelIdentifier.contains("Macmini9,") {
            return .m1
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
    
    private func computeUnitsDescription(_ units: MLComputeUnits) -> String {
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
        let reduceMemory = capabilities.availableMemoryGB < 6.0
        
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
