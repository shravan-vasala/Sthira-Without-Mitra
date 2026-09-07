import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';
import '../models/ai_cache_entry.dart';

class AiCache {
  late final Isar _isar;
  final Duration defaultTtl = const Duration(hours: 24);

  AiCache() {
    _isar = Isar.getInstance()!;
  }

  String _hash(String prompt, String? systemInstruction, String? imageContext) {
    var raw = prompt;
    if (systemInstruction != null) {
      raw += systemInstruction;
    }
    if (imageContext != null) {
      raw += imageContext;
    }
    return 'ai_cache_${sha256.convert(utf8.encode(raw)).toString()}';
  }

  Map<String, dynamic>? get(String prompt, String? systemInstruction, [String? imageContext]) {
    final key = _hash(prompt, systemInstruction, imageContext);
    final entry = _isar.aiCacheEntrys
        .where()
        .cacheKeyEqualTo(key)
        .findFirstSync();

    if (entry == null) return null;

    if (DateTime.now().difference(entry.timestamp) > defaultTtl) {
      _isar.writeTxnSync(() {
        _isar.aiCacheEntrys.deleteSync(entry.id);
      });
      return null;
    }

    try {
      return jsonDecode(entry.cachedResponse) as Map<String, dynamic>;
    } catch (e) {
      _isar.writeTxnSync(() {
        _isar.aiCacheEntrys.deleteSync(entry.id);
      });
      return null;
    }
  }

  Future<void> set(
    String prompt,
    String? systemInstruction,
    Map<String, dynamic> result, [
    String? imageContext,
  ]) async {
    final key = _hash(prompt, systemInstruction, imageContext);
    final data = jsonEncode(result);

    final existing = _isar.aiCacheEntrys
        .where()
        .cacheKeyEqualTo(key)
        .findFirstSync();

    final entry = AiCacheEntry(
      cacheKey: key,
      cachedResponse: data,
      timestamp: DateTime.now(),
    );

    if (existing != null) {
      entry.id = existing.id;
    }

    await _isar.writeTxn(() async {
      await _isar.aiCacheEntrys.put(entry);
    });
  }
}
