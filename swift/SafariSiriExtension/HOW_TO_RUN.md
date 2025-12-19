# How to Run the SafariSiri Extension

## Quick Demo (No macOS Required)

To see the extension's core functionality in action **right now**, run:

```bash
cd swift/SafariSiriExtension
swift RunExtensionDemo.swift
```

This demonstrates:
- ✅ ML Profile creation and customization
- ✅ Content analysis with relevance scoring
- ✅ Keyword extraction and matching
- ✅ Search suggestion generation
- ✅ Content highlighting simulation
- ✅ Siri integration (simulated)

## Running in Safari (macOS Required)

### Prerequisites

- macOS 13.0 or later
- Safari 16.0 or later
- Xcode 14.3 or later

### Step 1: Build the Extension

```bash
# From repository root
swift build
```

### Step 2: Enable in Safari

1. Open **Safari**
2. Go to **Safari** → **Preferences** (or **Settings** on macOS Ventura+)
3. Click **Extensions** tab
4. Find **SafariSiri Orb** in the list
5. Check the box to enable it
6. Click **Allow** when prompted for permissions

### Step 3: Configure Your Profile

Create a Swift script or use the example:

```swift
import SafariSiriExtension

let profile = MLProfile()
profile.keywords = ["Swift", "iOS", "CoreML", "programming"]
profile.saveToUserDefaults()
```

Or use the example code:

```bash
cd swift/SafariSiriExtension
swift SafariSiriExtensionExample.swift
```

### Step 4: Use the Extension

#### Method 1: Toolbar Button

1. Open any webpage in Safari
2. Look for the SafariSiri Orb button in the toolbar
3. Click it to toggle content highlighting

#### Method 2: Siri Commands

Say any of these:
- **"Hey Siri, highlight content"** - Enable/disable highlighting
- **"Hey Siri, help me with machine learning"** - Get suggestions
- **"Hey Siri, update my profile"** - Update ML profile

#### Method 3: JavaScript Console

Open Safari's Web Inspector and run:

```javascript
safari.extension.dispatchMessage('analyzeContent', {
    content: document.body.innerText,
    url: window.location.href
});
```

## Visual Guide

### What You'll See

When the extension is active:

1. **Yellow Highlights** 🟨
   - Standard relevance content
   - Keywords matching your profile

2. **Orange Highlights** 🟧
   - High priority content
   - Strong matches to your interests

3. **Suggestion Panel** 💡
   - Appears in top-right corner
   - Shows ML-generated suggestions
   - Auto-hides after 5 seconds

### Example Workflow

```
1. Browse to tech article
      ↓
2. Extension analyzes content
      ↓
3. Relevant keywords highlighted
      ↓
4. Suggestion panel shows topics
      ↓
5. Click highlight for more info
```

## Customization

### Change Highlight Colors

Edit `config.json`:

```json
{
  "highlighting": {
    "highlightColor": "#your-color",
    "priorityHighlightColor": "#your-priority-color"
  }
}
```

### Adjust Relevance Threshold

```swift
profile.preferences["minRelevanceScore"] = 0.7  // 0.0 to 1.0
profile.saveToUserDefaults()
```

### Add/Remove Keywords

```swift
var profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
profile.keywords.append("new-keyword")
profile.keywords.removeAll { $0 == "old-keyword" }
profile.saveToUserDefaults()
```

## Testing

### Run Unit Tests

```bash
swift test
```

### Run Example Scenarios

```bash
cd swift/SafariSiriExtension
swift SafariSiriExtensionExample.swift
```

### Debug in Safari

1. Enable Safari's **Develop** menu
2. Right-click on page → **Inspect Element**
3. Check **Console** for extension logs
4. View **Network** tab for message passing

## Troubleshooting

### Extension Not Appearing

```bash
# Rebuild and restart Safari
swift build
killall Safari
open -a Safari
```

### Highlights Not Working

1. Check extension is enabled in Safari preferences
2. Verify keywords in your ML profile
3. Check console for JavaScript errors

### Siri Not Responding

1. Check Siri is enabled: **System Preferences** → **Siri**
2. Grant permissions: **Privacy & Security** → **Siri & Dictation**
3. Try rephrasing command

## Performance Monitoring

### Memory Usage

Check memory in Activity Monitor:
- Filter for "Safari"
- Look for extension process
- Typical: ~85MB

### Analysis Speed

Use the demo to benchmark:

```bash
time swift RunExtensionDemo.swift
```

Typical results:
- Content extraction: <100ms
- ML analysis: <500ms
- Highlighting: <200ms

## Advanced Usage

### Custom Analyzers

```swift
// Extend ContentAnalyzer
extension ContentAnalyzer {
    func customAnalysis(_ text: String) -> [String] {
        // Your custom logic
    }
}
```

### Multiple Profiles

```swift
// Create profile for different contexts
let workProfile = MLProfile()
workProfile.keywords = ["business", "finance", "reports"]

let learnProfile = MLProfile()
learnProfile.keywords = ["tutorial", "guide", "course"]
```

### Integration with Other Apps

```swift
// Share profile data
let encoder = JSONEncoder()
if let data = try? encoder.encode(profile) {
    // Save to file, cloud, etc.
}
```

## Documentation

- 📖 [README.md](README.md) - Complete features
- 🚀 [QUICKSTART.md](QUICKSTART.md) - 5-minute guide
- 🔧 [INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md) - API reference
- 🏗️ [ARCHITECTURE.md](ARCHITECTURE.md) - System design

## Support

For issues:
1. Check the [FAQ](../../README.md#faq)
2. Review example code
3. Submit GitHub issue

---

**Tip**: Start with the demo script to understand the functionality before running in Safari!
