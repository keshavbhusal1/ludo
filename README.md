# 🎲 Ludo Offline

An offline 2D Ludo game for 2–4 players (any mix of humans and bots) built with Flutter. Game rules live in a pure, stateless Dart engine; a BLoC owns the match state; the board is drawn with `CustomPainter`. No network access is used.

---

## 🌟 Features

- **🎲 Board & rules**
  - 15×15 board: 52-tile common track, 4 yards, 4 five-tile home columns, and a center goal.
  - 8 safe squares (4 start squares + 4 stars) where tokens coexist without capture.
  - Exact roll required to reach home; landing on an opponent on a non-safe square sends it back to its yard.
  - Extra roll for a 6, a capture, or a token reaching home.
  - Too many consecutive 6s (3 by default) forfeits the turn.
  - If a roll has no legal move, the turn passes automatically.
- **🎮 Game modes** (chosen in Match Settings)
  - **Classic:** all 4 tokens home to win.
  - **Quick:** first token home wins; each player starts with 1 token already on the board.
  - **Rush:** first 2 tokens home win.
  - Optional rules: *Must capture before home* and *Unlock with 1 or 6*.
- **🤖 Bots** with three difficulty levels (Easy, Medium, Grandmaster). Moves are scored by heuristics:
  - Medium weights: capture `+100`, landing on a safe square `+60`, reaching home `+50`, escaping a threat `+40`, leaving the yard `+20`, plus a small bonus for advancing tokens further along.
  - Easy picks a random move 40% of the time.
  - Grandmaster raises the weights and penalizes moving into an opponent's reach.
  - Bots "think" for 600–900 ms before rolling and 450–750 ms before moving.
- **↩️ Undo & move history**
  - Undo returns to the most recent point where a human had more than one token to choose from, **with the same dice** (no re-rolling), undoing any bot turns since. Press again to step further back.
  - The history sheet logs every roll: moves, captures (with the victim), tokens reaching home, rolls with no legal move, and sixes penalties.
- **💾 Autosave & resume**
  - The match, its history, and the last 10 undo points are saved after every roll and move, via `shared_preferences`.
  - On launch, an unfinished match is offered in a *Previous match found* banner. Until you resume or dismiss it, the new game isn't saved, so the old match can't be overwritten.
- **🎨 Board themes:** Dark Modern, Classic Wood, Cyber Neon, Royal Marble.
- **🎬 Presentation:** full-screen tumbling dice overlay for human rolls, inline rolls for bots, hop-by-hop pawn animation with path previews, and confetti on victory.
- **📳 Haptics** for dice rolls, pawn hops, and victory (toggle in the app bar).

The app starts a 4-player Classic match with all seats human. Use **Settings** to choose players, bots, mode, difficulty, rules, and theme.

---

## 🏗️ Architecture

```
UI (screen, widgets) ──events──▶ LudoBloc ──▶ use cases ──▶ LudoEngine (pure rules)
        ▲                          │                    └──▶ repository ──▶ shared_preferences
        └─────────state────────────┘
```

- **`LudoEngine`** is pure and stateless: `rollDice(state, roll)`, `executeMove(state, move)`, and so on take a `GameState` and return the next one. It has no randomness (dice values are passed in) and never plays a move on its own.
- **`LudoBloc`** owns the match. `LudoActiveState.gameState` is the only copy of the game, alongside the move history, undo points, and UI state such as the in-flight dice roll and pawn animation.
  - Events are processed strictly one at a time.
  - Bot thinking and other delays are timers owned by the BLoC. They are cancelled when a different match takes over, so stale bot actions can't leak into a new or resumed game.
- **Use cases** wrap the engine and the repository and return `Either<Failure, T>` (fpdart). `RollDiceUseCase` holds the dice `Random`.
- **Dependency injection** is done with `get_it` in `bootstrap.dart`.

### Directory structure

