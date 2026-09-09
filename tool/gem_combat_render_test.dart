// 실행: flutter test tool/gem_combat_render_test.dart
// 실제 전투 컴포넌트와 명중 처리로 생성하는 오프라인 검토 이미지.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';
import 'package:rune_nexus/data/definitions/game_gem_data.dart';
import 'package:rune_nexus/ui/game/game_icons.dart';

import '../test/helpers/game_balance_test_helpers.dart';
import '../test/helpers/widget_test_helpers.dart'
    show HudRewardOverlay, resultSnapshot;

class _SelectedGame extends RuneNexusGame {
  _SelectedGame() : super(saveRepository: MemorySaveRepository());
  @override
  bool isTurretSelected(GridPoint point) => true;
}

void _label(Canvas canvas, String text, Offset offset, {double size = 18}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: 'RenderKorean',
        color: const Color(0xffe4edf7),
        fontSize: size,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, offset);
  painter.dispose();
}

Future<void> _save(
  ui.PictureRecorder recorder,
  String name,
  int w,
  int h,
) async {
  final picture = recorder.endRecording();
  final image = await picture.toImage(w, h);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(
    'design/ux-previews/gem-rules/$name.png',
  ).writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
  picture.dispose();
}

TurretComponent _tower(RuneNexusGame game, TurretType type, Vector2 position) =>
    TurretComponent(
      gridPoint: const GridPoint(0, 0),
      definition: gameTurrets[type]!,
      game: game,
      center: position,
      tileSize: 48 * game.boardDistanceScale,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final loader = FontLoader('RenderKorean')
      ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
    await loader.load();
    await Directory('design/ux-previews/gem-rules').create(recursive: true);
  });

  for (final scenario in [
    (
      name: 'render multiple projectiles reward choices',
      gems: [GemType.multipleProjectiles, GemType.chain, GemType.explosion],
      texts: ['다중 투사체', '투사체 +2\n피해 50% 감폭'],
      output: 'design/ux-previews/multiple-projectiles/reward.png',
    ),
    (
      name: 'render adjusted gem reward choices',
      gems: [GemType.criticalChance, GemType.aimSpeed, GemType.attackSpeed],
      texts: ['치명 확률 +30%p', '조준 속도 75% 증폭'],
      output: 'design/ux-previews/gem-balance/reward.png',
    ),
  ]) {
    testWidgets(scenario.name, (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(() async {
        for (final family in ['NotoSansKR', 'Ahem', 'Roboto', 'sans-serif']) {
          await (FontLoader(
            family,
          )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
        }
        await (FontLoader(
          'MaterialIcons',
        )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      });
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            textTheme: ThemeData.dark().textTheme.apply(
              fontFamily: 'NotoSansKR',
            ),
          ),
          home: RepaintBoundary(
            key: boundaryKey,
            child: Scaffold(
              backgroundColor: const Color(0xFF07111D),
              body: HudRewardOverlay(
                game: RuneNexusGame(saveRepository: MemorySaveRepository()),
                snapshot: resultSnapshot(
                  phase: GamePhase.reward,
                  currentStageNumber: 1,
                  completedRounds: 5,
                  rewardOptions: scenario.gems,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(
            image.image,
            tester.element(find.byType(Scaffold)),
          );
        }
      });
      await tester.pumpAndSettle();
      // 오프라인 엔진 기본 글꼴 보정, 실제 위젯 레이아웃 유지.
      for (final element in find.byType(RichText).evaluate()) {
        final paragraph = element.renderObject! as RenderParagraph;
        final span = paragraph.text as TextSpan;
        if (span.style?.fontFamily == null) {
          paragraph.text = TextSpan(
            text: span.text,
            children: span.children,
            style: (span.style ?? const TextStyle()).copyWith(
              fontFamily: 'NotoSansKR',
            ),
          );
        }
      }
      await tester.pump();
      for (final text in scenario.texts) {
        expect(find.text(text), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final output = File(scenario.output);
        await output.parent.create(recursive: true);
        await output.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    });
  }

  testWidgets('render implemented gem icons at HUD sizes', (tester) async {
    tester.view.physicalSize = const Size(840, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(
          textTheme: ThemeData.dark().textTheme.apply(
            fontFamily: 'RenderKorean',
          ),
        ),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '젬 에셋 적용 · 실제 GemIcon 위젯',
                    style: TextStyle(fontSize: 22),
                  ),
                  const SizedBox(height: 6),
                  const Text('각 행 왼쪽부터 14 · 24 · 40px / 오프라인 테스트 렌더'),
                  const SizedBox(height: 20),
                  for (var row = 0; row < 7; row++)
                    SizedBox(
                      height: 73,
                      child: Row(
                        children: [
                          for (var column = 0; column < 2; column++)
                            Expanded(
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 140,
                                    child: Text(
                                      gameGems[GemType.values[column * 7 +
                                              row]]!
                                          .name,
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ),
                                  for (final size in [14.0, 24.0, 40.0])
                                    SizedBox(
                                      width: 64,
                                      child: Center(
                                        child: GemIcon(
                                          GemType.values[column * 7 + row],
                                          size: size,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold));
      for (final type in GemType.values) {
        await precacheImage(gemIconImageProvider(type), context);
      }
    });
    await tester.pumpAndSettle();
    expect(find.byType(GemIcon), findsNWidgets(GemType.values.length * 3));
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('design/gem_concepts/implemented-icons-test.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  });

  testWidgets('render actual frost range and chained cannon impacts', (
    tester,
  ) async {
    final rangeRecorder = ui.PictureRecorder();
    final rangeCanvas = Canvas(rangeRecorder)
      ..drawColor(const Color(0xff101923), BlendMode.src);
    _label(rangeCanvas, '실제 서리 포탑 렌더 · 동일 배율', const Offset(24, 18), size: 24);
    for (var i = 0; i < 2; i++) {
      final game = _SelectedGame();
      final turret = _tower(
        game,
        TurretType.frost,
        Vector2(170 + i * 320, 190),
      );
      if (i == 1) turret.equipGem(GemType.explosion, 0);
      turret.renderTree(rangeCanvas);
      _label(
        rangeCanvas,
        i == 0 ? '기본 효과 범위' : '폭발 젬: 효과 범위 +25%',
        Offset(40 + i * 320, 320),
      );
      _label(
        rangeCanvas,
        '사거리 ${turret.range.toStringAsFixed(0)} / 효과 반경 ${turret.centeredAreaRadius.toStringAsFixed(0)}',
        Offset(40 + i * 320, 352),
        size: 16,
      );
    }
    await tester.runAsync(() => _save(rangeRecorder, 'frost-range', 660, 400));

    final game = RuneNexusGame(saveRepository: MemorySaveRepository());
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    final scale = game.boardDistanceScale;
    final turret = _tower(game, TurretType.cannon, Vector2(35, 80) * scale)
      ..upgradeLink()
      ..equipGem(GemType.explosion, 0)
      ..equipGem(GemType.chain, 1);
    final attack = turret.createAttackSnapshot();
    final enemies = <EnemyComponent>[];
    for (final x in [120.0, 195.0, 270.0]) {
      final enemy = EnemyComponent(
        definition: gameEnemies[EnemyType.normal]!,
        maxHp: 1000,
        path: [Vector2(x, 80) * scale, Vector2(x + 500, 80) * scale],
        game: game,
      );
      game.enemies.add(enemy);
      enemies.add(enemy);
    }
    var projectile = ProjectileComponent(
      origin: turret.position.clone(),
      targetPosition: enemies.first.position.clone(),
      owner: turret,
      attack: attack,
      game: game,
    );
    await game.add(projectile);
    await tester.pump();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xff101923), BlendMode.src);
    _label(canvas, '실제 포탄 연쇄 · 최초 명중 + 후속 2회', const Offset(24, 18), size: 24);
    for (var hit = 0; hit < 3; hit++) {
      projectile.update(110 * scale / attack.projectileSpeed);
      game.update(0);
      final impacts = game.children
          .whereType<ImpactEffectComponent>()
          .where((c) => !c.isRemoving)
          .toList();
      expect(impacts, isNotEmpty);
      final blast = impacts.lastWhere(
        (c) => c.style == ImpactEffectStyle.blast,
      );
      expect(
        blast.radius,
        closeTo(attack.splashRadius * (hit == 0 ? 1 : .5), 1e-8),
      );
      blast.update(.10);
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 95 + hit * 210, 670, 140));
      canvas.translate(40, 65 + hit * 210);
      canvas.scale(1.7 / scale);
      turret.renderTree(canvas);
      for (final enemy in enemies) {
        enemy.renderTree(canvas);
      }
      blast.renderTree(canvas);
      final next = game.children
          .whereType<ProjectileComponent>()
          .where((c) => !c.isRemoving)
          .toList();
      if (next.isNotEmpty) {
        next.single.renderTree(canvas);
      }
      canvas.restore();
      _label(
        canvas,
        '${hit == 0 ? '최초 명중' : '후속 $hit'} · 피해 ${hit == 0 ? '100%' : '50%'} · 폭발 반경 ${(blast.radius / scale).toStringAsFixed(2)}',
        Offset(24, 62 + hit * 210),
      );
      _label(
        canvas,
        '적 HP: ${enemies.map((e) => e.hp.toStringAsFixed(1)).join(' / ')}',
        Offset(24, 240 + hit * 210),
        size: 16,
      );
      for (final effect in impacts) {
        effect.removeFromParent();
      }
      game.update(0);
      if (hit < 2) {
        projectile = next.single;
      }
    }
    expect(enemies.map((e) => e.hp).toList(), [975.0, 987.5, 987.5]);
    await tester.runAsync(() => _save(recorder, 'cannon-chain', 670, 710));
    expect(tester.takeException(), isNull);
  });
}
