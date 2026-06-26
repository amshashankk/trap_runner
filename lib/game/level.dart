import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';
import 'package:flame/particles.dart';
import 'package:flame_tiled/flame_tiled.dart';

import 'adaptive_trap_manager.dart';
import 'components/ground.dart';
import 'components/player.dart';
import 'components/traps.dart';
import 'config.dart';
import '../data/level_data.dart';

/// One playable level. Loads a Tiled map, turns the Ground tile layer into
/// static collision boxes, and spawns trap/exit/player components from the
/// Objects layer. Exposes the per-frame collision queries the player needs.
/// Added into the camera's world; renders in world coordinates from (0,0).
class Level extends Component {
  Level(this.data);

  final LevelData data;

  final List<SolidBox> _staticSolids = [];
  final List<GroundTile> _groundCells = [];
  final List<MovingPlatform> movers = [];
  final List<Gate> gates = [];
  final List<Crusher> crushers = [];
  final List<Spikes> spikes = [];
  final List<RandomWall> walls = [];

  late Vector2 spawn;
  ExitDoor? _exit;
  Player? player;

  Rect? get exitRect => _exit?.rect;

  @override
  Future<void> onLoad() async {
    // The .tmx is used purely as level data (collision grid + object layer);
    // terrain is painted by GroundRenderer and traps draw themselves, so we
    // never add the flame_tiled tile renderer to the tree.
    final tiled = await TiledComponent.load(
      data.file,
      Vector2.all(Config.tileSize),
    );

    _parseGround(tiled);
    _parseObjects(tiled);
    add(GroundRenderer(_groundCells));

    // Player is added last so it updates after the traps each frame and reads
    // their freshly-advanced positions.
    player = Player(spawn);
    await add(player!);
  }

  void _parseGround(TiledComponent tiled) {
    final layer = tiled.tileMap.getLayer<TileLayer>('Ground');
    final tileData = layer?.data;
    if (layer == null || tileData == null) return;
    final w = layer.width;
    final h = layer.height;
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final gid = tileData[y * w + x];
        if (gid == 0) continue;
        final px = x * Config.tileSize;
        final py = y * Config.tileSize;
        _staticSolids.add(SolidBox(
            Rect.fromLTWH(px, py, Config.tileSize, Config.tileSize)));
        final above = y > 0 ? tileData[(y - 1) * w + x] : 0;
        _groundCells.add(GroundTile(px, py, above == 0));
      }
    }
  }

  void _parseObjects(TiledComponent tiled) {
    final group = tiled.tileMap.getLayer<ObjectGroup>('Objects');
    if (group == null) return;
    var crusherIndex = 0;
    for (final obj in group.objects) {
      final pos = Vector2(obj.x, obj.y);
      switch (obj.name) {
        case 'spawn':
          spawn = pos;
          break;
        case 'exit':
          _exit = ExitDoor(pos);
          add(_exit!);
          break;
        case 'spikes':
          final patrol = obj.properties.getValue<int>('patrol') ?? 0;
          final phase = obj.properties.getValue<double>('phase') ?? 0.0;
          final s = Spikes(pos, patrolTiles: patrol, phase: phase);
          spikes.add(s);
          add(s);
          break;
        case 'crusher':
          final range = obj.properties.getValue<int>('range') ?? 4;
          // Desync neighbours so a row of crushers slams in a wave.
          final phase = (crusherIndex % 4) / 4.0;
          crusherIndex++;
          final c = Crusher(pos, range, phase);
          crushers.add(c);
          add(c);
          break;
        case 'mover':
          final axis = obj.properties.getValue<String>('axis') ?? 'h';
          final range = obj.properties.getValue<int>('range') ?? 4;
          final m = MovingPlatform(pos, axis, range);
          movers.add(m);
          add(m);
          break;
        case 'gate':
          final g = Gate(pos);
          gates.add(g);
          add(g);
          break;
        case 'wall':
          final h = (obj.height / Config.tileSize).round().clamp(2, 8);
          final seed = obj.properties.getValue<int>('seed') ?? obj.x.toInt();
          final w = RandomWall(pos, h, seed);
          walls.add(w);
          add(w);
          break;
      }
    }
  }

  /// All solid boxes for this frame: static terrain + moving platforms +
  /// currently-closed gates.
  List<SolidBox> solids() {
    final list = List<SolidBox>.of(_staticSolids);
    for (final m in movers) {
      final b = m.solidBox;
      if (b != null) list.add(b);
    }
    for (final g in gates) {
      final b = g.solidBox;
      if (b != null) list.add(b);
    }
    for (final w in walls) {
      final b = w.solidBox;
      if (b != null) list.add(b);
    }
    return list;
  }

  /// All currently-deadly areas for this frame.
  List<Rect> hazards() {
    final list = <Rect>[];
    for (final s in spikes) {
      final r = s.hazardRect;
      if (r != null) list.add(r);
    }
    for (final c in crushers) {
      final r = c.hazardRect;
      if (r != null) list.add(r);
    }
    return list;
  }

  /// Push the adaptive manager's per-trap phase offsets onto every timed trap.
  /// Salt ranges keep spikes/crushers/gates from moving in lockstep.
  void applyAdaptive(AdaptiveTrapManager m) {
    for (var i = 0; i < spikes.length; i++) {
      spikes[i].adaptOffset = m.phaseFor(spikes[i].position.x, 1 + i);
    }
    for (var i = 0; i < crushers.length; i++) {
      crushers[i].adaptOffset = m.phaseFor(crushers[i].position.x, 100 + i);
    }
    for (var i = 0; i < gates.length; i++) {
      gates[i].adaptOffset = m.phaseFor(gates[i].position.x, 200 + i);
    }
  }

  /// Respawn the player and rewind every trap to its starting state, so each
  /// retry within a life plays out deterministically.
  void restart() {
    for (final m in movers) {
      m.reset();
    }
    for (final g in gates) {
      g.reset();
    }
    for (final c in crushers) {
      c.reset();
    }
    for (final w in walls) {
      w.reset();
    }
    player?.resetTo(spawn);
  }

  /// Burst of coloured shards where the player just died.
  void spawnDeathBurst(Vector2 center, Color color) {
    final rng = math.Random(center.x.toInt() ^ center.y.toInt());
    add(ParticleSystemComponent(
      position: center,
      particle: Particle.generate(
        count: 16,
        lifespan: 0.6,
        generator: (i) {
          final ang = (i / 16) * math.pi * 2 + rng.nextDouble();
          final spd = 70 + rng.nextDouble() * 150;
          return AcceleratedParticle(
            acceleration: Vector2(0, 380),
            speed: Vector2(math.cos(ang), math.sin(ang) - 0.5) * spd,
            child: CircleParticle(
              radius: 2.0 + rng.nextDouble() * 2.5,
              paint: Paint()..color = color,
            ),
          );
        },
      ),
    ));
  }
}
