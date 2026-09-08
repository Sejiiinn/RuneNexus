// 실행: flutter test tool/gem_combat_render_test.dart
// 실제 전투 컴포넌트와 명중 처리로 생성하는 오프라인 검토 이미지.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:rune_nexus/game/components/impact_effect_component.dart';

import '../test/helpers/game_balance_test_helpers.dart';

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
