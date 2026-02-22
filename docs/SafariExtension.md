# ML Content Highlighter – Safari Extension

A Safari Web Extension that uses Apple's on-device **Natural Language** framework and **Siri** to automatically highlight key passages of web content and let users find information with their voice.

---

## Table of Contents

1. [Features](#features)
2. [Architecture Overview](#architecture-overview)
3. [Requirements](#requirements)
4. [Installation](#installation)
   - [macOS](#macos)
   - [iOS / iPadOS](#ios--ipados)
5. [Configuration](#configuration)
6. [Siri Integration](#siri-integration)
7. [Building from Source](#building-from-source)
8. [Running the Tests](#running-the-tests)
9. [Project Structure](#project-structure)

---

## Features

| Feature | Description |
|---------|-------------|
| **NLP Highlighting** | Automatically detects *key points*, *summaries*, and *action items* using on-device NLP |
| **Siri Voice Commands** | Ask Siri "Find *<text>* on page" to jump to matching content |
| **Cross-platform** | Works in Safari on macOS 13+ and iOS/iPadOS 16+ |
| **Category Toggles** | Enable or disable each highlight category independently |
| **Colour Coding** | Each category has a distinct highlight colour configurable by the user |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│  Safari Browser                                                  │
│                                                                  │
│  ┌──────────────┐   messages    ┌───────────────────────────┐   │
│  │ content.js   │◄─────────────►│ background.js (SW)        │   │
│  │ (per-tab)    │               │ NLP scoring / routing     │   │
│  └──────────────┘               └───────────┬───────────────┘   │
│                                             │ native messaging  │
└─────────────────────────────────────────────┼───────────────────┘
                                              │
┌─────────────────────────────────────────────▼───────────────────┐
│  Swift Native Layer (SafariExtension package target)            │
│                                                                  │
│  ContentAnalyzer          – NaturalLanguage-powered scoring     │
│  SiriIntegrationHandler   – SiriKit vocab + intent dispatch     │
│  ExtensionConfiguration   – UserDefaults-backed preferences     │
└─────────────────────────────────────────────────────────────────┘
```

The extension is split into two layers:

* **Web layer** (`safari-extension/`) – runs inside Safari. `content.js` manipulates the DOM to wrap matched text in `<span class="ml-highlight">` elements. `background.js` performs lightweight JS-based NLP scoring and can forward requests to the native layer via the native-messaging protocol.

* **Native layer** (`swift/SafariExtension/`) – a Swift Package Manager library that provides heavier on-device NLP via `NaturalLanguage.framework`, Siri intent handling via `Intents.framework`, and shared configuration storage via `UserDefaults`.

---

## Requirements

| Platform | Minimum version |
|----------|----------------|
| macOS    | 13.0 (Ventura) |
| iOS / iPadOS | 16.0 |
| Xcode    | 15.0 |
| Swift    | 5.8 |

---

## Installation

### macOS

1. Open **Safari → Settings → Extensions**.
2. Click **"+"** and choose **"Open…"** or drag the built `.appex` bundle into the list.
3. Enable **ML Content Highlighter** and allow it access to *"All Websites"* (or specific sites of your choice).
4. The extension toolbar button appears in the Safari toolbar. Click it to open the configuration popup.

> **Note:** When loading an unsigned extension during development, you may need to enable **Safari → Develop → Allow Unsigned Extensions** first.

### iOS / iPadOS

1. Build and run the containing app target on your device or simulator via Xcode.
2. Navigate to **Settings → Safari → Extensions**.
3. Tap **ML Content Highlighter** and enable it.
4. Grant the extension permission to read the pages you visit.

---

## Configuration

The popup (click the toolbar button in Safari) exposes the following controls:

| Control | Description |
|---------|-------------|
| **Enable highlighting** | Master on/off switch |
| **Key Points** | Toggle yellow highlights for high-relevance body passages |
| **Summaries** | Toggle green highlights for introductory/concluding passages |
| **Action Items** | Toggle blue highlights for imperative sentences |
| **Find on page** | Type a query and press ↵ or 🔍 to scroll to the first match |
| **Highlight Now** | Re-run analysis on the current page |
| **Clear Highlights** | Remove all highlights without disabling the extension |

Settings are persisted in the browser's local storage (web layer) and in a shared `UserDefaults` app group (native layer) so they survive browser restarts.

### Programmatic configuration (Swift)

```swift
let config = ExtensionConfiguration.shared

// Disable the extension
config.isEnabled = false

// Enable only key-point highlights
config.enabledCategories = [.keyPoint]

// Change the key-point highlight colour
config.highlightColors["key-point"] = "#FFA726"
```

---

## Siri Integration

### Registering vocabulary

Call the following once during app startup (e.g. in `applicationDidFinishLaunching`):

```swift
SiriIntegrationHandler.shared.registerVocabulary()
```

This teaches Siri the extension's domain vocabulary ("key point", "action item", etc.) for improved speech recognition.

### Handling Siri find requests

In your `INExtension` subclass (Intents Extension target):

```swift
func handler(for intent: INIntent) -> Any {
    return SiriIntegrationHandler.shared
}
```

When Siri routes a find-on-page utterance to your extension, create a `FindRequest` and dispatch it:

```swift
let request = SiriIntegrationHandler.FindRequest(query: "machine learning")
try SiriIntegrationHandler.shared.dispatch(request)
```

`dispatch(_:)` writes a native-messaging message to `stdout`, which Safari delivers to the extension's `background.js`, which in turn sends a `findText` message to the active tab's `content.js`.

### Supported Siri phrases

After enabling the extension and granting Siri permissions, users can say:

* *"Find machine learning on page"*
* *"Highlight key points"*
* *"Show summaries"*
* *"Clear highlights"*

> Exact phrase support depends on the Intents Extension configuration in your Xcode project. The phrases above require an `NSUserActivity`-based Siri shortcut or a custom `INIntent` definition.

---

## Building from Source

```bash
# Clone the repository
git clone https://github.com/apple/ml-stable-diffusion.git
cd ml-stable-diffusion

# Build the SafariExtension library
swift build --target SafariExtension

# Build everything
swift build
```

### Xcode

Open `Package.swift` in Xcode. The `SafariExtension` library target and `SafariExtensionTests` test target will appear automatically alongside the existing StableDiffusion targets.

---

## Running the Tests

```bash
swift test --filter SafariExtensionTests
```

The test suite validates:

* `ContentAnalyzer` – NLP scoring, category assignment, and category filtering
* `SiriIntegrationHandler` – user-info serialisation / deserialisation
* `ExtensionConfiguration` – persistence, defaults, and reset behaviour

---

## Project Structure

```
safari-extension/          Web extension resources
├── manifest.json          Extension manifest (Manifest V3)
├── content.js             Per-tab DOM manipulation and highlighting
├── background.js          Service worker: NLP scoring and message routing
├── popup.html             Toolbar popup UI
├── popup.js               Popup logic
├── popup.css              Popup styles
└── styles.css             Injected page styles for highlight spans

swift/SafariExtension/     Swift Package Manager target (native layer)
├── ContentAnalyzer.swift          NLP-powered passage scoring
├── SiriIntegrationHandler.swift   Siri / SiriKit integration
└── ExtensionConfiguration.swift   Persisted user preferences

swift/SafariExtensionTests/
└── SafariExtensionTests.swift     Unit tests

docs/
└── SafariExtension.md     This file
```
