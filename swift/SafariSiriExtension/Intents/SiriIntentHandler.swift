//
//  SiriIntentHandler.swift
//  SafariSiriExtension
//
//  Handles Siri intent requests for web search assistance
//

import Foundation
import Intents

/// Intent handler for Siri web search assistance
class SiriIntentHandler: NSObject, SearchAssistanceIntentHandling {
    
    // MARK: - Search Assistance Intent
    
    func handle(intent: SearchAssistanceIntent, completion: @escaping (SearchAssistanceIntentResponse) -> Void) {
        guard let query = intent.searchQuery else {
            completion(SearchAssistanceIntentResponse(code: .failure, userActivity: nil))
            return
        }
        
        // Analyze query using ML profile
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        let suggestions = generateSuggestions(for: query, profile: profile)
        
        // Create response
        let response = SearchAssistanceIntentResponse(code: .success, userActivity: nil)
        response.suggestions = suggestions
        response.relevanceScore = NSNumber(value: calculateRelevance(query: query, profile: profile))
        
        completion(response)
    }
    
    func resolveSearchQuery(for intent: SearchAssistanceIntent, with completion: @escaping (INStringResolutionResult) -> Void) {
        if let query = intent.searchQuery, !query.isEmpty {
            completion(INStringResolutionResult.success(with: query))
        } else {
            completion(INStringResolutionResult.needsValue())
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateSuggestions(for query: String, profile: MLProfile) -> [String] {
        let queryLower = query.lowercased()
        
        // Filter keywords relevant to the query
        let relevantKeywords = profile.keywords.filter { keyword in
            queryLower.contains(keyword.lowercased()) || 
            keyword.lowercased().contains(queryLower)
        }
        
        // Add general suggestions if no specific matches
        if relevantKeywords.isEmpty {
            return profile.keywords.prefix(3).map { $0 }
        }
        
        return relevantKeywords
    }
    
    private func calculateRelevance(query: String, profile: MLProfile) -> Double {
        let queryLower = query.lowercased()
        let matchCount = profile.keywords.filter { queryLower.contains($0.lowercased()) }.count
        let relevance = Double(matchCount) / max(Double(profile.keywords.count), 1.0)
        return min(relevance, 1.0)
    }
}

// MARK: - Custom Intents

/// Intent for search assistance with Siri
class SearchAssistanceIntent: INIntent {
    @NSManaged public var searchQuery: String?
}

/// Response for search assistance intent
class SearchAssistanceIntentResponse: INIntentResponse {
    @NSManaged public var suggestions: [String]?
    @NSManaged public var relevanceScore: NSNumber?
    
    convenience init(code: Code, userActivity: NSUserActivity?) {
        self.init()
        self.code = code
        self.userActivity = userActivity
    }
    
    @objc public enum Code: Int {
        case success = 0
        case failure = 1
        case inProgress = 2
    }
    
    @NSManaged public var code: Code
}

// MARK: - Intent Protocol

protocol SearchAssistanceIntentHandling: NSObjectProtocol {
    func handle(intent: SearchAssistanceIntent, completion: @escaping (SearchAssistanceIntentResponse) -> Void)
    func resolveSearchQuery(for intent: SearchAssistanceIntent, with completion: @escaping (INStringResolutionResult) -> Void)
}
