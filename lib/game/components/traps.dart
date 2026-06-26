import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';

import '../config.dart';

/// Base for every hazard/obstacle. Subclasses animate themselves in [update];
/// the player polls [hazardRect] (deadly area) and [solidBox] (standable area)
/// each frame, so collision stays fully deterministic and easy to test.
abstract class TrapComponent extends PositionComponent {
  TrapComponent({required Vector2 position, required Vector2 size})
      : super(position: position, size: size);

  /// Current deadly area in world space, or null if not deadly right now.
  Rect? get hazardRect => null;

  /// Current solid (standable/blocking) area in world space, or null.
  SolidBox? get solidBox => null;

  /// Reset internal animation state to the start (used on respawn).
  void reset() {}
}

/// A solid rectangle the player can stand on or be blocked by. [owner] is set
/// when the box belongs to a moving platform so the player can ride it.
class SolidBox {
  SolidBox(this.rect, [this.owner]);
  final Rect rect;
  final MovingPlatform? owner;
}

/// A small spike hazard. Deadly on contact. When [patrolTiles] > 0 it slides
/// horizontally back and forth over that many tiles, opening a safe gap so the
/// player can time a run across instead of needing one big jump. The hazard
/// area is inset for fairness so a near-miss doesn't read as a hit.
class Spikes extends TrapComponent {
  Spikes(Vector2 position, {this.patrolTiles = 0, this.phase = 0})
      : _origin = position.clone(),
        super(position: position, size: Vector2.all(Config.tileSize));

  final int patrolTiles;
  final double phase; // 0..1 offset so neighbouring spikes stagger
  final Vector2 _origin;
  double _t = 0;

  /// Runtime phase shift applied by the AdaptiveTrapManager.
  double adaptOffset = 0;

  static const _period = 2.2; // seconds for a full back-and-forth

  bool get _moving => patrolTiles > 0;

  @override
  void update(double dt) {
    if (!_moving) return;
    _t += dt;
    final travel = patrolTiles * Config.tileSize;
    // ease in/out at the ends so it pauses briefly, giving a clear window
    final s =
        0.5 - 0.5 * math.cos((_t / _period + phase + adaptOffset) * math.pi * 2);
    position.x = _origin.x + s * travel;
  }

  @override
  void reset() {
    _t = 0;
    position.x = _origin.x;
  }

  @override
  Rect? get hazardRect =>
      Rect.fromLTWH(position.x + 5, position.y + 16, size.x - 10, size.y - 16);

  @override
  void render(Canvas canvas) {
    final paint = Paint()..color = Config.spike;
    final base = size.y;
    const teeth = 3;
    final w = size.x / teeth;
    for (var i = 0; i < teeth; i++) {
      final path = Path()
        ..moveTo(i * w, base)
        ..lineTo(i * w + w / 2, base * 0.42)
        ..lineTo(i * w + w, base)
        ..close();
      canvas.drawPath(path, paint);
    }
    // base strip
    canvas.drawRect(Rect.fromLTWH(0, base - 4, size.x, 4),
        Paint()..color = const Color(0xFF8A2C2C));
  }
}

/// A spiked block that hangs at the top, then slams down [rangeTiles] tiles on a
/// repeating cycle. Deadly across its whole body.
class Crusher extends TrapComponent {
  Crusher(Vector2 position, this.rangeTiles, this.phase)
      : _topY = position.y,
        super(position: position, size: Vector2.all(Config.tileSize));

  final int rangeTiles;
  final double phase; // 0..1 offset so a row of crushers can desync
  final double _topY;
  double _t = 0;

  /// Runtime phase shift applied by the AdaptiveTrapManager.
  double adaptOffset = 0;

  static const _cycle = 2.0; // seconds per slam cycle

  @override
  void update(double dt) {
    _t += dt;
    final p = ((_t / _cycle) + phase + adaptOffset) % 1.0;
    final travel = rangeTiles * Config.tileSize;
    double f; // 0 at top, 1 fully extended
    if (p < 0.45) {
      f = 0; // hang
    } else if (p < 0.55) {
      f = (p - 0.45) / 0.10; // fast slam
    } else if (p < 0.72) {
      f = 1; // hold down
    } else {
      f = 1 - (p - 0.72) / 0.28; // slow retract
    }
    position.y = _topY + travel * Curves01.clamp(f);
  }

  @override
  void reset() {
    _t = 0;
    position.y = _topY;
  }

  @override
  Rect? get hazardRect => Rect.fromLTWH(
      position.x + 2, position.y, size.x - 4, size.y);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y - 6), const Radius.circular(4)),
        Paint()..color = Config.crusher);
    // teeth on the underside
    final teethPaint = Paint()..color = Config.crusherTeeth;
    const teeth = 4;
    final w = size.x / teeth;
    for (var i = 0; i < teeth; i++) {
      final path = Path()
        ..moveTo(i * w, size.y - 8)
        ..lineTo(i * w + w / 2, size.y)
        ..lineTo(i * w + w, size.y - 8)
        ..close();
      canvas.drawPath(path, teethPaint);
    }
  }
}

