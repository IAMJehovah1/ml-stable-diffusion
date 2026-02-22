// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

import Foundation
#if canImport(NaturalLanguage)
import NaturalLanguage
#endif

/// Analyses plain-text passages using Apple's on-device Natural Language
/// framework and returns scored highlights suitable for the Safari extension.
@available(iOS 16.0, macOS 13.0, *)
public final class ContentAnalyzer {

    // MARK: - Types

    /// A category assigned to a highlighted passage.
    public enum Category: String, Codable, Sendable {
        case keyPoint   = "key-point"
        case summary    = "summary"
        case actionItem = "action-item"
    }

    /// The result for a single passage.
    public struct Highlight: Codable, Sendable {
        /// The zero-based index of the passage in the input array.
        public let id: Int
        /// The assigned highlight category.
        public let category: Category
    }

    /// A passage submitted for analysis.
    public struct Passage: Codable, Sendable {
        public let id: Int
        public let text: String
        public init(id: Int, text: String) {
            self.id = id
            self.text = text
        }
    }

    // MARK: - Initialisation

    #if canImport(NaturalLanguage)
    private let tagger: NLTagger
    #endif
    private let actionVerb: NSRegularExpression

    public init() {
        #if canImport(NaturalLanguage)
        tagger = NLTagger(tagSchemes: [.lexicalClass, .sentimentScore])
        #endif
        // Matches sentences that begin with an imperative verb pattern
        actionVerb = try! NSRegularExpression(
            pattern: #"^\s*(please\s+|to\s+)?(click|open|navigate|go\s+to|download|install|enable|disable|configure|set|add|remove|select|choose|update|check|ensure|make\s+sure)\b"#,
            options: [.caseInsensitive]
        )
    }

    // MARK: - Public API

    /// Analyse an array of passages and return highlights for those deemed
    /// significant by the on-device NLP model.
    ///
    /// - Parameters:
    ///   - passages: The text passages to evaluate.
    ///   - enabledCategories: Only return highlights in these categories.
    ///     Pass `nil` or an empty array to allow all categories.
    /// - Returns: An array of `Highlight` values, one per significant passage.
    public func analyse(
        passages: [Passage],
        enabledCategories: [Category]? = nil
    ) -> [Highlight] {
        guard !passages.isEmpty else { return [] }

        let total = passages.count
        let docFreq = buildDocumentFrequency(passages: passages)
        let totalDocTokens = docFreq.values.reduce(0, +)

        return passages.compactMap { passage in
            let score = nlpScore(
                text: passage.text,
                docFreq: docFreq,
                totalDocTokens: totalDocTokens
            )
            guard let category = assignCategory(
                text: passage.text,
                score: score,
                index: passage.id,
                total: total
            ) else { return nil }

            let allowed = enabledCategories ?? []
            if !allowed.isEmpty && !allowed.contains(category) { return nil }

            return Highlight(id: passage.id, category: category)
        }
    }

    // MARK: - Private helpers

    /// Build a document-level term frequency dictionary across all passages.
    private func buildDocumentFrequency(passages: [Passage]) -> [String: Int] {
        var freq: [String: Int] = [:]
        for passage in passages {
            for token in tokenize(text: passage.text) {
                freq[token, default: 0] += 1
            }
        }
        return freq
    }

    /// Compute an NLP relevance score for a single passage.
    private func nlpScore(
        text: String,
        docFreq: [String: Int],
        totalDocTokens: Int
    ) -> Double {
        guard totalDocTokens > 0 else { return 0 }

        let tokens = tokenize(text: text)
        guard !tokens.isEmpty else { return 0 }

        var score = 0.0
        var passageFreq: [String: Int] = [:]
        for token in tokens {
            passageFreq[token, default: 0] += 1
        }

        for (term, count) in passageFreq {
            let docCount = Double(docFreq[term] ?? 0)
            let tf = Double(count) / Double(totalDocTokens)
            score += tf * log(1 + docCount)
        }

        // Incorporate sentiment: positive sentiment boosts key-point likelihood
        let sentiment = sentimentScore(text: text)
        score += abs(sentiment) * 0.1

        return min(score, 1.0)
    }

    /// Assign a highlight category based on position, score, and text patterns.
    private func assignCategory(
        text: String,
        score: Double,
        index: Int,
        total: Int
    ) -> Category? {
        let relativePos = total > 1 ? Double(index) / Double(total - 1) : 0

        // Action items: imperatives near the body of the text
        let range = NSRange(text.startIndex..., in: text)
        if actionVerb.firstMatch(in: text, range: range) != nil {
            return .actionItem
        }

        // Summaries: high-scoring passages near document boundaries
        if (relativePos < 0.1 || relativePos > 0.88) && score > 0.3 {
            return .summary
        }

        // Key points: highly scored body passages
        if score > 0.45 {
            return .keyPoint
        }

        return nil
    }

    /// Tokenise text into lowercase content words, removing stopwords.
    private func tokenize(text: String) -> [String] {
        #if canImport(NaturalLanguage)
        var tokens: [String] = []
        tagger.string = text
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .lexicalClass,
            options: [.omitWhitespace, .omitPunctuation]
        ) { tag, range in
            guard let tag = tag else { return true }
            switch tag {
            case .noun, .verb, .adjective, .adverb:
                let word = text[range].lowercased()
                if !Self.stopwords.contains(word) {
                    tokens.append(word)
                }
            default:
                break
            }
            return true
        }
        return tokens
        #else
        // Fallback tokeniser for non-Apple platforms: split on non-word characters.
        return text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 3 && !Self.stopwords.contains($0) }
        #endif
    }

    /// Returns the sentiment score of the passage in [-1, 1].
    private func sentimentScore(text: String) -> Double {
        #if canImport(NaturalLanguage)
        tagger.string = text
        let (tag, _) = tagger.tag(
            at: text.startIndex,
            unit: .paragraph,
            scheme: .sentimentScore
        )
        return Double(tag?.rawValue ?? "0") ?? 0
        #else
        return 0
        #endif
    }

    // MARK: - Stopwords

    private static let stopwords: Set<String> = [
        "a","an","the","and","or","but","is","are","was","were","be","been",
        "being","have","has","had","do","does","did","will","would","could",
        "should","may","might","shall","can","to","of","in","on","at","by",
        "for","with","about","as","into","through","from","up","down","out",
        "over","that","this","these","those","it","its","i","we","you","he",
        "she","they","them","their","our","your","my","his","her","so","if",
        "not","no","nor","yet","both","either","each","all","any","more",
        "most","other","some","such","than","then","there","when","where",
        "which","while","who","whom","how",
    ]
}
