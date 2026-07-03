import 'dart:async';
import 'package:flutter/services.dart';

class CryptoService {
  static const MethodChannel _channel = MethodChannel('com.hyperlink/crypto');

  static Future<Map<String, String>> generateKeyPair() async {
    final result = await _channel.invokeMapMethod<String, String>('generateKeyPair');
    return result ?? {};
  }

  static Future<Map<String, String>> encryptText(String text, String publicKey) async {
    final result = await _channel.invokeMapMethod<String, String>(
      'encryptText',
      {
        'text': text,
        'publicKey': publicKey,
      },
    );
    return result ?? {};
  }

  static Future<String> decryptText({
    required String encryptedKey,
    required String iv,
    required String encryptedData,
    required String privateKey,
  }) async {
    final result = await _channel.invokeMethod<String>(
      'decryptText',
      {
        'encryptedKey': encryptedKey,
        'iv': iv,
        'encryptedData': encryptedData,
        'privateKey': privateKey,
      },
    );
    return result ?? '';
  }

  static Future<Map<String, dynamic>> encryptBytes(Uint8List bytes, String publicKey) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'encryptBytes',
      {
        'bytes': bytes,
        'publicKey': publicKey,
      },
    );
    return result ?? {};
  }

  static Future<Uint8List> decryptBytes({
    required String encryptedKey,
    required String iv,
    required Uint8List encryptedData,
    required String privateKey,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>(
      'decryptBytes',
      {
        'encryptedKey': encryptedKey,
        'iv': iv,
        'encryptedData': encryptedData,
        'privateKey': privateKey,
      },
    );
    return result ?? Uint8List(0);
  }
}
