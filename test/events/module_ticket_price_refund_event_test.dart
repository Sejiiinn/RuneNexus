import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/data/save/save_repository.dart';
import 'package:rune_nexus/game/events/module_ticket_price_refund_event.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test('마감 전 접속 시 구매 수당 40다이아를 한 번만 환급한다', () {
    final progression = RunProgression()
      ..turretModuleTicketPurchaseCount = 3
      ..addFreeDiamonds(10);

    expect(
      ModuleTicketPriceRefundEvent.apply(
        progression: progression,
        nowMillis:
            ModuleTicketPriceRefundEvent.claimDeadlineExclusiveMillis - 1,
      ),
      isTrue,
    );
    expect(progression.diamonds, 130);
    expect(
      progression.claimedEventIds,
      contains(ModuleTicketPriceRefundEvent.id),
    );

    expect(
      ModuleTicketPriceRefundEvent.apply(
        progression: progression,
        nowMillis:
            ModuleTicketPriceRefundEvent.claimDeadlineExclusiveMillis - 1,
      ),
      isFalse,
    );
    expect(progression.diamonds, 130);
  });

  test('한국시간 8월 6일 0시부터는 환급하지 않는다', () {
    final progression = RunProgression()..turretModuleTicketPurchaseCount = 3;

    expect(
      ModuleTicketPriceRefundEvent.apply(
        progression: progression,
        nowMillis: ModuleTicketPriceRefundEvent.claimDeadlineExclusiveMillis,
      ),
      isFalse,
    );
    expect(progression.diamonds, 0);
    expect(progression.claimedEventIds, isEmpty);
  });

  test('접속 환급 결과와 처리 이력을 즉시 저장한다', () async {
    final repository = MemorySaveRepository()
      ..data = _saveWithModuleTicketPurchases(2);
    final game = RuneNexusGame(
      saveRepository: repository,
      nowMillisForTesting: () =>
          ModuleTicketPriceRefundEvent.claimDeadlineExclusiveMillis - 1,
    );

    await game.prepareSavedStateForMenu();
    await game.saveNow();

    expect(game.snapshotNotifier.value.diamonds, 80);
    expect(
      repository.data!.progression.claimedEventIds,
      contains(ModuleTicketPriceRefundEvent.id),
    );

    final restored = RuneNexusGame(
      saveRepository: MemorySaveRepository()..data = repository.data,
      nowMillisForTesting: () =>
          ModuleTicketPriceRefundEvent.claimDeadlineExclusiveMillis - 1,
    );
    await restored.prepareSavedStateForMenu();
    expect(restored.snapshotNotifier.value.diamonds, 80);
  });
}

GameSaveData _saveWithModuleTicketPurchases(int purchaseCount) {
  return GameSaveData.fromJson(<String, Object?>{
    'version': GameSaveData.currentVersion,
    'progression': <String, Object?>{
      'turretModuleTicketPurchaseCount': purchaseCount,
    },
  })!;
}
