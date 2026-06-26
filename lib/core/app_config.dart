/// Build-time configuration. Values are injected via `--dart-define` so the
/// dev and prod flavors compile different behaviour with zero runtime cost.
///
///   dev   : flutter run/build --flavor dev  --dart-define=DEV_MODE=true
///   prod  : flutter run/build --flavor prod
class AppConfig {
  /// When true, dev-only affordances are enabled: every level unlocked, a
  /// "skip level" button, the on-screen log viewer, and verbose logging.
  static const bool isDev =
      bool.fromEnvironment('DEV_MODE', defaultValue: false);

  /// Flavor name, surfaced in the UI/logs so it's obvious which build is which.
  static const String flavor =
      String.fromEnvironment('FLAVOR', defaultValue: 'prod');

  static String get versionTag => isDev ? 'DEV' : 'RELEASE';
}
