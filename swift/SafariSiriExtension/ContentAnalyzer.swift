//
//  ContentAnalyzer.swift
//  SafariSiriExtension
//
//  ML-powered content analysis using Core ML
//

import Foundation
import CoreML
import NaturalLanguage

/// Content analyzer using machine learning
class ContentAnalyzer {
    
    private let sentimentPredictor: NLModel?
    private let tagger: NLTagger
    
    init() {
        // Initialize sentiment analysis model
        self.sentimentPredictor = try? NLModel(mlModel: MLModel())
        
        // Initialize NL tagger for entity recognition
        self.tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    }
    
    // MARK: - Public Methods
    
    /// Analyze content and return relevance scores
    func analyzeContent(_ text: String, profile: MLProfile) -> ContentAnalysis {
        let sentiment = analyzeSentiment(text)
        let entities = extractEntities(text)
        let keywords = extractKeywords(text)
        let relevance = calculateRelevance(text: text, profile: profile)
        
        return ContentAnalysis(
            sentiment: sentiment,
            entities: entities,
            keywords: keywords,
            relevanceScore: relevance
        )
    }
    
    /// Generate content suggestions based on query and profile
    func generateSuggestions(query: String, profile: MLProfile, context: String) -> [ContentSuggestion] {
        let queryKeywords = extractKeywords(query)
        let contextKeywords = extractKeywords(context)
        
        var suggestions: [ContentSuggestion] = []
        
        // Match profile keywords with query and context
        for keyword in profile.keywords {
            let queryRelevance = calculateKeywordRelevance(keyword, in: queryKeywords)
            let contextRelevance = calculateKeywordRelevance(keyword, in: contextKeywords)
            let totalRelevance = (queryRelevance + contextRelevance) / 2.0
            
            if totalRelevance > 0.3 {
                suggestions.append(ContentSuggestion(
                    text: keyword,
                    relevance: totalRelevance,
                    category: categorizeSuggestion(keyword)
                ))
            }
        }
        
        // Sort by relevance
        suggestions.sort { $0.relevance > $1.relevance }
        
        return Array(suggestions.prefix(10))
    }
    
    // MARK: - Private Methods
    
    private func analyzeSentiment(_ text: String) -> Double {
        // Use NLTagger for basic sentiment analysis
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        
        let (sentiment, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        
        if let sentimentValue = sentiment, let score = Double(sentimentValue.rawValue) {
            return score
        }
        
        return 0.0 // Neutral
    }
    
    private func extractEntities(_ text: String) -> [String] {
        tagger.string = text
        var entities: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, range in
            if let tag = tag {
                let entity = String(text[range])
                entities.append(entity)
            }
            return true
        }
        
        return entities
    }
    
    private func extractKeywords(_ text: String) -> [String] {
        let embedding = NLEmbedding.sentenceEmbedding(for: .english)
        
        // Simple keyword extraction using lexical analysis
        tagger.string = text
        var keywords: [String] = []
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun || tag == .verb {
                let word = String(text[range])
                if word.count > 3 { // Filter short words
                    keywords.append(word.lowercased())
                }
            }
            return true
        }
        
        return Array(Set(keywords)) // Remove duplicates
    }
    
    private func calculateRelevance(text: String, profile: MLProfile) -> Double {
        let textLower = text.lowercased()
        var totalScore = 0.0
        
        for keyword in profile.keywords {
            if textLower.contains(keyword.lowercased()) {
                totalScore += 1.0
            }
        }
        
        let relevance = totalScore / max(Double(profile.keywords.count), 1.0)
        return min(relevance, 1.0)
    }
    
    private func calculateKeywordRelevance(_ keyword: String, in keywords: [String]) -> Double {
        let keywordLower = keyword.lowercased()
        
        for kw in keywords {
            if kw.lowercased() == keywordLower {
                return 1.0
            } else if kw.lowercased().contains(keywordLower) || keywordLower.contains(kw.lowercased()) {
                return 0.7
            }
        }
        
        return 0.0
    }
    
    private func categorizeSuggestion(_ keyword: String) -> String {
        let techKeywords = ["ai", "ml", "technology", "software", "code", "programming"]
        let scienceKeywords = ["science", "research", "study", "experiment", "data"]
        
        let keywordLower = keyword.lowercased()
        
        if techKeywords.contains(where: { keywordLower.contains($0) }) {
            return "technology"
        } else if scienceKeywords.contains(where: { keywordLower.contains($0) }) {
            return "science"
        }
        
        return "general"
    }
}

// MARK: - Models

struct ContentAnalysis {
    let sentiment: Double
    let entities: [String]
    let keywords: [String]
    let relevanceScore: Double
}

struct ContentSuggestion {
    let text: String
    let relevance: Double
    let category: String
}
