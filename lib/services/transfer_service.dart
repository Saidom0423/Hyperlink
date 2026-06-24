import 'dart:io';
import 'dart:typed_data';
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
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _log.i('Transfer server listening on port $port');

    _server!.listen((socket) {
      _log.i('Incoming connection from ${socket.remoteAddress.address}');
      _handleIncoming(socket);
    });
  }

  Future<void> stopServer() async {
    await _server?.close();
    _server = null;
  }

  // ── Receive a file ───────────────────────────────────────────────────────
  Future<void> _handleIncoming(Socket socket) async {
    try {
      final bytes = <int>[];
      await for (final chunk in socket) {
        bytes.addAll(chunk);
      }

      if (bytes.isEmpty) return;

      final nameLen = ByteData.sublistView(
          Uint8List.fromList(bytes.sublist(0, 4))
      ).getInt32(0);

      final fileName = String.fromCharCodes(bytes.sublist(4, 4 + nameLen));
      final fileData = bytes.sublist(4 + nameLen);

      _log.i('File received: $fileName (${fileData.length} bytes)');

      // Try MediaStore first (Android 10+)
      String? savedPath;
      try {
        savedPath = await FileService.saveFile(fileName, fileData);
        _log.i('Saved via MediaStore: $savedPath');
      } catch (e) {
        _log.e('MediaStore failed: $e');
      }
      _log.i('Trying MediaStore save');

      savedPath = await FileService.saveFile(
        fileName,
        fileData,
      );

      _log.i('MediaStore result = $savedPath');

      // Fallback — write directly to Downloads folder
      if (savedPath == null) {
        try {
          final dir = Directory('/storage/emulated/0/Download/Hyperlink');
          if (!await dir.exists()) await dir.create(recursive: true);
          final path = '${dir.path}/$fileName';
          await File(path).writeAsBytes(fileData);
          savedPath = path;
          _log.i('Saved via fallback: $savedPath');
        } catch (e) {
          _log.e('Fallback save failed: $e');
        }
      }

      // Last resort — app private storage
      if (savedPath == null) {
        final dir = await getExternalStorageDirectory();
        final path = '${dir!.path}/$fileName';
        await File(path).writeAsBytes(fileData);
        savedPath = path;
        _log.i('Saved to app storage: $savedPath');
      }

      onReceiveComplete(fileName, savedPath!);
    } catch (e) {
      _log.e('Receive error: $e');
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
    final fileName = file.uri.pathSegments.last;
    final fileBytes = await file.readAsBytes();

    _log.i('Sending $fileName (${fileBytes.length} bytes) to ${peer.ip}');

    final socket = await Socket.connect(peer.ip, peer.port,
        timeout: const Duration(seconds: 10));

    // Write header
    final nameBytes = fileName.codeUnits;
    final header = ByteData(4);
    header.setInt32(0, nameBytes.length);

    socket.add(header.buffer.asUint8List());
    socket.add(nameBytes);

    // Write file in chunks with progress
    int sent = 0;
    while (sent < fileBytes.length) {
      final end = (sent + chunkSize).clamp(0, fileBytes.length);
      socket.add(fileBytes.sublist(sent, end));
      sent = end;
      onReceiveProgress(fileName, sent / fileBytes.length);
    }

    await socket.flush();
    await socket.close();
    _log.i('File sent: $fileName');
  }
}