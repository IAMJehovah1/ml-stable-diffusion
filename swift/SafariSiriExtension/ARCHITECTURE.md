# SafariSiri Extension - Architecture Overview

## System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │    Safari    │  │     Siri     │  │  Web Content │      │
│  │   Toolbar    │  │  Voice Input │  │   Scripts    │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼──────────────────┼──────────────────┼──────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────┐
│                    Extension Layer                           │
│  ┌───────────────────────────────────────────────────────┐  │
│  │         SafariExtensionHandler                        │  │
│  │  • Message routing                                    │  │
│  │  • Toolbar management                                 │  │
│  │  • Profile management                                 │  │
│  └────────────┬──────────────────────────────────────────┘  │
│               │                                              │
│  ┌────────────┴──────────────┬──────────────┐              │
│  │                            │              │              │
│  ▼                            ▼              ▼              │
│  ┌────────────┐  ┌────────────────┐  ┌─────────────┐      │
│  │  Siri      │  │   Content      │  │  ML Profile │      │
│  │  Intent    │  │   Analyzer     │  │   Manager   │      │
│  │  Handler   │  │                │  │             │      │
│  └────────────┘  └────────────────┘  └─────────────┘      │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                      ML Processing Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Core ML    │  │   Natural    │  │   Sentiment  │      │
│  │   Models     │  │   Language   │  │   Analysis   │      │
│  │              │  │   Processing │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌─────────────────────────────────────────────────────────────┐
│                       Data Layer                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ UserDefaults │  │  ML Profile  │  │  Analysis    │      │
│  │   Storage    │  │    Data      │  │   Cache      │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

## Component Interactions

### 1. Content Highlighting Flow

```
Web Page Load
     │
     ▼
content.js loads
     │
     ▼
Extract page content
     │
     ▼
Send to SafariExtensionHandler
     │
     ▼
ContentAnalyzer.analyzeContent()
     │
     ├─→ Extract keywords
     ├─→ Perform sentiment analysis
     ├─→ Calculate relevance score
     └─→ Identify entities
     │
     ▼
Match with ML Profile
     │
     ▼
Generate highlights data
     │
     ▼
Send to content.js
     │
     ▼
Apply highlights to DOM
     │
     ▼
User sees highlighted content
```

### 2. Siri Integration Flow

```
User Voice Command
     │
     ▼
Siri receives intent
     │
     ▼
SiriIntentHandler.handle()
     │
     ▼
Load ML Profile
     │
     ▼
Process query with ML
     │
     ├─→ Analyze query keywords
     ├─→ Match with profile
     └─→ Generate suggestions
     │
     ▼
Create response
     │
     ▼
Siri presents to user
```

### 3. ML Profile Update Flow

```
User updates preferences
     │
     ▼
Update request received
     │
     ▼
MLProfile.update()
     │
     ├─→ Validate new data
     ├─→ Merge with existing
     └─→ Update timestamp
     │
     ▼
MLProfile.saveToUserDefaults()
     │
     ▼
Profile persisted
     │
     ▼
Reload in extension
```

## File Structure

```
swift/SafariSiriExtension/
│
├── SafariExtensionHandler.swift      # Main extension handler
│   └── Manages all extension lifecycle and communication
│
├── ContentAnalyzer.swift              # ML analysis engine
│   ├── analyzeContent()               # Content analysis
│   ├── generateSuggestions()          # Suggestion generation
│   └── extractKeywords()              # Keyword extraction
│
├── Intents/
│   ├── SiriIntentHandler.swift        # Siri intent processing
│   │   ├── handle()                   # Intent handler
│   │   └── resolveSearchQuery()       # Query resolution
│   │
│   └── Intents.intentdefinition       # Intent definitions
│       ├── SearchAssistanceIntent
│       ├── UpdateMLProfileIntent
│       └── HighlightContentIntent
│
├── Resources/
│   └── content.js                     # Web content script
│       ├── analyzePageContent()
│       ├── applyHighlights()
│       └── toggleHighlighting()
│
├── Info.plist                         # Extension configuration
├── README.md                          # Feature documentation
├── INTEGRATION_GUIDE.md               # Integration instructions
├── QUICKSTART.md                      # Quick start guide
├── config.json                        # Configuration file
└── SafariSiriExtensionExample.swift   # Usage examples
```

