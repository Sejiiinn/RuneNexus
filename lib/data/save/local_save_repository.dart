import 'file_save_repository_stub.dart'
    if (dart.library.html) 'file_save_repository_web.dart'
    if (dart.library.io) 'file_save_repository_io.dart';
import 'save_repository.dart';

SaveRepository createDefaultSaveRepository() {
  return FileSaveRepository();
}
