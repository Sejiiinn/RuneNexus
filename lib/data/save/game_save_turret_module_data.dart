part of 'game_save_data.dart';

class SavedTurretModuleInventory {
  const SavedTurretModuleInventory({
    this.tickets = 0,
    this.drawCount = 0,
    this.ticketPurchaseCount = 0,
    this.itemSequence = 0,
    this.items = const [],
  });

  static const empty = SavedTurretModuleInventory();

  final int tickets;
  final int drawCount;
  final int ticketPurchaseCount;
  final int itemSequence;
  final List<SavedTurretModule> items;

  Map<String, Object?> toJson() {
    return {
      'tickets': tickets,
      'drawCount': drawCount,
      'ticketPurchaseCount': ticketPurchaseCount,
      'itemSequence': itemSequence,
      'items': items.map((module) => module.toJson()).toList(),
    };
  }

  static SavedTurretModuleInventory fromJson(Object? json) {
    return _fromJson(json, legacyProgressionKeys: false);
  }

  static SavedTurretModuleInventory fromLegacyProgressionJson(Object? json) {
    return _fromJson(json, legacyProgressionKeys: true);
  }

  static SavedTurretModuleInventory _fromJson(
    Object? json, {
    required bool legacyProgressionKeys,
  }) {
    final map = json is Map<String, Object?> ? json : const <String, Object?>{};
    final ticketsKey = legacyProgressionKeys
        ? 'turretModuleTickets'
        : 'tickets';
    final drawCountKey = legacyProgressionKeys
        ? 'turretModuleDrawCount'
        : 'drawCount';
    final ticketPurchaseCountKey = legacyProgressionKeys
        ? 'turretModuleTicketPurchaseCount'
        : 'ticketPurchaseCount';
    final itemSequenceKey = legacyProgressionKeys
        ? 'turretModuleItemSequence'
        : 'itemSequence';
    final itemsKey = legacyProgressionKeys ? 'ownedTurretModules' : 'items';
    final itemSequence = _nonNegativeInt(map[itemSequenceKey]);
    final drawCount = map.containsKey(drawCountKey)
        ? _nonNegativeInt(map[drawCountKey])
        : itemSequence;

    return SavedTurretModuleInventory(
      tickets: _intValue(map[ticketsKey]),
      drawCount: drawCount,
      ticketPurchaseCount: map.containsKey(ticketPurchaseCountKey)
          ? _nonNegativeInt(map[ticketPurchaseCountKey])
          : drawCount,
      itemSequence: itemSequence,
      items: _objectList(map[itemsKey], SavedTurretModule.fromJson),
    );
  }
}

class SavedTurretModule {
  const SavedTurretModule({
    required this.id,
    required this.turretType,
    required this.part,
    required this.family,
    required this.grade,
    required this.options,
    required this.acquiredOrder,
    required this.equipped,
  });

  final String id;
  final TurretType turretType;
  final TurretModulePart part;
  final TurretModuleFamily family;
  final TurretModuleGrade grade;
  final List<SavedTurretModuleOption> options;
  final int acquiredOrder;
  final bool equipped;

  TurretModuleKey get key {
    return TurretModuleKey(
      turretType: turretType,
      part: part,
      family: family,
      grade: grade,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'turretType': turretType.name,
      'part': part.name,
      'family': family.name,
      'grade': grade.name,
      'options': options.map((option) => option.toJson()).toList(),
      'acquiredOrder': acquiredOrder,
      'equipped': equipped,
    };
  }

  static SavedTurretModule? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final id = _stringValue(json['id']);
    final turretType = _enumValue(TurretType.values, json['turretType']);
    final part = _enumValue(TurretModulePart.values, json['part']);
    final family = _enumValue(TurretModuleFamily.values, json['family']);
    final grade = _enumValue(TurretModuleGrade.values, json['grade']);
    final options = _objectList(
      json['options'],
      SavedTurretModuleOption.fromJson,
    );
    if (id == null ||
        turretType == null ||
        part == null ||
        family == null ||
        grade == null ||
        options.isEmpty) {
      return null;
    }
    return SavedTurretModule(
      id: id,
      turretType: turretType,
      part: part,
      family: family,
      grade: grade,
      options: List.unmodifiable(options),
      acquiredOrder: _intValue(json['acquiredOrder']),
      equipped: _boolValue(json['equipped']),
    );
  }
}

class SavedTurretModuleOption {
  const SavedTurretModuleOption({required this.type, required this.value});

  final TurretModuleOptionType type;
  final int value;

  Map<String, Object?> toJson() {
    return {'type': type.name, 'value': value};
  }

  static SavedTurretModuleOption? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final type = _enumValue(TurretModuleOptionType.values, json['type']);
    if (type == null) {
      return null;
    }
    return SavedTurretModuleOption(type: type, value: _intValue(json['value']));
  }
}
