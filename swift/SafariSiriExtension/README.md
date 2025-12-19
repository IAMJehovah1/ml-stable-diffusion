# SafariSiri Extension Orb Application

## Overview

The SafariSiri Extension Orb Application is a powerful Safari extension that integrates with Siri to provide ML-powered web search assistance. It highlights relevant and engaging content based on your personalized machine learning profile.

## Features

### 🎯 Intelligent Content Highlighting
- Automatically highlights relevant content on web pages based on your ML profile
- Color-coded highlights for different priority levels
- Real-time content analysis as you browse

### 🗣️ Siri Integration
- Ask Siri for search suggestions: "Hey Siri, help me with my search"
- Voice-activated content highlighting
- Update your ML profile using voice commands

### 🧠 Machine Learning Profile
- Personalized content filtering based on your interests
- Learns from your browsing patterns
- Customizable keywords and preferences

### ⚡ Real-time Analysis
- Uses Core ML for fast, on-device analysis
- Natural language processing for content understanding
- Sentiment analysis and entity recognition

## Installation

### Prerequisites
- macOS 13.0 or later
- Safari 16.0 or later
- Xcode 14.3 or later (for development)

### Building from Source

1. Clone the repository:
```bash
git clone https://github.com/IAMJehovah1/ml-stable-diffusion.git
cd ml-stable-diffusion
```

2. Build the extension:
```bash
swift build
```

3. Open Safari and enable the extension:
   - Go to Safari > Preferences > Extensions
   - Enable "SafariSiri Orb"
   - Grant necessary permissions

## Usage

### Basic Usage

1. **Enable Content Highlighting**
   - Click the SafariSiri toolbar button in Safari
   - Or say "Hey Siri, highlight content"

2. **Customize Your Profile**
   - Use the extension settings to add keywords
   - Update your preferences for better content filtering

3. **Get Search Suggestions**
   - Say "Hey Siri, help me with [your search query]"
   - Receive ML-powered suggestions based on your profile

### Siri Commands

- **"Hey Siri, highlight content"** - Enable/disable content highlighting
- **"Hey Siri, search for [query]"** - Get ML-powered search suggestions
- **"Hey Siri, update my profile"** - Update ML profile preferences

### Content Highlighting

The extension uses two highlight colors:
- **Yellow** (default): Standard relevant content
- **Orange** (high priority): Highly relevant content based on your profile

## ML Profile Configuration

### Default Keywords
The extension comes with default keywords:
- technology
- science
- innovation
- AI
- machine learning

### Customizing Keywords

You can customize your ML profile by:

1. Using Siri: "Hey Siri, update my profile with keywords: [keyword1, keyword2]"
2. Programmatically updating via JavaScript:
```javascript
safari.extension.dispatchMessage('updateProfile', {
    preferences: {
        keywords: ['your', 'custom', 'keywords']
    }
});
```

## Architecture

### Components

1. **SafariExtensionHandler.swift**
   - Main extension handler
   - Manages communication between Safari and web content
   - Handles ML profile management

2. **SiriIntentHandler.swift**
   - Handles Siri intent requests
   - Processes voice commands
   - Generates ML-powered suggestions

3. **ContentAnalyzer.swift**
   - Core ML content analysis
   - Natural language processing
   - Entity recognition and keyword extraction

4. **content.js**
   - Web page content script
   - DOM manipulation for highlighting
   - Communication with extension backend

### Data Flow

```
User Browse → Content Analysis → ML Profile Matching → Highlighting
                    ↓
                Core ML Models
                    ↓
            Natural Language Processing
```

## Development

### Project Structure

```
swift/SafariSiriExtension/
├── SafariExtensionHandler.swift    # Main extension handler
├── ContentAnalyzer.swift            # ML analysis engine
├── Info.plist                       # Extension configuration
├── Intents/
│   ├── SiriIntentHandler.swift     # Siri integration
│   └── Intents.intentdefinition    # Intent definitions
└── Resources/
    └── content.js                   # Web content script
```

### Building and Testing

1. Build the project:
```bash
swift build
```

2. Run tests:
```bash
swift test
```

3. Debug in Safari:
   - Enable Safari's Develop menu
   - Use Web Inspector to debug content scripts
   - Check Console for extension logs

## Privacy

### Data Collection
- **No data is sent to external servers**
- All ML processing happens on-device using Core ML
- Your ML profile is stored locally using UserDefaults

### Permissions
- **Website Access**: Required to analyze and highlight content
- **Siri Integration**: Required for voice commands

## Troubleshooting

### Extension Not Appearing
1. Ensure Safari extension is enabled in Preferences
2. Check that you're using Safari 16.0 or later
3. Restart Safari

### Highlighting Not Working
1. Click the toolbar button to ensure highlighting is enabled
2. Check that the website allows content scripts
3. Review Console logs for errors

### Siri Not Responding
1. Ensure Siri is enabled on your device
2. Check that the extension has Siri permissions
3. Try restarting the device

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

See LICENSE.md in the repository root.

## Acknowledgments

Built on top of the ml-stable-diffusion repository by Apple, leveraging Core ML for on-device machine learning.
