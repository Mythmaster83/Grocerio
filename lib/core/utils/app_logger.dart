import 'package:logger/logger.dart';

/// Central logger. Never log secrets, API keys, or raw user PII here.
/// In release builds this should be wired to a crash/log backend (e.g.
/// Sentry) instead of console output — see architecture.md "Observability".
final AppLogger logger = AppLogger._();

class AppLogger {
  AppLogger._();

  final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
    ),
  );

  void debug(String message) => _logger.d(message);
  void info(String message) => _logger.i(message);
  void warning(String message) => _logger.w(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.e(message, error: error, stackTrace: stackTrace);
}
