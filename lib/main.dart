import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'audio/sound.dart';
import 'core/app_config.dart';
import 'core/log.dart';
import 'data/progress_store.dart';
import 'ui/app.dart';

Future<void> main() async {
  // Run inside a guarded zone so any uncaught async error is logged, not lost.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    // Funnel framework + platform errors through the app logger.
    FlutterError.onError = (details) {
      Log.e('FlutterError', details.exceptionAsString(), details.exception,
          details.stack);
      FlutterError.presentError(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      Log.e('PlatformError', error.toString(), error, stack);
      return true;
    };

    Log.i('boot', 'Starting Trap Runner (${AppConfig.versionTag}, '
        'flavor=${AppConfig.flavor})');

    // The game is authored in landscape; lock to it on mobile.
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    final progress = await ProgressStore.load();
    await Sound.init(
      music: progress.musicEnabled,
      sfx: progress.sfxEnabled,
      character: progress.selectedCharacter,
    );
    Log.i('boot', 'Progress loaded (highestUnlocked=${progress.highestUnlocked}, '
        'music=${progress.musicEnabled}, sfx=${progress.sfxEnabled}, '
        'char=${progress.selectedCharacter})');

    // Optional deep-link: ?play=<level number> jumps straight into a level.
    final playParam = Uri.base.queryParameters['play'];
    final deepLinkLevel = int.tryParse(playParam ?? '');

    runApp(TrapRunnerApp(progress: progress, deepLinkLevel: deepLinkLevel));
  }, (error, stack) {
    Log.e('zone', 'Uncaught zone error', error, stack);
  });
}
