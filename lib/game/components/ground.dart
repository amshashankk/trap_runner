import 'dart:ui';

import 'package:flame/components.dart';

import '../config.dart';

/// One solid terrain cell, with [top] set when there is open space above it
/// (so it gets a grassy cap instead of plain dirt).
class GroundTile {
  const GroundTile(this.x, this.y, this.top);
  final double x;
  final double y;
  final bool top;
}

/// Draws the terrain directly with the canvas instead of going through
/// flame_tiled's tile renderer, which blanks/bleeds tiles on web CanvasKit.
/// The .tmx still defines the layout — this just paints it in our own style.
class GroundRenderer extends Component {
  GroundRenderer(this.tiles);

  final List<GroundTile> tiles;

  @override
  int get priority => -10;

  static final _dirt = Paint()..color = const Color(0xFF6C4E34);
  static final _dirtShade = Paint()..color = const Color(0xFF5A4029);
  static final _grass = Paint()..color = const Color(0xFF56AA48);
  static final _grassLip = Paint()..color = const Color(0xFF3C7832);
  static final _blade = Paint()..color = const Color(0xFF78C860);

  @override
  void render(Canvas canvas) {
    const ts = Config.tileSize;
    for (final t in tiles) {
      canvas.drawRect(Rect.fromLTWH(t.x, t.y, ts, ts), _dirt);
      // a little speckled depth at the bottom of each cell
      canvas.drawRect(Rect.fromLTWH(t.x, t.y + ts - 3, ts, 3), _dirtShade);
      if (t.top) {
        canvas.drawRect(Rect.fromLTWH(t.x, t.y, ts, 8), _grass);
        canvas.drawRect(Rect.fromLTWH(t.x, t.y + 8, ts, 2), _grassLip);
        // grass blades
        for (var bx = t.x + 3; bx < t.x + ts; bx += 7) {
          canvas.drawRect(Rect.fromLTWH(bx, t.y - 2, 2, 4), _blade);
        }
      }
    }
  }
}
