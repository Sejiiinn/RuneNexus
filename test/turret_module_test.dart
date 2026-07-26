import 'package:flame/components.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/data/save/game_save_data.dart';
import 'package:rune_nexus/domain/map/grid_point.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';

void main() {
  test(
    'only the configured first clear grants module tickets and persists state',
    () {
      final progression = RunProgression();
      progression.finishRun(completedRounds: 40, success: true, stageNumber: 1);
      expect(progression.turretModuleTickets, 0);
      expect(progression.lastRunTurretModuleTicketReward, 0);

      progression.finishRun(
        completedRounds: 40,
        success: true,
        stageNumber: 11,
        firstClearTurretModuleTicketReward: 5,
      );
      expect(progression.turretModuleTickets, 5);
      expect(progression.lastRunTurretModuleTicketReward, 5);

      progression.finishRun(
        completedRounds: 40,
        success: true,
        stageNumber: 11,
        firstClearTurretModuleTicketReward: 5,
      );
      expect(progression.turretModuleTickets, 5);
      expect(progression.lastRunTurretModuleTicketReward, 0);

      final key = TurretModuleKey(
        turretType: TurretType.arrow,
        part: TurretModulePart.frame,
        family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
        grade: TurretModuleGrade.rare,
      );
      final item = progression.grantTurretModule(
        key,
        options: const [
          TurretModuleOptionRoll(
            type: TurretModuleOptionType.levelUpCostDiscount,
            value: 10,
          ),
        ],
      );
      expect(progression.equipTurretModule(item.id), isTrue);

      final saved = SavedProgression.fromJson(
        progression.toSaveData().toJson(),
      );
      final restored = RunProgression()..restoreFromSaveData(saved);

      expect(restored.turretModuleTickets, 5);
      expect(restored.lastRunTurretModuleTicketReward, 0);
      final restoredModule = restored.turretModuleFor(item.id);
      expect(restoredModule, isNotNull);
      expect(restoredModule!.equipped, isTrue);
      expect(
        restoredModule.options.single.type,
        TurretModuleOptionType.levelUpCostDiscount,
      );
      expect(restoredModule.options.single.value, 10);
    },
  );

  test('turret modules disassemble into diamonds except equipped items', () {
    final progression = RunProgression();
    final key = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.barrel,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.barrel),
      grade: TurretModuleGrade.normal,
    );

    final equipped = progression.grantTurretModule(key);
    final spare = progression.grantTurretModule(key);
    expect(progression.equipTurretModule(equipped.id), isTrue);

    expect(progression.disassembleTurretModule(equipped.id), isFalse);
    expect(progression.disassembleTurretModule(spare.id), isTrue);

    expect(progression.diamonds, 2);
    expect(progression.turretModuleFor(spare.id), isNull);
    expect(progression.turretModuleFor(equipped.id), isNotNull);
  });

  test('turret modules can be unequipped and then disassembled', () {
    final progression = RunProgression();
    final key = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.barrel,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.barrel),
      grade: TurretModuleGrade.rare,
    );
    final item = progression.grantTurretModule(
      key,
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 18,
        ),
      ],
    );

    expect(progression.unequipTurretModule('missing'), isFalse);
    expect(progression.unequipTurretModule(item.id), isFalse);
    expect(progression.equipTurretModule(item.id), isTrue);
    expect(progression.turretModuleFor(item.id)!.equipped, isTrue);
    expect(
      progression.turretModuleEffectFor(TurretType.arrow).damageIncreaseRate,
      closeTo(0.18, 0.001),
    );

    expect(progression.unequipTurretModule(item.id), isTrue);
    expect(progression.turretModuleFor(item.id)!.equipped, isFalse);
    expect(progression.unequipTurretModule(item.id), isFalse);
    expect(
      progression.turretModuleEffectFor(TurretType.arrow).damageIncreaseRate,
      0,
    );
    expect(progression.disassembleTurretModule(item.id), isTrue);
    expect(progression.diamonds, key.grade.disassembleDiamondValue);
    expect(progression.turretModuleFor(item.id), isNull);
  });

  test(
    'bulk disassembly refunds selected modules but protects equipped and unique items',
    () {
      final progression = RunProgression();

      TurretModuleInventoryItem grant(
        TurretModuleGrade grade, {
        TurretModulePart part = TurretModulePart.core,
      }) {
        return progression.grantTurretModule(
          TurretModuleKey(
            turretType: TurretType.arrow,
            part: part,
            family: turretModuleFamilyFor(TurretType.arrow, part),
            grade: grade,
          ),
        );
      }

      final equippedNormal = grant(TurretModuleGrade.normal);
      final spareNormal = grant(
        TurretModuleGrade.normal,
        part: TurretModulePart.barrel,
      );
      final spareMagic = grant(TurretModuleGrade.magic);
      final spareRare = grant(TurretModuleGrade.rare);
      final spareUnique = grant(TurretModuleGrade.unique);
      expect(progression.equipTurretModule(equippedNormal.id), isTrue);

      final disassembledCount = progression.disassembleTurretModules([
        equippedNormal.id,
        spareNormal.id,
        spareMagic.id,
        spareRare.id,
        spareUnique.id,
        spareNormal.id,
      ]);

      expect(disassembledCount, 3);
      expect(progression.diamonds, 2 + 5 + 20);
      expect(progression.turretModuleFor(spareNormal.id), isNull);
      expect(progression.turretModuleFor(spareMagic.id), isNull);
      expect(progression.turretModuleFor(spareRare.id), isNull);
      expect(progression.turretModuleFor(equippedNormal.id), isNotNull);
      expect(progression.turretModuleFor(spareUnique.id), isNotNull);
    },
  );

  test('draw can buy missing turret module tickets with diamonds', () {
    final progression = RunProgression()
      ..turretModuleTickets = 3
      ..addFreeDiamonds(160);

    expect(
      progression.drawTurretModules(
        count: 5,
        availableTurretTypes: const [TurretType.arrow],
      ),
      isEmpty,
    );
    expect(progression.turretModuleTickets, 3);
    expect(progression.diamonds, 160);

    final results = progression.drawTurretModules(
      count: 5,
      availableTurretTypes: const [TurretType.arrow],
      buyMissingTicketsWithDiamonds: true,
    );

    expect(results, hasLength(5));
    expect(progression.turretModuleTickets, 0);
    expect(progression.diamonds, 0);
  });

  test('turret module roll tables keep unique and core damage ranges', () {
    expect(turretModuleDisassembleDiamonds[TurretModuleGrade.unique], 50);
    expect(turretModuleOptionCountWeights[TurretModuleGrade.normal], [
      85,
      15,
      0,
    ]);
    expect(turretModuleOptionCountWeights[TurretModuleGrade.magic], [
      40,
      60,
      0,
    ]);
    expect(turretModuleOptionCountWeights[TurretModuleGrade.rare], [
      10,
      55,
      35,
    ]);
    expect(turretModuleOptionCountWeights[TurretModuleGrade.unique], [
      0,
      40,
      60,
    ]);

    final barrelDamageRange = turretModuleOptionRollRangeFor(
      part: TurretModulePart.barrel,
      grade: TurretModuleGrade.unique,
      type: TurretModuleOptionType.damageIncrease,
    );
    final coreDamageRange = turretModuleOptionRollRangeFor(
      part: TurretModulePart.core,
      grade: TurretModuleGrade.unique,
      type: TurretModuleOptionType.damageIncrease,
    );

    expect(barrelDamageRange.min, 22);
    expect(barrelDamageRange.max, 30);
    expect(coreDamageRange.min, 25);
    expect(coreDamageRange.max, 36);
    expect(
      turretModuleOptionPoolFor(TurretType.arrow, TurretModulePart.barrel),
      hasLength(greaterThanOrEqualTo(4)),
    );
    expect(
      turretModuleOptionPoolFor(TurretType.arrow, TurretModulePart.frame),
      hasLength(greaterThanOrEqualTo(4)),
    );
  });

  test('equipped turret modules affect turret stats and level up cost', () {
    final progression = RunProgression();
    final barrelKey = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.barrel,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.barrel),
      grade: TurretModuleGrade.rare,
    );
    final frameKey = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.frame,
      family: turretModuleFamilyFor(TurretType.arrow, TurretModulePart.frame),
      grade: TurretModuleGrade.rare,
    );
    final barrel = progression.grantTurretModule(
      barrelKey,
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.damageIncrease,
          value: 18,
        ),
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.attackRateIncrease,
          value: 8,
        ),
      ],
    );
    final frame = progression.grantTurretModule(
      frameKey,
      options: const [
        TurretModuleOptionRoll(
          type: TurretModuleOptionType.levelUpCostDiscount,
          value: 10,
        ),
      ],
    );
    progression
      ..equipTurretModule(barrel.id)
      ..equipTurretModule(frame.id);

    final base = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: RuneNexusGame(),
      center: Vector2.zero(),
      tileSize: 32,
    );
    final moduleGame = _ModuleEffectGame(progression);
    final moduleTurret = TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[TurretType.arrow]!,
      game: moduleGame,
      center: Vector2.zero(),
      tileSize: 32,
    );

    expect(moduleTurret.damage, closeTo(base.damage * 1.18, 0.001));
    expect(moduleTurret.attackRate, closeTo(base.attackRate * 1.08, 0.001));
    expect(moduleTurret.levelUpCost, 38);
  });
}

class _ModuleEffectGame extends RuneNexusGame {
  _ModuleEffectGame(this.progression);

  final RunProgression progression;

  @override
  TurretModuleEffect turretModuleEffectFor(TurretType type) {
    return progression.turretModuleEffectFor(type);
  }
}
