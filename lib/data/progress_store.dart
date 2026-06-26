import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import 'level_data.dart';

/// Persists meta-progression: which levels are unlocked/completed, total deaths,
/// and the mute preference. Backed by shared_preferences.
class ProgressStore {
  ProgressStore._(this._prefs);

  static const _kHighestUnlocked = 'highest_unlocked';
  static const _kCompleted = 'completed_levels';
  static const _kDeaths = 'total_deaths';
  static const _kMusic = 'music_enabled';
  static const _kSfx = 'sfx_enabled';
  static const _kCharacter = 'selected_character';

  final SharedPreferences _prefs;

  static Future<ProgressStore> load() async {
    final prefs = await SharedPreferences.getInstance();
    return ProgressStore._(prefs);
  }

  /// Highest level index the player may enter (0-based). Level 0 always open.
  int get highestUnlocked => _prefs.getInt(_kHighestUnlocked) ?? 0;

  /// Dev builds bypass progression entirely — every level is playable.
  bool isUnlocked(int index) => AppConfig.isDev || index <= highestUnlocked;

  Set<int> get completed =>
      (_prefs.getStringList(_kCompleted) ?? const [])
          .map(int.parse)
          .toSet();

  bool isCompleted(int index) => completed.contains(index);

  int get totalDeaths => _prefs.getInt(_kDeaths) ?? 0;

  bool get musicEnabled => _prefs.getBool(_kMusic) ?? true;
  bool get sfxEnabled => _prefs.getBool(_kSfx) ?? true;

  Future<void> setMusicEnabled(bool value) => _prefs.setBool(_kMusic, value);
  Future<void> setSfxEnabled(bool value) => _prefs.setBool(_kSfx, value);

  int get selectedCharacter => _prefs.getInt(_kCharacter) ?? 0;
  Future<void> setSelectedCharacter(int id) =>
      _prefs.setInt(_kCharacter, id);

  Future<void> addDeath() =>
      _prefs.setInt(_kDeaths, totalDeaths + 1);

  /// Marks [index] complete and unlocks the next level. Returns true if this
  /// unlocked something new.
  Future<bool> completeLevel(int index) async {
    final set = completed..add(index);
    await _prefs.setStringList(
        _kCompleted, set.map((e) => e.toString()).toList());
    final next = index + 1;
    var unlockedNew = false;
    if (next < kLevelCount && next > highestUnlocked) {
      await _prefs.setInt(_kHighestUnlocked, next);
      unlockedNew = true;
    }
    return unlockedNew;
  }

  Future<void> resetAll() async {
    await _prefs.remove(_kHighestUnlocked);
    await _prefs.remove(_kCompleted);
    await _prefs.remove(_kDeaths);
  }
}
