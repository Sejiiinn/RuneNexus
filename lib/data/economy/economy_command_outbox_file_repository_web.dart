// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import '../save/local_save_slot.dart';
import 'economy_command_outbox.dart';
import 'economy_command_outbox_repository.dart';

class FileEconomyCommandOutboxRepository
    implements EconomyCommandOutboxRepository {
  FileEconomyCommandOutboxRepository({required LocalSaveSlot slot})
    : _slot = slot;

  final LocalSaveSlot _slot;

  String get _key => 'rune_nexus:economy_outbox:${_slot.namespace}';
  String get _backupKey => '$_key:backup';

  @override
  Future<EconomyCommandOutboxState?> load() async {
    final storage = html.window.localStorage;
    final primary = _decode(storage[_key]);
    if (primary != null) {
      return primary;
    }
    final backupRaw = storage[_backupKey];
    final backup = _decode(backupRaw);
    if (backup != null) {
      storage[_key] = backupRaw!;
      return backup;
    }
    if (storage[_key] != null || backupRaw != null) {
      throw const FormatException('경제 명령 Outbox가 손상되었습니다.');
    }
    return null;
  }

  @override
  Future<void> save(EconomyCommandOutboxState state) async {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('경제 Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
    final storage = html.window.localStorage;
    final current = storage[_key];
    if (_decode(current) != null) {
      storage[_backupKey] = current!;
    }
    storage[_key] = jsonEncode(state.toJson());
  }

  EconomyCommandOutboxState? _decode(String? raw) {
    if (raw == null) {
      return null;
    }
    try {
      final state = EconomyCommandOutboxState.fromJson(jsonDecode(raw));
      return state?.accountIdBinding == _slot.accountId ? state : null;
    } on FormatException {
      return null;
    }
  }
}
