import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../save/local_save_slot.dart';
import 'economy_command_outbox.dart';
import 'economy_command_outbox_repository.dart';

class FileEconomyCommandOutboxRepository
    implements EconomyCommandOutboxRepository {
  FileEconomyCommandOutboxRepository({
    required LocalSaveSlot slot,
    File? file,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _slot = slot,
       _providedFile = file,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final LocalSaveSlot _slot;
  final File? _providedFile;
  final Future<Directory> Function() _applicationSupportDirectory;
  Future<File>? _resolvedFile;

  @override
  Future<EconomyCommandOutboxState?> load() async {
    final file = await _file();
    final primaryExists = await _existsWithArtifacts(file);
    final primary = await _read(file);
    if (primary != null) {
      return primary;
    }
    final backupFile = File('${file.path}.backup');
    final backupExists = await _existsWithArtifacts(backupFile);
    final backup = await _read(backupFile);
    if (backup != null) {
      await _write(file, jsonEncode(backup.toJson()));
      return backup;
    }
    if (primaryExists || backupExists) {
      throw const FormatException('경제 명령 Outbox가 손상되었습니다.');
    }
    return null;
  }

  @override
  Future<void> save(EconomyCommandOutboxState state) async {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('경제 Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
    final file = await _file();
    if (await _read(file) != null) {
      await _write(File('${file.path}.backup'), await file.readAsString());
    }
    await _write(file, jsonEncode(state.toJson()));
  }

  Future<File> _file() => _resolvedFile ??= _resolveFile();

  Future<File> _resolveFile() async {
    if (_providedFile != null) {
      return _providedFile;
    }
    final support = await _applicationSupportDirectory();
    return File(
      [
        support.path,
        'saves',
        'accounts',
        _slot.accountId!,
        'economy_outbox.json',
      ].join(Platform.pathSeparator),
    );
  }

  Future<EconomyCommandOutboxState?> _read(File file) async {
    await _recoverInterruptedWrite(file);
    if (!await file.exists()) {
      return null;
    }
    try {
      final state = EconomyCommandOutboxState.fromJson(
        jsonDecode(await file.readAsString()),
      );
      return state?.accountIdBinding == _slot.accountId ? state : null;
    } on Object {
      return null;
    }
  }

  Future<void> _write(File file, String contents) async {
    await file.parent.create(recursive: true);
    await _recoverInterruptedWrite(file);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(contents, flush: true);
    try {
      await temporary.rename(file.path);
      return;
    } on FileSystemException {
      // Windows의 기존 파일 rename 제한을 위한 교체 경로.
    }
    final displaced = File('${file.path}.replace');
    if (await displaced.exists()) {
      await displaced.delete();
    }
    if (await file.exists()) {
      await file.rename(displaced.path);
    }
    try {
      await temporary.rename(file.path);
    } on Object {
      if (!await file.exists() && await displaced.exists()) {
        await displaced.rename(file.path);
      }
      rethrow;
    }
    if (await displaced.exists()) {
      await displaced.delete();
    }
  }

  Future<void> _recoverInterruptedWrite(File file) async {
    final temporary = File('${file.path}.tmp');
    final displaced = File('${file.path}.replace');
    if (!await file.exists()) {
      if (await displaced.exists()) {
        await file.parent.create(recursive: true);
        await displaced.rename(file.path);
      } else if (await temporary.exists() && await _isReadable(temporary)) {
        await file.parent.create(recursive: true);
        await temporary.rename(file.path);
      }
    }
    if (await file.exists()) {
      if (await displaced.exists()) {
        await displaced.delete();
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
    }
  }

  Future<bool> _isReadable(File file) async {
    try {
      final state = EconomyCommandOutboxState.fromJson(
        jsonDecode(await file.readAsString()),
      );
      return state != null && state.accountIdBinding == _slot.accountId;
    } on Object {
      return false;
    }
  }

  Future<bool> _existsWithArtifacts(File file) async =>
      await file.exists() ||
      await File('${file.path}.tmp').exists() ||
      await File('${file.path}.replace').exists();
}
