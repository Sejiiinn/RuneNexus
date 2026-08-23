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
  OnlineSaveOutboxState? _state;

  @override
  Future<OnlineSaveOutboxState?> load() async => _state;

  @override
  Future<void> save(OnlineSaveOutboxState state) async {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
    _state = state;
  }

  @override
  Future<void> clear() async {
    _state = null;
  }
}
