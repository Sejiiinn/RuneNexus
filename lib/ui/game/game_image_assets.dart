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
const String gamePanelFrameAsset =
    'assets/images/ui/components/panel_frame.png';
const String gameCardFrameAsset = 'assets/images/ui/components/card_frame.png';
const String gameRowFrameAsset = 'assets/images/ui/components/row_frame.png';
const String gameLockedRowFrameAsset =
    'assets/images/ui/components/row_frame_locked.png';
const String gameButtonFrameAsset =
    'assets/images/ui/components/button_frame.png';
const String gameChipFrameAsset = 'assets/images/ui/components/chip_frame.png';
const String gameIconSocketAsset =
    'assets/images/ui/components/icon_socket.png';
const String gameSegmentedControlFrameAsset =
    'assets/images/ui/components/segmented_control_frame.png';
const String gameSegmentSelectedCyanAsset =
    'assets/images/ui/components/segment_selected_cyan.png';
const String gameSegmentSelectedGoldAsset =
    'assets/images/ui/components/segment_selected_gold.png';
const String stageDetailsDialogFrameAsset =
    'assets/images/stage_details/ui/dialog_frame.png';
const String stageDetailsHeaderIconSocketAsset =
    'assets/images/stage_details/ui/header_icon_socket.png';
const String stageDetailsCloseButtonFrameAsset =
    'assets/images/stage_details/ui/close_button_frame.png';
const String stageDetailsStatusChipFrameAsset =
    'assets/images/stage_details/ui/status_chip_frame.png';
const String stageDetailsQuickStatFrameAsset =
    'assets/images/stage_details/ui/quick_stat_frame.png';
const String stageDetailsUnlockPanelFrameAsset =
    'assets/images/stage_details/ui/unlock_panel_frame.png';
const String stageDetailsUnlockChipFrameAsset =
    'assets/images/stage_details/ui/unlock_chip_frame.png';
const String stageDetailsActionButtonFrameAsset =
    'assets/images/stage_details/ui/action_button_frame.png';
const String resultPanelFrameAsset =
    'assets/images/results/ui/result_panel_frame.png';
const String resultStatusEmblemSocketAsset =
    'assets/images/results/ui/status_emblem_socket.png';
const String resultRewardSummaryFrameAsset =
    'assets/images/results/ui/reward_summary_frame.png';
const String resultSectionFrameAsset =
    'assets/images/results/ui/section_frame.png';
const String resultUnlockChipFrameAsset =
    'assets/images/results/ui/unlock_chip_frame.png';
const String resultConfirmButtonFrameAsset =
    'assets/images/results/ui/confirm_button_frame.png';
const String resultConfirmButtonDangerFrameAsset =
    'assets/images/results/ui/confirm_button_danger_frame.png';
const String resultRestartButtonFrameAsset =
    'assets/images/results/ui/restart_button_frame.png';
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
const String turretModulePreviewFrameAsset =
    'assets/images/turret_modules/ui/turret_preview_frame.png';
const String turretModuleConnectorAssemblyAsset =
    'assets/images/turret_modules/ui/turret_connector_assembly.png';

enum GameUiAssetQuality {
  standard(scale: 1, variantDirectory: null),
  high(scale: 3, variantDirectory: '3.0x'),
  ultra(scale: 4, variantDirectory: '4.0x');

  const GameUiAssetQuality({
    required this.scale,
    required this.variantDirectory,
  });

  final double scale;
  final String? variantDirectory;
}

// 추후 사용자 화질 설정 연동 지점
const GameUiAssetQuality defaultGameUiAssetQuality = GameUiAssetQuality.ultra;

const Set<String> resolutionVariantUiImageAssets = {
  gamePanelFrameAsset,
  gameCardFrameAsset,
  gameRowFrameAsset,
  gameLockedRowFrameAsset,
  gameButtonFrameAsset,
  gameChipFrameAsset,
  gameIconSocketAsset,
  gameSegmentedControlFrameAsset,
  gameSegmentSelectedCyanAsset,
  gameSegmentSelectedGoldAsset,
  turretModulePreviewFrameAsset,
  turretModuleConnectorAssemblyAsset,
};

ImageProvider<Object> gameUiAssetImageProvider(
  String asset, {
  GameUiAssetQuality quality = defaultGameUiAssetQuality,
}) {
  final variantDirectory = quality.variantDirectory;
  if (variantDirectory == null ||
      !resolutionVariantUiImageAssets.contains(asset)) {
    return AssetImage(asset);
  }
  final separator = asset.lastIndexOf('/');
  final variantAsset =
      '${asset.substring(0, separator + 1)}$variantDirectory/'
      '${asset.substring(separator + 1)}';
  return ExactAssetImage(variantAsset, scale: quality.scale);
}

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
  gamePanelFrameAsset,
  gameCardFrameAsset,
  gameRowFrameAsset,
  gameLockedRowFrameAsset,
  gameButtonFrameAsset,
  gameChipFrameAsset,
  gameIconSocketAsset,
  gameSegmentedControlFrameAsset,
  gameSegmentSelectedCyanAsset,
  gameSegmentSelectedGoldAsset,
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

const List<String> upgradeUiImageAssets = [];

const List<String> researchUiImageAssets = [];

const List<String> turretModuleUiImageAssets = [
  turretModulePreviewFrameAsset,
  turretModuleConnectorAssemblyAsset,
];

const List<String> stageDetailsUiImageAssets = [
  stageDetailsDialogFrameAsset,
  stageDetailsHeaderIconSocketAsset,
  stageDetailsCloseButtonFrameAsset,
  stageDetailsStatusChipFrameAsset,
  stageDetailsQuickStatFrameAsset,
  stageDetailsUnlockPanelFrameAsset,
  stageDetailsUnlockChipFrameAsset,
  stageDetailsActionButtonFrameAsset,
];

const List<String> resultUiImageAssets = [
  resultPanelFrameAsset,
  resultStatusEmblemSocketAsset,
  resultRewardSummaryFrameAsset,
  resultSectionFrameAsset,
  resultUnlockChipFrameAsset,
  resultConfirmButtonFrameAsset,
  resultConfirmButtonDangerFrameAsset,
  resultRestartButtonFrameAsset,
];

const List<String> corePassiveTreeAssets = [
  corePassiveTreeBackgroundAsset,
  corePassiveTreeCoreAsset,
  corePassiveTreeFrameAsset,
];

List<ImageProvider<Object>> runeNexusStartupImageProviders() {
  final providers = <ImageProvider<Object>>[
    for (final asset in commonUiImageAssets) gameUiAssetImageProvider(asset),
    for (final asset in stageUiImageAssets) AssetImage(asset),
    for (final asset in questUiImageAssets) AssetImage(asset),
    for (final asset in upgradeUiImageAssets) AssetImage(asset),
    for (final asset in researchUiImageAssets) AssetImage(asset),
    for (final asset in turretModuleUiImageAssets)
      gameUiAssetImageProvider(asset),
    for (final asset in stageDetailsUiImageAssets) AssetImage(asset),
    for (final asset in resultUiImageAssets) AssetImage(asset),
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
