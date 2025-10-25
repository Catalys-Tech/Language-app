// ------------------------- Models -------------------------
import 'dart:io';

import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

@HiveType(typeId: 0)
class Recording extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String word;
  @HiveField(2)
  final String letter;
  @HiveField(3)
  final String audioPath;
  @HiveField(4)
  RecordingStatus status;
  @HiveField(5)
  final String langCode;

  Recording({
    required this.word,
    required this.letter,
    required this.audioPath,
    required this.langCode,
    this.status = RecordingStatus.pending,
  }) : id = DateTime.now().millisecondsSinceEpoch.toString();

  static Future<String> getUniqueAudioPath(String word) async {
    final directory = await getApplicationSupportDirectory();
    await Directory(directory.path).create(recursive: true);
    final safe = word.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
    final fileName = 'rec_${safe}_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${directory.path}/$fileName';
  }
}

@HiveType(typeId: 1)
enum RecordingStatus { pending, approved, rejected }

class RecordingStatusAdapter extends TypeAdapter<RecordingStatus> {
  @override
  final int typeId = 1;

  @override
  RecordingStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return RecordingStatus.pending;
      case 1:
        return RecordingStatus.approved;
      case 2:
        return RecordingStatus.rejected;
      default:
        return RecordingStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, RecordingStatus obj) {
    switch (obj) {
      case RecordingStatus.pending:
        writer.writeByte(0);
        break;
      case RecordingStatus.approved:
        writer.writeByte(1);
        break;
      case RecordingStatus.rejected:
        writer.writeByte(2);
        break;
    }
  }
}
