import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../core/log.dart';
import '../data/progress_store.dart';
import '../game/config.dart';
import 'app.dart';
import 'character_select_screen.dart';
import 'level_select_screen.dart';
import 'widgets/sound_toggles.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key, required this.progress});

  final ProgressStore progress;

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  @override
  void initState() {
    super.initState();
    Log.i('nav', 'Main menu');
    if (widget.progress.musicEnabled) Sound.startMusic();
  }

  Future<void> _play() async {
    Sound.click();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CharacterSelectScreen(progress: widget.progress),
    ));
    setState(() {}); // refresh after returning
  }

  Future<void> _levels() async {
    Sound.click();
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => LevelSelectScreen(progress: widget.progress),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Config.sky, Color(0xFF14193A)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: SoundToggles(
                  progress: widget.progress,
                  onChanged: () => setState(() {}),
                ),
              ),
              Center(
                child: _IntroAnim(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _Logo(),
                      const SizedBox(height: 8),
                      const Text(
                        'The level fights back.',
                        style: TextStyle(color: Colors.white60, fontSize: 14),
                      ),
                      const SizedBox(height: 36),
                      MenuButton(
                          label: 'PLAY', icon: Icons.play_arrow, onTap: _play),
                      const SizedBox(height: 14),
                      MenuButton(
                        label: 'LEVELS',
                        icon: Icons.grid_view,
                        color: const Color(0xFF6BCB77),
                        onTap: _levels,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Deaths so far: ${widget.progress.totalDeaths}',
                        style:
                            const TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Game-open animation: the title block drops in and settles with a bounce.
class _IntroAnim extends StatelessWidget {
  const _IntroAnim({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.elasticOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0, 1),
        child: Transform.scale(scale: 0.6 + 0.4 * t.clamp(0, 1), child: child),
      ),
      child: child,
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'TRAP',
          style: TextStyle(
            color: Config.spike,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            height: 0.9,
            shadows: const [Shadow(color: Colors.black54, offset: Offset(3, 3))],
          ),
        ),
        Text(
          'RUNNER',
          style: TextStyle(
            color: Config.accent,
            fontSize: 64,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            height: 0.9,
            shadows: const [Shadow(color: Colors.black54, offset: Offset(3, 3))],
          ),
        ),
      ],
    );
  }
}
