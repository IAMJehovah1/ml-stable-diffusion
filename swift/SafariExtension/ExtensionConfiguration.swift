// For licensing see accompanying LICENSE.md file.
// Copyright (C) 2024 Apple Inc. All Rights Reserved.

import Foundation

/// Persistent user configuration for the ML Content Highlighter extension.
///
/// Settings are stored in `UserDefaults` under a shared app-group suite so
/// that both the containing app and the extension process share the same
/// configuration.
@available(iOS 16.0, macOS 13.0, *)
public final class ExtensionConfiguration {

    // MARK: - Keys

    private enum Key {
        static let enabled        = "MLHighlighter.enabled"
        static let categories     = "MLHighlighter.categories"
        static let highlightColor = "MLHighlighter.highlightColor"
    }

    // MARK: - Defaults

    /// The app-group identifier used to share defaults between the host app
    /// and the extension. Override this before calling any other API if your
    /// app group has a different identifier.
    public var appGroupIdentifier: String = "group.com.apple.mlcontenthighlighter"

    /// Default highlight colours keyed by raw category string.
    public static let defaultHighlightColors: [String: String] = [
        "key-point":   "#FFEB3B",
        "summary":     "#A5D6A7",
        "action-item": "#90CAF9",
    ]

    // MARK: - Shared instance

    public static let shared = ExtensionConfiguration()
    private init() {}

    // MARK: - Storage

    private var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    // MARK: - Public API

    /// Whether the extension is currently enabled.
    public var isEnabled: Bool {
        get { defaults.object(forKey: Key.enabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.enabled) }
    }

    /// The set of enabled highlight categories.
    /// Defaults to all three categories when not previously set.
    public var enabledCategories: [ContentAnalyzer.Category] {
        get {
            guard let raw = defaults.array(forKey: Key.categories) as? [String] else {
                return [.keyPoint, .summary, .actionItem]
            }
            return raw.compactMap { ContentAnalyzer.Category(rawValue: $0) }
        }
        set {
            defaults.set(newValue.map(\.rawValue), forKey: Key.categories)
        }
    }

    /// Highlight colours keyed by raw category string.
    public var highlightColors: [String: String] {
        get {
            defaults.dictionary(forKey: Key.highlightColor) as? [String: String]
                ?? Self.defaultHighlightColors
        }
        set {
            defaults.set(newValue, forKey: Key.highlightColor)
        }
    }

    /// Convenience accessor: return the highlight colour for a given category.
    public func color(for category: ContentAnalyzer.Category) -> String {
        highlightColors[category.rawValue]
            ?? Self.defaultHighlightColors[category.rawValue]
            ?? "#FFEB3B"
    }

    /// Reset all settings to their default values.
    public func resetToDefaults() {
        defaults.removeObject(forKey: Key.enabled)
        defaults.removeObject(forKey: Key.categories)
        defaults.removeObject(forKey: Key.highlightColor)
    }

    /// Serialise the current configuration to a dictionary that can be sent
    /// to the web-extension content script via native messaging.
    public func toDictionary() -> [String: Any] {
        [
            "enabled":        isEnabled,
            "categories":     enabledCategories.map(\.rawValue),
            "highlightColor": highlightColors,
        ]
    }
}
