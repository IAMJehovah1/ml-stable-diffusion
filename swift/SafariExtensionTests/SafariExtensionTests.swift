// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

import XCTest
@testable import SafariExtension

@available(iOS 16.0, macOS 13.0, *)
final class SafariExtensionTests: XCTestCase {

    // MARK: - ContentAnalyzer tests

    func testAnalyseReturnsEmptyForNoPassages() {
        let analyzer = ContentAnalyzer()
        let result = analyzer.analyse(passages: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testAnalyseIdentifiesKeyPoints() {
        let analyzer = ContentAnalyzer()
        // Body passage with repeated key terms – should score as key-point
        let passage = ContentAnalyzer.Passage(
            id: 5,
            text: "Machine learning models are trained on large datasets to identify patterns. " +
                  "Neural networks leverage these patterns to make predictions. " +
                  "Training a model requires significant computational resources and data."
        )
        // Pad with filler so passage 5 sits in the middle of the document
        var passages: [ContentAnalyzer.Passage] = (0..<5).map { i in
            ContentAnalyzer.Passage(id: i, text: "Filler text for passage \(i).")
        }
        passages.append(passage)
        passages += (6..<12).map { i in
            ContentAnalyzer.Passage(id: i, text: "Filler text for passage \(i).")
        }

        let highlights = analyzer.analyse(passages: passages)
        let ids = highlights.map(\.id)
        XCTAssertTrue(ids.contains(5), "Expected passage 5 to be highlighted as a key point")
    }

    func testAnalyseIdentifiesActionItems() {
        let analyzer = ContentAnalyzer()
        let passages = [
            ContentAnalyzer.Passage(id: 0, text: "Download and install the latest version of Xcode from the Mac App Store."),
            ContentAnalyzer.Passage(id: 1, text: "The sky is blue and the grass is green."),
        ]
        let highlights = analyzer.analyse(passages: passages)
        let actionItems = highlights.filter { $0.category == .actionItem }
        XCTAssertFalse(actionItems.isEmpty, "Expected at least one action-item highlight")
        XCTAssertEqual(actionItems.first?.id, 0)
    }

    func testCategoryFilterIsRespected() {
        let analyzer = ContentAnalyzer()
        let passages = [
            ContentAnalyzer.Passage(id: 0, text: "Download the package and install it following the instructions below."),
            ContentAnalyzer.Passage(id: 1, text: "Machine learning models learn statistical patterns in large text corpora. " +
                                                 "Deep learning architectures such as transformers revolutionised NLP tasks."),
        ]
        // Only allow summaries – action items and key points should be suppressed
        let highlights = analyzer.analyse(passages: passages, enabledCategories: [.summary])
        let categories = Set(highlights.map(\.category))
        XCTAssertFalse(categories.contains(.actionItem), "Action items should be filtered out")
        XCTAssertFalse(categories.contains(.keyPoint), "Key points should be filtered out")
    }

    // MARK: - SiriIntegrationHandler tests

    func testFindRequestParsedFromUserInfo() {
        let handler = SiriIntegrationHandler.shared
        let userInfo: [AnyHashable: Any] = ["MLHighlighterQuery": "machine learning"]
        let request = handler.findRequest(from: userInfo)
        XCTAssertNotNil(request)
        XCTAssertEqual(request?.query, "machine learning")
    }

    func testFindRequestNilForMissingKey() {
        let handler = SiriIntegrationHandler.shared
        let request = handler.findRequest(from: [:])
        XCTAssertNil(request)
    }

    func testFindRequestNilForBlankQuery() {
        let handler = SiriIntegrationHandler.shared
        let request = handler.findRequest(from: ["MLHighlighterQuery": "   "])
        XCTAssertNil(request)
    }

    func testUserInfoRoundTrip() {
        let handler = SiriIntegrationHandler.shared
        let query = "Safari extension"
        let info = handler.userInfo(for: query)
        let request = handler.findRequest(from: info)
        XCTAssertEqual(request?.query, query)
    }

    // MARK: - ExtensionConfiguration tests

    func testDefaultsAreCorrect() {
        let config = ExtensionConfiguration.shared
        config.resetToDefaults()
        XCTAssertTrue(config.isEnabled)
        XCTAssertEqual(
            Set(config.enabledCategories),
            [.keyPoint, .summary, .actionItem]
        )
    }

    func testToggleEnabled() {
        let config = ExtensionConfiguration.shared
        config.resetToDefaults()
        config.isEnabled = false
        XCTAssertFalse(config.isEnabled)
        config.isEnabled = true
        XCTAssertTrue(config.isEnabled)
    }

    func testCategoryPersistence() {
        let config = ExtensionConfiguration.shared
        config.resetToDefaults()
        config.enabledCategories = [.keyPoint]
        XCTAssertEqual(config.enabledCategories, [.keyPoint])
        config.resetToDefaults()
    }

    func testColorForCategory() {
        let config = ExtensionConfiguration.shared
        config.resetToDefaults()
        XCTAssertEqual(config.color(for: .keyPoint), "#FFEB3B")
        XCTAssertEqual(config.color(for: .summary), "#A5D6A7")
        XCTAssertEqual(config.color(for: .actionItem), "#90CAF9")
    }

    func testToDictionaryContainsRequiredKeys() {
        let config = ExtensionConfiguration.shared
        config.resetToDefaults()
        let dict = config.toDictionary()
        XCTAssertNotNil(dict["enabled"])
        XCTAssertNotNil(dict["categories"])
        XCTAssertNotNil(dict["highlightColor"])
    }
}
