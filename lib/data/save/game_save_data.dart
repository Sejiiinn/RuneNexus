import '../../domain/combat/auto_start_mode.dart';
import '../../domain/combat/game_phase.dart';
import '../../data/definitions/game_core_passive_tree_data.dart' as core_tree;
import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';
import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/research/research_type.dart';
import '../../domain/run_upgrade/run_upgrade_type.dart';
import '../../domain/turret/turret_trait_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret/turret_target_priority.dart';
import '../../domain/turret_module/turret_module_type.dart';

part 'game_save_enemy_data.dart';
part 'game_save_migration.dart';
part 'game_save_progression_data.dart';
part 'game_save_run_data.dart';
part 'game_save_turret_data.dart';
part 'game_save_turret_module_data.dart';

class GameSaveData {
  const GameSaveData({
    required this.savedAtMillis,
    required this.preferences,
    required this.progression,
    required this.turretModules,
    this.activeRun,
  });

  static const currentVersion = 2;

  final int savedAtMillis;
  final SavedPreferences preferences;
  final SavedProgression progression;
  final SavedTurretModuleInventory turretModules;
  final SavedRunState? activeRun;

  int get version => currentVersion;
  bool get hasActiveRun => activeRun != null;

  Map<String, Object?> toJson() {
    return {
      'version': currentVersion,
      'savedAtMillis': savedAtMillis,
      'preferences': preferences.toJson(),
      'progression': progression.toJson(),
      'turretModules': turretModules.toJson(),
      'activeRun': activeRun?.toJson(),
    };
  }

  static GameSaveData? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final version = _intValue(json['version']);
    return switch (version) {
      1 => _gameSaveDataFromVersion1(json),
      currentVersion => _gameSaveDataFromVersion2(json),
      _ => null,
    };
  }

  static GameSaveData _gameSaveDataFromVersion2(Map<String, Object?> json) {
    final progression = SavedProgression.fromJson(json['progression']);
    final turretModules = json['turretModules'] is Map<String, Object?>
        ? SavedTurretModuleInventory.fromJson(json['turretModules'])
        : SavedTurretModuleInventory.fromLegacyProgressionJson(
            json['progression'],
          );
    return GameSaveData(
      savedAtMillis: _intValue(json['savedAtMillis']),
      preferences: SavedPreferences.fromJson(json['preferences']),
      progression: progression,
      turretModules: turretModules,
      activeRun: SavedRunState.fromJson(
        json['activeRun'],
        missingRunCoreCombatSkill: progression.coreCombatSkill,
      ),
    );
  }
}

class SavedCoreCombatSkillStats {
  const SavedCoreCombatSkillStats({
    required this.directDamageDealt,
    required this.bonusDamageDealt,
    required this.activationCount,
  });

  static const empty = SavedCoreCombatSkillStats(
    directDamageDealt: 0,
    bonusDamageDealt: 0,
    activationCount: 0,
  );

  final double directDamageDealt;
  final double bonusDamageDealt;
  final int activationCount;

  Map<String, Object?> toJson() {
    return {
      'directDamageDealt': directDamageDealt,
      'bonusDamageDealt': bonusDamageDealt,
      'activationCount': activationCount,
    };
  }

  static SavedCoreCombatSkillStats fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return empty;
    }
    return SavedCoreCombatSkillStats(
      directDamageDealt: _doubleValue(json['directDamageDealt']),
      bonusDamageDealt: _doubleValue(json['bonusDamageDealt']),
      activationCount: _intValue(json['activationCount']),
    );
  }
}

int _intValue(Object? value, {int fallback = 0}) {
  return switch (value) {
    int() => value,
    double() => value.toInt(),
    _ => fallback,
  };
}

int? _nullableIntValue(Object? value) {
  return switch (value) {
    int() => value,
    double() => value.toInt(),
    _ => null,
  };
}

double _doubleValue(Object? value, {double fallback = 0}) {
  return switch (value) {
    int() => value.toDouble(),
    double() => value,
    _ => fallback,
  };
}

int _nonNegativeInt(Object? value) {
  final parsed = _intValue(value);
  return parsed < 0 ? 0 : parsed;
}

bool _boolValue(Object? value, {bool fallback = false}) {
  return value is bool ? value : fallback;
}

String? _stringValue(Object? value) {
  return value is String && value.isNotEmpty ? value : null;
}

T? _enumValue<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) {
    return null;
  }
  for (final value in values) {
    if (value.name == name) {
      return value;
    }
  }
  return null;
}

Map<T, int> _enumIntMap<T extends Enum>(List<T> values, Object? json) {
  if (json is! Map<String, Object?>) {
    return {};
  }
  final result = <T, int>{};
  for (final entry in json.entries) {
    final key = _enumValue(values, entry.key);
    if (key != null) {
      result[key] = _intValue(entry.value);
    }
  }
  return result;
}

Map<int, int> _intIntMap(Object? json) {
  if (json is! Map<String, Object?>) {
    return {};
  }
  final result = <int, int>{};
  for (final entry in json.entries) {
    final key = int.tryParse(entry.key);
    final value = _intValue(entry.value);
    if (key != null && key > 0 && value > 0) {
      result[key] = value;
    }
  }
  return result;
}

Set<int> _intSet(Object? json) {
  if (json is! List) {
    return {};
  }
  final result = <int>{};
  for (final item in json) {
    final value = _intValue(item);
    if (value > 0) {
      result.add(value);
    }
  }
  return result;
}

Set<String> _stringSet(Object? json) {
  if (json is! List) {
    return {};
  }
  return {
    for (final item in json)
      if (item is String && item.isNotEmpty) item,
  };
}

List<T> _enumList<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return [];
  }
  final result = <T>[];
  for (final item in json) {
    final value = _enumValue(values, item);
    if (value != null) {
      result.add(value);
    }
  }
  return result;
}

Set<T> _enumSet<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return {};
  }
  final result = <T>{};
  for (final item in json) {
    final value = _enumValue(values, item);
    if (value != null) {
      result.add(value);
    }
  }
  return result;
}

List<T?> _nullableEnumList<T extends Enum>(List<T> values, Object? json) {
  if (json is! List) {
    return [];
  }
  final result = <T?>[];
  for (final item in json) {
    result.add(_enumValue(values, item));
  }
  return result;
}

List<T> _objectList<T>(Object? json, T? Function(Object?) parse) {
  if (json is! List) {
    return [];
  }
  final result = <T>[];
  for (final item in json) {
    final value = parse(item);
    if (value != null) {
      result.add(value);
    }
  }
  return result;
}
