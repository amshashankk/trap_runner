import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../audio/sound.dart';
import '../core/log.dart';
import '../data/characters.dart';
import '../data/level_data.dart';
import '../data/progress_store.dart';
import 'adaptive_trap_manager.dart';
import 'config.dart';
import 'level.dart';

enum Phase { playing, respawning, paused, dead, won, gameComplete }

/// Lightweight input state shared between the keyboard handler and the
/// on-screen touch buttons.
class Input {
  bool left = false;
  bool right = false;
  bool jump = false;

  void reset() {
    left = false;
    right = false;
    jump = false;
  }
}

/// Root game. Owns the camera, the active [Level], the lives/level-progression
/// state machine, and the overlay transitions. Flutter overlays read state via
/// [hud] (a tick notifier) and call the public intent methods (retry, next…).
class TrapRunnerGame extends FlameGame with KeyboardEvents {
  TrapRunnerGame({
    required this.progress,
    required this.startIndex,
    required this.character,
    required this.onExitToMenu,
  }) {
    Sound.setCharacter(character.id);
  }

  final ProgressStore progress;
  final int startIndex;
  final GameCharacter character;
  final VoidCallback onExitToMenu;

  final Input input = Input();

  /// Bumped whenever HUD-relevant state changes so overlays can rebuild.
  final ValueNotifier<int> hud = ValueNotifier<int>(0);

  Level? level;
  AdaptiveTrapManager? adaptive;
  int levelIndex = 0;
  int lives = Config.livesPerLevel;
  int deaths = 0;
  Phase phase = Phase.playing;

  bool get running => phase == Phase.playing;
  LevelData get levelData => kLevels[levelIndex];
  bool get hasNextLevel => levelIndex + 1 < kLevelCount;

  @override
  Color backgroundColor() => Config.sky;

  /// Fill the whole screen: scale so the full level *height* is visible and let
  /// the (narrower) world sit centred, with the sky backdrop covering the sides
  /// instead of black letterbox bars.
  void _fitCamera() {
    if (size.x <= 0 || size.y <= 0) return;
    camera.viewfinder.anchor = Anchor.center;
    camera.viewfinder.zoom = size.y / Config.worldHeight;
    camera.viewfinder.position =
        Vector2(Config.worldWidth / 2, Config.worldHeight / 2);
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _fitCamera();
  }

  @override
  Future<void> onLoad() async {
    _fitCamera();
    world.add(_Backdrop());
    await loadLevel(startIndex);
  }

  Future<void> loadLevel(int index) async {
    levelIndex = index;
    lives = Config.livesPerLevel;
    phase = Phase.playing;
    input.reset();
    _clearOverlays();

    // Keep the adaptive manager across retries of the SAME level so it learns
    // from repeated attempts; reset it when moving to a different level.
    if (adaptive == null || adaptive!.levelIndex != index) {
      adaptive = AdaptiveTrapManager(index);
    }

    level?.removeFromParent();
    final next = Level(kLevels[index]);
    level = next;
    await world.add(next);

    adaptive!.beginAttempt();
    next.applyAdaptive(adaptive!);

    overlays.add('hud');
    Log.i('game', 'Loaded level ${index + 1} (${kLevels[index].title})');
    _bump();
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (phase == Phase.playing) {
      final p = level?.player;
      if (p != null && !p.isDead) adaptive?.sample(p.position, dt);
    }
  }

  // --- player event callbacks (called from components) ---

  void onPlayerJump() => Sound.jump();
  void onPlayerLand() => Sound.land();

  void onPlayerDeath({bool fell = false}) {
    if (phase != Phase.playing) return;
    deaths++;
    lives--;
    progress.addDeath();
    final p = level?.player;
    if (p != null) {
      adaptive?.recordDeath(p.position);
      level?.spawnDeathBurst(p.position + p.size / 2, character.color);
    }
    fell ? Sound.fall() : Sound.die();
    Log.i('game', 'Death on level ${levelIndex + 1} (lives left $lives, '
        '${fell ? 'fell' : 'trap'})');
    if (lives <= 0) {
      phase = Phase.dead;
      overlays.add('dead');
    } else {
      phase = Phase.respawning;
      Future.delayed(const Duration(milliseconds: 550), () {
        if (phase != Phase.respawning) return;
        level?.restart();
        // Re-adapt: the traps shift their timing for this fresh attempt.
        if (level != null && adaptive != null) {
          adaptive!.beginAttempt();
          level!.applyAdaptive(adaptive!);
        }
        phase = Phase.playing;
        _bump();
      });
    }
    _bump();
  }

