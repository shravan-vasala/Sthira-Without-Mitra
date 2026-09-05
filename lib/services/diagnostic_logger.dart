import 'dart:collection';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_providers.dart';

final diagnosticLoggerProvider = Provider<DiagnosticLogger>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DiagnosticLogger(prefs);
});

class DiagnosticLog {
  final DateTime timestamp;
  final String level;
  final String message;
  final String? error;
  final String? stackTrace;

  DiagnosticLog({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
  });

  Map<String, dynamic> toJson() => {
        'ts': timestamp.toIso8601String(),
        'lvl': level,
        'msg': message,
        if (error != null) 'err': error,
        if (stackTrace != null) 'stack': stackTrace,
      };

  factory DiagnosticLog.fromJson(Map<String, dynamic> json) => DiagnosticLog(
        timestamp: DateTime.parse(json['ts']),
        level: json['lvl'],
        message: json['msg'],
        error: json['err'],
        stackTrace: json['stack'],
      );
}

class DiagnosticLogger {
  static const int _maxLogs = 100;
  static const String _prefsKey = 'diagnostic_ring_buffer';

  final SharedPreferences _prefs;
  final Queue<DiagnosticLog> _logs = Queue<DiagnosticLog>();

  DiagnosticLogger(this._prefs) {
    _loadFromPrefs();
  }

  void _loadFromPrefs() {
    try {
      final str = _prefs.getString(_prefsKey);
      if (str != null) {
        final List<dynamic> decoded = jsonDecode(str);
        for (var item in decoded) {
          if (item is Map<String, dynamic>) {
            _logs.addLast(DiagnosticLog.fromJson(item));
          }
        }
      }
    } catch (e) {
      debugPrint('DiagnosticLogger failed to load: $e');
    }
  }

  void _saveToPrefs() {
    try {
      final str = jsonEncode(_logs.map((e) => e.toJson()).toList());
      _prefs.setString(_prefsKey, str);
    } catch (e) {
      debugPrint('DiagnosticLogger failed to save: $e');
    }
  }

  void _addLog(String level, String message, [dynamic error, StackTrace? stack]) {
    final log = DiagnosticLog(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      error: error?.toString(),
      stackTrace: stack?.toString(),
    );

    _logs.addFirst(log);
    if (_logs.length > _maxLogs) {
      _logs.removeLast();
    }

    // Persist synchronously for best-effort crash survival
    _saveToPrefs();
    
    // Also echo to console in debug mode
    if (kDebugMode) {
      print('[$level] $message ${error != null ? '\nError: $error' : ''}');
    }
  }

  void info(String message) => _addLog('INFO', message);
  void warning(String message, [dynamic error, StackTrace? stack]) => _addLog('WARN', message, error, stack);
  void error(String message, [dynamic error, StackTrace? stack]) => _addLog('ERROR', message, error, stack);
  
  List<DiagnosticLog> getLogs() => _logs.toList();
  
  void clear() {
    _logs.clear();
    _prefs.remove(_prefsKey);
  }
}

/// A ProviderObserver that catches all Riverpod state errors and logs them
class DiagnosticProviderObserver extends ProviderObserver {
  final DiagnosticLogger logger;
  DiagnosticProviderObserver(this.logger);

  @override
  void didUpdateProvider(
    ProviderBase<Object?> provider,
    Object? previousValue,
    Object? newValue,
    ProviderContainer container,
  ) {
    // If it's an AsyncError, log it
    if (newValue is AsyncError) {
      logger.error(
        'Provider ${provider.name ?? provider.runtimeType} AsyncError',
        newValue.error,
        newValue.stackTrace,
      );
    }
  }
}
