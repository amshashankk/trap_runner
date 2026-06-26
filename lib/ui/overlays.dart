import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../audio/sound.dart';
import '../core/app_config.dart';
import '../game/config.dart';
import '../game/trap_runner_game.dart';
import 'app.dart';

/// In-game heads-up display: status bar on top, touch controls on the bottom.
class HudOverlay extends StatelessWidget {
  const HudOverlay({super.key, required this.game});

  final TrapRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Stack(
        children: [
          // top status bar
          Positioned(
            top: 6,
            left: 12,
            right: 12,
            child: ValueListenableBuilder<int>(
              valueListenable: game.hud,
              builder: (context, _, child) {
                return Row(
                  children: [
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${game.levelData.number}. ${game.levelData.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: List.generate(
                        Config.livesPerLevel,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(
                            i < game.lives ? Icons.favorite : Icons.favorite_border,
                            color: Config.spike,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    _IconChip(
                      icon: Sound.musicEnabled
                          ? Icons.music_note
                          : Icons.music_off,
                      onTap: game.toggleMusic,
                    ),
                    const SizedBox(width: 8),
                    _IconChip(
                      icon: Sound.sfxEnabled
                          ? Icons.volume_up
                          : Icons.volume_off,
                      onTap: game.toggleSfx,
                    ),
                    const SizedBox(width: 8),
                    if (AppConfig.isDev) ...[
                      _IconChip(
                        icon: Icons.skip_next,
                        onTap: game.devSkipLevel,
                      ),
                      const SizedBox(width: 8),
                    ],
                    _IconChip(
                      icon: Icons.pause,
                      onTap: game.pause,
                    ),
                  ],
                );
              },
            ),
          ),
          // bottom controls — kept well inside the safe area so they don't
          // hug the device bezel / rounded corners in landscape.
          Positioned(
            left: 36,
            bottom: 30,
            child: Row(
              children: [
                _TouchButton(
                  icon: Icons.arrow_left,
                  onDown: () => game.input.left = true,
                  onUp: () => game.input.left = false,
                ),
                const SizedBox(width: 18),
                _TouchButton(
                  icon: Icons.arrow_right,
                  onDown: () => game.input.right = true,
                  onUp: () => game.input.right = false,
                ),
              ],
            ),
          ),
          Positioned(
            right: 36,
            bottom: 30,
            child: _TouchButton(
              icon: Icons.keyboard_arrow_up,
              big: true,
              color: Config.accent,
              onDown: () => game.input.jump = true,
              onUp: () => game.input.jump = false,
            ),
          ),
        ],
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black38,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

/// A press-and-hold control that feeds the game's input state.
class _TouchButton extends StatefulWidget {
  const _TouchButton({
    required this.icon,
    required this.onDown,
    required this.onUp,
    this.big = false,
    this.color,
  });

  final IconData icon;
  final VoidCallback onDown;
  final VoidCallback onUp;
  final bool big;
  final Color? color;

  @override
  State<_TouchButton> createState() => _TouchButtonState();
}

class _TouchButtonState extends State<_TouchButton> {
  bool _pressed = false;

  void _set(bool down) {
    if (down == _pressed) return;
    setState(() => _pressed = down);
    down ? widget.onDown() : widget.onUp();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.big ? 84.0 : 64.0;
    final base = widget.color ?? Colors.white;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => _set(true),
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: base.withValues(alpha: _pressed ? 0.55 : 0.28),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
        ),
        child: Icon(widget.icon,
            color: Colors.white, size: widget.big ? 48 : 40),
      ),
    );
  }
}

/// A centered modal card used by the win/lose/pause overlays.
class _Dialog extends StatelessWidget {
  const _Dialog({
    required this.title,
    required this.color,
    required this.children,
    this.shake = false,
  });

  final String title;
  final Color color;
  final List<Widget> children;
  final bool shake;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      margin: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF20294A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color, width: 3),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 22),
          ...children,
        ],
      ),
    );

    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: shake ? 520 : 420),
        curve: shake ? Curves.elasticOut : Curves.easeOutBack,
        builder: (context, t, child) {
          if (shake) {
            // failure: shake horizontally, decaying
            final dx = (1 - t) * 16 * math.sin(t * math.pi * 6);
            return Opacity(
              opacity: t.clamp(0, 1),
              child: Transform.translate(offset: Offset(dx, 0), child: child),
            );
          }
          // win / pause / complete: bounce + fade in
          return Opacity(
            opacity: t.clamp(0, 1),
            child: Transform.scale(scale: 0.7 + 0.3 * t.clamp(0, 1), child: child),
          );
        },
        child: card,
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.game});
  final TrapRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return _Dialog(
      title: 'PAUSED',
      color: Config.accent,
      children: [
        MenuButton(label: 'RESUME', icon: Icons.play_arrow, onTap: game.resume),
        const SizedBox(height: 12),
        MenuButton(
          label: 'RETRY',
          icon: Icons.refresh,
          color: const Color(0xFF6BCB77),
          onTap: game.retryLevel,
        ),
        const SizedBox(height: 12),
        MenuButton(
          label: 'MENU',
          icon: Icons.home,
          color: Colors.white70,
          onTap: game.quitToMenu,
        ),
      ],
    );
  }
}

class WinOverlay extends StatelessWidget {
  const WinOverlay({super.key, required this.game});
  final TrapRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return _Dialog(
      title: 'LEVEL CLEAR!',
      color: Config.exit,
      children: [
        MenuButton(
          label: 'NEXT LEVEL',
          icon: Icons.arrow_forward,
          color: Config.exit,
          onTap: game.nextLevel,
        ),
        const SizedBox(height: 12),
        MenuButton(
          label: 'REPLAY',
          icon: Icons.refresh,
          color: Config.accent,
          onTap: game.retryLevel,
        ),
        const SizedBox(height: 12),
        MenuButton(
          label: 'MENU',
          icon: Icons.home,
          color: Colors.white70,
          onTap: game.quitToMenu,
        ),
      ],
    );
  }
}

class DeadOverlay extends StatelessWidget {
  const DeadOverlay({super.key, required this.game});
  final TrapRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return _Dialog(
      title: 'OUT OF LIVES',
      color: Config.spike,
      shake: true,
      children: [
        const Text(
          'The traps win this round.',
          style: TextStyle(color: Colors.white60),
        ),
        const SizedBox(height: 18),
        MenuButton(
          label: 'TRY AGAIN',
          icon: Icons.refresh,
          color: Config.accent,
          onTap: game.retryLevel,
        ),
        const SizedBox(height: 12),
        MenuButton(
          label: 'MENU',
          icon: Icons.home,
          color: Colors.white70,
          onTap: game.quitToMenu,
        ),
      ],
    );
  }
}

class GameCompleteOverlay extends StatelessWidget {
  const GameCompleteOverlay({super.key, required this.game});
  final TrapRunnerGame game;

  @override
  Widget build(BuildContext context) {
    return _Dialog(
      title: 'YOU BEAT\nTRAP RUNNER!',
      color: Config.exit,
      children: [
        Text(
          'Total deaths: ${game.deaths}',
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 18),
        MenuButton(
          label: 'MENU',
          icon: Icons.home,
          color: Config.accent,
          onTap: game.quitToMenu,
        ),
      ],
    );
  }
}
