import 'dart:convert';
import 'dart:io';

import 'game_save_data.dart';
import 'save_repository.dart';

class FileSaveRepository implements SaveRepository {
  FileSaveRepository({File? file}) : _file = file ?? _defaultSaveFile();

  final File _file;

  @override
  Future<GameSaveData?> load() async {
    if (!await _file.exists()) {
      return null;
    }
    try {
      final raw = await _file.readAsString();
      return GameSaveData.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(GameSaveData data) async {
    await _file.parent.create(recursive: true);
    final json = const JsonEncoder().convert(data.toJson());
    await _file.writeAsString(json, flush: true);
  }

  @override
  Future<void> clear() async {
    if (await _file.exists()) {
      await _file.delete();
    }
  }

  static File _defaultSaveFile() {
    final directory = Directory.systemTemp;
    return File(
      '${directory.path}${Platform.pathSeparator}rune_nexus_save_v1.json',
    );
  }
}
