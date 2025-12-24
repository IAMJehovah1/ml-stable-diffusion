# Examples

This directory contains example scripts demonstrating the Neural Engine discovery and optimization features.

## Neural Engine Discovery

### `neural_engine_discovery.swift`

A standalone example demonstrating how to:
- Detect device capabilities (M4, M3, M2, M1, A-series)
- Get Neural Engine specifications (cores, TOPS, features)
- Retrieve optimized configuration recommendations
- Display device-specific guidance

**Usage:**

```bash
# Run the example (requires building the project first)
cd ml-stable-diffusion
swift build
swift examples/neural_engine_discovery.swift
```

**Expected Output:**

```
🧠 Neural Engine Discovery Example
===================================

📱 Device Information:
   Name: My iPad Pro
   Model: iPad16,3
   Memory: ~8.0 GB

🔧 Neural Engine Details:
   Generation: Apple M4
   Cores: 16
   Performance: 38.0 TOPS
   int8 Support: ✅
   6-bit Compression: ✅

⚙️  Recommended Configuration:
   Compute Units: CPU + Neural Engine
   Memory Mode: Normal
   Attention: SPLIT_EINSUM_V2
   Quantization: 8-bit

🎉 iPad Pro M4 Detected!
   You have the most powerful Neural Engine available!
   Expected performance for SD 2.1 (512x512, 20 steps): ~5 seconds
   Recommended model conversion:
   python -m python_coreml_stable_diffusion.torch2coreml \
     --compute-unit CPU_AND_NE \
     --attention-implementation SPLIT_EINSUM_V2 \
     --quantize-nbits 8 \
     --chunk-unet

📊 Full Capabilities Report:
================================
=== Neural Engine Discovery Report ===
...
```

## Integration Examples

### Swift Package Example

```swift
import StableDiffusion
import CoreML

// Discover and use optimal settings
let discovery = NeuralEngineDiscovery.shared
let capabilities = discovery.discoverCapabilities()

// Create pipeline with auto-optimization
let pipeline = try StableDiffusionPipeline.createWithNeuralEngineDiscovery(
    resourcesAt: modelURL,
    printDiscoveryReport: true
)

// Generate images
let config = PipelineConfiguration(prompt: "a beautiful sunset")
let images = try pipeline.generateImages(configuration: config) { progress in
    print("Progress: \(progress.step)/\(progress.stepCount)")
    return true
}
```

### Manual Configuration Example

```swift
import StableDiffusion
import CoreML

// Get device-specific optimized configuration
let capabilities = NeuralEngineDiscovery.shared.discoverCapabilities()
let optimized = NeuralEngineOptimizedConfiguration.optimized(for: capabilities)

// Apply to ML model configuration
let config = MLModelConfiguration()
config.computeUnits = optimized.computeUnits

// Create pipeline
let pipeline = try StableDiffusionPipeline(
    resourcesAt: modelURL,
    configuration: config,
    reduceMemory: optimized.reduceMemory
)
```

### CLI Examples

```bash
# Discover Neural Engine capabilities
swift run StableDiffusionSample discover

# Discover with verbose details
swift run StableDiffusionSample discover --verbose

# Generate with auto-optimization
swift run StableDiffusionSample generate "a beautiful sunset" \
  --resource-path ./models \
  --auto-optimize \
  --output-path ./output

# Generate with manual compute unit selection
swift run StableDiffusionSample generate "a beautiful sunset" \
  --resource-path ./models \
  --compute-units cpuAndNeuralEngine \
  --output-path ./output
```

## More Information

For complete documentation, see [NEURAL_ENGINE_GUIDE.md](../NEURAL_ENGINE_GUIDE.md)
