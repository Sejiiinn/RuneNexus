import 'dart:async';

import 'package:flutter/material.dart';

import '../../domain/core/core_ability.dart';
import '../../domain/core/core_passive_tree.dart';
import '../../domain/research/research_type.dart';
import 'core_ability_icon.dart';
import 'research_icon.dart';
import 'upgrade_icon.dart';

const String stageChapterOneBannerAsset = 'assets/images/chapter_1_banner.png';
const String stageChapterTwoBannerAsset = 'assets/images/chapter_2_banner.png';
const String stageChapterThreeBannerAsset =
    'assets/images/chapter_3_banner.png';
const String gameLogoAsset = 'assets/images/rune_nexus_logo.png';
const String resultSuccessEmblemAsset =
    'assets/images/results/result_success.png';
const String resultFailureEmblemAsset =
    'assets/images/results/result_failure.png';
const String stageRewardUpgradeIconAsset =
    'assets/images/stage_rewards/reward_upgrade.png';
const String stageRewardResearchIconAsset =
    'assets/images/stage_rewards/reward_research.png';
const String stageRewardGemIconAsset =
    'assets/images/stage_rewards/reward_gem.png';
const String stageRewardCoreIconAsset =
    'assets/images/stage_rewards/reward_core.png';
const String stageRewardStageIconAsset =
    'assets/images/stage_rewards/reward_stage.png';
const String stageRewardTurretIconAsset =
    'assets/images/stage_rewards/reward_turret.png';
const String turretModuleTicketIconAsset =
    'assets/images/stage_rewards/reward_module_ticket.png';
const String corePassiveTreeBackgroundAsset =
    'assets/images/core_passive_tree/tree_circuit_background.png';
const String corePassiveTreeCoreAsset =
    'assets/images/core_passive_tree/nexus_core.png';
const String corePassiveTreeFrameAsset =
    'assets/images/core_passive_tree/notable_hex_frame.png';

const List<String> stageChapterBannerAssets = [
  stageChapterOneBannerAsset,
  stageChapterTwoBannerAsset,
  stageChapterThreeBannerAsset,
];

const List<String> stageRewardIconAssets = [
  stageRewardUpgradeIconAsset,
  stageRewardResearchIconAsset,
  stageRewardGemIconAsset,
  stageRewardCoreIconAsset,
  stageRewardStageIconAsset,
  stageRewardTurretIconAsset,
  turretModuleTicketIconAsset,
];

const List<String> commonUiImageAssets = [
  gameLogoAsset,
  resultSuccessEmblemAsset,
  resultFailureEmblemAsset,
];

const List<String> corePassiveTreeAssets = [
  corePassiveTreeBackgroundAsset,
  corePassiveTreeCoreAsset,
  corePassiveTreeFrameAsset,
];

List<ImageProvider<Object>> runeNexusStartupImageProviders() {
  final providers = <ImageProvider<Object>>[
    for (final asset in commonUiImageAssets) AssetImage(asset),
    for (final asset in stageChapterBannerAssets) AssetImage(asset),
    for (final asset in stageRewardIconAssets) AssetImage(asset),
    for (final type in GameUpgradeIconType.values)
      upgradeIconImageProvider(type),
    for (final type in ResearchType.values) researchIconImageProvider(type),
    for (final skill in CoreCombatSkill.values)
      coreAbilityIconImageProvider(skill),
    for (final asset in corePassiveTreeAssets) AssetImage(asset),
  ];
  for (final nodeId in CorePassiveNodeId.values) {
    final provider = corePassiveNodeIconImageProvider(nodeId);
    if (provider != null) {
      providers.add(provider);
    }
  }
  return providers;
}

Future<void> precacheRuneNexusStartupImages(
  BuildContext context, {
  ValueChanged<double>? onProgress,
}) async {
  final providers = runeNexusStartupImageProviders();
  const batchSize = 4;
  onProgress?.call(0);
  for (var start = 0; start < providers.length; start += batchSize) {
    if (!context.mounted) {
      return;
    }
    final end = (start + batchSize).clamp(0, providers.length);
    await Future.wait([
      for (var index = start; index < end; index++)
        _precacheImageOrThrow(providers[index], context),
    ]);
    onProgress?.call(end / providers.length);
  }
}

Future<void> _precacheImageOrThrow(
  ImageProvider<Object> provider,
  BuildContext context,
) {
  final completer = Completer<void>();
  precacheImage(
    provider,
    context,
    onError: (error, stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  ).then(
    (_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );
  return completer.future;
}
