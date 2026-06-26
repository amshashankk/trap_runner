# Trap Runner

> **"The level fights back."**

A 2D adaptive-trap platformer built with Flutter + Flame. Run through 100 procedurally-generated levels packed with spikes, crushers, moving platforms, and timed gates. The trap system records where you die and shifts timing on every retry — the level learns your habits.

## Tech Stack

| Package | Version |
|---|---|
| `flame` | ^1.37.0 |
| `flame_tiled` | ^3.1.1 |
| `flame_audio` | ^2.12.1 |
| `shared_preferences` | ^2.5.5 |

## Features (Phase 1 + 2 + 3 complete)

- **100 procedurally-generated Tiled levels** (`level_001.tmx` … `level_100.tmx`), guaranteed solvable by construction (gaps ≤ 4 tiles, climbs ≤ 3 tiles, within jump reach)
- **Adaptive Trap System (Phase 3)** — on each retry, trap *timing/phase* shifts (never positions) toward the player's death spot; anti-memorization jitter grows with repeated failures (capped); every trap keeps a passable window; manager persists across retries of the same level
- **4 trap types:** Spikes (horizontally patrolling), Crusher (slams down), MovingPlatform (ride it), Gate-wall (wait for it to open)
- **Level-select map** with unlock progression
- **Lives / retry system** (3 lives per run)
- **Procedural SFX and music** generated with Python (`wave` module)
- **Keyboard and touch controls** (web and Android); in-game sound toggle in HUD
- **Dev / Prod flavors** — dev unlocks all levels, adds floating debug overlay, HUD skip-level button, and an in-app log viewer

## Controls

| Action | Keyboard | Touch |
|---|---|---|
| Move left / right | `A`/`D` or `←`/`→` | On-screen buttons |
| Jump | `Space` / `W` / `↑` | On-screen button |
| Pause | `P` / `Esc` | On-screen button |
| Retry | `R` | On-screen button |

## Getting Started

```bash
flutter pub get

# Web
flutter run -d chrome

# Android — dev flavor (all levels unlocked, debug overlay)
flutter run --flavor dev --dart-define=DEV_MODE=true --dart-define=FLAVOR=dev
```

> **Note:** macOS and iOS builds require a full Xcode installation (not just Command Line Tools). Web and Android are the primary targets.

### Deep-link into a specific level (web)

Append `?play=N` (N = 1–100) to jump straight into a level:

```
http://localhost:XXXX/?play=42
```

## Building Release APKs

```bash
# Dev flavor — installs alongside prod (different package suffix)
flutter build apk --flavor dev \
  --dart-define=DEV_MODE=true \
  --dart-define=FLAVOR=dev \
  --no-tree-shake-icons
# → build/app/outputs/flutter-apk/app-dev-release.apk

# Prod flavor
flutter build apk --flavor prod \
  --dart-define=FLAVOR=prod \
  --no-tree-shake-icons
# → build/app/outputs/flutter-apk/app-prod-release.apk
```

## Running Tests

```bash
flutter test
```

108 tests cover:

- Level catalogue — all 100 levels registered and accessible
- Asset pipeline — loads all 100 `.tmx` files through the real Flame asset loader
- Progress / unlock persistence via `shared_preferences`
- Trap timing (crusher cycle, gate open/close intervals)

## Architecture

```
lib/
├── main.dart
├── core/
│   ├── app_config.dart
│   └── log.dart                    # App-wide Log.i/w/e/d ring buffer + dart:developer;
│                                   #   global error capture (FlutterError, PlatformDispatcher,
│                                   #   runZonedGuarded); viewable via dev log screen
├── game/
│   ├── trap_runner_game.dart        # Root FlameGame — input routing, viewport, state machine
│   ├── level.dart                   # Loads .tmx as data; parses Ground tiles + Objects layer
│   ├── adaptive_trap_manager.dart   # Phase 3 — tracks path/death, shifts trap timing per retry
│   └── components/
│       ├── ground.dart              # GroundRenderer — canvas-painted terrain (see note below)
│       ├── player.dart              # Manual AABB physics, coyote-time, jump-buffer, variable height
│       └── traps.dart               # All trap types; self-drawn with canvas API
├── data/
│   ├── level_data.dart              # Generated — do not hand-edit (see Assets below)
│   └── progress_store.dart          # shared_preferences persistence
└── ui/
    ├── app.dart
    ├── main_menu_screen.dart
    ├── level_select_screen.dart
    ├── game_screen.dart
    ├── overlays.dart                # HUD, Pause, Win, Dead, GameComplete
    └── dev/
        └── dev_overlay.dart         # Floating debug overlay (dev flavor only)
```

### Key design notes

**`adaptive_trap_manager.dart`** — Records the player's path and death position each run. On retry, shifts trap timing/phase only (positions are fixed in the `.tmx`). Jitter magnitude grows with repeated failures at the same spot (capped), and traps near the death location get a higher targeting bias. Every trap always has a passable window, so the level remains solvable. The manager persists for the lifetime of a level session.

**`ground.dart` (`GroundRenderer`)** — Paints terrain directly to the canvas rather than using `flame_tiled`'s tile renderer. `flame_tiled`'s `drawImageRect` atlas pipeline renders tiles as white/blank on web CanvasKit, so terrain is drawn manually from tile IDs. Tileset image lives in `assets/images/` (Flame's `Flame.images` prefix); `.tmx` files live in `assets/tiles/`.

**`player.dart`** — Manual axis-separated AABB collision for tight, predictable platforming. Implements coyote-time, jump-buffering, and variable jump height (hold to jump higher).

**`traps.dart`** — All trap types draw themselves with the canvas API; no external sprite art required.

## Assets

All assets are procedurally generated — **do not hand-edit `lib/data/level_data.dart`**; regenerate everything with:

```bash
python3 tools/gen_assets.py
```

This produces:

- `assets/images/tileset.png` — PIL-generated tileset
- `assets/tiles/level_001.tmx` … `level_100.tmx` — procedurally generated, guaranteed-solvable Tiled maps
- `assets/audio/*.wav` — Python `wave`-generated SFX and music tracks
- `lib/data/level_data.dart` — level catalogue (auto-generated)

## Roadmap

| Phase | Status |
|---|---|
| Phase 1 — Core platforming engine | Done |
| Phase 2 — 100 levels, traps, level-select, lives | Done |
| Phase 3 — Adaptive Trap System | Done |
| Phase 4 — Monetization (AdMob, IAP) | Planned |
| Phase 5 — Launch | Planned |
