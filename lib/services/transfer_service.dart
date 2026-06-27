import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/peer_device.dart';
import '../services/file_service.dart';

class TransferService {
  static const int port = 8765;
  static const int chunkSize = 256 * 1024; // 256KB

  final Logger _log = Logger();
  ServerSocket? _server;

  final void Function(String fileName, double progress) onReceiveProgress;
  final void Function(String fileName, String savePath) onReceiveComplete;

  TransferService({
    required this.onReceiveProgress,
    required this.onReceiveComplete,
  });

  // ── Start TCP server to receive files ───────────────────────────────────

  Future<void> startServer() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _log.i('Transfer server listening on port $port');

      _server!.listen((socket) {
        _log.i('Incoming connection from ${socket.remoteAddress.address}');
        _handleIncoming(socket);
      });
    } catch (e) {
      _log.e('Failed to start server: $e');
      rethrow;
    }
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
    _log.i('Transfer server stopped.');
  }

  // ── Receive a file ───────────────────────────────────────────────────────

  Future<void> _handleIncoming(Socket socket) async {
    try {
      final bytes = <int>[];
      await for (final chunk in socket) {
        bytes.addAll(chunk);
        // Note: For future huge files, stream this straight to a temp file instead of holding in memory!
      }

      if (bytes.isEmpty) {
        _log.w('Received empty byte stream from socket.');
        return;
      }

      // Read Header (First 4 Bytes = Length of file name)
      final nameLen = ByteData.sublistView(
          Uint8List.fromList(bytes.sublist(0, 4))
      ).getInt32(0);

      final fileName = String.fromCharCodes(bytes.sublist(4, 4 + nameLen));
      final fileData = bytes.sublist(4 + nameLen);

      _log.i('File payload extracted: $fileName (${fileData.length} bytes)');

      String? savedPath;

      // 1. Try MediaStore first (Android 10+)
      try {
        _log.i('Attempting MediaStore save...');
        savedPath = await FileService.saveFile(fileName, fileData);
        if (savedPath != null) _log.i('Saved via MediaStore: $savedPath');
      } catch (e) {
        _log.e('MediaStore save failed: $e');
      }

      // 2. Fallback — write directly to Shared Downloads folder
      if (savedPath == null) {
        try {
          _log.i('Attempting Download folder fallback...');
          final dir = Directory('/storage/emulated/0/Download/Hyperlink');
          if (!await dir.exists()) await dir.create(recursive: true);
          final path = '${dir.path}/$fileName';
          await File(path).writeAsBytes(fileData);
          savedPath = path;
          _log.i('Saved via fallback: $savedPath');
        } catch (e) {
          _log.e('Shared Downloads fallback save failed: $e');
        }
      }

      // 3. Last resort — App private external storage directory
      if (savedPath == null) {
        try {
          _log.i('Attempting App Private Storage fallback...');
          final dir = await getExternalStorageDirectory();
          if (dir != null) {
            final path = '${dir.path}/$fileName';
            await File(path).writeAsBytes(fileData);
            savedPath = path;
            _log.i('Saved to app storage: $savedPath');
          }
        } catch (e) {
          _log.e('App private storage save failed: $e');
        }
      }

      if (savedPath != null) {
        onReceiveComplete(fileName, savedPath);
      } else {
        _log.e('Failed to save file across all destination fallbacks.');
      }
    } catch (e) {
      _log.e('Receive error processing incoming socket payload: $e');
    } finally {
      await socket.close();
    }
  }

  // ── Send a file ──────────────────────────────────────────────────────────

  Future<void> sendFile({
    required PeerDevice peer,
    required String filePath,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException("Target send file does not exist", filePath);
    }

    final fileName = file.uri.pathSegments.last;
    final fileBytes = await file.readAsBytes();

    _log.i('Sending $fileName (${fileBytes.length} bytes) to ${peer.ip}');

    debugPrint("========== SEND ==========");
    debugPrint("Peer name : ${peer.name}");
    debugPrint("Peer IP   : '${peer.ip}'");
    debugPrint("Peer port : ${peer.port}");
    debugPrint("==========================");

    if (peer.ip.isEmpty) {
      throw ArgumentError("Cannot connect! Target peer IP is blank. Verify Wi-Fi Direct connection info extraction.");
    }

    final socket = await Socket.connect(
      peer.ip,
      peer.port,
      timeout: const Duration(seconds: 10),
    );

    // Write header string metadata info
    final nameBytes = fileName.codeUnits;
    final header = ByteData(4);
    header.setInt32(0, nameBytes.length);

    socket.add(header.buffer.asUint8List());
    socket.add(nameBytes);

    // Write file payload in chunks with progress reporting updates
    int sent = 0;
    while (sent < fileBytes.length) {
      final end = (sent + chunkSize).clamp(0, fileBytes.length);
      socket.add(fileBytes.sublist(sent, end));
      sent = end;

      // Updates the notification/UI state contextually
      onReceiveProgress(fileName, sent / fileBytes.length);
    }

    await socket.flush();
    await socket.close();
    _log.i('File completely sent: $fileName');
  }
}