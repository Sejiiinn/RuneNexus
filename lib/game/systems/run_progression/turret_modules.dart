part of '../run_progression.dart';

mixin _TurretModuleProgression {
  DiamondSpendResult? spendDiamonds(int amount);
  void addFreeDiamonds(int amount);

  int turretModuleTickets = 0;
  int lastRunTurretModuleTicketReward = 0;
  int turretModuleDrawCount = 0;
  int turretModuleTicketPurchaseCount = 0;
  int turretModuleItemSequence = 0;
  final Map<String, TurretModuleInventoryItem> turretModules =
      _TurretModuleInventory();

  List<TurretModuleInventoryItem> get ownedTurretModules {
    final items = turretModules.values.toList()
      ..sort(_compareTurretModuleItems);
    return List.unmodifiable(items);
  }

  SavedTurretModuleInventory toTurretModuleSaveData() {
    return SavedTurretModuleInventory(
      tickets: turretModuleTickets,
      drawCount: turretModuleDrawCount,
      ticketPurchaseCount: turretModuleTicketPurchaseCount,
      itemSequence: turretModuleItemSequence,
      items: List.unmodifiable(
        ownedTurretModules.map(
          (module) => SavedTurretModule(
            id: module.id,
            turretType: module.key.turretType,
            part: module.key.part,
            family: module.key.family,
            grade: module.key.grade,
            options: List.unmodifiable(
              module.options.map(
                (option) => SavedTurretModuleOption(
                  type: option.type,
                  value: option.value,
                ),
              ),
            ),
            acquiredOrder: module.acquiredOrder,
            equipped: module.equipped,
          ),
        ),
      ),
    );
  }

  void restoreTurretModulesFromSaveData(SavedTurretModuleInventory data) {
    turretModuleTickets = math.max(0, data.tickets);
    turretModuleDrawCount = math.max(0, data.drawCount);
    turretModuleTicketPurchaseCount = math.max(0, data.ticketPurchaseCount);
    turretModuleItemSequence = math.max(0, data.itemSequence);
    turretModules
      ..clear()
      ..addEntries(
        data.items
            .where(
              (module) => gameTurretModuleDefinitions.containsKey(module.key),
            )
            .map(
              (module) => MapEntry(
                module.id,
                TurretModuleInventoryItem(
                  id: module.id,
                  key: module.key,
                  options: List.unmodifiable(
                    _sanitizeTurretModuleOptions(
                      module.key,
                      module.options.map(
                        (option) => TurretModuleOptionRoll(
                          type: option.type,
                          value: option.value,
                        ),
                      ),
                    ),
                  ),
                  acquiredOrder: math.max(0, module.acquiredOrder),
                  equipped: module.equipped,
                ),
              ),
            ),
      );
    _sanitizeTurretModules();
  }

  TurretModuleInventoryItem? turretModuleFor(String id) {
    return turretModules[id];
  }

  TurretModuleInventoryItem? equippedTurretModuleFor(
    TurretType turretType,
    TurretModulePart part,
  ) {
    for (final item in turretModules.values) {
      if (item.equipped &&
          item.key.turretType == turretType &&
          item.key.part == part) {
        return item;
      }
    }
    return null;
  }

  TurretModuleEffect turretModuleEffectFor(TurretType turretType) {
    return (turretModules as _TurretModuleInventory).effectFor(turretType);
  }

  List<TurretModuleInventoryItem> drawTurretModules({
    required int count,
    required List<TurretType> availableTurretTypes,
    bool buyMissingTicketsWithDiamonds = false,
    math.Random? random,
  }) {
    if (count <= 0) {
      return const [];
    }
    final turretPool = availableTurretTypes
        .where(
          (type) => gameTurretModuleDefinitions.keys.any(
            (key) => key.turretType == type,
          ),
        )
        .toList(growable: false);
    if (turretPool.isEmpty) {
      return const [];
    }
    final missingTickets = math.max(0, count - turretModuleTickets);
    if (missingTickets > 0) {
      if (!buyMissingTicketsWithDiamonds) {
        return const [];
      }
      final ticketCost =
          missingTickets * RunProgression.turretModuleTicketDiamondCost;
      if (spendDiamonds(ticketCost) == null) {
        return const [];
      }
      turretModuleTicketPurchaseCount += missingTickets;
      turretModuleTickets += missingTickets;
    }

    final rollRandom = random ?? math.Random();
    turretModuleTickets -= count;
    final results = <TurretModuleInventoryItem>[];
    for (var i = 0; i < count; i++) {
      final turretType = turretPool[rollRandom.nextInt(turretPool.length)];
      final part = TurretModulePart
          .values[rollRandom.nextInt(TurretModulePart.values.length)];
      final grade = _rollTurretModuleGrade(rollRandom);
      final key = TurretModuleKey(
        turretType: turretType,
        part: part,
        family: turretModuleFamilyFor(turretType, part),
        grade: grade,
      );
      results.add(
        grantTurretModule(
          key,
          options: rollTurretModuleOptions(
            turretType: turretType,
            part: part,
            grade: grade,
            random: rollRandom,
          ),
        ),
      );
      turretModuleDrawCount += 1;
    }
    return List.unmodifiable(results);
  }

  TurretModuleInventoryItem grantTurretModule(
    TurretModuleKey key, {
    List<TurretModuleOptionRoll>? options,
  }) {
    final id = _createTurretModuleItemId();
    final itemOptions = List<TurretModuleOptionRoll>.unmodifiable(
      _sanitizeTurretModuleOptions(
        key,
        options ?? minimumTurretModuleOptionsFor(key),
      ),
    );
    if (!gameTurretModuleDefinitions.containsKey(key)) {
      return TurretModuleInventoryItem(
        id: id,
        key: key,
        options: itemOptions,
        acquiredOrder: turretModuleItemSequence,
        equipped: false,
      );
    }
    turretModules[id] = TurretModuleInventoryItem(
      id: id,
      key: key,
      options: itemOptions,
      acquiredOrder: turretModuleItemSequence,
      equipped: false,
    );
    _sanitizeTurretModules();
    return turretModules[id]!;
  }

  bool equipTurretModule(String id) {
    final item = turretModules[id];
    if (item == null) {
      return false;
    }
    for (final entry in turretModules.entries.toList()) {
      final candidate = entry.value;
      if (candidate.key.turretType != item.key.turretType ||
          candidate.key.part != item.key.part) {
        continue;
      }
      turretModules[entry.key] = candidate.copyWith(
        equipped: candidate.id == id,
      );
    }
    _sanitizeTurretModules();
    return true;
  }

  bool unequipTurretModule(String id) {
    final item = turretModules[id];
    if (item == null || !item.equipped) {
      return false;
    }
    turretModules[id] = item.copyWith(equipped: false);
    _sanitizeTurretModules();
    return true;
  }

  bool disassembleTurretModule(String id) {
    final item = turretModules[id];
    if (item == null ||
        item.equipped ||
        item.key.grade == TurretModuleGrade.unique) {
      return false;
    }
    turretModules.remove(id);
    addFreeDiamonds(item.key.grade.disassembleDiamondValue);
    return true;
  }

  int disassembleTurretModules(Iterable<String> ids) {
    var disassembledCount = 0;
    var returnDiamonds = 0;
    for (final id in ids.toSet()) {
      final item = turretModules[id];
      if (item == null ||
          item.equipped ||
          item.key.grade == TurretModuleGrade.unique) {
        continue;
      }
      turretModules.remove(id);
      disassembledCount += 1;
      returnDiamonds += item.key.grade.disassembleDiamondValue;
    }
    addFreeDiamonds(returnDiamonds);
    return disassembledCount;
  }

  TurretModuleGrade _rollTurretModuleGrade(math.Random random) {
    final buildLevel = turretModuleBuildLevelForDrawCount(
      turretModuleDrawCount,
    );
    final roll = random.nextInt(100);
    final uniqueThreshold = buildLevel.rateFor(TurretModuleGrade.unique);
    if (roll < uniqueThreshold) {
      return TurretModuleGrade.unique;
    }
    final rareThreshold =
        uniqueThreshold + buildLevel.rateFor(TurretModuleGrade.rare);
    if (roll < rareThreshold) {
      return TurretModuleGrade.rare;
    }
    final magicThreshold =
        rareThreshold + buildLevel.rateFor(TurretModuleGrade.magic);
    if (roll < magicThreshold) {
      return TurretModuleGrade.magic;
    }
    return TurretModuleGrade.normal;
  }

  void _sanitizeTurretModules() {
    final equippedParts = <String, String>{};
    for (final entry in turretModules.entries.toList()) {
      final item = entry.value;
      final options = _sanitizeTurretModuleOptions(item.key, item.options);
      if (!gameTurretModuleDefinitions.containsKey(item.key) ||
          entry.key.isEmpty ||
          item.id != entry.key ||
          options.isEmpty) {
        turretModules.remove(entry.key);
        continue;
      }
      final sanitized = item.copyWith(options: List.unmodifiable(options));
      turretModules[entry.key] = sanitized;
      turretModuleItemSequence = math.max(
        turretModuleItemSequence,
        sanitized.acquiredOrder,
      );
      if (!sanitized.equipped) {
        continue;
      }
      final slotKey =
          '${sanitized.key.turretType.name}:${sanitized.key.part.name}';
      final previous = equippedParts[slotKey];
      if (previous != null) {
        turretModules[entry.key] = sanitized.copyWith(equipped: false);
        continue;
      }
      equippedParts[slotKey] = sanitized.id;
    }
  }

  String _createTurretModuleItemId() {
    do {
      turretModuleItemSequence++;
    } while (turretModules.containsKey('tm_$turretModuleItemSequence'));
    return 'tm_$turretModuleItemSequence';
  }
}

