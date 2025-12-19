# SafariSiri Extension - Integration Guide

## Table of Contents
1. [Quick Start](#quick-start)
2. [Safari Extension Setup](#safari-extension-setup)
3. [Siri Integration](#siri-integration)
4. [ML Profile Configuration](#ml-profile-configuration)
5. [Advanced Features](#advanced-features)
6. [API Reference](#api-reference)

## Quick Start

### 1. Add the Extension to Your Project

Add the SafariSiriExtension to your Xcode project:

```swift
import SafariSiriExtension

// Initialize the extension handler
let handler = SafariExtensionHandler()
```

### 2. Configure Your ML Profile

```swift
let profile = MLProfile()
profile.keywords = ["technology", "AI", "programming", "science"]
profile.saveToUserDefaults()
```

### 3. Enable Content Highlighting

The extension automatically highlights content when the toolbar button is clicked or when activated via Siri.

## Safari Extension Setup

### Entitlements Required

Add these entitlements to your app:

```xml
<key>com.apple.security.app-sandbox</key>
<true/>
<key>com.apple.security.files.user-selected.read-write</key>
<true/>
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:yourdomain.com</string>
</array>
```

### Info.plist Configuration

The extension's Info.plist must include:

```xml
<key>NSExtension</key>
<dict>
    <key>NSExtensionPointIdentifier</key>
    <string>com.apple.Safari.extension</string>
    <key>NSExtensionPrincipalClass</key>
    <string>SafariExtensionHandler</string>
</dict>
```

## Siri Integration

### Defining Intents

Create an `Intents.intentdefinition` file with your custom intents:

1. **SearchAssistanceIntent** - For search suggestions
2. **UpdateMLProfileIntent** - For profile updates
3. **HighlightContentIntent** - For content highlighting

### Intent Handler Implementation

```swift
class SiriIntentHandler: NSObject, SearchAssistanceIntentHandling {
    func handle(intent: SearchAssistanceIntent, completion: @escaping (SearchAssistanceIntentResponse) -> Void) {
        let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
        let suggestions = generateSuggestions(for: intent.searchQuery, profile: profile)
        
        let response = SearchAssistanceIntentResponse(code: .success, userActivity: nil)
        response.suggestions = suggestions
        completion(response)
    }
}
```

### Siri Shortcuts

Users can create custom Siri shortcuts:

1. Open Settings → Siri & Search
2. Tap "All Shortcuts"
3. Find "SafariSiri Orb" shortcuts
4. Record custom phrases

## ML Profile Configuration

### Creating a Profile

```swift
let profile = MLProfile()
profile.keywords = [
    "machine learning",
    "artificial intelligence",
    "data science"
]
profile.preferences = [
    "autoHighlight": true,
    "highlightColor": "yellow",
    "minRelevanceScore": 0.5
]
profile.saveToUserDefaults()
```

### Loading a Profile

```swift
if let profile = MLProfile.loadFromUserDefaults() {
    print("Loaded profile with \(profile.keywords.count) keywords")
} else {
    print("No profile found, using defaults")
}
```

### Updating a Profile

```swift
var profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
profile.keywords.append("new keyword")
profile.saveToUserDefaults()
```

## Advanced Features

### Custom Content Analysis

```swift
let analyzer = ContentAnalyzer()
let profile = MLProfile.loadFromUserDefaults() ?? MLProfile()

let analysis = analyzer.analyzeContent(pageContent, profile: profile)
print("Relevance: \(analysis.relevanceScore)")
print("Sentiment: \(analysis.sentiment)")
print("Keywords: \(analysis.keywords)")
```

### Real-time Content Monitoring

```swift
// In your content script (content.js)
function monitorPageChanges() {
    const observer = new MutationObserver((mutations) => {
        // Analyze new content
        analyzePageContent();
    });
    
    observer.observe(document.body, {
        childList: true,
        subtree: true
    });
}
```

### Custom Highlighting Styles

```swift
// Send custom styles to content script
page.dispatchMessageToScript(
    withName: "applyCustomStyles",
    userInfo: [
        "highlightColor": "#ffeb3b",
        "priorityColor": "#ff9800",
        "borderRadius": "4px"
    ]
)
```

## API Reference

### SafariExtensionHandler

#### Methods

- `messageReceived(withName:from:userInfo:)` - Handle messages from content scripts
- `toolbarItemClicked(in:)` - Handle toolbar button clicks
- `validateToolbarItem(in:validationHandler:)` - Validate toolbar item state

### MLProfile

#### Properties

- `keywords: [String]` - Keywords for content matching
- `preferences: [String: Any]` - User preferences
- `lastUpdated: Date` - Last update timestamp

#### Methods

- `update(with:)` - Update profile with new preferences
- `saveToUserDefaults()` - Save profile to persistent storage
- `loadFromUserDefaults()` - Load profile from persistent storage

### ContentAnalyzer

#### Methods

- `analyzeContent(_:profile:)` - Analyze content and return analysis results
- `generateSuggestions(query:profile:context:)` - Generate content suggestions

### Content Script API (JavaScript)

#### Functions

- `analyzePageContent()` - Analyze current page content
- `toggleHighlighting(enabled)` - Enable/disable highlighting
- `applyHighlights(highlights, relevanceScore)` - Apply highlights to page
- `displaySuggestions(suggestions)` - Display suggestion panel

#### Message Names

- `analyzeContent` - Request content analysis
- `highlightContent` - Apply highlights to page
- `applySuggestions` - Display suggestions
- `toggleHighlighting` - Toggle highlighting on/off

## Best Practices

### 1. Performance Optimization

- Limit content analysis to visible text
- Use debouncing for real-time analysis
- Cache analysis results

```swift
private var contentCache: [String: ContentAnalysis] = [:]

func getCachedAnalysis(for content: String, profile: MLProfile) -> ContentAnalysis {
    let key = content.hash.description
    if let cached = contentCache[key] {
        return cached
    }
    
    let analysis = analyzer.analyzeContent(content, profile: profile)
    contentCache[key] = analysis
    return analysis
}
```

### 2. Privacy Considerations

- All ML processing happens on-device
- No data sent to external servers
- User profiles stored locally
- Clear user data when requested

### 3. Error Handling

```swift
override func messageReceived(withName messageName: String, from page: SFSafariPage, userInfo: [String : Any]?) {
    do {
        switch messageName {
        case "analyzeContent":
            try handleContentAnalysis(page: page, userInfo: userInfo)
        default:
            print("Unknown message: \(messageName)")
        }
    } catch {
        print("Error handling message: \(error)")
        page.dispatchMessageToScript(
            withName: "error",
            userInfo: ["message": error.localizedDescription]
        )
    }
}
```

### 4. Testing

- Test on various websites
- Test with different content lengths
- Test Siri integration
- Test offline functionality

## Troubleshooting

### Common Issues

**Issue**: Extension not loading
- **Solution**: Check Safari Extensions preferences, ensure extension is enabled

**Issue**: Highlights not appearing
- **Solution**: Verify content script is loaded, check console for errors

**Issue**: Siri not responding
- **Solution**: Check intent definitions, verify Siri permissions

**Issue**: Poor relevance scores
- **Solution**: Update ML profile keywords, increase training data

## Examples

See `SafariSiriExtensionExample.swift` for complete code examples covering:
- Profile creation and management
- Content analysis
- Suggestion generation
- Siri intent handling
- Custom filtering
- Batch processing

## Support

For issues and questions:
- Check the README.md in the SafariSiriExtension directory
- Review example code in SafariSiriExtensionExample.swift
- Submit issues on GitHub

## License

See LICENSE.md in the repository root.
