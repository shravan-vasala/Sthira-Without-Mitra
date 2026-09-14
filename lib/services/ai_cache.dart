import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:isar/isar.dart';
import '../models/ai_cache_entry.dart';

class AiCache {
  late final Isar _isar;
  final Duration defaultTtl = const Duration(hours: 24);

  AiCache() {
    _isar = Isar.getInstance(Isar.getInstanceNames().first)!;
  }

  String _hash(String prompt, String? systemInstruction, String? imageContext, String? schemaStr) {
    var raw = prompt;
    if (systemInstruction != null) {
      raw += systemInstruction;
    }
    if (imageContext != null) {
      raw += imageContext;
    }
    if (schemaStr != null) {
      raw += schemaStr;
    }
    return 'ai_cache_${sha256.convert(utf8.encode(raw)).toString()}';
  }

  Map<String, dynamic>? get(String prompt, String? systemInstruction, [String? imageContext, String? schemaStr]) {
    final key = _hash(prompt, systemInstruction, imageContext, schemaStr);
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
    String? schemaStr,
  ]) async {
    final key = _hash(prompt, systemInstruction, imageContext, schemaStr);
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

  /// Extracts routine bounded cache cleanup out of one-time schema version migrations.
  /// Runs reliably uncoupled from startup schema blocks.
  Future<void> prune() async {
    try {
      final cutoff = DateTime.now().subtract(const Duration(days: 90));
      await _isar.writeTxn(() async {
        final oldEntries = _isar.aiCacheEntrys
            .where()
            .filter()
            .timestampLessThan(cutoff)
            .findAllSync();
        if (oldEntries.isNotEmpty) {
          await _isar.aiCacheEntrys.deleteAll(oldEntries.map((e) => e.id).toList());
        }
      });
    } catch (_) {
      // Ignore background cache pruning failures safely
    }
  }
}
