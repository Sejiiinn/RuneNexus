import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'backup_save_repository.dart';
import 'game_save_data.dart';
import 'local_save_slot.dart';

class FileSaveRepository implements BackupSaveRepository {
  FileSaveRepository({
    File? file,
    File? backupFile,
    File? conflictBackupFile,
    File? legacyFile,
    LocalSaveSlot slot = LocalSaveSlot.guest,
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _providedPrimaryFile = file,
       _providedBackupFile = backupFile,
       _providedConflictBackupFile = conflictBackupFile,
       _providedLegacyFile = legacyFile,
       _slot = slot,
       _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final File? _providedPrimaryFile;
  final File? _providedBackupFile;
  final File? _providedConflictBackupFile;
  final File? _providedLegacyFile;
  final LocalSaveSlot _slot;
  final Future<Directory> Function() _applicationSupportDirectory;

  Future<_SaveFiles>? _resolvedFiles;

  @override
  Future<GameSaveData?> load() async {
    final files = await _files();
    final primary = await _readValid(files.primary);
    if (primary != null) {
      return primary.data;
    }

    final backup = await _readValid(files.backup);
    if (backup != null) {
      await save(backup.data);
      return backup.data;
    }

    final legacyFile = files.legacy;
    if (legacyFile == null) {
      return null;
    }
    final legacy = await _readValid(legacyFile, legacyV1Only: true);
    if (legacy == null) {
      return null;
    }
    await save(legacy.data);
    return legacy.data;
  }

  @override
  Future<void> save(GameSaveData data) async {
    final files = await _files();
    await _recoverInterruptedWrite(files.primary);
    await _recoverInterruptedWrite(files.backup);

    final json = const JsonEncoder().convert(data.toJson());
    final current = await _readValid(files.primary);
    if (current != null && current.raw != json) {
      await _writeAtomically(files.backup, current.raw);
    }
    await _writeAtomically(files.primary, json);
  }

  @override
  Future<void> preserveCurrentAsBackup() async {
    final files = await _files();
    final current = await _readValid(files.primary);
    if (current != null) {
      await _writeAtomically(files.backup, current.raw);
    }
  }

  @override
  Future<void> preserveConflictBackup(ConflictSaveBackup backup) async {
    final files = await _files();
    final existingRebaseId = await _conflictBackupRebaseId(
      files.conflictBackup,
    );
    if (existingRebaseId == backup.rebaseId) {
      return;
    }
    await _writeAtomically(
      files.conflictBackup,
      const JsonEncoder().convert(backup.toJson()),
    );
  }

  @override
  Future<void> clear() async {
    final files = await _files();
    await _deleteWithArtifacts(files.primary);
    await _deleteWithArtifacts(files.backup);
    await _deleteWithArtifacts(files.conflictBackup);
    final legacyFile = files.legacy;
    if (legacyFile != null) {
      await _deleteWithArtifacts(legacyFile);
    }
  }

  Future<_SaveFiles> _files() {
    return _resolvedFiles ??= _resolveFiles();
  }

  Future<_SaveFiles> _resolveFiles() async {
    final providedPrimary = _providedPrimaryFile;
    if (providedPrimary != null) {
      return _SaveFiles(
        primary: providedPrimary,
        backup: _providedBackupFile ?? _backupFor(providedPrimary),
        conflictBackup:
            _providedConflictBackupFile ?? _conflictBackupFor(providedPrimary),
        legacy: _providedLegacyFile,
      );
    }

    final supportDirectory = await _applicationSupportDirectory();
    final slotDirectory = _slot.isGuest
        ? Directory(_join(supportDirectory.path, const ['saves', 'guest']))
        : Directory(
            _join(supportDirectory.path, [
              'saves',
              'accounts',
              _slot.accountId!,
            ]),
          );
    return _SaveFiles(
      primary: File(_join(slotDirectory.path, const ['save_v2.json'])),
      backup: File(_join(slotDirectory.path, const ['save_v2.backup.json'])),
      conflictBackup: File(
        _join(slotDirectory.path, const ['save_v2.conflict.json']),
      ),
      legacy: _slot.isGuest
          ? File(
              _join(Directory.systemTemp.path, const [
                'rune_nexus_save_v1.json',
              ]),
            )
          : null,
    );
  }

  Future<_DecodedSave?> _readValid(
    File file, {
    bool legacyV1Only = false,
  }) async {
    await _recoverInterruptedWrite(file);
    if (!await file.exists()) {
      return null;
    }
    try {
      final raw = await file.readAsString();
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
      return _DecodedSave(data: data, raw: raw);
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
      } else if (await temporary.exists() && await _readableSave(temporary)) {
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

  Future<bool> _readableSave(File file) async {
    try {
      return GameSaveData.fromJson(jsonDecode(await file.readAsString())) !=
          null;
    } on Object {
      return false;
    }
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

  Future<String?> _conflictBackupRebaseId(File file) async {
    await _recoverInterruptedWrite(file);
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
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

  static File _backupFor(File primary) {
    final path = primary.path;
    if (path.endsWith('.json')) {
      return File('${path.substring(0, path.length - 5)}.backup.json');
    }
    return File('$path.backup');
  }

  static File _conflictBackupFor(File primary) {
    final path = primary.path;
    if (path.endsWith('.json')) {
      return File('${path.substring(0, path.length - 5)}.conflict.json');
    }
    return File('$path.conflict');
  }

  static String _join(String base, List<String> parts) {
    return <String>[base, ...parts].join(Platform.pathSeparator);
  }
}

class _SaveFiles {
  const _SaveFiles({
    required this.primary,
    required this.backup,
    required this.conflictBackup,
    required this.legacy,
  });

  final File primary;
  final File backup;
  final File conflictBackup;
  final File? legacy;
}

class _DecodedSave {
  const _DecodedSave({required this.data, required this.raw});

  final GameSaveData data;
  final String raw;
}
