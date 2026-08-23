import 'save_repository.dart';

abstract interface class BackupSaveRepository implements SaveRepository {
  Future<void> preserveCurrentAsBackup();
}
