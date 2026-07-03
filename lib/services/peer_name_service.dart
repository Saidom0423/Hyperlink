import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

class PeerNameService {
  static final Map<String, String> _cache = {};

  static Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/peer_names.json');
  }

  static Future<void> load() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> json = jsonDecode(content);
        json.forEach((k, v) {
          _cache[k] = v.toString();
        });
      }
    } catch (e) {
      debugPrint('Failed to load peer names: $e');
    }
  }

  static Future<void> save(String peerId, String name) async {
    if (name.isEmpty || name == 'Contact' || name.startsWith('Nearby Peer')) return;
    if (_cache[peerId] == name) return;

    _cache[peerId] = name;
    try {
      final file = await _getFile();
      await file.writeAsString(jsonEncode(_cache));
    } catch (e) {
      debugPrint('Failed to save peer names: $e');
    }
  }

  static String get(String peerId, {String fallback = 'Contact'}) {
    return _cache[peerId] ?? fallback;
  }
}
