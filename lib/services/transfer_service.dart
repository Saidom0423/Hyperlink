import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:convert/convert.dart';
import '../models/peer_device.dart';
import 'crypto_service.dart';
import 'file_service.dart';
import 'profile_service.dart';

class SocketReader {
  final Socket socket;
  final List<int> _buffer = [];
  Completer<void>? _dataCompleter;
  StreamSubscription? _subscription;
  bool _done = false;

  SocketReader(this.socket) {
    _subscription = socket.listen(
      (data) {
        _buffer.addAll(data);
        if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
          _dataCompleter!.complete();
        }
      },
      onDone: () {
        _done = true;
        if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
          _dataCompleter!.complete();
        }
      },
      onError: (e) {
        _done = true;
        if (_dataCompleter != null && !_dataCompleter!.isCompleted) {
          _dataCompleter!.completeError(e);
        }
      },
    );
  }

  Future<Uint8List> readBytes(int count) async {
    while (_buffer.length < count && !_done) {
      _dataCompleter = Completer<void>();
      await _dataCompleter!.future;
    }
    if (_buffer.length < count) {
      throw StateError("Socket closed before reading $count bytes.");
    }
    final result = Uint8List.fromList(_buffer.sublist(0, count));
    _buffer.removeRange(0, count);
    return result;
  }

  Future<Map<String, dynamic>> readJson() async {
    final lenBytes = await readBytes(4);
    final len = ByteData.view(lenBytes.buffer).getInt32(0);
    final jsonBytes = await readBytes(len);
    return jsonDecode(utf8.decode(jsonBytes)) as Map<String, dynamic>;
  }

  Future<void> pipeToFile(File file, int count, void Function(double progress)? onProgress) async {
    final sink = file.openWrite(mode: FileMode.writeOnlyAppend);
    int remaining = count;
    while (remaining > 0) {
      if (_buffer.isEmpty) {
        if (_done) break;
        _dataCompleter = Completer<void>();
        await _dataCompleter!.future;
      }
      if (_buffer.isNotEmpty) {
        final toWrite = _buffer.length.clamp(0, remaining);
        final chunk = _buffer.sublist(0, toWrite);
        sink.add(chunk);
        _buffer.removeRange(0, toWrite);
        remaining -= toWrite;
        onProgress?.call((count - remaining) / count);
      }
    }
    await sink.flush();
    await sink.close();
    if (remaining > 0) {
      throw StateError("Socket closed with $remaining bytes remaining to read");
    }
  }

  Future<void> close() async {
    await _subscription?.cancel();
  }
}

class TransferService {
  static const int port = 8765;
  final Logger _log = Logger();
  ServerSocket? _server;

  final void Function(String fileName, double progress) onReceiveProgress;
  final void Function(String fileName, String savePath, String senderId, String senderName) onReceiveComplete;
  final void Function(String remoteIp)? onConnectionReceived;
  final void Function(String fileName, double progress)? onSendProgress;

  TransferService({
    required this.onReceiveProgress,
    required this.onReceiveComplete,
    this.onConnectionReceived,
    this.onSendProgress,
  });