// 공개 Map의 직접 수정도 추적하는 모듈 효과 캐시.
class _TurretModuleInventory
    extends MapBase<String, TurretModuleInventoryItem> {
  final _items = <String, TurretModuleInventoryItem>{};
  final _effects = <TurretType, _CachedTurretModuleEffect>{};

  @override
  TurretModuleInventoryItem? operator [](Object? key) => _items[key];

  @override
  void operator []=(String key, TurretModuleInventoryItem value) {
    _items[key] = value;
    _effects.clear();
  }

  @override
  Iterable<String> get keys => _items.keys;

  @override
  int get length => _items.length;

  @override
  void clear() {
    _items.clear();
    _effects.clear();
  }

  @override
  TurretModuleInventoryItem? remove(Object? key) {
    final removed = _items.remove(key);
    if (removed != null) {
      _effects.clear();
    }
    return removed;
  }

  TurretModuleEffect effectFor(TurretType type) {
    final cached = _effects[type];
    if (cached != null && cached.hasCurrentOptions) {
      return cached.effect;
    }
    final equipped = _items.values
        .where((item) => item.equipped && item.key.turretType == type)
        .toList(growable: false);
    final result = _CachedTurretModuleEffect(equipped);
    _effects[type] = result;
    return result.effect;
  }
}

