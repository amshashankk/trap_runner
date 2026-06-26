import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:trap_runner/data/level_data.dart';
import 'package:trap_runner/data/progress_store.dart';
import 'package:trap_runner/game/components/traps.dart';

void main() {
  group('Level catalogue', () {
    test('has at least the Phase 2 target of levels', () {
      expect(kLevelCount, greaterThanOrEqualTo(8));
    });

    test('every level references a distinct tmx file', () {
      final files = kLevels.map((l) => l.file).toSet();
      expect(files.length, kLevelCount);
    });

    test('indices are sequential and 0-based', () {
      for (var i = 0; i < kLevelCount; i++) {
        expect(kLevels[i].index, i);
        expect(kLevels[i].number, i + 1);
      }
    });
  });

  group('ProgressStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('only the first level is unlocked initially', () async {
      final store = await ProgressStore.load();
      expect(store.isUnlocked(0), isTrue);
      expect(store.isUnlocked(1), isFalse);
    });

    test('completing a level unlocks the next and records completion', () async {
      final store = await ProgressStore.load();
      final unlockedNew = await store.completeLevel(0);
      expect(unlockedNew, isTrue);
      expect(store.isUnlocked(1), isTrue);
      expect(store.isCompleted(0), isTrue);
    });

    test('deaths accumulate', () async {
      final store = await ProgressStore.load();
      await store.addDeath();
      await store.addDeath();
      expect(store.totalDeaths, 2);
    });
  });

  group('Gate timing', () {
    test('starts closed (solid), opens during its cycle, reset re-closes', () {
      final gate = Gate(Vector2.zero());
      expect(gate.isClosed, isTrue);
      expect(gate.solidBox, isNotNull);

      var sawOpen = false;
      for (var i = 0; i < 200; i++) {
        gate.update(1 / 60);
        if (!gate.isClosed) sawOpen = true;
      }
      expect(sawOpen, isTrue);

      gate.reset();
      expect(gate.isClosed, isTrue);
    });
  });

  group('Crusher motion', () {
    test('hangs at the top initially and descends during its cycle', () {
      final c = Crusher(Vector2(0, 100), 4, 0);
      final topY = c.position.y;
      expect(topY, 100);

      var maxY = topY;
      for (var i = 0; i < 120; i++) {
        c.update(1 / 60);
        if (c.position.y > maxY) maxY = c.position.y;
      }
      expect(maxY, greaterThan(topY)); // it slams downward
      c.reset();
      expect(c.position.y, topY);
    });
  });
}
