import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  LogEntry(this.time, this.level, this.tag, this.message, [this.error]);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;
  final Object? error;

  String get stamp =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
}

/// App-wide logger. Keeps a rolling in-memory buffer (shown by the dev log
/// overlay) and also forwards to `dart:developer` so logs appear in the
/// console / IDE. Every screen and the game funnel events through this so a
/// problem anywhere is captured with context.
class Log {
  Log._();

  static const int _max = 400;
  static final List<LogEntry> _entries = [];

  /// Bumped on every new entry so the dev log overlay can rebuild.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static int get errorCount =>
      _entries.where((e) => e.level == LogLevel.error).length;

  static void d(String tag, String message) =>
      _add(LogLevel.debug, tag, message);
  static void i(String tag, String message) =>
      _add(LogLevel.info, tag, message);
  static void w(String tag, String message) =>
      _add(LogLevel.warn, tag, message);
  static void e(String tag, String message, [Object? error, StackTrace? st]) =>
      _add(LogLevel.error, tag, message, error, st);

  static void _add(LogLevel level, String tag, String message,
      [Object? error, StackTrace? st]) {
    final entry = LogEntry(DateTime.now(), level, tag, message, error);
    _entries.add(entry);
    if (_entries.length > _max) _entries.removeAt(0);

    developer.log(
      message,
      name: tag,
      level: switch (level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warn => 900,
        LogLevel.error => 1000,
      },
      error: error,
      stackTrace: st,
    );
    revision.value++;
  }

  static void clear() {
    _entries.clear();
    revision.value++;
  }
}
