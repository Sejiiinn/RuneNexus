import 'dart:ui' show PictureRecorder;

import 'package:flame/components.dart' show Component;
import 'package:flame/events.dart' show TapUpEvent;
import 'package:flutter/gestures.dart';
import 'package:rune_nexus/domain/gem/gem_reward_target_status.dart';

import 'helpers/game_balance_test_helpers.dart';

const _target = GridPoint(2, 0);
const _options = [GemType.range, GemType.attackSpeed, GemType.heavyWeapon];

class _BoardTransformProbe extends Component {
  List<double>? transform;

  @override
  void render(Canvas canvas) {
    transform = canvas.getTransform().toList();
  }
}

List<double> _renderBoardTransform(
  RuneNexusGame game,
  _BoardTransformProbe probe,
) {
  final recorder = PictureRecorder();
  game.render(Canvas(recorder));
  recorder.endRecording().dispose();
  return probe.transform!;
}

Future<RuneNexusGame> _load(MemorySaveRepository repository) async {
  final game = RuneNexusGame(saveRepository: repository);
  game.onGameResize(Vector2(400, 800));
  await game.onLoad();
  return game;
}

Future<({RuneNexusGame game, MemorySaveRepository repository})> _reward({
  GemType? equipped,
  bool purchased = false,
}) async {
  final repository = MemorySaveRepository()
    ..data = saveWithResearch(
      clearedStageNumbers: const {},
      researchLevels: const {},
      gemShards: 40,
      roundIndex: 1,
      mapSignature: const GameSaveAdapter().mapSignature(gameMap),
    );
  final initial = await _load(repository);
  initial.tryBuildTurret(_target);
  if (equipped != null) {
    initial.grantGem(equipped);
    initial.equipSelectedTurret(equipped);
  }
  await initial.saveNow();
  // 실제 포탑 직렬화를 유지한 보상 진입 시점 구성.
  final json = repository.data!.toJson();
  final run = json['activeRun']! as Map<String, Object?>;
  run['phase'] = GamePhase.reward.name;
  run['isPurchasedGemReward'] = purchased;
  run['rewardOptions'] = _options.map((type) => type.name).toList();
  repository.data = GameSaveData.fromJson(json)!;
  return (game: await _load(repository), repository: repository);
}

