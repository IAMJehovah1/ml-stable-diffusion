//
//  SafariSiriExtensionTests.swift
//  SafariSiriExtension
//
//  Tests for the SafariSiri Extension
//

import XCTest
@testable import SafariSiriExtension

class SafariSiriExtensionTests: XCTestCase {
    
    // MARK: - ML Profile Tests
    
    func testMLProfileCreation() {
        let profile = MLProfile()
        XCTAssertNotNil(profile)
        XCTAssertFalse(profile.keywords.isEmpty)
        XCTAssertNotNil(profile.lastUpdated)
    }
    
    func testMLProfileSaveAndLoad() {
        // Create and save profile
        let profile = MLProfile()
        profile.keywords = ["test1", "test2", "test3"]
        profile.saveToUserDefaults()
        
        // Load profile
        let loadedProfile = MLProfile.loadFromUserDefaults()
        XCTAssertNotNil(loadedProfile)
        XCTAssertEqual(loadedProfile?.keywords.count, 3)
        XCTAssertTrue(loadedProfile?.keywords.contains("test1") ?? false)
    }
    
    func testMLProfileUpdate() {
        var profile = MLProfile()
        let originalCount = profile.keywords.count
        
        profile.update(with: ["keywords": ["new1", "new2"]])
        
        XCTAssertEqual(profile.keywords.count, 2)
        XCTAssertNotEqual(profile.keywords.count, originalCount)
    }
    
    // MARK: - Content Analyzer Tests
    
    func testContentAnalyzerInitialization() {
        let analyzer = ContentAnalyzer()
        XCTAssertNotNil(analyzer)
    }
    
    func testContentAnalysis() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        profile.keywords = ["machine", "learning", "AI"]
        
        let content = "This is an article about machine learning and AI technology."
        let analysis = analyzer.analyzeContent(content, profile: profile)
        
        XCTAssertGreaterThan(analysis.relevanceScore, 0.0)
        XCTAssertFalse(analysis.keywords.isEmpty)
    }
    
    func testRelevanceCalculation() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        profile.keywords = ["swift", "iOS"]
        
        let relevantContent = "This article discusses Swift programming for iOS development."
        let irrelevantContent = "This is about cooking recipes."
        
        let relevantAnalysis = analyzer.analyzeContent(relevantContent, profile: profile)
        let irrelevantAnalysis = analyzer.analyzeContent(irrelevantContent, profile: profile)
        
        XCTAssertGreaterThan(relevantAnalysis.relevanceScore, irrelevantAnalysis.relevanceScore)
    }
    
    func testSuggestionGeneration() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        profile.keywords = ["technology", "programming", "AI"]
        
        let query = "programming tutorials"
        let context = "Looking for resources on technology and AI"
        
        let suggestions = analyzer.generateSuggestions(query: query, profile: profile, context: context)
        
        XCTAssertFalse(suggestions.isEmpty)
        XCTAssertLessThanOrEqual(suggestions.count, 10)
    }
    
    // MARK: - Siri Intent Handler Tests
    
    func testSiriIntentHandlerCreation() {
        let handler = SiriIntentHandler()
        XCTAssertNotNil(handler)
    }
    
    func testSearchAssistanceIntent() {
        let handler = SiriIntentHandler()
        let intent = SearchAssistanceIntent()
        intent.searchQuery = "machine learning"
        
        let expectation = self.expectation(description: "Intent handled")
        
        handler.handle(intent: intent) { response in
            XCTAssertEqual(response.code, .success)
            XCTAssertNotNil(response.suggestions)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    func testSearchAssistanceIntentWithEmptyQuery() {
        let handler = SiriIntentHandler()
        let intent = SearchAssistanceIntent()
        intent.searchQuery = ""
        
        let expectation = self.expectation(description: "Intent failed")
        
        handler.handle(intent: intent) { response in
            XCTAssertEqual(response.code, .failure)
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 5, handler: nil)
    }
    
    // MARK: - Performance Tests
    
    func testContentAnalysisPerformance() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        let content = String(repeating: "This is test content about machine learning. ", count: 100)
        
        measure {
            _ = analyzer.analyzeContent(content, profile: profile)
        }
    }
    
    func testSuggestionGenerationPerformance() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        profile.keywords = Array(repeating: "keyword", count: 50)
        
        measure {
            _ = analyzer.generateSuggestions(
                query: "test query",
                profile: profile,
                context: "test context"
            )
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testEmptyContentAnalysis() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        
        let analysis = analyzer.analyzeContent("", profile: profile)
        
        XCTAssertEqual(analysis.relevanceScore, 0.0)
        XCTAssertTrue(analysis.keywords.isEmpty)
    }
    
    func testLargeContentAnalysis() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        
        let largeContent = String(repeating: "word ", count: 10000)
        let analysis = analyzer.analyzeContent(largeContent, profile: profile)
        
        XCTAssertNotNil(analysis)
    }
    
    func testSpecialCharactersInContent() {
        let analyzer = ContentAnalyzer()
        let profile = MLProfile()
        profile.keywords = ["test"]
        
        let content = "Test content with special chars: !@#$%^&*()_+-=[]{}|;':\",./<>?"
        let analysis = analyzer.analyzeContent(content, profile: profile)
        
        XCTAssertNotNil(analysis)
    }
}
