import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() {
  // Ensure framework bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: HyperlinkApp(),
    ),
  );
}

class HyperlinkApp extends StatelessWidget {
  const HyperlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyperlink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5B4FE8)),
        useMaterial3: true,
      ),
      // Use a builder wrapper or a lifecycle starter widget
      // instead of stalling native main engine execution threads.
      home: const PermissionGateway(child: HomeScreen()),
    );
  }
}

// ── Permission Wrapper Gateway ──────────────────────────────────────────────

class PermissionGateway extends StatefulWidget {
  final Widget child;
  const PermissionGateway({required this.child, super.key});

  @override
  State<PermissionGateway> createState() => _PermissionGatewayState();
}

class _PermissionGatewayState extends State<PermissionGateway> {
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 1. Request hardware/network discovery tokens in parallel
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
    ].request();

    // 2. Request appropriate storage/media read-write bindings
    await [
      Permission.photos,
      Permission.videos,
      Permission.audio,
      Permission.storage,
    ].request();

    // 3. Handle Special Scopes (Android 11+ High-level management) safely
    try {
      final isManagedStorageGranted = await Permission.manageExternalStorage.isGranted;
      if (!isManagedStorageGranted) {
        // Safe check: Instead of instantly redirecting out of the app unexpectedly,
        // you can optionally show a custom Dialog explaining *why* you need it first.
        await Permission.manageExternalStorage.request();
      }
    } catch (e) {
      debugPrint('Manage storage resolution bypassed or unsupported on platform: $e');
    }

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF5B4FE8)),
          ),
        ),
      );
    }
    return widget.child;
  }
}