void main() {
  test(
    'reward targeting preserves an already zoomed and panned camera',
    () async {
      final fixture = await _reward();
      final game = fixture.game;
      game.selectRewardGemShards();
      expect(game.snapshotNotifier.value.phase, GamePhase.preparation);
      game.handleTrackpadZoomStart(
        const PointerPanZoomStartEvent(position: Offset(200, 400)),
      );
      game.handleTrackpadZoomUpdate(
        const PointerPanZoomUpdateEvent(position: Offset(200, 400), scale: 1.5),
      );
      game.handleBoardPointerDown(
        const PointerDownEvent(pointer: 1, position: Offset(200, 400)),
      );
      game.handleBoardPointerMove(
        const PointerMoveEvent(pointer: 1, position: Offset(230, 440)),
      );
      game.handleBoardPointerUp(
        const PointerUpEvent(pointer: 1, position: Offset(230, 440)),
      );
      expect(game.debugBoardZoom(), 1.5);
      expect(game.debugBoardOffset().length2, greaterThan(0));
      final probe = _BoardTransformProbe();
      await game.add(probe);
      await game.ready();
      final before = _renderBoardTransform(game, probe);

      expect(game.purchaseGemChoice(), isTrue);
      expect(_renderBoardTransform(game, probe), before);
      final gem = game.snapshotNotifier.value.rewardOptions.firstWhere(
        (type) => canEquipGemOnTurret(type, gameTurrets[TurretType.arrow]!),
      );
      expect(game.previewRewardGem(gem), isTrue);
      game.setGemRewardBoardViewport(const Rect.fromLTWH(24, 240, 352, 400));
      expect(_renderBoardTransform(game, probe), before);
      game.clearRewardGemPreview();
      expect(_renderBoardTransform(game, probe), before);

      expect(game.previewRewardGem(gem), isTrue);
      game.setGemRewardBoardViewport(const Rect.fromLTWH(24, 220, 352, 440));
      expect(_renderBoardTransform(game, probe), before);
      expect(game.selectRewardGemTarget(_target), isTrue);
      expect(_renderBoardTransform(game, probe), before);
    },
  );

  test(
    'reward targeting and completion preserve the rendered camera',
    () async {
      final fixture = await _reward();
      final game = fixture.game;
      final probe = _BoardTransformProbe();
      await game.add(probe);
      await game.ready();
      final before = _renderBoardTransform(game, probe);

      expect(game.previewRewardGem(GemType.range), isTrue);
      game.setGemRewardBoardViewport(const Rect.fromLTWH(24, 240, 352, 400));
      expect(_renderBoardTransform(game, probe), before);
      game.clearRewardGemPreview();
      expect(_renderBoardTransform(game, probe), before);

      expect(game.previewRewardGem(GemType.range), isTrue);
      game.setGemRewardBoardViewport(const Rect.fromLTWH(24, 220, 352, 440));
      expect(_renderBoardTransform(game, probe), before);
      expect(game.selectRewardGemTarget(_target), isTrue);
      expect(_renderBoardTransform(game, probe), before);
    },
  );

  test(
    'reward replacement uses the original screen position for taps and anchor',
    () async {
      final fixture = await _reward(equipped: GemType.attackSpeed);
      final game = fixture.game;
      final origin = game.debugBoardOrigin();
      final tileSize = game.debugBoardSize().x / gameMap.columns;
      final screen = Offset(
        origin.x + (_target.x + 0.5) * tileSize,
        origin.y + (_target.y + 0.5) * tileSize,
      );
      final viewport = Rect.fromCenter(center: screen, width: 120, height: 120);
      expect(game.previewRewardGem(GemType.range), isTrue);
      game.setGemRewardBoardViewport(viewport);
      tapBuildTile(game, _target);
      expect(game.snapshotNotifier.value.rewardReplacementPoint, isNull);
      final release = TapUpEvent(
        1,
        game,
        TapUpDetails(globalPosition: screen, kind: PointerDeviceKind.touch),
      )..renderingTrace.add(Vector2(screen.dx, screen.dy));
      game.onTapUp(release);
      expect(game.snapshotNotifier.value.rewardReplacementPoint, _target);
      expect(game.gemRewardReplacementAnchor!.dx, closeTo(0.5, 0.000001));
      expect(game.gemRewardReplacementAnchor!.dy, closeTo(0.5, 0.000001));
    },
  );

  test('preview and cancellation never acquire or consume a reward', () async {
    final fixture = await _reward();
    final game = fixture.game;
    final before = game.snapshotNotifier.value;

    expect(game.previewRewardGem(GemType.range), isTrue);
    expect(game.snapshotNotifier.value.pendingRewardGem, GemType.range);
    expect(game.previewRewardGem(GemType.attackSpeed), isTrue);
    expect(game.snapshotNotifier.value.pendingRewardGem, GemType.attackSpeed);
    game.clearRewardGemPreview();

    final after = game.snapshotNotifier.value;
    expect(after.pendingRewardGem, isNull);
    expect(after.phase, GamePhase.reward);
    expect(after.rewardOptions, before.rewardOptions);
    expect(after.gemInventory, before.gemInventory);
    expect(after.gemShards, before.gemShards);
    expect(game.storeRewardGem(), isFalse);
    expect(game.previewRewardGem(GemType.chain), isFalse);
  });

  test('empty socket acquires exactly one gem and closes the reward', () async {
    final fixture = await _reward();
    final game = fixture.game;
    expect(game.previewRewardGem(GemType.range), isTrue);
    expect(
      game.gemRewardTargetStatus(_target),
      GemRewardTargetStatus.available,
    );
    expect(game.selectRewardGemTarget(_target), isTrue);
    expect(game.selectRewardGemTarget(_target), isFalse);
    expect(game.storeRewardGem(), isFalse);
    await game.saveNow();

    final saved = fixture.repository.data!.activeRun!;
    expect(saved.turrets.single.equippedGemSlots, [GemType.range]);
    expect(saved.gemInventory, isEmpty);
    expect(saved.rewardOptions, isEmpty);
    expect(saved.phase, GamePhase.preparation);
    expect(game.snapshotNotifier.value.pendingRewardGem, isNull);
  });

  test(
    'full socket waits for replacement and returns the old gem once',
    () async {
      final fixture = await _reward(equipped: GemType.attackSpeed);
      final game = fixture.game;
      expect(game.previewRewardGem(GemType.range), isTrue);
      expect(
        game.gemRewardTargetStatus(_target),
        GemRewardTargetStatus.replacement,
      );
      expect(game.selectRewardGemTarget(_target), isTrue);
      expect(game.snapshotNotifier.value.rewardReplacementPoint, _target);
      expect(game.snapshotNotifier.value.phase, GamePhase.reward);
      expect(game.snapshotNotifier.value.gemInventory, isEmpty);
      expect(game.replaceRewardGem(-1), isFalse);
      expect(game.replaceRewardGem(1), isFalse);
      game.cancelRewardGemReplacement();
      expect(game.snapshotNotifier.value.rewardReplacementPoint, isNull);
      expect(game.snapshotNotifier.value.pendingRewardGem, GemType.range);
      expect(game.selectRewardGemTarget(_target), isTrue);
      expect(game.replaceRewardGem(0), isTrue);
      expect(game.replaceRewardGem(0), isFalse);
      await game.saveNow();

      final saved = fixture.repository.data!.activeRun!;
      expect(saved.turrets.single.equippedGemSlots, [GemType.range]);
      expect(saved.gemInventory, {GemType.attackSpeed: 1});
      expect(saved.rewardOptions, isEmpty);
    },
  );

  test(
    'duplicate incompatible and missing targets leave reward intact',
    () async {
      final fixture = await _reward(equipped: GemType.range);
      final game = fixture.game;
      expect(game.previewRewardGem(GemType.range), isTrue);
      expect(
        game.gemRewardTargetStatus(_target),
        GemRewardTargetStatus.unavailable,
      );
      expect(game.selectRewardGemTarget(_target), isFalse);
      expect(game.previewRewardGem(GemType.heavyWeapon), isTrue);
      expect(
        game.gemRewardTargetStatus(_target),
        GemRewardTargetStatus.unavailable,
      );
      expect(game.selectRewardGemTarget(_target), isFalse);
      expect(game.selectRewardGemTarget(const GridPoint(-1, -1)), isFalse);
      expect(game.replaceRewardGem(0), isFalse);
      await game.saveNow();

      final saved = fixture.repository.data!.activeRun!;
      expect(saved.rewardOptions, _options);
      expect(saved.turrets.single.equippedGemSlots, [GemType.range]);
      expect(saved.gemInventory, isEmpty);
      expect(saved.gemShards, 40);
    },
  );

  test(
    'preview save restores unclaimed options and storage acquires once',
    () async {
      final fixture = await _reward(purchased: true);
      expect(fixture.game.previewRewardGem(GemType.range), isTrue);
      await fixture.game.saveNow();
      final restored = await _load(fixture.repository);
      expect(restored.snapshotNotifier.value.pendingRewardGem, isNull);
      expect(restored.snapshotNotifier.value.rewardOptions, _options);
      expect(restored.snapshotNotifier.value.gemInventory, isEmpty);
      expect(restored.snapshotNotifier.value.gemShards, 40);
      expect(restored.previewRewardGem(GemType.range), isTrue);
      expect(restored.storeRewardGem(), isTrue);
      expect(restored.storeRewardGem(), isFalse);
      await restored.saveNow();
      final reloaded = await _load(fixture.repository);
      expect(reloaded.snapshotNotifier.value.gemInventory, {GemType.range: 1});
      expect(reloaded.snapshotNotifier.value.rewardOptions, isEmpty);
      expect(reloaded.snapshotNotifier.value.gemShards, 40);
    },
  );

  test(
    'replacement preview restore keeps old socket until final commit',
    () async {
      final fixture = await _reward(
        equipped: GemType.attackSpeed,
        purchased: true,
      );
      fixture.game.previewRewardGem(GemType.range);
      fixture.game.selectRewardGemTarget(_target);
      await fixture.game.saveNow();
      final restored = await _load(fixture.repository);
      expect(restored.snapshotNotifier.value.rewardReplacementPoint, isNull);
      expect(restored.snapshotNotifier.value.pendingRewardGem, isNull);
      expect(restored.snapshotNotifier.value.gemInventory, isEmpty);
      expect(restored.snapshotNotifier.value.rewardOptions, _options);
      restored.previewRewardGem(GemType.range);
      restored.selectRewardGemTarget(_target);
      expect(restored.replaceRewardGem(0), isTrue);
      await restored.saveNow();
      await _load(fixture.repository);
      final saved = fixture.repository.data!.activeRun!;
      expect(saved.turrets.single.equippedGemSlots, [GemType.range]);
      expect(saved.gemInventory, {GemType.attackSpeed: 1});
      expect(saved.rewardOptions, isEmpty);
    },
  );

  for (final initiallyPaused in [false, true]) {
    test(
      'combat purchase preserves engine pause=$initiallyPaused until completion',
      () async {
        final repository = MemorySaveRepository()
          ..data = saveWithResearch(
            clearedStageNumbers: const {},
            researchLevels: const {},
            gemShards: 40,
            roundIndex: 1,
            mapSignature: const GameSaveAdapter().mapSignature(gameMap),
          );
        final game = await _load(repository);
        game.startNextWave();
        final enemy = targetPriorityEnemy(
          game: game,
          hp: 100,
          progress: 0,
          position: Vector2.zero(),
        );
        game.enemies.add(enemy);
        await game.add(enemy);
        if (initiallyPaused) game.pauseEngine();
        expect(game.purchaseGemChoice(), isTrue);
        expect(game.paused, initiallyPaused);
        final gem = game.snapshotNotifier.value.rewardOptions.first;
        expect(game.previewRewardGem(gem), isTrue);
        final before = enemy.distanceTravelled;
        game.update(1);
        expect(enemy.distanceTravelled, before);
        expect(game.snapshotNotifier.value.gemShards, 20);
        expect(game.snapshotNotifier.value.gemInventory, isEmpty);
        expect(game.storeRewardGem(), isTrue);
        expect(game.snapshotNotifier.value.phase, GamePhase.wave);
        expect(game.paused, initiallyPaused);
        if (!initiallyPaused) {
          game.update(0.1);
          expect(enemy.distanceTravelled, greaterThan(before));
        }
      },
    );
  }

  test(
    'free shard alternative clears preview and purchased alternative stays blocked',
    () async {
      final free = await _reward();
      free.game.previewRewardGem(GemType.range);
      free.game.selectRewardGemShards();
      expect(free.game.snapshotNotifier.value.gemShards, 50);
      expect(free.game.snapshotNotifier.value.pendingRewardGem, isNull);
      expect(free.game.snapshotNotifier.value.gemInventory, isEmpty);
      expect(free.game.storeRewardGem(), isFalse);

      final purchased = await _reward(purchased: true);
      purchased.game.previewRewardGem(GemType.range);
      purchased.game.selectRewardGemShards();
      expect(purchased.game.snapshotNotifier.value.gemShards, 40);
      expect(purchased.game.snapshotNotifier.value.phase, GamePhase.reward);
      expect(purchased.game.snapshotNotifier.value.rewardOptions, _options);
      expect(purchased.game.storeRewardGem(), isTrue);
    },
  );

  test('legacy selection still stores a reward directly', () async {
    final fixture = await _reward();
    fixture.game.selectRewardGem(GemType.range);
    fixture.game.selectRewardGem(GemType.range);
    expect(fixture.game.snapshotNotifier.value.gemInventory, {
      GemType.range: 1,
    });
    expect(fixture.game.snapshotNotifier.value.phase, GamePhase.preparation);
  });
}
