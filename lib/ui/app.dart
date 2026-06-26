import 'package:flutter/material.dart';

import '../core/app_config.dart';
import '../data/level_data.dart';
import '../data/progress_store.dart';
import '../game/config.dart';
import 'dev/dev_overlay.dart';
import 'game_screen.dart';
import 'main_menu_screen.dart';

class TrapRunnerApp extends StatelessWidget {
  TrapRunnerApp({
    super.key,
    required this.progress,
    this.deepLinkLevel,
  });

  final ProgressStore progress;
  final int? deepLinkLevel;

  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final dl = deepLinkLevel;
    final Widget home = (dl != null && dl >= 1 && dl <= kLevelCount)
        ? GameScreen(progress: progress, startIndex: dl - 1)
        : MainMenuScreen(progress: progress);
    return MaterialApp(
      title: 'Trap Runner',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Config.accent,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF1B2440),
        fontFamily: 'monospace',
      ),
      // In dev builds, float a draggable bypass/log button over every screen.
      builder: (context, child) {
        if (!AppConfig.isDev) return child!;
        return Stack(
          children: [
            child!,
            DevFab(progress: progress, navigatorKey: _navKey),
          ],
        );
      },
      home: home,
    );
  }
}

/// Shared chunky button used across menus.
class MenuButton extends StatelessWidget {
  const MenuButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Config.accent;
    return Material(
      color: c,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          constraints: const BoxConstraints(minWidth: 220),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF1B2440)),
                const SizedBox(width: 10),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF1B2440),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
