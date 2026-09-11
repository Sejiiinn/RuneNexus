import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/game/components/turret_component.dart';
import 'package:rune_nexus/ui/hud/top_bar.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  testWidgets(
    'debug panel opens and its gold and enemy actions remain usable',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final game = RuneNexusGame(saveRepository: MemorySaveRepository());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: GameHud(game: game)),
        ),
      );
      await pumpGameFrames(tester, frameCount: 10);
      await tester.runAsync(
        () => game.loaded.timeout(const Duration(seconds: 10)),
      );
      game.pauseEngine();

      if (!const bool.fromEnvironment('RUNE_NEXUS_DEBUG_PANEL')) {
        expect(find.text('테스트 패널'), findsNothing);
        return;
      }

      await tester.tap(find.text('테스트 패널'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      final panel = find.byType(HudGemDebugPanel);
      expect(panel, findsOneWidget);
      expect(
        find.descendant(of: panel, matching: find.text('포탑 레벨 1~10')),
        findsOneWidget,
      );

      final goldBefore = game.snapshotNotifier.value.gold;
      final addGold = find.descendant(of: panel, matching: find.text('+500G'));
      await tester.ensureVisible(addGold);
      await tester.tap(addGold);
      await tester.pump();
      expect(game.snapshotNotifier.value.gold, goldBefore + 500);

      final spawnNormal = find.descendant(of: panel, matching: find.text('일반'));
      await tester.ensureVisible(spawnNormal);
      await tester.tap(spawnNormal);
      await tester.pump();
      expect(game.enemies.single.definition.type, EnemyType.normal);
      expect(tester.takeException(), isNull);

      final barrage = find.descendant(
        of: panel,
        matching: find.text('대포 6문 · 고체력 표적'),
      );
      await tester.ensureVisible(barrage);
      await tester.tap(barrage);
      await tester.pump();
      game.update(0);
      await tester.pump();
      final cannons = game.children.whereType<TurretComponent>().toList();
      expect(cannons, hasLength(6));
      expect(
        cannons.every((t) => t.definition.type == TurretType.cannon),
        isTrue,
      );
      expect(game.enemies, hasLength(3));
      final positions = [
        for (final enemy in game.enemies) enemy.position.clone(),
      ];
      for (var frame = 0; frame < 360; frame++) {
        game.update(1 / 60);
        await tester.pump();
      }
      expect(cannons.every((t) => t.damageDealt > 0), isTrue);
      expect(game.enemies.every((e) => e.hp > 999000000), isTrue);
      expect([for (final enemy in game.enemies) enemy.position], positions);

      await tester.pumpWidget(const SizedBox.shrink());
      game.disposeAppResources();
    },
  );
}
