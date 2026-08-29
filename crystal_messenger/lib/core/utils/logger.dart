import 'dart:collection';

class Logger {
  static final _logs = LinkedHashMap<String, List<String>>();
  static const _maxEntries = 100;

  static void info(String tag, String message) {
    _log(tag, 'INFO', message);
  }

  static void debug(String tag, String message) {
    _log(tag, 'DEBUG', message);
  }

  static void warning(String tag, String message) {
    _log(tag, 'WARN', message);
  }

  static void error(String tag, String message, [Object? error, StackTrace? stackTrace]) {
    _log(tag, 'ERROR', '$message${error != null ? ' | $error' : ''}');
    if (stackTrace != null) {
      _log(tag, 'STACK', stackTrace.toString());
    }
  }

  static void _log(String tag, String level, String message) {
    final entry = '[$level] $message';
    _logs.putIfAbsent(tag, () => []).add(entry);
    if ((_logs[tag]?.length ?? 0) > _maxEntries) {
      _logs[tag]?.removeAt(0);
    }
  }

  static List<String> getLogs(String tag) => _logs[tag] ?? [];
  static Map<String, List<String>> getAllLogs() => Map.unmodifiable(_logs);
  static void clearLogs() => _logs.clear();
}
