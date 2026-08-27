import 'game_save_data.dart';
import 'save_repository.dart';

abstract interface class BackupSaveRepository implements SaveRepository {
  Future<void> preserveCurrentAsBackup();

  Future<void> preserveConflictBackup(ConflictSaveBackup backup);
}

class ConflictSaveBackup {
  const ConflictSaveBackup({
    required this.rebaseId,
    required this.accountId,
    required this.baseRevision,
    required this.targetRevision,
    required this.localPayloadHash,
    required this.createdAt,
    required this.data,
  });

  static const currentVersion = 1;

  final String rebaseId;
  final String accountId;
  final int baseRevision;
  final int targetRevision;
  final String localPayloadHash;
  final DateTime createdAt;
  final GameSaveData data;

  Map<String, Object?> toJson() {
    return {
      'version': currentVersion,
      'rebaseId': rebaseId,
      'accountId': accountId,
      'baseRevision': baseRevision,
      'targetRevision': targetRevision,
      'localPayloadHash': localPayloadHash,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'data': data.toJson(),
    };
  }
}
