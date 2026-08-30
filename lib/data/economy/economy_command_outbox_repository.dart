import 'economy_command_outbox.dart';

abstract interface class EconomyCommandOutboxRepository {
  Future<EconomyCommandOutboxState?> load();
  Future<void> save(EconomyCommandOutboxState state);
}

class MemoryEconomyCommandOutboxRepository
    implements EconomyCommandOutboxRepository {
  EconomyCommandOutboxState? state;

  @override
  Future<EconomyCommandOutboxState?> load() async => state;

  @override
  Future<void> save(EconomyCommandOutboxState state) async {
    this.state = state;
  }
}
