#!/usr/bin/env swift

//
//  RunExtensionDemo.swift
//  Demonstrates the SafariSiri Extension functionality
//

import Foundation

// Since we're on Linux, we'll simulate the extension behavior
// by demonstrating the core ML functionality without Safari-specific APIs

print("╔══════════════════════════════════════════════════════════════════════╗")
print("║                                                                      ║")
print("║        SafariSiri Extension - Demonstration                          ║")
print("║                                                                      ║")
print("╚══════════════════════════════════════════════════════════════════════╝")
print()

// Simulate ML Profile
class MLProfile {
    var keywords: [String]
    var preferences: [String: Any]
    var lastUpdated: Date
    
    init() {
        self.keywords = ["technology", "science", "innovation", "AI", "machine learning"]
        self.preferences = [:]
        self.lastUpdated = Date()
    }
    
    func update(with newPreferences: [String: Any]) {
        if let newKeywords = newPreferences["keywords"] as? [String] {
            self.keywords = newKeywords
        }
        self.preferences = newPreferences
        self.lastUpdated = Date()
    }
}

// Simulate Content Analysis
struct ContentAnalysis {
    let keywords: [String]
    let relevanceScore: Double
}

class ContentAnalyzer {
    func analyzeContent(_ text: String, profile: MLProfile) -> ContentAnalysis {
        let textLower = text.lowercased()
        var foundKeywords: [String] = []
        var score = 0.0
        
        for keyword in profile.keywords {
            if textLower.contains(keyword.lowercased()) {
                foundKeywords.append(keyword)
                score += 1.0
            }
        }
        
        let relevance = score / max(Double(profile.keywords.count), 1.0)
        return ContentAnalysis(keywords: foundKeywords, relevanceScore: min(relevance, 1.0))
    }
    
    func generateSuggestions(query: String, profile: MLProfile, context: String) -> [String] {
        let queryLower = query.lowercased()
        return profile.keywords.filter { keyword in
            queryLower.contains(keyword.lowercased()) || 
            keyword.lowercased().contains(queryLower)
        }
    }
}

// Demo 1: Create and configure ML Profile
print("🎯 Demo 1: Creating ML Profile")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
let profile = MLProfile()
print("✓ Created profile with keywords: \(profile.keywords.joined(separator: ", "))")
print()

// Demo 2: Analyze web content
print("🧠 Demo 2: Analyzing Web Content")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
let sampleContent = """
Machine learning and artificial intelligence are transforming the tech industry.
Neural networks enable computers to learn from data and make intelligent decisions.
Recent advances in deep learning have achieved breakthrough results in science and innovation.
"""
print("Sample web content:")
print("  \"\(sampleContent.split(separator: "\n").joined(separator: "\n  "))\"")
print()

let analyzer = ContentAnalyzer()
let analysis = analyzer.analyzeContent(sampleContent, profile: profile)

print("Analysis Results:")
print("  • Relevance Score: \(String(format: "%.2f", analysis.relevanceScore * 100))%")
print("  • Keywords Found: \(analysis.keywords.joined(separator: ", "))")
print()

// Demo 3: Generate suggestions for search query
print("💡 Demo 3: Generating Search Suggestions")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
let query = "machine learning tutorials"
let context = "Looking for resources to learn about AI"
print("Search Query: \"\(query)\"")
print("Context: \"\(context)\"")
print()

let suggestions = analyzer.generateSuggestions(query: query, profile: profile, context: context)
print("Generated Suggestions:")
for (index, suggestion) in suggestions.enumerated() {
    print("  \(index + 1). \(suggestion)")
}
print()

// Demo 4: Content highlighting simulation
print("🎨 Demo 4: Content Highlighting Simulation")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Original content:")
print("  \"This article discusses machine learning and AI technology.\"")
print()
print("Highlighted content (keywords marked with [HIGHLIGHT]):")
let testContent = "This article discusses machine learning and AI technology."
var highlightedContent = testContent
for keyword in analysis.keywords {
    if testContent.lowercased().contains(keyword.lowercased()) {
        // Simple case-insensitive replacement for demo
        let range = testContent.range(of: keyword, options: .caseInsensitive)
        if let range = range {
            let original = String(testContent[range])
            highlightedContent = highlightedContent.replacingOccurrences(
                of: original,
                with: "[HIGHLIGHT]\(original)[/HIGHLIGHT]"
            )
        }
    }
}
print("  \"\(highlightedContent)\"")
print()

// Demo 5: Profile customization
print("⚙️  Demo 5: Customizing ML Profile")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Original keywords: \(profile.keywords.joined(separator: ", "))")
profile.update(with: ["keywords": ["Swift", "iOS", "CoreML", "programming"]])
print("Updated keywords: \(profile.keywords.joined(separator: ", "))")
print()

let newContent = "This Swift tutorial covers iOS development with CoreML."
let newAnalysis = analyzer.analyzeContent(newContent, profile: profile)
print("Analyzing new content with updated profile:")
print("  Content: \"\(newContent)\"")
print("  Relevance Score: \(String(format: "%.2f", newAnalysis.relevanceScore * 100))%")
print("  Keywords Found: \(newAnalysis.keywords.joined(separator: ", "))")
print()

// Demo 6: Siri Integration (simulated)
print("🗣️  Demo 6: Siri Integration (Simulated)")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("Siri Command: \"Hey Siri, help me with Swift programming\"")
print()
let siriQuery = "Swift programming"
let siriSuggestions = analyzer.generateSuggestions(
    query: siriQuery,
    profile: profile,
    context: ""
)
print("Siri Response:")
print("  \"I found \(siriSuggestions.count) relevant topics for you:\"")
for suggestion in siriSuggestions {
    print("    • \(suggestion)")
}
print()

// Summary
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
print("✅ Demo Complete!")
print()
print("📝 To run this extension in Safari:")
print("   1. Build: swift build")
print("   2. Enable in Safari → Preferences → Extensions")
print("   3. Click toolbar button or use Siri commands")
print()
print("📚 Documentation:")
print("   • README: swift/SafariSiriExtension/README.md")
print("   • Quick Start: swift/SafariSiriExtension/QUICKSTART.md")
print("   • Architecture: swift/SafariSiriExtension/ARCHITECTURE.md")
print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
