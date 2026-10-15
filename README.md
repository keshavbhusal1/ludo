# 🎲 Ludo Offline - Pure Flutter Game Engine

A production-ready, completely offline 2D Ludo game built with Flutter. Designed with **Clean Architecture**, a deterministic pure Dart game engine, heuristic-driven offline bot AI, local state persistence, responsive `CustomPainter` rendering, and **zero external pub dependencies**.

---

## 🌟 Key Features

- **📱 Completely Offline & Zero Dependencies:** Operates 100% locally with zero network calls and zero third-party pub packages. Everything is crafted using the Flutter SDK and Dart standard libraries.
- **📐 Mathematical Graph Coordinates (15×15):** Precise coordinate graph pathing with 52 perimeter tiles, 4 home yards (4 slots each), 4 colored home runs (5 tiles each), 8 safe zones (4 starts + 4 stars), and a center apex goal.
- **🎲 Single Shared Dice & 3D Tumbling Overlay:**
  - One central HUD dice displaying the active player's color.
  - Full-screen tumbling 3D dice overlay with perspective tilt and dynamic pip face cycling on human roll.
  - Seamless in-HUD rolling for offline bots to keep gameplay fluid and unobtrusive.
- **🤖 Smart Heuristic Bot AI:**
  - Multi-tier tactical evaluation: Opponent capture (`+100`), Safe zone advancement (`+60`), Token home entry (`+50`), Escape enemy threat (`+40`), and Yard breakout (`+20`).
  - Humanized thinking delays (`600ms–900ms`) for natural game pacing.
- **🎮 Multiple Game Modes & Flexible Rules:**
  - **Classic Mode:** All 4 tokens must reach home to win.
  - **Quick 1 Mode:** First token home wins.
  - **Quick 2 Mode:** First 2 tokens home win.
  - **Configurable Rules:** Capture required before entering home run, roll 1 or 6 to exit yard, 3 consecutive sixes penalty, and extra turns on 6 / capture / home token.
- **🎨 Visual Themes:**
  - **Dark Modern:** Deep slate navy (`#0F172A`) with vibrant primary accents.
  - **Classic Wooden:** Warm textured wood board styling.
  - **Cyberpunk Neon:** High-contrast synthwave palette.
- **💾 Auto-Save & Resume:**
  - Deterministic JSON game state serialization saved on every roll and hop.
  - Instant match restoration banner on app launch.
- **📳 Tactile Haptic Feedback:** Native vibration patterns for dice rolling, token hops, captures, and victory.
- **🖥️ Responsive Scaling:** 1:1 board aspect ratio adapts across mobile phones and tablets framed by 4 corner player status badges.

---

## 🏗️ Architecture & Directory Structure

Built following Clean Architecture principles, completely decoupling pure game math and state from UI rendering.

```
lib/
├── core/
│   ├── coordinates/
│   │   ├── board_coordinate.dart      # 15x15 coordinate definition
│   │   └── board_path_registry.dart   # Graph paths, safe zones, yard slots
│   ├── services/
│   │   ├── game_storage_service.dart  # Offline JSON match state persistence
│   │   └── haptics_service.dart       # Native Android haptic feedback
│   └── theme/
│       └── board_theme.dart           # Dark Modern, Wooden, and Neon themes
│
├── models/
│   ├── board_theme_type.dart          # Visual theme enum
│   ├── game_rules.dart                # Rules & victory conditions
│   ├── game_state.dart                # Immutable root state with JSON serialization
│   ├── move.dart                      # Hop trajectory & move mechanics
│   ├── pawn.dart                      # Pawn state (yard, track, home run, home)
│   ├── pawn_position.dart             # Sealed coordinate position hierarchy
│   ├── player.dart                    # Player metadata & pawn collections
│   └── player_color.dart              # Red, Green, Yellow, Blue definitions
│
├── engine/
│   ├── ludo_game_controller.dart      # Pure Dart state machine & rule engine
│   └── ludo_ai_engine.dart            # Heuristic bot decision engine
│
├── presentation/
│   ├── painters/
│   │   ├── ludo_board_painter.dart    # 15x15 vector board renderer
│   │   └── pawn_painter.dart          # 3D token renderer with selection bounce
│   ├── screens/
│   │   └── ludo_game_screen.dart      # Main game scaffold & orchestration
│   └── widgets/
│       ├── badges/
│       │   └── player_badge_widget.dart   # 4 corner player status chips
│       ├── confetti/
│       │   └── confetti_overlay.dart      # Zero-dep particle victory fanfare
│       ├── dialogs/
│       │   └── game_setup_dialog.dart     # Rules, AI config, & theme selector
│       └── dice/
│           ├── animated_dice_widget.dart          # Shared HUD dice widget
│           └── full_screen_dice_roll_overlay.dart # 3D tumbling roll overlay
│
└── main.dart                          # App entry point & global M3 theme
```

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (v3.19+ recommended)
- Android Studio / VS Code with Dart & Flutter extensions
- Android device or emulator (Android 7.0+ / API 24+)

### Installation & Run

1. Clone or navigate to the repository:
   ```bash
   cd /Users/keshav/StudioProjects/ludo
   ```

2. Verify dependencies (no external pub packages needed):
   ```bash
   flutter pub get
   ```

3. Run the application:
   ```bash
   flutter run
   ```

---

## 🧪 Testing

The codebase includes comprehensive unit tests verifying coordinate graph mappings, rule enforcement, win conditions, and JSON state persistence.

Run all tests:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## 📦 Building Android APK

Build a debug APK:
```bash
flutter build apk --debug
```

Build an optimized release APK:
```bash
flutter build apk --release
```

The compiled binary will be generated at:
`build/app/outputs/flutter-apk/app-release.apk`

---

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.
