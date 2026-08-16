// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'save_repository.dart';

class FileSaveRepository implements SaveRepository {
  FileSaveRepository({LocalSaveSlot slot = LocalSaveSlot.guest}) : _slot = slot;

  static const _legacyGuestKey = 'rune_nexus_save_v1';

  final LocalSaveSlot _slot;

  String get _primaryKey => 'rune_nexus:save:v2:${_slot.namespace}:primary';
  String get _backupKey => 'rune_nexus:save:v2:${_slot.namespace}:backup';

  @override
  Future<GameSaveData?> load() async {
    final primary = _decode(html.window.localStorage[_primaryKey]);
    if (primary != null) {
      if (!primary.isCanonical) {
        await save(primary.data);
      }
      return primary.data;
    }

    final backup = _decode(html.window.localStorage[_backupKey]);
    if (backup != null) {
      await save(backup.data);
      return backup.data;
    }

    if (!_slot.isGuest) {
      return null;
    }
    final legacy = _decode(html.window.localStorage[_legacyGuestKey]);
    if (legacy == null) {
      return null;
    }
    await save(legacy.data);
    return legacy.data;
  }

  @override
  Future<void> save(GameSaveData data) async {
    final storage = html.window.localStorage;
    final currentRaw = storage[_primaryKey];
    if (_decode(currentRaw) != null) {
      storage[_backupKey] = currentRaw!;
    }
    storage[_primaryKey] = const JsonEncoder().convert(data.toJson());
  }

  @override
  Future<void> clear() async {
    final storage = html.window.localStorage;
    storage.remove(_primaryKey);
    storage.remove(_backupKey);
    if (_slot.isGuest) {
      storage.remove(_legacyGuestKey);
    }
  }

  _DecodedSave? _decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      final data = GameSaveData.fromJson(json);
      if (data == null) {
        return null;
      }
      return _DecodedSave(
        data: data,
        isCanonical: GameSaveData.isCanonicalVersion2Envelope(json),
      );
    } on Object {
      return null;
    }
  }
}

class _DecodedSave {
  const _DecodedSave({required this.data, required this.isCanonical});

  final GameSaveData data;
  final bool isCanonical;
}
