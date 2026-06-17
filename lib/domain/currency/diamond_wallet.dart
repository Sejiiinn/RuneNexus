import 'dart:math' as math;

class DiamondWallet {
  DiamondWallet({int free = 0, int paid = 0})
    : _free = math.max(0, free),
      _paid = math.max(0, paid);

  int _free;
  int _paid;

  int get free => _free;
  set free(int value) {
    _free = math.max(0, value);
  }

  int get paid => _paid;
  set paid(int value) {
    _paid = math.max(0, value);
  }

  int get total => _free + _paid;

  bool canSpend(int amount) {
    return amount >= 0 && total >= amount;
  }

  void addFree(int amount) {
    if (amount <= 0) {
      return;
    }
    _free += amount;
  }

  void setBalances({required int free, required int paid}) {
    this.free = free;
    this.paid = paid;
  }

  DiamondSpendResult? spend(int amount) {
    if (!canSpend(amount)) {
      return null;
    }

    final freeSpent = math.min(_free, amount);
    final paidSpent = amount - freeSpent;
    _free -= freeSpent;
    _paid -= paidSpent;
    return DiamondSpendResult(
      amount: amount,
      freeSpent: freeSpent,
      paidSpent: paidSpent,
    );
  }
}

class DiamondSpendResult {
  const DiamondSpendResult({
    required this.amount,
    required this.freeSpent,
    required this.paidSpent,
  });

  final int amount;
  final int freeSpent;
  final int paidSpent;
}
