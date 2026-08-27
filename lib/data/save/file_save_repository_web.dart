// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'backup_save_repository.dart';
import 'game_save_data.dart';
import 'local_save_slot.dart';

class FileSaveRepository implements BackupSaveRepository {
  FileSaveRepository({LocalSaveSlot slot = LocalSaveSlot.guest}) : _slot = slot;

  static const _legacyGuestKey = 'rune_nexus_save_v1';

  final LocalSaveSlot _slot;

  String get _primaryKey => 'rune_nexus:save:v2:${_slot.namespace}:primary';
  String get _backupKey => 'rune_nexus:save:v2:${_slot.namespace}:backup';
  String get _conflictBackupKey =>
      'rune_nexus:save:v2:${_slot.namespace}:conflict';

  @override
  Future<GameSaveData?> load() async {
    final primary = _decode(html.window.localStorage[_primaryKey]);
    if (primary != null) {
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
    final legacy = _decode(
      html.window.localStorage[_legacyGuestKey],
      legacyV1Only: true,
    );
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
  Future<void> preserveCurrentAsBackup() async {
    final storage = html.window.localStorage;
    final currentRaw = storage[_primaryKey];
    if (_decode(currentRaw) != null) {
      storage[_backupKey] = currentRaw!;
    }
  }

  @override
  Future<void> preserveConflictBackup(ConflictSaveBackup backup) async {
    final storage = html.window.localStorage;
    final existingRaw = storage[_conflictBackupKey];
    if (_conflictBackupRebaseId(existingRaw) == backup.rebaseId) {
      return;
    }
    storage[_conflictBackupKey] = const JsonEncoder().convert(backup.toJson());
  }

  @override
  Future<void> clear() async {
    final storage = html.window.localStorage;
    storage.remove(_primaryKey);
    storage.remove(_backupKey);
    storage.remove(_conflictBackupKey);
    if (_slot.isGuest) {
      storage.remove(_legacyGuestKey);
    }
  }

  _DecodedSave? _decode(String? raw, {bool legacyV1Only = false}) {
    if (raw == null) {
      return null;
    }
    try {
      final json = jsonDecode(raw);
      final isCanonical = GameSaveData.isCanonicalVersion2Envelope(json);
      final isLegacyV1 = json is Map && json['version'] == 1;
      if (legacyV1Only ? !isLegacyV1 : !isCanonical) {
        return null;
      }
      final data = GameSaveData.fromJson(json);
      if (data == null) {
        return null;
      }
      return _DecodedSave(data: data);
    } on Object {
      return null;
    }
  }

  String? _conflictBackupRebaseId(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded['version'] != ConflictSaveBackup.currentVersion ||
          !GameSaveData.isCanonicalVersion2Envelope(decoded['data'])) {
        return null;
      }
      final rebaseId = decoded['rebaseId'];
      return rebaseId is String ? rebaseId : null;
    } on Object {
      return null;
    }
  }
}

class _DecodedSave {
  const _DecodedSave({required this.data});

  final GameSaveData data;
}
