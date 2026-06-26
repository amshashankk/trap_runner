import 'package:flame/game.dart';
import 'package:flutter/material.dart';

import '../core/log.dart';
import '../data/characters.dart';
import '../data/progress_store.dart';
import '../game/trap_runner_game.dart';
import 'overlays.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.progress,
    required this.startIndex,
    this.character,
  });

  final ProgressStore progress;
  final int startIndex;
  final GameCharacter? character;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final TrapRunnerGame _game;

  @override
  void initState() {
    super.initState();
    final character =
        widget.character ?? characterById(widget.progress.selectedCharacter);
    Log.i('nav',
        'Game screen (level ${widget.startIndex + 1}, char ${character.name})');
    _game = TrapRunnerGame(
      progress: widget.progress,
      startIndex: widget.startIndex,
      character: character,
      onExitToMenu: () {
        if (mounted) Navigator.of(context).pop();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GameWidget<TrapRunnerGame>(
        game: _game,
        overlayBuilderMap: {
          'hud': (_, game) => HudOverlay(game: game),
          'pause': (_, game) => PauseOverlay(game: game),
          'won': (_, game) => WinOverlay(game: game),
          'dead': (_, game) => DeadOverlay(game: game),
          'gameComplete': (_, game) => GameCompleteOverlay(game: game),
        },
      ),
    );
  }
}
