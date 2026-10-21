import 'dart:typed_data';
import 'package:flutter/services.dart';

/// Jembatan ke Kotlin (MainActivity). Satu channel untuk semua kebutuhan native,
/// jadi tidak perlu plugin tambahan.
const _ch = MethodChannel('waweb/files');

class FileSaver {
  static Future<String?> save(String name, String mime, Uint8List bytes) {
    return _ch.invokeMethod<String>('save', {
      'name': name,
      'mime': mime,
      'bytes': bytes,
    });
  }

  static Future<void> open(String uri, String mime) async {
    try {
      await _ch.invokeMethod('open', {'uri': uri, 'mime': mime});
    } catch (_) {}
  }

  /// Buka folder tujuan (folder pilihan, atau Download kalau belum memilih).
  static Future<void> openDownloads() async {
    try {
      await _ch.invokeMethod('openDownloads');
    } catch (_) {}
  }

  /// Pemilih folder bawaan sistem. Folder baru bisa dibuat langsung di dalamnya.
  /// Mengembalikan label folder, atau null kalau dibatalkan.
  static Future<String?> pickFolder() async {
    try {
      return await _ch.invokeMethod<String>('pickFolder');
    } catch (_) {
      return null;
    }
  }

  static Future<String> folderLabel() async {
    try {
      return await _ch.invokeMethod<String>('folderLabel') ?? 'Download/waweb';
    } catch (_) {
      return 'Download/waweb';
    }
  }

  static Future<void> resetFolder() async {
    try {
      await _ch.invokeMethod('resetFolder');
    } catch (_) {}
  }
}

class Native {
  static Future<Map<String, dynamic>> prefs() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('prefs');
      return m ?? {};
    } catch (_) {
      return {};
    }
  }

  static void setPref(String key, Object? value) {
    _ch.invokeMethod('setPref', {'key': key, 'value': value}).catchError((_) {});
  }

  static Future<bool> online() async {
    try {
      return await _ch.invokeMethod<bool>('online') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> launch(String url) async {
    try {
      await _ch.invokeMethod('launch', {'url': url});
    } catch (_) {}
  }

  static Future<bool> perms(List<String> list) async {
    try {
      return await _ch.invokeMethod<bool>('perms', {'list': list}) ?? false;
    } catch (_) {
      return false;
    }
  }
}
