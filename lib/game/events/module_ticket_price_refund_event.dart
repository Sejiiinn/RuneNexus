import '../systems/run_progression.dart';

abstract final class ModuleTicketPriceRefundEvent {
  static const String id = 'module_ticket_price_refund_2026_08_05';
  static const int refundDiamondsPerTicket = 40;

  // 2026-08-06 00:00 KST부터 지급 종료.
  static final int claimDeadlineExclusiveMillis = DateTime.utc(
    2026,
    8,
    5,
    15,
  ).millisecondsSinceEpoch;

  static bool apply({
    required RunProgression progression,
    required int nowMillis,
  }) {
    if (nowMillis >= claimDeadlineExclusiveMillis ||
        !progression.claimedEventIds.add(id)) {
      return false;
    }

    progression.addFreeDiamonds(
      progression.turretModuleTicketPurchaseCount * refundDiamondsPerTicket,
    );
    return true;
  }
}
