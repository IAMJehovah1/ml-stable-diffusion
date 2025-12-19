//
//  SafariExtensionHandler.swift
//  SafariSiriExtension
//
//  Handles Safari extension lifecycle and communication with web content.
//

import SafariServices
import CoreML

class SafariExtensionHandler: SFSafariExtensionHandler {
    
    /// User's ML profile for content personalization
    private var userProfile: MLProfile?
    
    override init() {
        super.init()
        loadUserProfile()
    }
    
    // MARK: - Message Handling
    
    override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
        switch messageName {
        case "analyzeContent":
            handleContentAnalysis(page: page, userInfo: userInfo)
        case "updateProfile":
            handleProfileUpdate(userInfo: userInfo)
        case "highlightRequest":
            handleHighlightRequest(page: page, userInfo: userInfo)
        default:
            print("Unknown message: \(messageName)")
        }
    }
    
    // MARK: - Toolbar Item
    
    override func toolbarItemClicked(in window: SFSafariWindow) {
        window.getActiveTab { tab in
            tab?.getActivePage { page in
                page?.dispatchMessageToScript(
                    withName: "toggleHighlighting",
                    userInfo: ["enabled": true]
                )
            }
        }
    }
    
    override func validateToolbarItem(in window: SFSafariWindow, validationHandler: @escaping ((Bool, String) -> Void)) {
        validationHandler(true, "")
    }
    
    // MARK: - Content Analysis
    
    private func handleContentAnalysis(page: SFSafariPage, userInfo: [String: Any]?) {
        guard let content = userInfo?["content"] as? String else { return }
        
        // Analyze content using ML profile
        let relevanceScore = analyzeRelevance(content: content)
        let highlights = identifyHighlights(content: content, score: relevanceScore)
        
        // Send results back to web content
        page.dispatchMessageToScript(
            withName: "highlightContent",
            userInfo: [
                "highlights": highlights,
                "relevanceScore": relevanceScore
            ]
        )
    }
    
    private func handleHighlightRequest(page: SFSafariPage, userInfo: [String: Any]?) {
        guard let query = userInfo?["query"] as? String else { return }
        
        // Generate highlights based on user's ML profile and query
        let suggestions = generateContentSuggestions(query: query)
        
        page.dispatchMessageToScript(
            withName: "applySuggestions",
            userInfo: ["suggestions": suggestions]
        )
    }
    
    // MARK: - Profile Management
    
    private func loadUserProfile() {
        // Load or create user's ML profile
        userProfile = MLProfile.loadFromUserDefaults() ?? MLProfile()
    }
    
    private func handleProfileUpdate(userInfo: [String: Any]?) {
        guard let preferences = userInfo?["preferences"] as? [String: Any] else { return }
        userProfile?.update(with: preferences)
        userProfile?.saveToUserDefaults()
    }
    
    // MARK: - ML Analysis
    
    private func analyzeRelevance(content: String) -> Double {
        // Use ML model to determine content relevance
        guard let profile = userProfile else { return 0.5 }
        
        // Simple relevance scoring based on profile preferences
        let keywords = profile.keywords
        let contentLower = content.lowercased()
        
        let matchCount = keywords.filter { contentLower.contains($0.lowercased()) }.count
        let relevance = Double(matchCount) / max(Double(keywords.count), 1.0)
        
        return min(relevance, 1.0)
    }
    
    private func identifyHighlights(content: String, score: Double) -> [[String: Any]] {
        // Identify segments to highlight based on relevance
        guard score > 0.3, let profile = userProfile else { return [] }
        
        var highlights: [[String: Any]] = []
        
        for keyword in profile.keywords {
            if content.lowercased().contains(keyword.lowercased()) {
                highlights.append([
                    "keyword": keyword,
                    "priority": score
                ])
            }
        }
        
        return highlights
    }
    
    private func generateContentSuggestions(query: String) -> [[String: String]] {
        // Generate content suggestions based on ML profile
        guard let profile = userProfile else { return [] }
        
        return profile.keywords.prefix(5).map { keyword in
            ["suggestion": keyword, "relevance": "high"]
        }
    }
}

// MARK: - ML Profile Model

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
    
    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(keywords, forKey: "mlProfileKeywords")
        defaults.set(preferences, forKey: "mlProfilePreferences")
        defaults.set(lastUpdated, forKey: "mlProfileLastUpdated")
    }
    
    static func loadFromUserDefaults() -> MLProfile? {
        let defaults = UserDefaults.standard
        guard let keywords = defaults.array(forKey: "mlProfileKeywords") as? [String] else {
            return nil
        }
        
        let profile = MLProfile()
        profile.keywords = keywords
        profile.preferences = defaults.dictionary(forKey: "mlProfilePreferences") ?? [:]
        profile.lastUpdated = defaults.object(forKey: "mlProfileLastUpdated") as? Date ?? Date()
        
        return profile
    }
}
