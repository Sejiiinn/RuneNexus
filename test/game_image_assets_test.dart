import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:rune_nexus/ui/game/game_image_assets.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  test(
    'startup image catalog covers every used image with matching providers',
    () {
      final providers = runeNexusStartupImageProviders();

      expect(providers, hasLength(95));
      expect(providers.whereType<ResizeImage>(), hasLength(29));
      for (final asset in commonUiImageAssets) {
        expect(providers, contains(gameUiAssetImageProvider(asset)));
      }
      for (final asset in questUiImageAssets) {
        expect(providers, contains(AssetImage(asset)));
      }
      for (final asset in upgradeUiImageAssets) {
        expect(providers, contains(AssetImage(asset)));
      }
      for (final asset in researchUiImageAssets) {
        expect(providers, contains(AssetImage(asset)));
      }
      for (final asset in turretModuleUiImageAssets) {
        expect(providers, contains(gameUiAssetImageProvider(asset)));
      }
      for (final asset in stageDetailsUiImageAssets) {
        expect(providers, contains(AssetImage(asset)));
      }
      for (final asset in resultUiImageAssets) {
        expect(providers, contains(AssetImage(asset)));
      }
      for (final type in GameUpgradeIconType.values) {
        expect(providers, contains(upgradeIconImageProvider(type)));
      }
      for (final type in ResearchType.values) {
        expect(providers, contains(researchIconImageProvider(type)));
      }
      for (final skill in CoreCombatSkill.values) {
        expect(providers, contains(coreAbilityIconImageProvider(skill)));
      }
      expect(
        corePassiveNodeIconImageProvider(CorePassiveNodeId.efficiencySaving),
        isNotNull,
      );
      expect(
        corePassiveNodeIconImageProvider(CorePassiveNodeId.controlSelfRepair),
        isNull,
      );
    },
  );

  testWidgets('app loading message follows the active startup stage', (
    tester,
  ) async {
    final repository = _DelayedSaveRepository();

    await tester.pumpWidget(
      RuneNexusApp(game: RuneNexusGame(saveRepository: repository)),
    );
    await tester.pump();

    expect(find.text('게임을 시작하는 중'), findsOneWidget);
    expect(find.text('RUNE NEXUS'), findsNothing);
    expect(find.text('룬 넥서스 준비 중'), findsNothing);

    repository.completeLoad();
    await pumpUntilFound(tester, find.text('이미지 에셋 로드 중'), maxFrameCount: 60);
    expect(find.text('게임을 시작하는 중'), findsNothing);
    await pumpUntilLoadedApp(tester);
    expect(find.byType(MainMenuScreen), findsOneWidget);
  });

  testWidgets('mobile image source dimensions stay bounded', (tester) async {
    await tester.runAsync(() async {
      final resizedProviders = runeNexusStartupImageProviders()
          .whereType<ResizeImage>();
      for (final provider in resizedProviders) {
        final source = provider.imageProvider;
        expect(source, isA<AssetImage>());
        final size = await _assetImageSize((source as AssetImage).assetName);
        expect(size.width, lessThanOrEqualTo(256));
        expect(size.height, lessThanOrEqualTo(256));
      }

      for (final asset in stageChapterBannerAssets) {
        final size = await _assetImageSize(asset);
        expect(size.width, lessThanOrEqualTo(1280));
      }
      for (final asset in [
        turretModuleTicketIconAsset,
        resultSuccessEmblemAsset,
        resultFailureEmblemAsset,
      ]) {
        final size = await _assetImageSize(asset);
        expect(size.width, lessThanOrEqualTo(256));
        expect(size.height, lessThanOrEqualTo(256));
      }
      final turretPreviewFrameSize = await _assetImageSize(
        turretModulePreviewFrameAsset,
      );
      expect(turretPreviewFrameSize, const Size(512, 512));
      final turretConnectorSize = await _assetImageSize(
        turretModuleConnectorAssemblyAsset,
      );
      expect(turretConnectorSize, const Size(456, 800));
      final sharedComponentSizes = <String, Size>{
        gamePanelFrameAsset: const Size(1504, 640),
        gameCardFrameAsset: const Size(684, 464),
        gameRowFrameAsset: const Size(1428, 176),
        gameLockedRowFrameAsset: const Size(1428, 236),
        gameButtonFrameAsset: const Size(604, 136),
        gameChipFrameAsset: const Size(240, 108),
        gameIconSocketAsset: const Size(176, 176),
        gameSegmentedControlFrameAsset: const Size(552, 172),
        gameSegmentSelectedCyanAsset: const Size(256, 128),
        gameSegmentSelectedGoldAsset: const Size(256, 128),
      };
      for (final entry in sharedComponentSizes.entries) {
        expect(await _assetImageSize(entry.key), entry.value);
      }
      final logoSize = await _assetImageSize(gameLogoAsset);
      expect(logoSize.width, lessThanOrEqualTo(1024));
      final menuBackgroundSize = await _assetImageSize(mainMenuBackgroundAsset);
      expect(menuBackgroundSize, const Size(853, 1844));
      final menuBackgroundData = await rootBundle.load(mainMenuBackgroundAsset);
      expect(menuBackgroundData.lengthInBytes, lessThanOrEqualTo(512 * 1024));
      for (final asset in [
        corePassiveTreeCoreAsset,
        corePassiveTreeFrameAsset,
      ]) {
        final size = await _assetImageSize(asset);
        expect(size.width, lessThanOrEqualTo(384));
        expect(size.height, lessThanOrEqualTo(384));
      }
      final backgroundSize = await _assetImageSize(
        corePassiveTreeBackgroundAsset,
      );
      expect(backgroundSize, const Size(1254, 1254));
    });
  });

  testWidgets('cannon blast atlas keeps twelve 256 pixel frames', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final size = await _assetImageSize(
        'assets/images/cannon_blast_core_sheet.png',
      );

      expect(size, const Size(1024, 768));
    });
  });

  testWidgets('shared UI always selects the single high resolution master', (
    tester,
  ) async {
    for (final asset in [
      gamePanelFrameAsset,
      gameCardFrameAsset,
      gameRowFrameAsset,
      gameButtonFrameAsset,
      turretModulePreviewFrameAsset,
      turretModuleConnectorAssemblyAsset,
    ]) {
      final provider = gameUiAssetImageProvider(asset);
      expect(provider, isA<ExactAssetImage>());
      final resolved = provider as ExactAssetImage;
      expect(resolved.scale, gameUiMasterAssetScale);
      expect(resolved.assetName, asset);
      expect(resolved.assetName, isNot(contains('/3.0x/')));
      expect(resolved.assetName, isNot(contains('/4.0x/')));
    }
  });
}

Future<Size> _assetImageSize(String asset) async {
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
  );
  try {
    final frame = await codec.getNextFrame();
    try {
      return Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    } finally {
      frame.image.dispose();
    }
  } finally {
    codec.dispose();
  }
}

class _DelayedSaveRepository implements SaveRepository {
  final Completer<GameSaveData?> _loadCompleter = Completer<GameSaveData?>();

  void completeLoad() {
    _loadCompleter.complete();
  }

  @override
  Future<GameSaveData?> load() => _loadCompleter.future;

  @override
  Future<void> save(GameSaveData data) async {}

  @override
  Future<void> clear() async {}
}
