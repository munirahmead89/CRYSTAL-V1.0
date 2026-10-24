import 'package:logger/logger.dart';

/// Application-facing logging abstraction.
abstract interface class LoggerService {
  void debug(String message, [Object? error, StackTrace? stackTrace]);

  void info(String message, [Object? error, StackTrace? stackTrace]);

  void warn(String message, [Object? error, StackTrace? stackTrace]);

  void error(String message, [Object? error, StackTrace? stackTrace]);
}

class AppLogger implements LoggerService {
  AppLogger(this._logger);

  final Logger _logger;

  @override
  void debug(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void warn(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }
}

/// Builds a [LoggerService] that respects the configured verbosity.
LoggerService createLogger({required String verbosity, bool silent = false}) {
  final Level level;
  if (silent) {
    level = Level.off;
  } else {
    level = switch (verbosity.toLowerCase()) {
      'off' => Level.off,
      'fatal' => Level.fatal,
      'error' => Level.error,
      'warning' || 'warn' => Level.warning,
      'info' => Level.info,
      'debug' => Level.debug,
      'trace' || 'verbose' => Level.trace,
      _ => Level.debug,
    };
  }

  return AppLogger(
    Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        colors: false,
        printEmojis: false,
        lineLength: 120,
      ),
      level: level,
    ),
  );
}
