// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

import Foundation
#if canImport(Intents)
import Intents
#endif

/// Handles Siri / SiriKit integration for the ML Content Highlighter.
///
/// Registers the `INSearchForMessagesIntent`-like vocabulary so that Siri
/// can route "find <text> on page" utterances to the extension, and provides
/// a bridge to dispatch find requests back to the active browser tab via the
/// native-messaging host.
///
/// > Note: Full Siri integration requires an Intents Extension target in the
/// > containing app. This file provides the shared coordination layer and
/// > intent-handling logic that the Intents Extension delegates to.
@available(iOS 16.0, macOS 13.0, *)
public final class SiriIntegrationHandler {

    // MARK: - Types

    /// A Siri find-on-page request decoded from an incoming intent.
    public struct FindRequest: Sendable {
        /// The text the user asked Siri to find on the page.
        public let query: String
    }

    // MARK: - Shared instance

    public static let shared = SiriIntegrationHandler()
    private init() {}

    // MARK: - Intent registration

    /// Register user-facing vocabulary with Siri so that the extension's
    /// terminology is recognised during speech recognition.
    ///
    /// Call this once during app / extension startup (e.g. in
    /// `applicationDidFinishLaunching`).
    public func registerVocabulary() {
        #if canImport(Intents)
        let vocabulary = INVocabulary.shared()
        // Register common highlight-related terms for better recognition
        vocabulary.setVocabularyStrings(
            NSOrderedSet(array: [
                "key point",
                "key points",
                "summary",
                "summaries",
                "action item",
                "action items",
                "highlight",
                "highlights",
            ]),
            of: .contactGroupName          // closest available vocabulary type
        )
        #endif
    }

    // MARK: - Intent handling

    /// Parse a raw intent activity user-info dictionary produced by an
    /// Intents Extension and extract a ``FindRequest`` if the intent
    /// matches the expected schema.
    ///
    /// - Parameter userInfo: The `userInfo` from an `NSUserActivity`.
    /// - Returns: A `FindRequest` if the activity encodes a valid query,
    ///   otherwise `nil`.
    public func findRequest(from userInfo: [AnyHashable: Any]) -> FindRequest? {
        guard let query = userInfo["MLHighlighterQuery"] as? String,
              !query.trimmingCharacters(in: .whitespaces).isEmpty
        else { return nil }
        return FindRequest(query: query)
    }

    /// Build a user-info dictionary suitable for embedding in an
    /// `NSUserActivity` that encodes a find-on-page request.
    ///
    /// - Parameter query: The text to find on the page.
    /// - Returns: A dictionary to assign to `NSUserActivity.userInfo`.
    public func userInfo(for query: String) -> [String: String] {
        ["MLHighlighterQuery": query]
    }

    // MARK: - Native-message bridge

    /// Dispatch a find request to the content script running in the active
    /// Safari tab by posting a native-messaging message.
    ///
    /// The message is serialised to JSON and written to `stdout`, which is
    /// the standard transport for Safari Web Extension native-messaging hosts.
    ///
    /// - Parameter request: The find request to dispatch.
    /// - Throws: `EncodingError` if the message cannot be serialised.
    public func dispatch(_ request: FindRequest) throws {
        let message: [String: Any] = [
            "action": "findText",
            "query": request.query,
        ]
        try writeNativeMessage(message)
    }

    // MARK: - Private helpers

    private func writeNativeMessage(_ message: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: message)
        // Native messaging protocol: 4-byte little-endian length prefix
        var length = UInt32(data.count).littleEndian
        let lengthData = Data(bytes: &length, count: 4)
        FileHandle.standardOutput.write(lengthData)
        FileHandle.standardOutput.write(data)
    }
}
