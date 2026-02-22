// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2022 Apple Inc. All Rights Reserved.

import CoreML
import Foundation

/// Utilities for detecting Neural Engine availability and Apple Silicon chip
/// generation at runtime.
///
/// All Apple Silicon devices (M1 and later) include a Neural Engine, so
/// ``hasNeuralEngine`` is equivalent to an arm64 architecture check.
/// ``chipGeneration`` provides finer-grained identification to allow callers
/// to apply generation-specific optimizations—for example, the M4 Neural
/// Engine offers roughly double the compute throughput of the M3 (38 TOPS vs
/// 18 TOPS), making ``cpuAndNeuralEngine`` especially beneficial on M4 devices.
@available(iOS 16.2, macOS 13.1, *)
public struct NeuralEngineDetector {

    // MARK: - Chip Generation

    /// Represents an Apple Silicon chip generation.
    public enum ChipGeneration: String, Sendable {
        /// Apple M1 / A14 Bionic (Firestorm / Icestorm cores)
        case m1 = "M1"
        /// Apple M2 / A15–A16 Bionic (Avalanche / Blizzard cores)
        case m2 = "M2"
        /// Apple M3 / A17 Pro (Everest / Sawtooth cores)
        case m3 = "M3"
        /// Apple M4 / A18 (Donan / Brava cores)
        case m4 = "M4"
        /// Apple Silicon chip of an unrecognised (likely newer) generation
        case unknown = "Unknown"
    }

    // ARM CPU family identifiers from Apple's open-source XNU kernel.
    // Each constant encodes the high-performance / efficiency core pair for
    // a particular chip generation.
    private static let cpuFamilyM1: UInt32 = 0x1B588BB3 // Firestorm / Icestorm
    private static let cpuFamilyM2: UInt32 = 0xDA33D83D // Avalanche / Blizzard
    private static let cpuFamilyM3: UInt32 = 0x8765EDEA // Everest / Sawtooth
    private static let cpuFamilyM4: UInt32 = 0xFA33415E // Donan / Brava

    // MARK: - Public API

    /// `true` if the current device has a Neural Engine.
    ///
    /// All Apple Silicon (arm64) devices include a dedicated Neural Engine,
    /// so this property returns `true` on any M-series Mac, iPad, or iPhone.
    public static var hasNeuralEngine: Bool {
        #if arch(arm64)
        return true
        #else
        return false
        #endif
    }

    /// The Apple Silicon chip generation running on this device.
    ///
    /// Detection is performed by querying the ``hw.cpufamily`` sysctl key and
    /// matching the result against known constants.  Returns ``unknown`` when
    /// on Apple Silicon but the family value is unrecognised (future chip), or
    /// when running on non-Apple-Silicon hardware.
    public static var chipGeneration: ChipGeneration {
        #if arch(arm64)
        var value: UInt32 = 0
        var size = MemoryLayout<UInt32>.size
        sysctlbyname("hw.cpufamily", &value, &size, nil, 0)
        switch value {
        case cpuFamilyM1: return .m1
        case cpuFamilyM2: return .m2
        case cpuFamilyM3: return .m3
        case cpuFamilyM4: return .m4
        default:          return .unknown
        }
        #else
        return .unknown
        #endif
    }

    /// `true` when running on an M4 chip.
    ///
    /// Use this to conditionally apply M4-specific pipeline optimisations.
    public static var isM4OrNewer: Bool {
        chipGeneration == .m4
    }

    /// The `MLComputeUnits` value recommended for the current device.
    ///
    /// - Returns `.cpuAndNeuralEngine` on Apple Silicon (Neural Engine available).
    /// - Returns `.cpuAndGPU` on non-Apple-Silicon hardware.
    public static var recommendedComputeUnits: MLComputeUnits {
        hasNeuralEngine ? .cpuAndNeuralEngine : .cpuAndGPU
    }

    /// Returns an `MLModelConfiguration` pre-configured for the current device.
    ///
    /// The compute units are set to ``recommendedComputeUnits``.  On M4
    /// devices this means ``cpuAndNeuralEngine``, directing the Core ML
    /// runtime to maximise Neural Engine utilisation.
    ///
    /// - Parameter base: An existing configuration to start from.  Defaults
    ///   to a fresh `MLModelConfiguration()`.
    /// - Returns: A copy of `base` with the compute units updated.
    public static func optimizedConfiguration(
        for base: MLModelConfiguration = .init()
    ) -> MLModelConfiguration {
        let config = base
        config.computeUnits = recommendedComputeUnits
        return config
    }
}