/// Simple easing helper so we don't pull in a heavyweight curves dependency.
class Curves01 {
  static double clamp(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);
}

/// A platform that slides back and forth along one axis. Solid and ridable;
/// never deadly. Exposes [delta] (this frame's movement) so the player can be
/// carried while standing on it.
class MovingPlatform extends TrapComponent {
  MovingPlatform(Vector2 anchor, this.axis, this.rangeTiles)
      : _origin = anchor.clone(),
        super(
          position: Vector2(anchor.x - Config.tileSize, anchor.y + 8),
          size: Vector2(Config.tileSize * 3, 16),
        );

  final String axis; // 'h' or 'v'
  final int rangeTiles;
  final Vector2 _origin;
  double _t = 0;
  Vector2 delta = Vector2.zero();

  static const _period = 2.6;

  @override
  void update(double dt) {
    _t += dt;
    final travel = rangeTiles * Config.tileSize;
    final s = math.sin(_t / _period * math.pi * 2);
    final before = position.clone();
    if (axis == 'v') {
      position
        ..x = _origin.x - Config.tileSize
        ..y = _origin.y + 8 + s * travel * 0.5;
    } else {
      position
        ..x = _origin.x - Config.tileSize + s * travel * 0.5
        ..y = _origin.y + 8;
    }
    delta = position - before;
  }

  @override
  void reset() {
    _t = 0;
    delta = Vector2.zero();
  }

  @override
  SolidBox? get solidBox =>
      SolidBox(Rect.fromLTWH(position.x, position.y, size.x, size.y), this);

  @override
  void render(Canvas canvas) {
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(5)),
        Paint()..color = Config.mover);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.x, 4),
        Paint()..color = const Color(0xFF9BE7A5));
  }
}

/// A gate segment that toggles between solid (closed) and passable (open) on a
/// timer. Blocking, not deadly — you wait for the opening and slip through.
class Gate extends TrapComponent {
  Gate(Vector2 position)
      : super(position: position, size: Vector2.all(Config.tileSize));

  double _t = 0;
  static const _cycle = 2.6;
  double _open = 0; // 0 closed, 1 open

  /// Runtime phase shift applied by the AdaptiveTrapManager.
  double adaptOffset = 0;

  bool get isClosed => _open < 0.5;

  @override
  void update(double dt) {
    _t += dt;
    final p = (_t / _cycle + adaptOffset) % 1.0;
    // closed 0..0.45, opening 0.45..0.55, open 0.55..0.9, closing 0.9..1
    if (p < 0.45) {
      _open = 0;
    } else if (p < 0.55) {
      _open = (p - 0.45) / 0.10;
    } else if (p < 0.90) {
      _open = 1;
    } else {
      _open = 1 - (p - 0.90) / 0.10;
    }
  }

  @override
  void reset() {
    _t = 0;
    _open = 0;
  }

  @override
  SolidBox? get solidBox => isClosed
      ? SolidBox(Rect.fromLTWH(position.x, position.y, size.x, size.y))
      : null;

  @override
  void render(Canvas canvas) {
    // bar retracts upward as it opens
    final h = size.y * (1 - Curves01.clamp(_open));
    final r = Rect.fromLTWH(size.x * 0.18, 0, size.x * 0.64, h);
    canvas.drawRRect(
        RRect.fromRectAndRadius(r, const Radius.circular(3)),
        Paint()..color = Config.gate.withValues(alpha: isClosed ? 1 : 0.6));
    // glowing edge
    if (h > 2) {
      canvas.drawRect(Rect.fromLTWH(size.x * 0.18, h - 3, size.x * 0.64, 3),
          Paint()..color = const Color(0xFFD9B8FF));
    }
  }
}

/// The level exit. Reaching it clears the level.
class ExitDoor extends TrapComponent {
  ExitDoor(Vector2 position)
      : super(
          position: position,
          size: Vector2(Config.tileSize, Config.tileSize),
        );

  double _t = 0;

  Rect get rect =>
      Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void update(double dt) => _t += dt;

  @override
  void render(Canvas canvas) {
    // frame
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(2, -2, size.x - 4, size.y + 2),
            const Radius.circular(6)),
        Paint()..color = const Color(0xFF2C6E54));
    // glowing portal
    final glow = 0.5 + 0.5 * math.sin(_t * 4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(6, 2, size.x - 12, size.y - 4),
            const Radius.circular(5)),
        Paint()..color = Color.lerp(Config.exit, const Color(0xFFB6FFE3), glow)!);
  }
}

