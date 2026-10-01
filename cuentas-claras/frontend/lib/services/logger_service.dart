import 'package:flutter/foundation.dart';

/// Severity level for log entries.
enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// A single log entry stored by [LoggerService].
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? source;
  final Map<String, dynamic>? details;

  LogEntry({
    required this.level,
    required this.message,
    this.source,
    this.details,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get formattedTime {
    final t = timestamp;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}.${t.millisecond.toString().padLeft(3, '0')}';
  }

  String get levelLabel {
    switch (level) {
      case LogLevel.debug:
        return 'DEBUG';
      case LogLevel.info:
        return 'INFO ';
      case LogLevel.warning:
        return 'WARN ';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    final sourceStr = source != null ? ' [$source]' : '';
    final detailsStr = details != null ? ' ${details.toString()}' : '';
    return '[$formattedTime] $levelLabel$sourceStr  $message$detailsStr';
  }
}

/// Central logging service for the app.
///
/// Keeps an in-memory ring buffer of the last [maxEntries] log entries
/// so they can be inspected at runtime via the debug overlay.
class LoggerService extends ChangeNotifier {
  final int maxEntries;
  final List<LogEntry> _entries = [];

  LoggerService({this.maxEntries = 500});

  /// Read-only snapshot of current log entries (newest last).
  List<LogEntry> get entries => List.unmodifiable(_entries);

  /// The most recent entry, if any.
  LogEntry? get lastEntry => _entries.isEmpty ? null : _entries.last;

  /// Remove all stored entries.
  void clear() {
    _entries.clear();
    notifyListeners();
  }

  // ── Logging helpers ─────────────────────────────────────────────

  void debug(String message, {String? source, Map<String, dynamic>? details}) {
    _log(LogLevel.debug, message, source: source, details: details);
  }

  void info(String message, {String? source, Map<String, dynamic>? details}) {
    _log(LogLevel.info, message, source: source, details: details);
  }

  void warning(String message, {String? source, Map<String, dynamic>? details}) {
    _log(LogLevel.warning, message, source: source, details: details);
  }

  void error(String message, {String? source, Map<String, dynamic>? details, Object? exception}) {
    final merged = <String, dynamic>{};
    if (details != null) merged.addAll(details);
    if (exception != null) merged['exception'] = exception.toString();
    _log(LogLevel.error, message, source: source, details: merged.isEmpty ? null : merged);
  }

  // ── Internal ───────────────────────────────────────────────────

  void _log(LogLevel level, String message, {String? source, Map<String, dynamic>? details}) {
    final entry = LogEntry(
      level: level,
      message: message,
      source: source,
      details: details,
    );

    // Always print to the debug console
    debugPrint(entry.toString());

    // Store in the ring buffer
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);

    // Notify UI listeners (batched via microtask to avoid flooding)
    notifyListeners();
  }
}
