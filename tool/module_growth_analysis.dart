import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:rune_nexus/data/definitions/game_daily_quest_data.dart';
import 'package:rune_nexus/data/definitions/game_turret_module_data.dart';
import 'package:rune_nexus/data/definitions/game_weekly_quest_data.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/domain/turret_module/turret_module_type.dart';

// 실제 옵션 생성기를 사용하는 재현 가능한 수급 분석. 게임 상태·운영 계정 변경 없음.
void main() {
  const trials = 10000;
  const seed = 20260910;
  const weeks = 52;
  final catalog = File('server/internal/economy/catalog.go').readAsStringSync();
  final price = int.parse(
    RegExp(
      r'ModuleTicketDiamondCost\s+int64\s*=\s*(\d+)',
    ).firstMatch(catalog)!.group(1)!,
  );
  final dailyDiamonds =
      dailyAttendanceRewardDiamonds +
      dailyQuestAllCompleteRewardDiamonds +
      gameDailyQuestDefinitions.values.fold<int>(
        0,
        (sum, q) => sum + q.rewardDiamonds,
      );
  final weeklyDiamonds =
      dailyDiamonds * 7 +
      weeklyAttendanceRewardDiamonds +
      weeklyQuestAllCompleteRewardDiamonds +
      gameWeeklyQuestDefinitions.values.fold<int>(
        0,
        (sum, q) => sum + q.rewardDiamonds,
      );
  final tickets =
      dailyQuestAllCompleteRewardModuleTickets * 7 +
      weeklyQuestAllCompleteRewardModuleTickets;
  final budgets = [
    tickets * price,
    tickets * price + weeklyDiamonds ~/ 2,
    tickets * price + weeklyDiamonds,
  ];
  const targets = [
    'first_unique',
    'three_rare_or_better_parts',
    'three_unique_parts',
    'rare_or_better_barrel_damage',
    'unique_barrel_damage_attack',
    'unique_barrel_damage_attack_upper_half',
  ];
  final targetCapital = List.generate(
    2,
    (_) => {
      for (final target in targets) target: <int>[],
      for (final threshold in [100, 250, 500, 800]) 'draws_$threshold': <int>[],
    },
  );
  final counts = List.generate(
    2,
    (_) => List.generate(
      3,
      (_) => {
        for (final week in [1, 4, 12, 26, 52]) '$week': <int>[],
      },
    ),
  );
  final random = math.Random(seed);
  var totalDraws = 0;
  var first100NoUnique = 0;
  for (var trial = 0; trial < trials; trial++) {
    final spent = [0, 0];
    final capital = [0, 0];
    final history = [<int>[], <int>[]];
    final bestScores = [-1.0, -1.0, -1.0];
    final bestGrades = List<TurretModuleGrade?>.filled(3, null);
    final seen = <String>{};
    var rareParts = 0;
    var uniqueParts = 0;
    var drawCount = 0;
    while (capital[1] <= budgets.last * weeks) {
      final part = TurretModulePart.values[random.nextInt(3)];
      final level = turretModuleBuildLevelForDrawCount(drawCount);
      var roll = random.nextInt(100);
      var grade = TurretModuleGrade.normal;
      for (final candidate in TurretModuleGrade.values) {
        roll -= level.rateFor(candidate);
        if (roll < 0) {
          grade = candidate;
          break;
        }
      }
      final options = rollTurretModuleOptions(
        turretType: TurretType.arrow,
        part: part,
        grade: grade,
        random: random,
      );
      for (var mode = 0; mode < 2; mode++) {
        // 분해 환급 전 40다이아를 먼저 보유해야 하는 유동성 조건.
        capital[mode] = math.max(capital[mode], spent[mode] + price);
        history[mode].add(capital[mode]);
        spent[mode] += price;
      }
      drawCount++;
      if (grade.index >= TurretModuleGrade.rare.index) {
        rareParts |= 1 << part.index;
      }
      if (grade == TurretModuleGrade.unique) uniqueParts |= 1 << part.index;
      final values = {for (final option in options) option.type: option.value};
      final damage = values[TurretModuleOptionType.damageIncrease];
      final attack = values[TurretModuleOptionType.attackRateIncrease];
      final upperHalf =
          [
            TurretModuleOptionType.damageIncrease,
            TurretModuleOptionType.attackRateIncrease,
          ].every((type) {
            final range = turretModuleOptionRollRangeFor(
              part: part,
              grade: grade,
              type: type,
            );
            return (values[type] ?? -1) >= (range.min + range.max + 1) ~/ 2;
          });
      final events = <String>[
        if (uniqueParts != 0) 'first_unique',
        if (rareParts == 7) 'three_rare_or_better_parts',
        if (uniqueParts == 7) 'three_unique_parts',
        if (part == TurretModulePart.barrel &&
            grade.index >= 2 &&
            damage != null)
          'rare_or_better_barrel_damage',
        if (part == TurretModulePart.barrel &&
            grade == TurretModuleGrade.unique &&
            damage != null &&
            attack != null)
          'unique_barrel_damage_attack',
        if (part == TurretModulePart.barrel &&
            grade == TurretModuleGrade.unique &&
            upperHalf)
          'unique_barrel_damage_attack_upper_half',
        if ([100, 250, 500, 800].contains(drawCount)) 'draws_$drawCount',
      ];
      for (final event in events) {
        if (seen.add(event)) {
          for (var mode = 0; mode < 2; mode++) {
            targetCapital[mode][event]!.add(capital[mode]);
          }
        }
      }
      if (drawCount == 100 && uniqueParts == 0) first100NoUnique++;
      // 보관 정책: 부위별 등급 → 지정 옵션 개수 → 정규화 옵션값 순으로 1개 유지.
      final wanted = part == TurretModulePart.frame
          ? [
              TurretModuleOptionType.gemEffectIncrease,
              TurretModuleOptionType.levelUpCostDiscount,
            ]
          : [
              TurretModuleOptionType.damageIncrease,
              TurretModuleOptionType.attackRateIncrease,
            ];
      final score =
          grade.index * 100.0 +
          wanted.where(values.containsKey).length * 10 +
          options.fold(0.0, (sum, option) {
            final range = turretModuleOptionRollRangeFor(
              part: part,
              grade: grade,
              type: option.type,
            );
            return sum +
                (option.value - range.min + 1) / (range.max - range.min + 1);
          });
      final oldGrade = bestGrades[part.index];
      final discarded = score > bestScores[part.index] ? oldGrade : grade;
      if (score > bestScores[part.index]) {
        bestScores[part.index] = score;
        bestGrades[part.index] = grade;
      }
      if (discarded != null) {
        final refund = discarded.disassembleDiamondValue;
        if (discarded != TurretModuleGrade.unique) spent[0] -= refund;
        // 비교안은 유니크도 개별 확인 후 분해할 수 있다고 가정.
        spent[1] -= refund;
      }
    }
    totalDraws += drawCount;
    for (var mode = 0; mode < 2; mode++) {
      for (final target in targetCapital[mode].keys) {
        if (!seen.contains(target)) targetCapital[mode][target]!.add(1 << 30);
      }
      for (var scenario = 0; scenario < 3; scenario++) {
        for (final week in [1, 4, 12, 26, 52]) {
          counts[mode][scenario]['$week']!.add(
            upperBound(history[mode], budgets[scenario] * week),
          );
        }
      }
    }
  }
  final report = {
    'seed': seed,
    'trials': trials,
    'simulatedDraws': totalDraws,
    'weeklyDiamonds': weeklyDiamonds,
    'weeklyTickets': tickets,
    'ticketPrice': price,
    'weekBudget': budgets,
    'first100NoUnique': first100NoUnique / trials,
    'first100NoUniqueExact': math.pow(0.97, 100),
    'modes': [
      for (var mode = 0; mode < 2; mode++)
        {
          'name': mode == 0
              ? 'current_unique_protected'
              : 'allow_individual_unique_disassembly',
          'scenarios': [
            for (var scenario = 0; scenario < 3; scenario++)
              {
                'questDiamondFraction': [0, 0.5, 1][scenario],
                'drawsByWeek': {
                  for (final entry in counts[mode][scenario].entries)
                    entry.key: distribution(entry.value),
                },
                'targetWeeks': {
                  for (final entry in targetCapital[mode].entries)
                    entry.key: {
                      'median': weekQuantile(
                        entry.value,
                        .5,
                        budgets[scenario],
                        weeks,
                      ),
                      'p90': weekQuantile(
                        entry.value,
                        .9,
                        budgets[scenario],
                        weeks,
                      ),
                      'successAt4Weeks':
                          entry.value
                              .where((x) => x <= budgets[scenario] * 4)
                              .length /
                          trials,
                      'successAt12Weeks':
                          entry.value
                              .where((x) => x <= budgets[scenario] * 12)
                              .length /
                          trials,
                      'successAt52Weeks':
                          entry.value
                              .where((x) => x <= budgets[scenario] * 52)
                              .length /
                          trials,
                    },
                },
              },
          ],
        },
    ],
  };
  final output = File('docs/analysis/module_growth_20260910.json');
  output.parent.createSync(recursive: true);
  output.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(report)}\n',
  );
  stdout.writeln(
    'Trials=$trials simulatedDraws=$totalDraws output=${output.path}',
  );
  stdout.writeln(
    '100 draws no unique: observed=${report['first100NoUnique']} exact=${report['first100NoUniqueExact']}',
  );
}

int upperBound(List<int> values, int limit) {
  var left = 0;
  var right = values.length;
  while (left < right) {
    final middle = (left + right) ~/ 2;
    if (values[middle] <= limit) {
      left = middle + 1;
    } else {
      right = middle;
    }
  }
  return left;
}

Map<String, num> distribution(List<int> values) {
  final sorted = values.toList()..sort();
  return {
    'mean': values.reduce((a, b) => a + b) / values.length,
    'p10': sorted[(values.length * .1).ceil() - 1],
    'median': sorted[(values.length * .5).ceil() - 1],
    'p90': sorted[(values.length * .9).ceil() - 1],
  };
}

Object weekQuantile(
  List<int> values,
  double quantile,
  int budget,
  int horizon,
) {
  final sorted = values.toList()..sort();
  final week = (sorted[(values.length * quantile).ceil() - 1] / budget).ceil();
  return week > horizon ? '>$horizon' : week;
}
