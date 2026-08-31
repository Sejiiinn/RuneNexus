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
const String mainMenuBackgroundAsset = 'assets/images/main_menu_background.jpg';
const String gameLogoAsset = 'assets/images/rune_nexus_logo_serif.png';
const String stageReferenceShellFillAsset =
    'assets/images/ui/stage_reference/stage_shell_fill.png';
const String stageReferenceShellFrameAsset =
    'assets/images/ui/stage_reference/stage_shell_frame.png';
const String stageReferenceChapterTabIdleAsset =
    'assets/images/ui/stage_reference/chapter_tab_idle.png';
const String stageReferenceChapterTabSelectedAsset =
    'assets/images/ui/stage_reference/chapter_tab_selected.png';
const String stageReferenceBannerFrameAsset =
    'assets/images/ui/stage_reference/chapter_banner_frame.png';
const String stageReferenceBridgeAsset =
    'assets/images/ui/stage_reference/chapter_bridge.png';
const String stageReferenceActivePanelAsset =
    'assets/images/ui/stage_reference/active_stage_panel.png';
const String stageReferenceNumberSocketAsset =
    'assets/images/ui/stage_reference/stage_number_socket.png';
const String stageReferenceStatStripAsset =
    'assets/images/ui/stage_reference/stage_stat_strip.png';
const String stageReferenceContinueButtonAsset =
    'assets/images/ui/stage_reference/continue_button_idle.png';
const String stageReferenceLockedRowAsset =
    'assets/images/ui/stage_reference/locked_stage_row.png';
const String stageReferenceNumberPlateAsset =
    'assets/images/ui/stage_reference/stage_number_plate.png';
const String questDialogFrameAsset = 'assets/images/quests/ui/dialog_frame.png';
const String questTabIdleAsset = 'assets/images/quests/ui/tab_idle.png';
const String questTabSelectedAsset = 'assets/images/quests/ui/tab_selected.png';
const String questSummaryFrameAsset =
    'assets/images/quests/ui/summary_frame.png';
const String questRowFrameAsset = 'assets/images/quests/ui/quest_row_frame.png';
const String questIconSocketAsset = 'assets/images/quests/ui/icon_socket.png';
const String questActionIdleAsset = 'assets/images/quests/ui/action_idle.png';
const String questActionClaimAsset = 'assets/images/quests/ui/action_claim.png';
const String questCloseButtonAsset = 'assets/images/quests/ui/close_button.png';
const String upgradeCardFrameAsset =
    'assets/images/upgrades/ui/upgrade_card_frame.png';
const String upgradeIconSocketAsset =
    'assets/images/upgrades/ui/upgrade_icon_socket.png';
const String upgradeActionFrameAsset =
    'assets/images/upgrades/ui/upgrade_action_frame.png';
const String upgradeCostChipFrameAsset =
    'assets/images/upgrades/ui/upgrade_cost_chip_frame.png';
const String upgradeGroupFrameAsset =
    'assets/images/upgrades/ui/upgrade_group_frame.png';
const String upgradeGroupCombatSelectedAsset =
    'assets/images/upgrades/ui/upgrade_group_combat_selected.png';
const String upgradeGroupEconomySelectedAsset =
    'assets/images/upgrades/ui/upgrade_group_economy_selected.png';
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
  mainMenuBackgroundAsset,
  gameLogoAsset,
  resultSuccessEmblemAsset,
  resultFailureEmblemAsset,
];

const List<String> stageUiImageAssets = [
  stageReferenceShellFillAsset,
  stageReferenceShellFrameAsset,
  stageReferenceChapterTabIdleAsset,
  stageReferenceChapterTabSelectedAsset,
  stageReferenceBannerFrameAsset,
  stageReferenceBridgeAsset,
  stageReferenceActivePanelAsset,
  stageReferenceNumberSocketAsset,
  stageReferenceStatStripAsset,
  stageReferenceContinueButtonAsset,
  stageReferenceLockedRowAsset,
  stageReferenceNumberPlateAsset,
];

const List<String> questUiImageAssets = [
  questDialogFrameAsset,
  questTabIdleAsset,
  questTabSelectedAsset,
  questSummaryFrameAsset,
  questRowFrameAsset,
  questIconSocketAsset,
  questActionIdleAsset,
  questActionClaimAsset,
  questCloseButtonAsset,
];

const List<String> upgradeUiImageAssets = [
  upgradeCardFrameAsset,
  upgradeIconSocketAsset,
  upgradeActionFrameAsset,
  upgradeCostChipFrameAsset,
  upgradeGroupFrameAsset,
  upgradeGroupCombatSelectedAsset,
  upgradeGroupEconomySelectedAsset,
];

const List<String> corePassiveTreeAssets = [
  corePassiveTreeBackgroundAsset,
  corePassiveTreeCoreAsset,
  corePassiveTreeFrameAsset,
];

List<ImageProvider<Object>> runeNexusStartupImageProviders() {
  final providers = <ImageProvider<Object>>[
    for (final asset in commonUiImageAssets) AssetImage(asset),
    for (final asset in stageUiImageAssets) AssetImage(asset),
    for (final asset in questUiImageAssets) AssetImage(asset),
    for (final asset in upgradeUiImageAssets) AssetImage(asset),
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
