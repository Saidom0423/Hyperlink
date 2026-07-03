import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'database_service.dart';
import 'file_service.dart';

class BackupService {
  /// Backs up the current Isar database to the public Downloads/Hyperlink folder.
  static Future<bool> backupDatabase() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/default.isar');
      if (!await dbFile.exists()) {
        debugPrint('Isar database file default.isar not found at ${dbFile.path}');
        return false;
      }

      // Safe snapshot copy using Isar's copyToFile to a temporary location
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/temp_backup.isar';
      final tempFile = File(tempPath);
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      DatabaseService.isar.copyToFile(tempPath);

      final bytes = await tempFile.readAsBytes();
      await tempFile.delete(); // Cleanup temp snapshot file

      final savedPath = await FileService.saveFile(
        'hyperlink_chat_backup.isar',
        bytes,
      );

      return savedPath != null;
    } catch (e) {
      debugPrint('Backup database error: $e');
      return false;
    }
  }

  /// Restores the Isar database from a backup file selected by the user.
  static Future<bool> restoreDatabase() async {
    try {
      // Direct silent lookup of the backup file bytes from Downloads
      final bytes = await FileService.loadBackupFile('hyperlink_chat_backup.isar');
      if (bytes == null) {
        debugPrint('Restore error: No backup file found in Downloads/Hyperlink/');
        return false;
      }

      // Close the current Isar instance to safely write the file
      DatabaseService.isar.close();

      // Overwrite the default.isar file in the documents directory
      final dir = await getApplicationDocumentsDirectory();
      final dbFile = File('${dir.path}/default.isar');
      await dbFile.writeAsBytes(bytes);

      // Re-initialize the database
      await DatabaseService.initialize();

      debugPrint('Database restore completed successfully');
      return true;
    } catch (e) {
      debugPrint('Restore database error: $e');
      return false;
    }
  }
}
