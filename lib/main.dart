import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const ProviderScope(child: HyperlinkApp()));
}

Future<void> _requestPermissions() async {
  await Permission.location.request();
  await Permission.nearbyWifiDevices.request();

  // Android 13+ uses media permissions
  await Permission.photos.request();
  await Permission.videos.request();
  await Permission.audio.request();

  // Android 11-12 uses storage
  await Permission.storage.request();

  // Android 11+ manage external storage needs settings page
  if (!await Permission.manageExternalStorage.isGranted) {
    await openAppSettings();
  }
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
      home: const HomeScreen(),
    );
  }
}