## Data Models

### MLProfile

```swift
class MLProfile {
    var keywords: [String]              // Content matching keywords
    var preferences: [String: Any]      // User preferences
    var lastUpdated: Date               // Last update timestamp
    
    func update(with: [String: Any])
    func saveToUserDefaults()
    static func loadFromUserDefaults() -> MLProfile?
}
```

### ContentAnalysis

```swift
struct ContentAnalysis {
    let sentiment: Double               // -1.0 to 1.0
    let entities: [String]              // Recognized entities
    let keywords: [String]              // Extracted keywords
    let relevanceScore: Double          // 0.0 to 1.0
}
```

### ContentSuggestion

```swift
struct ContentSuggestion {
    let text: String                    // Suggestion text
    let relevance: Double               // 0.0 to 1.0
    let category: String                // Suggestion category
}
```

## Message Protocol

### Extension to Content Script

| Message Name        | Parameters                    | Description                  |
|--------------------|-------------------------------|------------------------------|
| toggleHighlighting | enabled: Bool                 | Enable/disable highlighting  |
| highlightContent   | highlights: Array, score: Double | Apply highlights to page  |
| applySuggestions   | suggestions: Array            | Display suggestion panel     |

### Content Script to Extension

| Message Name     | Parameters                       | Description                |
|-----------------|----------------------------------|----------------------------|
| analyzeContent  | content: String, url: String     | Request content analysis   |
| updateProfile   | preferences: Dictionary          | Update ML profile          |
| highlightRequest| query: String                    | Request highlight data     |

## Performance Considerations

### Optimization Strategies

1. **Content Length Limiting**
   - Max 5000 characters analyzed per request
   - Prevents memory spikes

2. **Caching**
   - Cache analysis results
   - Reuse for identical content

3. **Lazy Loading**
   - Load ML models on demand
   - Unload when not in use

4. **Debouncing**
   - Delay analysis on rapid page changes
   - Reduce unnecessary processing

### Memory Management

```
Typical Memory Usage:
├── Extension Handler: ~10 MB
├── Content Analyzer: ~20 MB
├── ML Models: ~50 MB
├── Content Cache: ~5 MB
└── Total: ~85 MB
```

## Security Considerations

### Data Protection

1. **On-Device Processing**
   - All ML happens locally
   - No network requests

2. **Sandboxing**
   - Extension runs in Safari sandbox
   - Limited system access

3. **User Data**
   - Profile stored in UserDefaults
   - No external transmission

### Permissions

```
Required:
- com.apple.Safari.extension
- com.apple.security.app-sandbox

Optional:
- com.apple.developer.siri
```

## Extension Points

### Adding Custom Analyzers

```swift
protocol CustomAnalyzer {
    func analyze(_ content: String) -> AnalysisResult
}

// Implement and register
class MyCustomAnalyzer: CustomAnalyzer {
    func analyze(_ content: String) -> AnalysisResult {
        // Custom analysis logic
    }
}
```

### Adding Custom Intents

1. Define in Intents.intentdefinition
2. Implement handler in SiriIntentHandler
3. Update Info.plist

### Extending Content Scripts

```javascript
// Add to content.js
function customHighlightLogic(text) {
    // Custom highlighting logic
}
```

## Testing Strategy

### Unit Tests
- ML Profile management
- Content analysis
- Suggestion generation

### Integration Tests
- Extension-content communication
- Siri intent handling
- Profile persistence

### UI Tests
- Highlight appearance
- Toolbar interactions
- Suggestion display

## Deployment

### Build Configuration

```bash
# Debug build
swift build

# Release build
swift build -c release

# Xcode build
xcodebuild -scheme SafariSiriExtension
```

### Distribution

1. Sign with Developer ID
2. Package as .app
3. Submit to App Store (optional)
4. Or distribute directly

---

For more details, see:
- [README.md](README.md)
- [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)
- [QUICKSTART.md](QUICKSTART.md)
