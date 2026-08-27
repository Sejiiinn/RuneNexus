// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'local_save_slot.dart';
import 'online_save_outbox.dart';
import 'online_save_outbox_repository.dart';

class FileOnlineSaveOutboxRepository implements OnlineSaveOutboxRepository {
  FileOnlineSaveOutboxRepository({required LocalSaveSlot slot}) : _slot = slot {
    if (slot.isGuest) {
      throw ArgumentError.value(slot, 'slot', '계정 슬롯만 Outbox를 가질 수 있습니다.');
    }
  }

  final LocalSaveSlot _slot;

  String get _primaryKey => 'rune_nexus:outbox:${_slot.namespace}';
  String get _backupKey => '$_primaryKey:backup';

  @override
  Future<OnlineSaveOutboxState?> load() async {
    final storage = html.window.localStorage;
    final primaryRaw = storage[_primaryKey];
    final primary = _decode(primaryRaw);
    if (primary != null) {
      return primary;
    }
    final backupRaw = storage[_backupKey];
    final backup = _decode(backupRaw);
    if (backup != null) {
      storage[_primaryKey] = backupRaw!;
      return backup;
    }
    if (primaryRaw != null || backupRaw != null) {
      throw const FormatException('온라인 저장 Outbox가 손상되었습니다.');
    }
    return null;
  }

  @override
  Future<void> save(OnlineSaveOutboxState state) async {
    _validateBinding(state);
    final storage = html.window.localStorage;
    final currentRaw = storage[_primaryKey];
    if (_decode(currentRaw) != null) {
      storage[_backupKey] = currentRaw!;
    }
    storage[_primaryKey] = jsonEncode(state.toJson());
  }

  @override
  Future<void> clear() async {
    final storage = html.window.localStorage;
    storage.remove(_primaryKey);
    storage.remove(_backupKey);
  }

  OnlineSaveOutboxState? _decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final state = OnlineSaveOutboxState.fromJson(jsonDecode(raw));
      if (state == null || state.accountIdBinding != _slot.accountId) {
        return null;
      }
      return state;
    } on FormatException {
      return null;
    }
  }

  void _validateBinding(OnlineSaveOutboxState state) {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
  }
}
