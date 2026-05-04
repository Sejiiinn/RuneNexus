// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'game_save_data.dart';
import 'save_repository.dart';

class FileSaveRepository implements SaveRepository {
  static const _key = 'rune_nexus_save_v1';

  @override
  Future<GameSaveData?> load() async {
    final raw = html.window.localStorage[_key];
    if (raw == null) {
      return null;
    }
    try {
      return GameSaveData.fromJson(jsonDecode(raw));
    } on Object {
      return null;
    }
  }

  @override
  Future<void> save(GameSaveData data) async {
    html.window.localStorage[_key] = const JsonEncoder().convert(data.toJson());
  }

  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_key);
  }
}
