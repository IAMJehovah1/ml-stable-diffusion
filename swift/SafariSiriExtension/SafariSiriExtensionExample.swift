//
//  SafariSiriExtensionExample.swift
//  SafariSiriExtension
//
//  Example usage of the SafariSiri Extension
//

import Foundation
import SafariServices

/// Example demonstrating SafariSiri Extension usage
class SafariSiriExtensionExample {
    
    // MARK: - Basic Usage Examples
    
    /// Example: Creating and configuring an ML profile
    static func exampleCreateProfile() {
        let profile = MLProfile()
        
        // Set custom keywords
        profile.keywords = [
            "machine learning",
            "artificial intelligence",
            "neural networks",
            "deep learning",
            "computer vision"
        ]
        
        // Set additional preferences
        profile.preferences = [
            "highlightColor": "yellow",
            "minRelevanceScore": 0.5,
            "autoHighlight": true
        ]
        
        // Save profile
        profile.saveToUserDefaults()
        
        print("ML Profile created and saved")
    }
    
    /// Example: Loading and updating an existing profile
    static func exampleUpdateProfile() {
        guard var profile = MLProfile.loadFromUserDefaults() else {
            print("No profile found, creating new one")
            exampleCreateProfile()
            return
        }
        
        // Add new keywords
        profile.keywords.append(contentsOf: [
            "Swift programming",
            "iOS development",
            "Core ML"
        ])
        
        // Update preferences
        profile.preferences["highlightPriority"] = "high"
        
        // Save updated profile
        profile.saveToUserDefaults()
        
        print("Profile updated with \(profile.keywords.count) keywords")
    }
    
    // MARK: - Content Analysis Examples
    
    /// Example: Analyzing web content
    static func exampleAnalyzeContent() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        
        let sampleContent = """
        Machine learning and artificial intelligence are transforming the tech industry.
        Neural networks enable computers to learn from data and make intelligent decisions.
        Deep learning models have achieved breakthrough results in computer vision tasks.
        """
        
        let analysis = analyzer.analyzeContent(sampleContent, profile: profile)
        
        print("Content Analysis Results:")
        print("- Sentiment: \(analysis.sentiment)")
        print("- Relevance Score: \(analysis.relevanceScore)")
        print("- Keywords found: \(analysis.keywords.joined(separator: ", "))")
        print("- Entities: \(analysis.entities.joined(separator: ", "))")
    }
    
    /// Example: Generating content suggestions
    static func exampleGenerateSuggestions() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        
        let query = "machine learning tutorials"
        let context = "Looking for resources to learn about neural networks and AI"
        
        let suggestions = analyzer.generateSuggestions(
            query: query,
            profile: profile,
            context: context
        )
        
        print("Content Suggestions:")
        for (index, suggestion) in suggestions.enumerated() {
            print("\(index + 1). \(suggestion.text)")
            print("   Relevance: \(String(format: "%.2f", suggestion.relevance))")
            print("   Category: \(suggestion.category)")
        }
    }
    
    // MARK: - Safari Extension Integration Examples
    
    /// Example: Sending message to content script
    static func exampleSendMessageToContent() {
        // This would typically be called from SafariExtensionHandler
        // when responding to user actions or Siri commands
        
        // Simulated page object (in real usage, this comes from Safari)
        // page.dispatchMessageToScript(
        //     withName: "highlightContent",
        //     userInfo: [
        //         "highlights": [
        //             ["keyword": "machine learning", "priority": 0.9],
        //             ["keyword": "AI", "priority": 0.8]
        //         ],
        //         "relevanceScore": 0.85
        //     ]
        // )
        
        print("Would send highlight message to content script")
    }
    
    /// Example: Handling Siri intent
    static func exampleHandleSiriIntent() {
        let handler = SiriIntentHandler()
        let intent = SearchAssistanceIntent()
        intent.searchQuery = "best practices for machine learning"
        
        handler.handle(intent: intent) { response in
            if response.code == .success {
                print("Siri Intent Handled Successfully")
                print("Suggestions: \(response.suggestions ?? [])")
                print("Relevance Score: \(response.relevanceScore ?? 0)")
            } else {
                print("Siri Intent Failed")
            }
        }
    }
    
    // MARK: - Advanced Usage Examples
    
    /// Example: Custom content filtering
    static func exampleCustomFiltering() {
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        
        let webpageContent = """
        This article discusses machine learning applications in healthcare.
        Recent advances in deep learning have enabled better disease diagnosis.
        Artificial intelligence is revolutionizing medical imaging analysis.
        """
        
        // Custom filtering logic
        let sentences = webpageContent.components(separatedBy: ".")
        var relevantSentences: [(String, Double)] = []
        
        for sentence in sentences {
            var score = 0.0
            for keyword in profile.keywords {
                if sentence.lowercased().contains(keyword.lowercased()) {
                    score += 1.0
                }
            }
            
            let relevance = score / Double(profile.keywords.count)
            if relevance > 0.3 {
                relevantSentences.append((sentence.trimmingCharacters(in: .whitespaces), relevance))
            }
        }
        
        print("Relevant Content:")
        for (sentence, relevance) in relevantSentences.sorted(by: { $0.1 > $1.1 }) {
            print("[\(String(format: "%.2f", relevance))] \(sentence)")
        }
    }
    
    /// Example: Batch content analysis
    static func exampleBatchAnalysis() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        
        let contents = [
            "Introduction to machine learning algorithms",
            "Best restaurants in San Francisco",
            "Neural network architectures for computer vision",
            "Travel guide to Europe",
            "Deep learning frameworks comparison"
        ]
        
        print("Batch Analysis Results:")
        for (index, content) in contents.enumerated() {
            let analysis = analyzer.analyzeContent(content, profile: profile)
            print("\(index + 1). \(content)")
            print("   Relevance: \(String(format: "%.2f", analysis.relevanceScore))")
            print("   Keywords: \(analysis.keywords.prefix(3).joined(separator: ", "))")
            print()
        }
    }
}

// MARK: - Usage

/*
 To use these examples:
 
 1. Create and configure ML profile:
    SafariSiriExtensionExample.exampleCreateProfile()
 
 2. Analyze content:
    SafariSiriExtensionExample.exampleAnalyzeContent()
 
 3. Generate suggestions:
    SafariSiriExtensionExample.exampleGenerateSuggestions()
 
 4. Handle Siri intents:
    SafariSiriExtensionExample.exampleHandleSiriIntent()
 
 5. Custom filtering:
    SafariSiriExtensionExample.exampleCustomFiltering()
 
 6. Batch analysis:
    SafariSiriExtensionExample.exampleBatchAnalysis()
 */
