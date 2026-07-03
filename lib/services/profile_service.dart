import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'contacts_service.dart';
import 'crypto_service.dart';

class UserProfile {
  final String name;
  final String phoneNumber;
  final String hashedPhone;
  final String publicKey;
  final String privateKey;

  UserProfile({
    required this.name,
    required this.phoneNumber,
    required this.hashedPhone,
    required this.publicKey,
    required this.privateKey,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'phoneNumber': phoneNumber,
        'hashedPhone': hashedPhone,
        'publicKey': publicKey,
        'privateKey': privateKey,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] ?? '',
        phoneNumber: json['phoneNumber'] ?? '',
        hashedPhone: json['hashedPhone'] ?? '',
        publicKey: json['publicKey'] ?? '',
        privateKey: json['privateKey'] ?? '',
      );
}

class ProfileService {
  static final Logger _log = Logger();
  static const MethodChannel _wifiChannel = MethodChannel('com.hyperlink/wifi_direct');

  static UserProfile? _currentProfile;

  static UserProfile? get currentProfile => _currentProfile;

  static bool get isProfileSetup => _currentProfile != null;

  static Future<File> _getProfileFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/profile.json');
  }

  static Future<void> loadProfile() async {
    try {
      final file = await _getProfileFile();
      if (await file.exists()) {
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        _currentProfile = UserProfile.fromJson(json);
        _log.i('Loaded profile for ${_currentProfile!.name} (${_currentProfile!.phoneNumber})');
        
        // Sync device name on load
        await syncDeviceName();
      } else {
        _log.i('No profile found, setup required');
      }
    } catch (e) {
      _log.e('Failed to load profile: $e');
    }
  }

  static Future<void> setupProfile(String name, String phoneNumber) async {
    try {
      final normalized = ContactsService.normalizePhone(phoneNumber);
      final hashedPhone = ContactsService.computePhoneHash(normalized);

      _log.i('Generating E2EE RSA keys natively...');
      final keys = await CryptoService.generateKeyPair();
      final publicKey = keys['publicKey'] ?? '';
      final privateKey = keys['privateKey'] ?? '';

      final profile = UserProfile(
        name: name,
        phoneNumber: normalized,
        hashedPhone: hashedPhone,
        publicKey: publicKey,
        privateKey: privateKey,
      );

      final file = await _getProfileFile();
      await file.writeAsString(jsonEncode(profile.toJson()));
      _currentProfile = profile;
      _log.i('Profile saved successfully');

      // Sync device name
      await syncDeviceName();
    } catch (e) {
      _log.e('Failed to setup profile: $e');
      rethrow;
    }
  }

  static Future<void> syncDeviceName() async {
    if (_currentProfile == null) return;
    try {
      final wfdName = 'HP_${_currentProfile!.hashedPhone}';
      _log.i('Setting Wi-Fi Direct device name to $wfdName...');
      await _wifiChannel.invokeMethod('setDeviceName', {'name': wfdName});
      _log.i('Wi-Fi Direct device name updated successfully');
    } catch (e) {
      _log.e('Failed to set Wi-Fi Direct device name: $e');
    }
  }
}
