import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';

import '../data/characters.dart';

/// Audio facade. Two independent channels the player can toggle: [musicEnabled]
/// (the looping track) and [sfxEnabled] (jump/die/fall/win/click). Sound effects
/// are per-character — [setCharacter] selects which voice plays.
class Sound {
  static bool _ready = false;
  static bool musicEnabled = true;
  static bool sfxEnabled = true;
  static int _char = 0;

  static List<String> _allSfx() {
    final shared = ['land.wav', 'click.wav'];
    final perChar = <String>[];
    for (var c = 0; c < kCharacterCount; c++) {
      perChar.addAll(['c${c}_jump.wav', 'c${c}_die.wav',
        'c${c}_fall.wav', 'c${c}_win.wav']);
    }
    return [...shared, ...perChar];
  }

  static Future<void> init({
    required bool music,
    required bool sfx,
    int character = 0,
  }) async {
    musicEnabled = music;
    sfxEnabled = sfx;
    _char = character;
    try {
      await FlameAudio.audioCache.loadAll(_allSfx());
      _ready = true;
    } catch (e) {
      debugPrint('Sound init failed (continuing silent): $e');
      _ready = false;
    }
  }

  static void setCharacter(int id) => _char = id;

  static void _play(String file, {double volume = 1.0}) {
    if (!_ready || !sfxEnabled) return;
    try {
      FlameAudio.play(file, volume: volume);
    } catch (e) {
      debugPrint('Sound play failed: $e');
    }
  }

  // character-specific
  static void jump() => _play('c${_char}_jump.wav', volume: 0.6);
  static void die() => _play('c${_char}_die.wav', volume: 0.7);
  static void fall() => _play('c${_char}_fall.wav', volume: 0.6);
  static void win() => _play('c${_char}_win.wav', volume: 0.7);
  // shared
  static void land() => _play('land.wav', volume: 0.4);
  static void click() => _play('click.wav', volume: 0.5);

  static void startMusic() {
    if (!musicEnabled) return;
    try {
      FlameAudio.bgm.initialize();
      FlameAudio.bgm.play('music.wav', volume: 0.35);
    } catch (e) {
      debugPrint('Music start failed: $e');
    }
  }

  static void stopMusic() {
    try {
      FlameAudio.bgm.stop();
    } catch (_) {}
  }

  static Future<void> setMusicEnabled(bool value) async {
    musicEnabled = value;
    if (value) {
      startMusic();
    } else {
      stopMusic();
    }
  }

  static void setSfxEnabled(bool value) {
    sfxEnabled = value;
    if (value) click();
  }
}
