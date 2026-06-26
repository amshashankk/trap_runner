import 'package:flutter/material.dart';

import '../../core/app_config.dart';
import '../../core/log.dart';
import '../../data/progress_store.dart';
import '../game_screen.dart';
import '../level_select_screen.dart';

/// A draggable floating "DEV" button injected over every screen (dev builds
/// only) so you can bypass progression and inspect logs from anywhere.
class DevFab extends StatefulWidget {
  const DevFab({super.key, required this.progress, required this.navigatorKey});

  final ProgressStore progress;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<DevFab> createState() => _DevFabState();
}

class _DevFabState extends State<DevFab> {
  Offset _pos = const Offset(16, 90);

  NavigatorState? get _nav => widget.navigatorKey.currentState;

  void _openMenu() {
    final nav = _nav;
    if (nav == null) return;
    showModalBottomSheet(
      context: nav.context,
      backgroundColor: const Color(0xFF20294A),
      builder: (sheetCtx) {
        return SafeArea(
          child: ValueListenableBuilder<int>(
            valueListenable: Log.revision,
            builder: (context, _, child) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'DEV MENU · flavor=${AppConfig.flavor} · errors=${Log.errorCount}',
                    style: const TextStyle(
                        color: Colors.amber, fontWeight: FontWeight.bold),
                  ),
                ),
                _tile(sheetCtx, Icons.list_alt, 'View logs (${Log.entries.length})',
                    () {
                  Navigator.pop(sheetCtx);
                  nav.push(MaterialPageRoute(builder: (_) => const LogScreen()));
                }),
                _tile(sheetCtx, Icons.grid_view, 'Jump to any level', () {
                  Navigator.pop(sheetCtx);
                  nav.push(MaterialPageRoute(
                      builder: (_) =>
                          LevelSelectScreen(progress: widget.progress)));
                }),
                _tile(sheetCtx, Icons.play_arrow, 'Play level 1 (bypass)', () {
                  Navigator.pop(sheetCtx);
                  nav.push(MaterialPageRoute(
                      builder: (_) => GameScreen(
                          progress: widget.progress, startIndex: 0)));
                }),
                _tile(sheetCtx, Icons.lock_open, 'Reset progress', () async {
                  await widget.progress.resetAll();
                  Log.w('dev', 'Progress reset');
                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext ctx, IconData icon, String label, VoidCallback tap) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: tap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      left: _pos.dx,
      top: _pos.dy,
      child: GestureDetector(
        onPanUpdate: (d) => setState(() {
          _pos = Offset(
            (_pos.dx + d.delta.dx).clamp(0, size.width - 52),
            (_pos.dy + d.delta.dy).clamp(0, size.height - 52),
          );
        }),
        onTap: _openMenu,
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.92),
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: const Icon(Icons.bug_report, color: Color(0xFF1B2440)),
        ),
      ),
    );
  }
}

/// Scrollable viewer for the in-memory log buffer.
class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  Color _color(LogLevel l) => switch (l) {
        LogLevel.error => Colors.redAccent,
        LogLevel.warn => Colors.orangeAccent,
        LogLevel.info => Colors.lightBlueAccent,
        LogLevel.debug => Colors.white54,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: Log.clear,
          ),
        ],
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: Log.revision,
        builder: (context, _, child) {
          final entries = Log.entries.reversed.toList();
          if (entries.isEmpty) {
            return const Center(
                child: Text('No logs yet',
                    style: TextStyle(color: Colors.white38)));
          }
          return ListView.builder(
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                        text: '${e.stamp} ',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 12)),
                    TextSpan(
                        text: '[${e.tag}] ',
                        style: TextStyle(
                            color: _color(e.level),
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                    TextSpan(
                        text: e.message +
                            (e.error != null ? '\n   ↳ ${e.error}' : ''),
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ]),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
