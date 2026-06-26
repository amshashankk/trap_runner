import 'dart:math';

import 'package:flame/components.dart';

import '../core/log.dart';

/// Phase 3 — the signature reactive-trap system.
///
/// It records how the player moves and where they die, then on each retry nudges
/// trap *timing* (never their positions) so the level feels like it is learning
/// the player. Two effects, both bounded so every level stays beatable:
///
///  * Anti-memorization: a small per-attempt phase jitter that grows with the
///    number of failures (capped), so a fixed memorized run stops working.
///  * Pattern-targeting: traps near where the player keeps dying get an extra
///    phase bias, tending to be "in the way" at that spot next time.
///
/// Only phase offsets change, so each trap's safe window still exists — the
/// player is outsmarted, never cheated.
class AdaptiveTrapManager {
  AdaptiveTrapManager(this.levelIndex);

  final int levelIndex;

  int attempts = 0;
  double? lastDeathX;
  double avgPlayerY = 0;

  final List<Vector2> _path = [];
  double _sampleAccum = 0;

  static const double _maxJitter = 0.4; // capped phase swing
  static const double _targetBias = 0.28; // extra shift near death spot
  static const double _targetRangePx = 80; // ~2.5 tiles

  /// Sample the player's position over time (called each frame while playing).
  void sample(Vector2 pos, double dt) {
    _sampleAccum += dt;
    if (_sampleAccum < 0.1) return;
    _sampleAccum = 0;
    _path.add(pos.clone());
    if (_path.length > 240) _path.removeAt(0);
  }

  void recordDeath(Vector2 pos) {
    lastDeathX = pos.x;
  }

  /// Called when a new attempt begins (respawn or retry). Folds the last run's
  /// path into the model and bumps the attempt counter.
  void beginAttempt() {
    if (_path.isNotEmpty) {
      avgPlayerY =
          _path.map((p) => p.y).reduce((a, b) => a + b) / _path.length;
      _path.clear();
    }
    attempts++;
    if (attempts > 1) {
      Log.d('adaptive',
          'L${levelIndex + 1} attempt $attempts (deathX=${lastDeathX?.toStringAsFixed(0)})');
    }
  }

  /// Phase offset in [0,1) for a trap at world-x [x]. [salt] keeps distinct
  /// traps from moving in lockstep.
  double phaseFor(double x, int salt) {
    // deterministic per (level, attempt, trap) so behaviour is reproducible.
    final rng = Random(levelIndex * 9301 + attempts * 233 + salt * 49297);
    final amplitude = min(_maxJitter, 0.06 * attempts);
    var offset = (rng.nextDouble() - 0.5) * 2 * amplitude;

    if (lastDeathX != null && (x - lastDeathX!).abs() < _targetRangePx) {
      offset += _targetBias; // bias traps toward the player's death spot
    }
    // normalise to [0,1)
    offset %= 1.0;
    if (offset < 0) offset += 1.0;
    return offset;
  }

  void reset() {
    attempts = 0;
    lastDeathX = null;
    avgPlayerY = 0;
    _path.clear();
    _sampleAccum = 0;
  }
}