/// A cracked stone wall that runs a short randomized sequence of events — it
/// shifts sideways ("move") or splits open ("break") at intervals, then settles
/// permanently OPEN (shattered). Blocking, never deadly. Because it always ends
/// open, the level stays solvable; the unpredictable active phase is what makes
/// it harder. e.g. a seed might produce: move, break, break, … then stay.
class RandomWall extends TrapComponent {
  RandomWall(Vector2 position, this.heightTiles, this.seed)
      : _originX = position.x,
        super(
          position: position,
          size: Vector2(Config.tileSize, heightTiles * Config.tileSize),
        );

  final int heightTiles;
  final int seed;
  final double _originX;

  static const double _interval = 1.6; // seconds between events

  late final List<bool> _events; // true = break, false = move
  int _ei = 0;
  double _t = 0;
  double _shake = 0;
  double _shiftTiles = 0;
  bool _broken = false; // open this interval
  bool _settled = false; // permanently open
  bool _shattered = false;

  @override
  Future<void> onLoad() async {
    _buildSequence();
  }

  void _buildSequence() {
    final rng = math.Random(seed);
    final n = 3 + rng.nextInt(3); // 3..5 events
    _events = List.generate(n, (_) => rng.nextBool());
    // guarantee at least one "break" so it visibly opens during the run
    if (!_events.contains(true)) _events[rng.nextInt(n)] = true;
  }

  @override
  void update(double dt) {
    if (_settled) return;
    if (_shake > 0) _shake = math.max(0, _shake - dt * 4);
    _t += dt;
    if (_t >= _interval) {
      _t = 0;
      _advance();
    }
  }

  void _advance() {
    if (_ei >= _events.length) {
      _settle();
      return;
    }
    final isBreak = _events[_ei++];
    _shake = 1.0;
    if (isBreak) {
      _broken = true; // open for this interval
    } else {
      _broken = false; // re-form solid and shift sideways
      final rng = math.Random(seed * 31 + _ei);
      final dir = rng.nextBool() ? 1 : -1;
      _shiftTiles = (_shiftTiles + dir).clamp(-2, 2).toDouble();
      position.x = _originX + _shiftTiles * Config.tileSize;
    }
  }

  void _settle() {
    _settled = true;
    _broken = true;
    if (!_shattered) {
      _shattered = true;
      _spawnDebris();
    }
  }

  void _spawnDebris() {
    final rng = math.Random(seed * 7 + 1);
    parent?.add(ParticleSystemComponent(
      position: position + Vector2(size.x / 2, size.y / 2),
      particle: Particle.generate(
        count: 16,
        lifespan: 0.7,
        generator: (i) {
          final ang = rng.nextDouble() * math.pi * 2;
          final spd = 60 + rng.nextDouble() * 130;
          return AcceleratedParticle(
            acceleration: Vector2(0, 420),
            speed: Vector2(math.cos(ang), math.sin(ang) - 0.5) * spd,
            child: CircleParticle(
              radius: 1.6 + rng.nextDouble() * 1.6,
              paint: Paint()..color = const Color(0xFF9AA0AE),
            ),
          );
        },
      ),
    ));
  }

  @override
  void reset() {
    _ei = 0;
    _t = 0;
    _shake = 0;
    _shiftTiles = 0;
    _broken = false;
    _settled = false;
    _shattered = false;
    position.x = _originX;
  }

  @override
  SolidBox? get solidBox => (_broken || _settled)
      ? null
      : SolidBox(Rect.fromLTWH(position.x, position.y, size.x, size.y));

  @override
  void render(Canvas canvas) {
    if (_settled) return; // shattered away
    final dx = _shake > 0 ? (math.Random((_t * 1000).toInt()).nextDouble() - 0.5) * 4 * _shake : 0.0;
    canvas.save();
    canvas.translate(dx, 0);
    final base = _broken ? const Color(0x668A8FA3) : const Color(0xFF8A8FA3);
    final edge = _broken ? const Color(0x445A5F6E) : const Color(0xFF5A5F6E);
    if (_broken) {
      // split open: two halves pulled apart
      final hw = size.x * 0.4;
      canvas.drawRect(Rect.fromLTWH(0, 0, hw, size.y), Paint()..color = base);
      canvas.drawRect(
          Rect.fromLTWH(size.x - hw, 0, hw, size.y), Paint()..color = base);
    } else {
      canvas.drawRect(Rect.fromLTWH(0, 0, size.x, size.y), Paint()..color = base);
      // brick cracks
      final crack = Paint()
        ..color = edge
        ..strokeWidth = 1.5;
      for (var y = 8.0; y < size.y; y += 12) {
        canvas.drawLine(Offset(2, y), Offset(size.x - 2, y), crack);
      }
      canvas.drawLine(Offset(size.x / 2, 0), Offset(size.x / 2, size.y), crack);
    }
    canvas.restore();
  }
}
