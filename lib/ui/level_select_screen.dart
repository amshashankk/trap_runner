import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../core/log.dart';
import '../data/level_data.dart';
import '../data/progress_store.dart';
import '../game/config.dart';
import 'game_screen.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key, required this.progress});

  final ProgressStore progress;

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  @override
  void initState() {
    super.initState();
    Log.i('nav', 'Level select');
  }

  Future<void> _open(LevelData level) async {
    if (!widget.progress.isUnlocked(level.index)) return;
    Sound.click();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(
        progress: widget.progress,
        startIndex: level.index,
      ),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SELECT LEVEL',
            style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1,
            ),
            itemCount: kLevelCount,
            itemBuilder: (context, i) {
              final level = kLevels[i];
              final unlocked = widget.progress.isUnlocked(i);
              final done = widget.progress.isCompleted(i);
              return _LevelTile(
                level: level,
                unlocked: unlocked,
                completed: done,
                onTap: () => _open(level),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.unlocked,
    required this.completed,
    required this.onTap,
  });

  final LevelData level;
  final bool unlocked;
  final bool completed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final base = unlocked
        ? (completed ? Config.exit : Config.accent)
        : const Color(0xFF2D375C);
    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        decoration: BoxDecoration(
          color: base.withValues(alpha: unlocked ? 1 : 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black26, width: 2),
        ),
        child: Stack(
          children: [
            Center(
              child: unlocked
                  ? Text(
                      '${level.number}',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B2440),
                      ),
                    )
                  : const Icon(Icons.lock, color: Colors.white38, size: 28),
            ),
            if (completed)
              const Positioned(
                top: 6,
                right: 6,
                child: Icon(Icons.star, color: Color(0xFF1B2440), size: 18),
              ),
            Positioned(
              left: 6,
              right: 6,
              bottom: 6,
              child: Text(
                unlocked ? level.title : 'LOCKED',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  color: unlocked ? const Color(0xFF1B2440) : Colors.white38,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
