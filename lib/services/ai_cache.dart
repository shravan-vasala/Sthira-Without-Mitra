import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCache {
  final SharedPreferences _prefs;
  final Duration defaultTtl = const Duration(hours: 24);

  AiCache(this._prefs);

  String _hash(String prompt, String? imageContext) {
    var raw = prompt;
    if (imageContext != null) {
      raw += imageContext;
    }
    return 'ai_cache_\${sha256.convert(utf8.encode(raw)).toString()}';
  }

  Map<String, dynamic>? get(String prompt, [String? imageContext]) {
    final key = _hash(prompt, imageContext);
    final data = _prefs.getString(key);
    if (data == null) return null;

    try {
      final map = jsonDecode(data) as Map<String, dynamic>;
      final timestamp = DateTime.parse(map['timestamp'] as String);
      if (DateTime.now().difference(timestamp) > defaultTtl) {
        _prefs.remove(key); // Expired
        return null;
      }
      return map['result'] as Map<String, dynamic>;
    } catch (e) {
      _prefs.remove(key);
      return null;
    }
  }

  Future<void> set(String prompt, Map<String, dynamic> result, [String? imageContext]) async {
    final key = _hash(prompt, imageContext);
    final data = jsonEncode({
      'timestamp': DateTime.now().toIso8601String(),
      'result': result,
    });
    await _prefs.setString(key, data);
  }
}
