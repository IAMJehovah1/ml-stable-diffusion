# SafariSiri Extension - Quick Start Guide

Get started with the SafariSiri Extension Orb Application in 5 minutes!

## Prerequisites

- macOS 13.0 or later
- Safari 16.0 or later
- Xcode 14.3 or later (for development)

## Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/IAMJehovah1/ml-stable-diffusion.git
cd ml-stable-diffusion
```

### Step 2: Build the Extension

```bash
swift build
```

### Step 3: Enable in Safari

1. Open Safari
2. Go to **Safari → Preferences** (or **Settings** on macOS Ventura and later)
3. Click on **Extensions**
4. Find and enable **SafariSiri Orb**
5. Grant the necessary permissions when prompted

## First Use

### 1. Configure Your ML Profile

The extension comes with default keywords, but you can customize them:

```swift
import SafariSiriExtension

let profile = MLProfile()
profile.keywords = [
    "your",
    "custom",
    "keywords",
    "here"
]
profile.saveToUserDefaults()
```

### 2. Try Content Highlighting

1. Open any webpage in Safari
2. Click the **SafariSiri Orb** toolbar button
3. Watch as relevant content gets highlighted!

**Colors:**
- 🟨 **Yellow**: Standard relevant content
- 🟧 **Orange**: High priority content

### 3. Use Siri Commands

Try these voice commands:

- **"Hey Siri, highlight content"** - Enable/disable highlighting
- **"Hey Siri, help me with [your query]"** - Get ML-powered suggestions
- **"Hey Siri, update my profile"** - Update your preferences

## Common Use Cases

### For Research

**Keywords:** `research, study, paper, journal, academic, science`

Browse academic websites and the extension will automatically highlight:
- Research findings
- Study results
- Scientific terms
- Academic references

### For Development

**Keywords:** `code, programming, development, API, framework, library`

Browse developer documentation and tutorials with highlighted:
- Code examples
- API references
- Best practices
- Technical concepts

### For Learning

**Keywords:** `tutorial, learn, guide, how-to, beginner, course`

Browse educational content with highlighted:
- Learning resources
- Step-by-step guides
- Educational materials
- Training content

## Customization

### Changing Highlight Colors

Edit `config.json`:

```json
{
  "highlighting": {
    "highlightColor": "#your-color-here",
    "priorityHighlightColor": "#your-priority-color-here"
  }
}
```

### Adjusting Relevance Threshold

```swift
profile.preferences["minRelevanceScore"] = 0.7  // 0.0 to 1.0
profile.saveToUserDefaults()
```

### Adding More Keywords

```swift
var profile = MLProfile.loadFromUserDefaults() ?? MLProfile()
profile.keywords.append(contentsOf: ["new", "keywords", "here"])
profile.saveToUserDefaults()
```

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Click toolbar button | Toggle highlighting |
| Cmd + Shift + H | Toggle highlighting (if configured) |

## Tips & Tricks

### 1. **Start Broad, Then Narrow**
Begin with general keywords like "technology" and refine to specific terms like "Swift programming"

### 2. **Use Categories**
Organize keywords by topic:
- Tech: `AI, ML, programming, code`
- Science: `research, study, experiment`
- Business: `startup, funding, growth`

### 3. **Review and Update**
Periodically review your ML profile and update keywords based on your interests

### 4. **Combine with Siri Shortcuts**
Create custom Siri shortcuts for quick access to specific highlighting profiles

## Troubleshooting

### Extension Not Working?

1. **Check Safari Extensions**
   - Safari → Preferences → Extensions
   - Ensure SafariSiri Orb is enabled

2. **Restart Safari**
   ```bash
   # Kill Safari process
   killall Safari
   # Reopen Safari
   open -a Safari
   ```

3. **Check Console Logs**
   - Safari → Develop → Show Web Inspector
   - Check for error messages

### Highlighting Not Appearing?

1. **Click the toolbar button** to ensure highlighting is enabled
2. **Check your keywords** - they might not match the page content
3. **Try a different website** - some sites may block content scripts

### Siri Not Responding?

1. **Check Siri is enabled** in System Preferences
2. **Grant Siri permissions** to the extension
3. **Try rephrasing** your command

## Next Steps

- 📖 Read the [full README](README.md) for detailed features
- 🔧 Check out the [Integration Guide](INTEGRATION_GUIDE.md) for advanced usage
- 💻 Browse [example code](SafariSiriExtensionExample.swift) for development

## Getting Help

- Check the [FAQ](../../README.md#faq) section
- Review [example code](SafariSiriExtensionExample.swift)
- Submit issues on GitHub

## Quick Reference

### Code Snippets

**Create Profile:**
```swift
let profile = MLProfile()
profile.keywords = ["your", "keywords"]
profile.saveToUserDefaults()
```

**Analyze Content:**
```swift
let analyzer = ContentAnalyzer()
let analysis = analyzer.analyzeContent(text, profile: profile)
```

**Generate Suggestions:**
```swift
let suggestions = analyzer.generateSuggestions(
    query: "search query",
    profile: profile,
    context: "page context"
)
```

### JavaScript API

**Toggle Highlighting:**
```javascript
safari.extension.dispatchMessage('toggleHighlighting', { enabled: true });
```

**Request Analysis:**
```javascript
safari.extension.dispatchMessage('analyzeContent', {
    content: document.body.innerText,
    url: window.location.href
});
```

---

**Happy Highlighting! 🎯**

For more information, visit the [project repository](https://github.com/IAMJehovah1/ml-stable-diffusion).
