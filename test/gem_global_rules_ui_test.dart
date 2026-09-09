import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:rune_nexus/data/definitions/game_turret_data.dart';
import 'package:rune_nexus/domain/gem/gem_equip_rules.dart';
import 'package:rune_nexus/ui/hud/gem_socket_section.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets('모든 보상 젬 설명은 좁은 카드와 글자 확대에서도 잘리지 않는다', (tester) async {
    await tester.runAsync(() async {
      await (FontLoader(
        'NotoSansKR',
      )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    for (final width in [320.0, 390.0]) {
      tester.view.physicalSize = Size(width, 800);
      for (final scale in [1.0, 1.3]) {
        for (var start = 0; start < GemType.values.length; start += 3) {
          final options = List.generate(
            3,
            (index) => GemType.values[(start + index) % GemType.values.length],
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(fontFamily: 'NotoSansKR'),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Scaffold(
                  body: HudRewardOverlay(
                    game: game,
                    snapshot: resultSnapshot(
                      phase: GamePhase.reward,
                      currentStageNumber: 1,
                      rewardOptions: options,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final type in options) {
            final description = hudRewardGemEffectText(type);
            final finder = find.byKey(
              ValueKey('reward-gem-effects-${type.name}'),
            );
            expect(finder, findsOneWidget);
            final richTextFinder = find.descendant(
              of: finder,
              matching: find.byType(RichText),
            );
            final renderedParts = <String>[];
            for (final element in richTextFinder.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              final painter = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textScaler: paragraph.textScaler,
              )..layout(maxWidth: paragraph.size.width);
              final rendered = paragraph.text.toPlainText();
              renderedParts.add(rendered);
              expect(
                painter.height,
                lessThanOrEqualTo(paragraph.size.height + .1),
              );
              for (final line in painter.computeLineMetrics()) {
                expect(
                  line.width,
                  lessThanOrEqualTo(paragraph.size.width + .1),
                );
              }
              // 수치·배율과 한글 단어는 동일한 줄에서 온전히 표시.
              for (final unit in RegExp(
                r'\d+%\u00a0[가-힣\u2060]+|[가-힣][가-힣\u2060]+',
              ).allMatches(rendered)) {
                final boxes = painter.getBoxesForSelection(
                  TextSelection(baseOffset: unit.start, extentOffset: unit.end),
                );
                expect(boxes.map((box) => box.top).toSet(), hasLength(1));
              }
              painter.dispose();
            }
            if (type == GemType.heavyWeapon) {
              final restriction = find.text('중화기 전용');
              expect(restriction, findsOneWidget);
              expect(
                tester.getTopLeft(restriction).dy,
                greaterThanOrEqualTo(tester.getBottomLeft(finder).dy),
              );
              expect(
                tester.getBottomLeft(restriction).dy,
                lessThanOrEqualTo(
                  tester
                      .getTopLeft(find.text('미보유').at(options.indexOf(type)))
                      .dy,
                ),
              );
              renderedParts.add('중화기 전용');
            }
            expect(
              renderedParts
                  .join(' ')
                  .replaceAll('\u2060', '')
                  .replaceAll(RegExp(r'\s+'), ' '),
              description.replaceAll(RegExp(r'\s+'), ' '),
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    }
  });

  test('global gem descriptions do not change with the turret', () {
    for (final type in [
      GemType.explosion,
      GemType.chain,
      GemType.heavyWeapon,
      GemType.multipleProjectiles,
    ]) {
      final descriptions = gameTurrets.values
          .map((turret) => hudGemEffectText(type, turret))
          .toSet();
      expect(descriptions, hasLength(1));
    }
  });

  test('multiple projectiles only equips on projectile turrets', () {
    for (final turret in gameTurrets.values) {
      expect(
        canEquipGemOnTurret(GemType.multipleProjectiles, turret),
        turret.firesProjectile,
        reason: turret.name,
      );
    }
  });

  for (final size in [const Size(320, 800), const Size(640, 360)]) {
    for (final thirdGem in [GemType.heavyWeapon, GemType.multipleProjectiles]) {
      testWidgets(
        'global gem reward rules remain readable at $size with $thirdGem',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(() {
            tester.view.resetPhysicalSize();
            tester.view.resetDevicePixelRatio();
          });
          final game = RuneNexusGame(saveRepository: MemorySaveRepository());
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: HudRewardOverlay(
                  game: game,
                  snapshot: resultSnapshot(
                    phase: GamePhase.reward,
                    currentStageNumber: 1,
                    completedRounds: 5,
                    rewardOptions: [GemType.explosion, GemType.chain, thirdGem],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          for (final text in [
            '범위 피해 부여\n효과 범위 25% 증가',
            '(폭발은 직접 명중한 대상을 제외한 주변 적에게 명중 피해의 50%를 줍니다.)',
            '연쇄 횟수 +2',
            '(연쇄된 투사체는 피해 및 효과 범위가 50% 감폭됩니다.)',
            if (thirdGem == GemType.heavyWeapon)
              '피해 30% 증폭\n효과 범위 20% 증가\n중화기 전용'
            else
              '투사체 +2\n피해 50% 감폭',
          ]) {
            final matchingGems = GemType.values.where(
              (type) => hudRewardGemEffectText(type) == text,
            );
            final finder = matchingGems.isEmpty
                ? find.text(text)
                : find.byKey(
                    ValueKey('reward-gem-effects-${matchingGems.single.name}'),
                  );
            expect(finder, findsOneWidget);
            final paragraphs = find.descendant(
              of: finder,
              matching: find.byType(RichText),
            );
            for (final element in paragraphs.evaluate()) {
              final paragraph = element.renderObject! as RenderParagraph;
              expect(paragraph.didExceedMaxLines, isFalse);
              final painter = TextPainter(
                text: paragraph.text,
                textDirection: TextDirection.ltr,
                textScaler: paragraph.textScaler,
              )..layout(maxWidth: paragraph.size.width);
              expect(
                painter.height,
                lessThanOrEqualTo(paragraph.size.height + 0.1),
              );
              painter.dispose();
            }
          }
          if (thirdGem == GemType.heavyWeapon) {
            final explosionArea = find.descendant(
              of: find.byKey(const ValueKey('reward-gem-effects-explosion')),
              matching: find.text('효과 범위'),
            );
            final heavyArea = find.descendant(
              of: find.byKey(const ValueKey('reward-gem-effects-heavyWeapon')),
              matching: find.text('효과 범위'),
            );
            expect(
              tester.getCenter(explosionArea).dy,
              tester.getCenter(heavyArea).dy,
            );
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
