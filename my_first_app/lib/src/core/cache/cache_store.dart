import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class CacheStore {
  CacheStore._();

  static final CacheStore instance = CacheStore._();

  static const _boxName = 'curate_cache_v1';
  Box<dynamic>? _box;

  bool get isReady => _box != null;

  Future<void> init() async {
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<dynamic>(_boxName);
    } catch (_) {
      _box = null;
    }
  }

  Future<void> clear() async {
    final box = _box;
    if (box == null) return;
    try {
      await box.clear();
    } catch (_) {
      // ignore cache wipe failures
    }
  }

  Future<void> setJson(
    String key,
    Object value,
    Duration ttl,
  ) async {
    final box = _box;
    if (box == null) return;
    try {
      final payload = jsonEncode(value);
      final expiresAt = DateTime.now().add(ttl).millisecondsSinceEpoch;
      await box.put(key, {
        'payload': payload,
        'expiresAt': expiresAt,
      });
    } catch (_) {
      // ignore cache write failures
    }
  }

  dynamic getJson(String key) {
    final box = _box;
    if (box == null) return null;
    try {
      final entry = box.get(key);
      if (entry is Map) {
        final expiresAt = entry['expiresAt'] as int?;
        if (expiresAt != null &&
            DateTime.now().millisecondsSinceEpoch > expiresAt) {
          box.delete(key);
          return null;
        }
        final payload = entry['payload'];
        if (payload is String) {
          return jsonDecode(payload);
        }
        return null;
      }
      if (entry is String) {
        return jsonDecode(entry);
      }
    } catch (_) {
      // ignore cache read failures
    }
    return null;
  }
}
