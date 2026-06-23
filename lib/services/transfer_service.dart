import 'dart:io';
import 'dart:typed_data';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import '../models/peer_device.dart';

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

      // Parse header: [4B nameLen][name][rest = file data]
      final nameLen = ByteData.sublistView(
          Uint8List.fromList(bytes.sublist(0, 4))
      ).getInt32(0);

      final fileName = String.fromCharCodes(bytes.sublist(4, 4 + nameLen));
      final fileData = bytes.sublist(4 + nameLen);

      // Save to downloads
      final dir = await getExternalStorageDirectory();
      final savePath = '${dir!.path}/$fileName';
      await File(savePath).writeAsBytes(fileData);

      _log.i('File received: $fileName (${fileData.length} bytes)');
      onReceiveComplete(fileName, savePath);
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