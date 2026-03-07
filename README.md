# 🌞 Voice AI Solar Dashboard

A Flutter mobile application that wraps the **aALoK Solar Monitoring Dashboard** in a WebView and lets users control it with **voice commands** and **text input** via an on-device **Smart Assistant**. No API calls — everything runs locally using pattern matching and JavaScript injection.

---

## ✨ Features

| Feature | Description |
|---------|-------------|
| **Voice & Text Control** | Navigate the dashboard hands-free using natural language |
| **On-Device AI** | All command routing runs locally — no external API calls |
| **Dynamic Discovery** | Plants, sensors, inverters, and filter types are scraped at runtime — nothing hardcoded |
| **Multi-Step Alert Flow** | Guided flow for filtering alerts: select plants → devices → date range |
| **Fuzzy Matching** | Finds the best match even with voice transcription typos |
| **Smart Suggestions** | Context-aware suggestion chips based on current page and action |
| **Plant Detail Local Search** | "Select inverter X" or "filter by temperature" on a plant detail page stays on that page |

---

## 🏗️ Architecture

```
lib/
├── main.dart                          # App entry point
├── config.dart                        # Base URL & system prompt config
├── screens/
│   └── home_screen.dart               # Main screen: header + WebView + chat overlay
├── widgets/
│   ├── chat_panel.dart                # Chat UI with messages, suggestions, mic, send
│   ├── suggestion_chips.dart          # Suggestion chip widget
│   └── webview_container.dart         # WebView widget with progress bar
├── models/
│   └── chat_message.dart              # Chat message & tool call models
├── services/
│   ├── command_router.dart            # 🧠 Core: pattern-matches user input → tool calls
│   ├── web_data_discovery.dart        # Scrapes live data from the website at runtime
│   └── webview_controller_service.dart # WebView controller + JS execution bridge
└── tools/
    ├── tool_registry.dart             # Registers & executes all tools by name
    ├── navigation_tools.dart          # Page navigation (dashboard, plants, sensors, etc.)
    ├── plant_tools.dart               # Plant card scraping & clicking
    ├── sensor_tools.dart              # Sensor table scraping & clicking
    ├── sensor_detail_tools.dart       # Sensor detail page value reading
    └── page_interaction_tools.dart    # Generic page tools: click, scroll, alerts, filters
```

### How It Works

```
User speaks / types
       ↓
  CommandRouter.processMessage()
       ↓
  Pattern-match to a command
       ↓
  ToolRegistry.executeTool()
       ↓
  JavaScript injected into WebView
       ↓
  Dashboard UI responds
```

1. **User input** goes to `CommandRouter` which pattern-matches it to a known command
2. The matched command calls a **tool** via `ToolRegistry`
3. Tools execute **JavaScript** in the embedded WebView to interact with the dashboard
4. Results are shown in the chat as text + suggestion chips

---

## 🗣️ Supported Commands

### Navigation
| Command | Action |
|---------|--------|
| `open dashboard` | Navigate to dashboard |
| `open plants` | Navigate to plants list |
| `open sensors` | Navigate to sensors list |
| `open inverters` | Navigate to inverters list |
| `open slms` | Navigate to SLMs page |
| `open alerts` | Open alerts page & start filter flow |
| `go back` | Go to previous page |

### Plant Commands
| Command | Action |
|---------|--------|
| `open [plant name] plant` | Open a specific plant's detail page |
| `show energy for [plant name]` | Show energy data for a plant |
| `show yearly revenue for [plant name]` | Show revenue with period filter |

### Sensor Commands
| Command | Action |
|---------|--------|
| `open sensor [name]` | Open a specific sensor |
| `filter wms` / `filter temperature` | Filter sensors by type |
| `get sensor value` | Read current sensor reading |

### Dashboard Tabs
| Command | Action |
|---------|--------|
| `show energy` / `show revenue` | Switch dashboard tab |
| `monthly` / `yearly` / `lifetime` | Change period view |
| `change month to April` | Navigate to a specific month |
| `year 2024` | Navigate to a specific year |
| `next month` / `previous month` | Step through months |

### Alert Flow (Multi-Step)
| Step | Command |
|------|---------|
| Start | `open alerts` |
| Select plants | Tap a plant suggestion or type a name |
| More plants | `select more plants` |
| Next step | `next: select devices` |
| Select devices | Tap a device suggestion or type a name |
| Set dates | `01/01/2026 to 07/03/2026` |
| Cancel | `cancel` / `stop` / `exit` |

### Plant Detail Page (Context-Aware)
| Command | Action |
|---------|--------|
| `select [inverter name]` | Click item on current page only |
| `filter by temperature` | Click filter tab on current page only |
| `filter by inverter` | Click filter tab on current page only |

### Other
| Command | Action |
|---------|--------|
| `scroll up` / `scroll down` | Scroll the page |
| `read page` | Read the current page content |

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** ≥ 3.11.1
- **Android Studio** / **VS Code** with Flutter extension
- Android device or emulator (API 21+)

### Setup

```bash
# Clone the repository
git clone <repository-url>
cd Voice-AI-Solar-Dashboard

# Install dependencies
flutter pub get

# Run on a connected device
flutter run
```

### Build APK

```bash
flutter build apk --release
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

---

## 📦 Dependencies

| Package | Purpose |
|---------|---------|
| `webview_flutter` | Embed the solar dashboard website |
| `speech_to_text` | Voice-to-text for voice commands |

---

## 🔧 Configuration

Edit `lib/config.dart` to change the dashboard URL:

```dart
class AppConfig {
  static const String websiteBaseUrl = 'https://aalok.dyulabs.co.in';
  static const String dashboardUrl = '$websiteBaseUrl/dashboard';
}
```

---

## 📱 App Structure

- **Header Bar** — Shows current page title, back button, refresh button
- **WebView** — Full-screen embedded dashboard
- **Chat Panel** — Draggable overlay at the bottom with:
  - Message history (user + AI responses)
  - Tool call indicators (executing / done)
  - Context-aware suggestion chips
  - Text input field
  - Microphone button for voice input
  - Send button

---

## 🧠 Key Design Decisions

- **No external API** — All command routing is local pattern matching (`CommandRouter`)
- **No hardcoded data** — `WebDataDiscovery` scrapes plant/sensor/inverter names at runtime
- **Fuzzy matching** — `clickBestMatch()` uses token overlap + edit distance for voice typo tolerance
- **Context-aware routing** — Plant detail page commands stay local; other pages use standard navigation
- **Alert state machine** — Multi-step flow with escape hatch for explicit navigation commands

---

## 📄 License

Private project — not published to pub.dev.
