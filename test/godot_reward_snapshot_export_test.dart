import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/systems/run_progression.dart';
import 'package:rune_nexus/domain/economy/economy_snapshot.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';

void main() {
  test('authoritative economy snapshot matches Dart', () {
    final p = RunProgression();
    const key = TurretModuleKey(
      turretType: TurretType.arrow,
      part: TurretModulePart.core,
      family: TurretModuleFamily.rapidCore,
      grade: TurretModuleGrade.rare,
    );
    final legacy = p.grantTurretModule(key);
    p.equipTurretModule(legacy.id);
    Map<String, Object?> state() => {
      ...p.toSaveData().toJson(),
      'turretModules': p.toTurretModuleSaveData().toJson(),
    };
    final cases = <Map<String, Object?>>[];
    final modules = [
      EconomyModule(
        id: 'server-1',
        legacyItemId: legacy.id,
        turretType: key.turretType,
        part: key.part,
        family: key.family,
        grade: key.grade,
        options: const [
          TurretModuleOptionRoll(
            type: TurretModuleOptionType.damageIncrease,
            value: 9999,
          ),
          TurretModuleOptionRoll(
            type: TurretModuleOptionType.damageIncrease,
            value: 1,
          ),
          TurretModuleOptionRoll(
            type: TurretModuleOptionType.attackRateIncrease,
            value: 1,
          ),
        ],
        acquiredOrder: 10,
      ),
      EconomyModule(
        id: 'server-2',
        legacyItemId: legacy.id,
        turretType: key.turretType,
        part: key.part,
        family: key.family,
        grade: key.grade,
        options: const [
          TurretModuleOptionRoll(
            type: TurretModuleOptionType.damageIncrease,
            value: 5,
          ),
        ],
        acquiredOrder: 20,
      ),
    ];
    for (final list in [
      modules,
      modules.reversed.toList(),
      <EconomyModule>[],
    ]) {
      final snapshot = EconomySnapshot(
        authorityEpoch: 'test',
        authorityState: 'server_authoritative',
        authorityVersion: 1,
        revision: 1,
        catalogVersion: 1,
        serverTime: DateTime.utc(2026),
        wallet: const EconomyWallet(
          freeDiamonds: 101,
          paidDiamonds: 7,
          moduleTickets: 8,
        ),
        moduleDrawCount: 4,
        moduleTicketPurchaseCount: 3,
        modules: list,
        researchSlotTwoUnlocked: true,
        pendingProgressionEffects: const [],
        claimedRewardKeys: const {},
      );
      final raw = {
        'wallet': {'freeDiamonds': 101, 'paidDiamonds': 7, 'moduleTickets': 8},
        'turretModules': {
          'drawCount': 4,
          'ticketPurchaseCount': 3,
          'items': [
            for (final m in list)
              {
                'id': m.id,
                'legacyItemId': m.legacyItemId,
                'turretType': m.turretType.name,
                'part': m.part.name,
                'family': m.family.name,
                'grade': m.grade.name,
                'acquiredOrder': m.acquiredOrder,
                'options': [
                  for (final o in m.options)
                    {'type': o.type.name, 'value': o.value},
                ],
              },
          ],
        },
        'entitlements': {'researchSlotTwoUnlocked': true},
      };
      final before = state();
      p.applyAuthoritativeEconomy(snapshot);
      cases.add({'before': before, 'snapshot': raw, 'after': state()});
    }
    final encoded =
        '${const JsonEncoder.withIndent('  ').convert({'cases': cases})}\n';
    final file = File('test/fixtures/reward_snapshot_cases.json');
    if (Platform.environment['UPDATE_GODOT_QUEST'] == '1') {
      file.writeAsStringSync(encoded);
    }
    expect(file.readAsStringSync(), encoded);
  });
}