```
lib/
├── main.dart                        # Entry point: bootstrap() then runApp
├── bootstrap.dart                   # DI registration, portrait lock, shared_preferences
├── app/
│   ├── app.dart                     # MaterialApp + BlocProvider
│   └── theme/app_theme.dart         # Global dark Material theme
├── core/
│   ├── coordinates/
│   │   ├── board_coordinate.dart    # 15×15 grid coordinate
│   │   └── board_path_registry.dart # Track, home columns, yards, safe squares, step→cell mapping
│   ├── errors/failures.dart         # Failure types used by Either results
│   └── services/haptics_service.dart
├── engine/
│   ├── ludo_game_engine.dart        # Pure rules engine (state in → state out)
│   ├── ludo_engine.dart             # Barrel export of the engine and models
│   └── ai/ludo_ai_engine.dart       # Bot move scoring and thinking delays
├── models/
│   ├── game_state.dart              # Immutable match state + JSON
│   ├── game_config.dart             # Game modes (Classic/Quick/Rush), timer config
│   ├── game_rules.dart              # Rule options, win conditions, AI difficulty
│   ├── player.dart, token.dart      # Players and their 4 tokens
│   ├── player_color.dart            # Colors, start squares, palette
│   ├── board_position.dart          # Sealed token position (base/track/home column/goal)
│   ├── move.dart                    # A legal move and its hop trajectory
│   ├── history_entry.dart           # One resolved roll in the move history
│   ├── saved_match.dart             # Persisted match: game + history + undo points
│   └── pawn.dart, pawn_position.dart  # Legacy aliases for Token / BoardPosition
├── features/ludo/
│   ├── data/
│   │   ├── datasources/ludo_local_data_source.dart  # shared_preferences JSON storage
│   │   └── repositories/ludo_repository_impl.dart
│   ├── domain/
│   │   ├── repositories/ludo_repository.dart
│   │   └── usecases/                # roll dice, execute move, get/save/clear saved match
│   └── presentation/
│       ├── bloc/                    # LudoBloc, events, states
│       └── screens/ludo_game_screen.dart
└── presentation/
    ├── screens/ludo_game_screen.dart  # Re-export of the feature screen
    ├── themes/board_theme.dart        # The four board themes
    └── widgets/
        ├── board/                   # Board painter, board widget, pawn widget
        ├── dialogs/game_setup_dialog.dart
        ├── dice/                    # HUD dice and full-screen roll overlay
        ├── effects/confetti_overlay.dart
        └── hud/                     # Player badges, move history sheet
```

### Saved-game format

The autosave is a single JSON value under the `shared_preferences` key `ludo_autosave_v1`. The key name predates the current format. Its contents are a `SavedMatch` (format version 2):

- The game state.
- The full move history. Moves are stored without their animation paths.
- The 10 most recent undo points. The BLoC keeps up to 50 in memory.

Version 1 saves (a bare `GameState`) still load, with empty history. Saves from a newer format version are rejected rather than misread.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart `^3.13.5` (see `pubspec.yaml`).
- Android (minimum SDK is Flutter's default) or iOS 15.0+. Platform folders also exist for web, macOS, Windows, and Linux.

### Dependencies

| Package | Used for |
|---|---|
| `flutter_bloc` | State management |
| `get_it` | Dependency injection |
| `fpdart` | `Either` results from use cases |
| `shared_preferences` | Autosave storage |
| `bloc_test` (dev) | BLoC tests |
| `flutter_lints` (dev) | Lint rules |

`cupertino_icons` and `mocktail` are declared in `pubspec.yaml` but not currently used.

### Run

```bash
flutter pub get
flutter run
```

---

## 🧪 Testing

```bash
flutter test      # all tests
flutter analyze   # static analysis
```

| File | Covers |
|---|---|
| `test/ludo_engine_test.dart` | Board topology, rules (captures, safe squares, exact home, sixes, mandatory capture), game modes, serialization, AI scoring |
| `test/features/ludo/presentation/bloc/ludo_bloc_test.dart` | Turn flow, forced moves, bot timing and game speed, stale-event handling, resume banner, undo and history, persistence across resume |
| `test/features/ludo/data/ludo_local_data_source_test.dart` | Save/load/clear, corrupt and future-format saves, v1 compatibility, history and undo persistence |
| `test/widget_test.dart` | Screen loads, dice overlay, undo button and history sheet |

Test helpers:
- `test/helpers/ludo_game_controller.dart` is a small stateful wrapper over the pure engine, used by the engine tests.
- `test/helpers/in_memory_local_data_source.dart` replaces real storage.

Widget tests must use the in-memory store and run `bootstrap()` in `setUpAll`. Inside `testWidgets`' fake-async zone, real platform channels and storage never complete.

---

## 🚧 Known gaps

- **Game speed has no control in the UI.** The engine and BLoC honor `GameRules.gameSpeed`, scaling bot thinking, dice settling, and pawn hops, but the setup dialog doesn't expose it, so it's always 1×. The consecutive-sixes limit is likewise only configurable in code.
- **The turn timer isn't used.** `TimerConfig` and `LudoEngine.handleTurnTimeout` (strikes and disconnects) exist and are tested, but nothing in the UI runs a turn timer.
- **Some haptics never fire.** `HapticsService.capture()` and `tokenHome()` are defined but never called. The haptics on/off setting isn't saved.
- **Unused and legacy code:** `player_station_widget.dart` is unused, and `pawn.dart`, `pawn_position.dart`, and `TurnPhase` are kept as legacy aliases.
- **Undo is shared in pass-and-play.** With several humans, undo returns to the most recent choice by any of them.

---

## 📦 Building

```bash
flutter build apk --release   # → build/app/outputs/flutter-apk/app-release.apk
flutter build ios --release
flutter build web
```
