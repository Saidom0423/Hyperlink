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
  await [
    Permission.location,
    Permission.nearbyWifiDevices,
  ].request();
}

class HyperlinkApp extends StatelessWidget {
  const HyperlinkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hyperlink',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF5B4FE8),
        ),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}