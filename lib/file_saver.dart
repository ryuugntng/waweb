import 'dart:typed_data';
import 'package:flutter/services.dart';

class FileSaver {
  static const _ch = MethodChannel('waweb/files');

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

  static Future<void> openDownloads() async {
    try {
      await _ch.invokeMethod('openDownloads');
    } catch (_) {}
  }
}