class _CachedTurretModuleEffect {
  _CachedTurretModuleEffect(this.items)
    : options = [for (final item in items) List.of(item.options)],
      effect = items.fold(
        TurretModuleEffect.zero,
        (effect, item) => effect + effectiveTurretModuleEffect(item),
      );

  final List<TurretModuleInventoryItem> items;
  final List<List<TurretModuleOptionRoll>> options;
  final TurretModuleEffect effect;

  bool get hasCurrentOptions {
    // 외부에서 전달한 가변 옵션 목록은 장착 항목만 비교.
    for (var i = 0; i < items.length; i++) {
      final current = items[i].options;
      final previous = options[i];
      if (current.length != previous.length) {
        return false;
      }
      for (var j = 0; j < current.length; j++) {
        if (!identical(current[j], previous[j])) {
          return false;
        }
      }
    }
    return true;
  }
}

int _compareTurretModuleItems(
  TurretModuleInventoryItem a,
  TurretModuleInventoryItem b,
) {
  final turretCompare = a.key.turretType.index.compareTo(
    b.key.turretType.index,
  );
  if (turretCompare != 0) {
    return turretCompare;
  }
  final gradeCompare = b.key.grade.order.compareTo(a.key.grade.order);
  if (gradeCompare != 0) {
    return gradeCompare;
  }
  final optionCountCompare = b.options.length.compareTo(a.options.length);
  if (optionCountCompare != 0) {
    return optionCountCompare;
  }
  final acquiredCompare = b.acquiredOrder.compareTo(a.acquiredOrder);
  if (acquiredCompare != 0) {
    return acquiredCompare;
  }
  return a.key.part.index.compareTo(b.key.part.index);
}

List<TurretModuleOptionRoll> _sanitizeTurretModuleOptions(
  TurretModuleKey key,
  Iterable<TurretModuleOptionRoll> options,
) {
  final pool = turretModuleOptionPoolFor(key.turretType, key.part).toSet();
  final seen = <TurretModuleOptionType>{};
  final sanitized = <TurretModuleOptionRoll>[];
  for (final option in options) {
    if (!pool.contains(option.type) || !seen.add(option.type)) {
      continue;
    }
    final range = turretModuleOptionRollRanges[option.type]?[key.grade];
    if (range == null) {
      continue;
    }
    sanitized.add(
      TurretModuleOptionRoll(
        type: option.type,
        value: option.value.clamp(range.min, range.max).toInt(),
      ),
    );
  }
  return sanitized;
}
