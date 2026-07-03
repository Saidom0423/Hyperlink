import 'package:flutter/services.dart';

/// Flutter-side bridge to query and control the native Android
/// Accessibility Service for auto-accepting WiFi Direct invitations.
class AccessibilityService {
  static const MethodChannel _channel =
      MethodChannel('com.hyperlink/accessibility');

  /// Returns `true` if the Hyperlink Auto-Accept accessibility service
  /// is currently enabled in Android Accessibility Settings.
  static Future<bool> isEnabled() async {
    final result = await _channel.invokeMethod<bool>('isAccessibilityServiceEnabled');
    return result ?? false;
  }

  /// Opens the Android Accessibility Settings screen so the user can
  /// manually enable or disable the auto-accept service.
  static Future<void> openSettings() async {
    await _channel.invokeMethod('openAccessibilitySettings');
  }
}
