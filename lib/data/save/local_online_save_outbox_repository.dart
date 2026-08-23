import 'local_save_slot.dart';
import 'online_save_outbox_file_repository_stub.dart'
    if (dart.library.html) 'online_save_outbox_file_repository_web.dart'
    if (dart.library.io) 'online_save_outbox_file_repository_io.dart';
import 'online_save_outbox_repository.dart';

OnlineSaveOutboxRepository createDefaultOnlineSaveOutboxRepository({
  required LocalSaveSlot slot,
}) {
  if (slot.isGuest) {
    throw ArgumentError.value(slot, 'slot', '계정 슬롯만 Outbox를 가질 수 있습니다.');
  }
  return FileOnlineSaveOutboxRepository(slot: slot);
}