  void onReachExit() {
    if (phase != Phase.playing) return;
    phase = Phase.won;
    Sound.win();
    progress.completeLevel(levelIndex);
    overlays.add(hasNextLevel ? 'won' : 'gameComplete');
    _bump();
  }

  // --- intents from overlays ---

  void retryLevel() {
    Sound.click();
    loadLevel(levelIndex);
  }

  void nextLevel() {
    Sound.click();
    if (hasNextLevel) {
      loadLevel(levelIndex + 1);
    } else {
      onExitToMenu();
    }
  }

  void pause() {
    if (phase != Phase.playing) return;
    phase = Phase.paused;
    input.reset();
    overlays.add('pause');
    pauseEngine();
    _bump();
  }

  void resume() {
    if (phase != Phase.paused) return;
    overlays.remove('pause');
    resumeEngine();
    phase = Phase.playing;
    _bump();
  }

  void quitToMenu() {
    Sound.click();
    onExitToMenu();
  }

  /// Toggle the music track, persisting the choice.
  Future<void> toggleMusic() async {
    final next = !Sound.musicEnabled;
    await Sound.setMusicEnabled(next);
    await progress.setMusicEnabled(next);
    Log.i('audio', 'Music ${next ? 'on' : 'off'}');
    _bump();
  }

  /// Toggle sound effects, persisting the choice.
  Future<void> toggleSfx() async {
    final next = !Sound.sfxEnabled;
    Sound.setSfxEnabled(next);
    await progress.setSfxEnabled(next);
    Log.i('audio', 'SFX ${next ? 'on' : 'off'}');
    _bump();
  }

  /// Dev-only: instantly clear the current level and advance.
  void devSkipLevel() {
    Log.w('dev', 'Skip level ${levelIndex + 1}');
    progress.completeLevel(levelIndex);
    if (hasNextLevel) {
      loadLevel(levelIndex + 1);
    } else {
      _clearOverlays();
      overlays.add('gameComplete');
      phase = Phase.gameComplete;
      _bump();
    }
  }

  void _clearOverlays() {
    for (final o in ['hud', 'won', 'dead', 'pause', 'gameComplete']) {
      overlays.remove(o);
    }
  }

  void _bump() => hud.value++;

  // --- keyboard ---

  @override
  KeyEventResult onKeyEvent(
      KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    final isDown = event is KeyDownEvent || event is KeyRepeatEvent;
    final key = event.logicalKey;

    if (event is KeyDownEvent) {
      if (key == LogicalKeyboardKey.escape ||
          key == LogicalKeyboardKey.keyP) {
        if (phase == Phase.paused) {
          resume();
        } else {
          pause();
        }
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.keyR) {
        retryLevel();
        return KeyEventResult.handled;
      }
    }

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.keyA) {
      input.left = isDown;
    } else if (key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.keyD) {
      input.right = isDown;
    } else if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.keyW ||
        key == LogicalKeyboardKey.keyZ) {
      input.jump = isDown;
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }
}

/// A simple vertical-gradient sky drawn behind the world.
class _Backdrop extends Component with HasGameReference<TrapRunnerGame> {
  @override
  int get priority => -100;

  @override
  void render(Canvas canvas) {
    // Extend well past the level on both sides so the gradient (not black bars)
    // fills the screen when the world is narrower than the device.
    const overscan = 600.0;
    final rect = Rect.fromLTWH(
        -overscan, 0, Config.worldWidth + overscan * 2, Config.worldHeight);
    final shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Config.sky, Config.skyLow],
    ).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }
}
