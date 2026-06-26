import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';
import '../level.dart';
import '../trap_runner_game.dart';
import 'traps.dart';

/// The player avatar. Uses manual axis-separated AABB resolution against the
/// level's solids for tight, predictable platforming (Flame's collision system
/// detects but doesn't resolve, which is too loose for a precision game).
class Player extends PositionComponent with HasGameReference<TrapRunnerGame> {
  Player(Vector2 spawn)
      : _spawn = spawn.clone(),
        super(
          position: spawn.clone(),
          size: Vector2(Config.playerWidth, Config.playerHeight),
          anchor: Anchor.topLeft,
          priority: 10,
        );

  final Vector2 _spawn;
  final Vector2 velocity = Vector2.zero();

  bool onGround = false;
  bool _dead = false;
  bool get isDead => _dead;

  double _coyote = 0;
  double _jumpBuffer = 0;
  bool _prevJump = false;
  bool _wasOnGround = false;
  MovingPlatform? _riding;

  // facing + squash/stretch for a little juice
  int _facing = 1;
  double _squash = 1;

  void resetTo(Vector2? spawn) {
    position.setFrom(spawn ?? _spawn);
    velocity.setZero();
    onGround = false;
    _dead = false;
    _coyote = 0;
    _jumpBuffer = 0;
    _riding = null;
    _squash = 1;
  }

  Rect get _rect => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void update(double dt) {
    if (_dead || !game.running) return;
    final level = game.level;
    if (level == null) return;

    final input = game.input;
    final solids = level.solids();

    // Ride the platform we were standing on (carry by its frame delta).
    if (_riding != null) {
      position.add(_riding!.delta);
    }

    // --- horizontal ---
    final target = (input.left ? -1 : 0) + (input.right ? 1 : 0);
    if (target != 0) _facing = target;
    velocity.x = target * Config.moveSpeed; // direct, snappy control

    position.x += velocity.x * dt;
    _resolveAxis(solids, horizontal: true);

    // --- vertical ---
    velocity.y += Config.gravity * dt;
    if (velocity.y > Config.maxFallSpeed) velocity.y = Config.maxFallSpeed;

    // jump timers
    if (onGround) {
      _coyote = Config.coyoteTime;
    } else if (_coyote > 0) {
      _coyote -= dt;
    }
    final jumpPressed = input.jump && !_prevJump;
    if (jumpPressed) _jumpBuffer = Config.jumpBuffer;
    if (_jumpBuffer > 0) _jumpBuffer -= dt;

    if (_jumpBuffer > 0 && _coyote > 0) {
      velocity.y = -Config.jumpSpeed;
      _jumpBuffer = 0;
      _coyote = 0;
      _riding = null;
      _squash = 0.7; // stretch up
      game.onPlayerJump();
    }
    // variable jump height: release cuts the rise
    if (!input.jump && velocity.y < 0) {
      velocity.y *= Config.jumpCutMultiplier;
    }
    _prevJump = input.jump;

    position.y += velocity.y * dt;
    _wasOnGround = onGround;
    onGround = false;
    _riding = null;
    _resolveAxis(solids, horizontal: false);

    if (onGround && !_wasOnGround && velocity.y >= 0) {
      _squash = 1.3; // squash on land
      game.onPlayerLand();
    }
    _squash += (1 - _squash) * (dt * 12); // ease back to neutral

    // keep inside the world horizontally; falling out the bottom = death
    if (position.x < 0) position.x = 0;
    if (position.x + size.x > Config.worldWidth) {
      position.x = Config.worldWidth - size.x;
    }
    if (position.y > Config.worldHeight + 40) {
      _die(fell: true);
      return;
    }

    _checkHazards(level);
    _checkExit(level);
  }

  void _resolveAxis(List<SolidBox> solids, {required bool horizontal}) {
    for (final box in solids) {
      final s = box.rect;
      if (!_rect.overlaps(s)) continue;
      if (horizontal) {
        if (velocity.x > 0) {
          position.x = s.left - size.x;
        } else if (velocity.x < 0) {
          position.x = s.right;
        }
        velocity.x = 0;
      } else {
        if (velocity.y > 0) {
          position.y = s.top - size.y;
          onGround = true;
          _riding = box.owner;
        } else if (velocity.y < 0) {
          position.y = s.bottom;
        }
        velocity.y = 0;
      }
    }
  }

  void _checkHazards(Level level) {
    for (final h in level.hazards()) {
      if (_rect.overlaps(h)) {
        _die(fell: false);
        return;
      }
    }
  }

  void _checkExit(Level level) {
    final exit = level.exitRect;
    if (exit != null && _rect.overlaps(exit)) {
      game.onReachExit();
    }
  }

  void _die({required bool fell}) {
    if (_dead) return;
    _dead = true;
    game.onPlayerDeath(fell: fell);
  }

  @override
  void render(Canvas canvas) {
    final sx = 1 / _squash;
    final sy = _squash;
    canvas.save();
    // squash/stretch around the bottom-center
    canvas.translate(size.x / 2, size.y);
    canvas.scale(sx, sy);
    canvas.translate(-size.x / 2, -size.y);

    final ch = game.character;
    final body = RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.x, size.y), const Radius.circular(7));
    canvas.drawRRect(
        body.shift(const Offset(0, 2)), Paint()..color = ch.dark);
    canvas.drawRRect(body, Paint()..color = ch.color);

    // eyes, facing the move direction
    final eyePaint = Paint()..color = const Color(0xFF2B2B2B);
    final ex = _facing >= 0 ? size.x * 0.56 : size.x * 0.24;
    canvas.drawCircle(Offset(ex, size.y * 0.38), 2.6, eyePaint);
    canvas.drawCircle(Offset(ex + _facing * 6, size.y * 0.38), 2.6, eyePaint);
    canvas.restore();
  }
}
