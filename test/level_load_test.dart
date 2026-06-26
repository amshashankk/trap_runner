import 'package:flame/components.dart';
import 'package:flame_tiled/flame_tiled.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:trap_runner/data/level_data.dart';

/// Loads every authored level through the real asset bundle to prove the Tiled
/// pipeline works end-to-end: the .tmx parses, the tileset image resolves, the
/// Ground tile layer has solids, and each level has exactly one spawn + exit.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final level in kLevels) {
    testWidgets('loads ${level.file}', (tester) async {
      await tester.runAsync(() async {
        final tiled = await TiledComponent.load(
          level.file,
          Vector2.all(32),
        );

        final ground = tiled.tileMap.getLayer<TileLayer>('Ground');
        expect(ground, isNotNull, reason: 'Ground layer missing');
        final solids = ground!.data!.where((g) => g != 0).length;
        expect(solids, greaterThan(0), reason: 'no solid tiles');

        final objects = tiled.tileMap.getLayer<ObjectGroup>('Objects');
        expect(objects, isNotNull, reason: 'Objects layer missing');
        final names = objects!.objects.map((o) => o.name).toList();
        expect(names.where((n) => n == 'spawn').length, 1,
            reason: 'need exactly one spawn');
        expect(names.where((n) => n == 'exit').length, 1,
            reason: 'need exactly one exit');
      });
    });
  }
}
