import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'screens/home_screen.dart';
import 'services/database_service.dart';
import 'services/wifi_direct_service.dart';

import 'services/peer_name_service.dart';

void main() async {
  // Ensure framework bindings are ready
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Database Service (Isar)
  await DatabaseService.initialize();

  // Initialize Peer Name Service
  await PeerNameService.load();

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
  bool _isWifiEnabled = true;
  Timer? _wifiCheckTimer;

  @override
  void initState() {
    super.initState();
    _checkAndRequestPermissions();
  }

  @override
  void dispose() {
    _wifiCheckTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndRequestPermissions() async {
    // 1. Request hardware/network discovery tokens in parallel
    await [
      Permission.location,
      Permission.nearbyWifiDevices,
      Permission.contacts,
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

    // 4. Verify initial Wi-Fi status and start periodic checks
    await _checkWifiStatus();
    _startWifiCheckTimer();

    if (mounted) {
      setState(() => _isInitializing = false);
    }
  }

  Future<void> _checkWifiStatus() async {
    try {
      final wifiEnabled = await WifiDirectService().isWifiEnabled();
      if (mounted && wifiEnabled != _isWifiEnabled) {
        setState(() {
          _isWifiEnabled = wifiEnabled;
        });
      }
    } catch (e) {
      debugPrint('Error verifying Wi-Fi status: $e');
    }
  }

  void _startWifiCheckTimer() {
    _wifiCheckTimer?.cancel();
    _wifiCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      await _checkWifiStatus();
    });
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

    if (!_isWifiEnabled) {
      final theme = Theme.of(context);
      final colorScheme = theme.colorScheme;

      return Scaffold(
        backgroundColor: colorScheme.surface,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Icon(
                        Icons.wifi_off_rounded,
                        size: 72,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Wi-Fi Required',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Hyperlink communicates offline using Wi-Fi Direct. Please turn on Wi-Fi to scan and chat with nearby devices.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton.icon(
                        onPressed: () async {
                          try {
                            await WifiDirectService().openWifiSettings();
                          } catch (e) {
                            debugPrint('Failed to open Wi-Fi settings panel: $e');
                          }
                        },
                        icon: const Icon(Icons.wifi_rounded),
                        label: const Text('Turn on Wi-Fi'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return widget.child;
  }
}