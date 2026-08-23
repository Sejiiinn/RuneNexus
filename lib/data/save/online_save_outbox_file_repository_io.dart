import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'local_save_slot.dart';
import 'online_save_outbox.dart';
import 'online_save_outbox_repository.dart';

class FileOnlineSaveOutboxRepository implements OnlineSaveOutboxRepository {
  FileOnlineSaveOutboxRepository({
    required LocalSaveSlot slot,
    File? file,
    File? backupFile,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _slot = slot,
       _providedFile = file,
       _providedBackupFile = backupFile,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory {
    if (slot.isGuest) {
      throw ArgumentError.value(slot, 'slot', '계정 슬롯만 Outbox를 가질 수 있습니다.');
    }
  }

  final LocalSaveSlot _slot;
  final File? _providedFile;
  final File? _providedBackupFile;
  final Future<Directory> Function() _applicationSupportDirectory;
  Future<_OutboxFiles>? _resolvedFiles;

  @override
  Future<OnlineSaveOutboxState?> load() async {
    final files = await _files();
    final primaryExists = await _existsWithArtifacts(files.primary);
    final primary = await _readValid(files.primary);
    if (primary != null) {
      return primary;
    }
    final backupExists = await _existsWithArtifacts(files.backup);
    final backup = await _readValid(files.backup);
    if (backup != null) {
      await _writeAtomically(files.primary, jsonEncode(backup.toJson()));
      return backup;
    }
    if (primaryExists || backupExists) {
      throw const FormatException('온라인 저장 Outbox가 손상되었습니다.');
    }
    return null;
  }

  @override
  Future<void> save(OnlineSaveOutboxState state) async {
    _validateBinding(state);
    final files = await _files();
    await _recoverInterruptedWrite(files.primary);
    await _recoverInterruptedWrite(files.backup);
    final encoded = jsonEncode(state.toJson());
    final current = await _readRawValid(files.primary);
    if (current != null && current != encoded) {
      await _writeAtomically(files.backup, current);
    }
    await _writeAtomically(files.primary, encoded);
  }

  @override
  Future<void> clear() async {
    final files = await _files();
    await _deleteWithArtifacts(files.primary);
    await _deleteWithArtifacts(files.backup);
  }

  Future<_OutboxFiles> _files() {
    return _resolvedFiles ??= _resolveFiles();
  }

  Future<_OutboxFiles> _resolveFiles() async {
    final provided = _providedFile;
    if (provided != null) {
      return _OutboxFiles(
        primary: provided,
        backup: _providedBackupFile ?? File('${provided.path}.backup'),
      );
    }
    final supportDirectory = await _applicationSupportDirectory();
    final directory = Directory(
      _join(supportDirectory.path, ['saves', 'accounts', _slot.accountId!]),
    );
    return _OutboxFiles(
      primary: File(_join(directory.path, const ['outbox_v1.json'])),
      backup: File(_join(directory.path, const ['outbox_v1.backup.json'])),
    );
  }

  Future<OnlineSaveOutboxState?> _readValid(File file) async {
    final raw = await _readRawValid(file);
    if (raw == null) {
      return null;
    }
    return OnlineSaveOutboxState.fromJson(jsonDecode(raw));
  }

  Future<String?> _readRawValid(File file) async {
    await _recoverInterruptedWrite(file);
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
      final state = OnlineSaveOutboxState.fromJson(jsonDecode(raw));
      if (state == null || state.accountIdBinding != _slot.accountId) {
        return null;
      }
      return raw;
    } on Object {
      return null;
    }
  }

  Future<void> _writeAtomically(File destination, String contents) async {
    await destination.parent.create(recursive: true);
    await _recoverInterruptedWrite(destination);
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    try {
      await temporary.rename(destination.path);
      return;
    } on FileSystemException {
      // Windows의 기존 파일 rename 제한을 위한 교체 경로.
    }

    final displaced = File('${destination.path}.replace');
    if (await displaced.exists()) {
      await displaced.delete();
    }
    if (await destination.exists()) {
      await destination.rename(displaced.path);
    }
    try {
      await temporary.rename(destination.path);
    } on Object {
      if (!await destination.exists() && await displaced.exists()) {
        await displaced.rename(destination.path);
      }
      rethrow;
    }
    if (await displaced.exists()) {
      await displaced.delete();
    }
  }

  Future<void> _recoverInterruptedWrite(File destination) async {
    final temporary = File('${destination.path}.tmp');
    final displaced = File('${destination.path}.replace');
    if (!await destination.exists()) {
      if (await displaced.exists()) {
        await destination.parent.create(recursive: true);
        await displaced.rename(destination.path);
      } else if (await temporary.exists() && await _readableState(temporary)) {
        await destination.parent.create(recursive: true);
        await temporary.rename(destination.path);
      }
    }
    if (await destination.exists()) {
      if (await displaced.exists()) {
        await displaced.delete();
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<bool> _readableState(File file) async {
    try {
      final state = OnlineSaveOutboxState.fromJson(
        jsonDecode(await file.readAsString()),
      );
      return state != null && state.accountIdBinding == _slot.accountId;
    } on Object {
      return false;
    }
  }

  Future<bool> _existsWithArtifacts(File file) async {
    return await file.exists() ||
        await File('${file.path}.tmp').exists() ||
        await File('${file.path}.replace').exists();
  }

  Future<void> _deleteWithArtifacts(File file) async {
    for (final candidate in [
      file,
      File('${file.path}.tmp'),
      File('${file.path}.replace'),
    ]) {
      if (await candidate.exists()) {
        await candidate.delete();
      }
    }
  }

  void _validateBinding(OnlineSaveOutboxState state) {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
  }

  static String _join(String base, List<String> parts) {
    return <String>[base, ...parts].join(Platform.pathSeparator);
  }
}

class _OutboxFiles {
  const _OutboxFiles({required this.primary, required this.backup});

  final File primary;
  final File backup;
}
