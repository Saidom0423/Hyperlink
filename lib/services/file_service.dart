import 'package:flutter/services.dart';

class FileService {
  static const _channel = MethodChannel('com.hyperlink/files');

  static Future<String?> pickFile() async {
    try {
      final path = await _channel.invokeMethod<String>('pickFile');
      return path;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> saveFile(
      String fileName,
      List<int> bytes,
      ) async {
    try {
      final uri = await _channel.invokeMethod<String>(
        'saveFile',
        {
          'fileName': fileName,
          'bytes': Uint8List.fromList(bytes),
        },
      );

      print('SAVE URI = $uri');

      return uri;
    } catch (e, st) {
      print('SAVE ERROR = $e');
      print(st);

      return null;
    }
  }
}