  Future<void> startServer() async {
    try {
      _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
      _log.i('Transfer server listening on port $port');

      _server!.listen((socket) {
        final remoteIp = socket.remoteAddress.address;
        _log.i('Incoming connection from $remoteIp');
        onConnectionReceived?.call(remoteIp);
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

  static Future<void> writeJson(Socket socket, Map<String, dynamic> json) async {
    final str = jsonEncode(json);
    final bytes = utf8.encode(str);
    final lenBytes = Uint8List(4);
    ByteData.view(lenBytes.buffer).setInt32(0, bytes.length);
    socket.add(lenBytes);
    socket.add(bytes);
    await socket.flush();
  }

  static Future<String> calculateFileChecksum(File file) async {
    final digest = SHA256Digest();
    final stream = file.openRead();
    await for (final chunk in stream) {
      digest.update(Uint8List.fromList(chunk), 0, chunk.length);
    }
    final hash = Uint8List(digest.digestSize);
    digest.doFinal(hash, 0);
    return hex.encode(hash);
  }

  // ── Receive a file ───────────────────────────────────────────────────────
  Future<void> _handleIncoming(Socket socket) async {
    final reader = SocketReader(socket);
    File? partialFile;
    try {
      final meta = await reader.readJson();
      final senderId = meta['senderId'] as String? ?? 'unknown_sender';
      final senderName = meta['senderName'] as String? ?? 'Contact';
      final fileName = meta['fileName'] as String;
      final fileSize = meta['fileSize'] as int;
      final checksum = meta['checksum'] as String;
      final encryptedKey = meta['encryptedKey'] as String;
      final iv = meta['iv'] as String;

      final tempDir = await getTemporaryDirectory();
      final partialPath = '${tempDir.path}/temp_$checksum.part';
      partialFile = File(partialPath);

      int receivedBytes = 0;
      if (await partialFile.exists()) {
        receivedBytes = await partialFile.length();
      } else {
        await partialFile.create();
      }

      // Send resume response
      await writeJson(socket, {'receivedBytes': receivedBytes});

      if (receivedBytes < fileSize) {
        // Read the remaining bytes from the socket
        await reader.pipeToFile(
          partialFile,
          fileSize - receivedBytes,
          (progress) {
            final totalProgress = (receivedBytes + (progress * (fileSize - receivedBytes))) / fileSize;
            onReceiveProgress(fileName, totalProgress);
          },
        );
      }

      // Transfer completed successfully
      _log.i('Received complete encrypted file: $fileName, decrypting...');

      // Decrypt file
      final encryptedBytes = await partialFile.readAsBytes();
      final privateKey = ProfileService.currentProfile!.privateKey;
      final decryptedBytes = await CryptoService.decryptBytes(
        encryptedKey: encryptedKey,
        iv: iv,
        encryptedData: encryptedBytes,
        privateKey: privateKey,
      );

      // Verify checksum
      final decryptedDigest = SHA256Digest().process(decryptedBytes);
      final decryptedChecksum = hex.encode(decryptedDigest);
      if (decryptedChecksum != checksum) {
        throw StateError("File integrity check failed: Checksum mismatch");
      }

      // Save local copy for app/chat rendering
      final appDir = await getApplicationDocumentsDirectory();
      final receivedDir = Directory('${appDir.path}/received_files');
      if (!await receivedDir.exists()) await receivedDir.create(recursive: true);
      final localPath = '${receivedDir.path}/$fileName';
      await File(localPath).writeAsBytes(decryptedBytes);

      // Save public copy in Downloads folder
      String? savedPath = await FileService.saveFile(fileName, decryptedBytes);
      if (savedPath == null) {
        final destDir = Directory('/storage/emulated/0/Download/Hyperlink');
        if (!await destDir.exists()) await destDir.create(recursive: true);
        final path = '${destDir.path}/$fileName';
        await File(path).writeAsBytes(decryptedBytes);
        savedPath = path;
      }

      _log.i('File decrypted and saved. Public: $savedPath, Local: $localPath');
      onReceiveComplete(fileName, localPath, senderId, senderName);

      // Cleanup partial file
      await partialFile.delete();
    } catch (e) {
      _log.e('Receive error: $e');
    } finally {
      await reader.close();
      await socket.close();
    }
  }

  // ── Send a file ──────────────────────────────────────────────────────────
  Future<void> sendFile({
    required PeerDevice peer,
    required String filePath,
    required String senderId,
    required String senderName,
  }) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileSystemException("Target send file does not exist", filePath);
    }

    final fileName = file.uri.pathSegments.last;
    _log.i('Encrypting and sending $fileName to ${peer.ip}');

    if (peer.ip.isEmpty) {
      throw ArgumentError("Cannot connect! Target peer IP is blank.");
    }

    // 1. Calculate checksum
    final checksum = await calculateFileChecksum(file);

    // 2. Encrypt original file bytes
    final originalBytes = await file.readAsBytes();
    final encryptedMap = await CryptoService.encryptBytes(originalBytes, peer.publicKey);
    final encryptedKey = encryptedMap['encryptedKey'] as String;
    final iv = encryptedMap['iv'] as String;
    final encryptedData = encryptedMap['encryptedData'] as Uint8List;

    // 3. Save encrypted file to a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempEncFile = File('${tempDir.path}/enc_$checksum.tmp');
    await tempEncFile.writeAsBytes(encryptedData);
    final encryptedSize = encryptedData.length;

    Socket? socket;
    SocketReader? reader;
    try {
      socket = await Socket.connect(
        peer.ip,
        peer.port,
        timeout: const Duration(seconds: 10),
      );
      reader = SocketReader(socket);

      // Send metadata JSON
      await writeJson(socket, {
        'senderId': senderId,
        'senderName': senderName,
        'fileName': fileName,
        'fileSize': encryptedSize,
        'checksum': checksum,
        'encryptedKey': encryptedKey,
        'iv': iv,
      });

      // Read resume response
      final resp = await reader.readJson();
      final int skipBytes = resp['receivedBytes'] as int? ?? 0;

      // Stream remaining bytes
      final fileStream = tempEncFile.openRead(skipBytes);
      int sent = skipBytes;

      await for (final chunk in fileStream) {
        socket.add(chunk);
        sent += chunk.length;
        (onSendProgress ?? onReceiveProgress)(fileName, sent / encryptedSize);
      }

      await socket.flush();
    } catch (e) {
      _log.e('Send file error: $e');
      rethrow;
    } finally {
      await reader?.close();
      await socket?.close();
      try {
        if (await tempEncFile.exists()) await tempEncFile.delete();
      } catch (_) {}
    }
  }
}