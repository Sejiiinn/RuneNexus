import '../save/local_save_slot.dart';
import 'economy_command_outbox_file_repository_stub.dart'
    if (dart.library.html) 'economy_command_outbox_file_repository_web.dart'
    if (dart.library.io) 'economy_command_outbox_file_repository_io.dart';
import 'economy_command_outbox_repository.dart';

EconomyCommandOutboxRepository createDefaultEconomyCommandOutboxRepository({
  required LocalSaveSlot slot,
}) {
  if (slot.isGuest) {
    throw ArgumentError.value(slot, 'slot', '계정 슬롯만 경제 Outbox를 가질 수 있습니다.');
  }
  return FileEconomyCommandOutboxRepository(slot: slot);
}
