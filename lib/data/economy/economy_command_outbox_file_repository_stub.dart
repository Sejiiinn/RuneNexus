import '../save/local_save_slot.dart';
import 'economy_command_outbox.dart';
import 'economy_command_outbox_repository.dart';

class FileEconomyCommandOutboxRepository
    implements EconomyCommandOutboxRepository {
  FileEconomyCommandOutboxRepository({required LocalSaveSlot slot})
    : _slot = slot;

  final LocalSaveSlot _slot;
  EconomyCommandOutboxState? _state;

  @override
  Future<EconomyCommandOutboxState?> load() async => _state;

  @override
  Future<void> save(EconomyCommandOutboxState state) async {
    if (state.accountIdBinding != _slot.accountId) {
      throw StateError('경제 Outbox와 저장 슬롯의 계정이 일치하지 않습니다.');
    }
    _state = state;
  }
}
