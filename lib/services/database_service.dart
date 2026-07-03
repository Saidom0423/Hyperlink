import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import '../models/chat_message_entity.dart';

class DatabaseService {
  static late Isar isar;

  static Future<void> initialize() async {
    final dir = await getApplicationDocumentsDirectory();
    isar = Isar.open(
      schemas: [ChatMessageEntitySchema],
      directory: dir.path,
    );
  }
}
