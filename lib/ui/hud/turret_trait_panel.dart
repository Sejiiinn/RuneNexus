import 'package:flutter/material.dart';

import '../../domain/turret/turret_trait_type.dart';
import '../../game/game_snapshot.dart';
import '../game/game_ui.dart';
import 'hud_common.dart';

class HudTurretTraitActionButton extends StatelessWidget {
  const HudTurretTraitActionButton({
    required this.snapshot,
    required this.onPressed,
    super.key,
  });

  final GameSnapshot snapshot;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final selected = snapshot.selectedTurretPrimaryTrait != null;
    final readyPrimary =
        snapshot.selectedTurretCanChoosePrimaryTrait &&
        snapshot.gemShards >= snapshot.selectedTurretPrimaryTraitCost;
    final readySecondary =
        snapshot.selectedTurretCanChooseSecondaryTrait &&
        snapshot.gemShards >= snapshot.selectedTurretSecondaryTraitCost;
    final ready = readyPrimary || readySecondary;
    final complete = snapshot.selectedTurretSecondaryTrait != null;
    final locked = !selected && !ready;
    final color = locked ? const Color(0xFF607587) : const Color(0xFF63E6A5);
    final badgeIcon = complete
        ? Icons.done_all
        : selected
        ? Icons.check
        : ready
        ? Icons.priority_high
        : Icons.lock_outline;

    return Tooltip(
      message: '특성',
      child: SizedBox(
        width: 34,
        height: 30,
        child: GameButton(
          onPressed: onPressed,
          compact: true,
          variant: locked ? GameButtonVariant.ghost : GameButtonVariant.confirm,
          accentColor: color,
          padding: EdgeInsets.zero,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(child: Icon(Icons.auto_awesome, size: 15)),
              Positioned(
                right: -2,
                top: -3,
                child: _TraitActionBadge(icon: badgeIcon, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraitActionBadge extends StatelessWidget {
  const _TraitActionBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 13,
      height: 13,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF07111D),
        border: Border.all(color: color, width: 1.2),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 9, color: color),
    );
  }
}

class HudTurretTraitDialog extends StatefulWidget {
  const HudTurretTraitDialog({required this.snapshot, super.key});

  final GameSnapshot snapshot;

  @override
  State<HudTurretTraitDialog> createState() => _TurretTraitDialogState();
}

class _TurretTraitDialogState extends State<HudTurretTraitDialog> {
  late int _selectedTier = widget.snapshot.selectedTurretPrimaryTrait != null
      ? 2
      : 1;
  int? _previewTier;
  TurretTraitType? _previewTrait;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final primary = snapshot.selectedTurretPrimaryTrait;
    final secondary = snapshot.selectedTurretSecondaryTrait;
    final primaryChoices = snapshot.selectedTurretPrimaryTraitChoices;
    final secondaryChoices = snapshot.selectedTurretSecondaryTraitChoices;
    final canChoosePrimary =
        snapshot.selectedTurretCanChoosePrimaryTrait &&
        snapshot.gemShards >= snapshot.selectedTurretPrimaryTraitCost;
    final canChooseSecondary =
        snapshot.selectedTurretCanChooseSecondaryTrait &&
        snapshot.gemShards >= snapshot.selectedTurretSecondaryTraitCost;
    final primaryBlockedText = _primaryTraitBlockedText(snapshot);
    final secondaryBlockedText = _secondaryTraitBlockedText(snapshot);
    final size = MediaQuery.sizeOf(context);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 20),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 344,
          maxHeight: size.height * 0.82,
        ),
        child: GamePanel(
          variant: GamePanelVariant.reward,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _TraitDialogHeader(
                title: '${snapshot.selectedTurretName ?? '포탑'} 특성',
              ),
              _TraitResourceStrip(
                gemShards: snapshot.gemShards,
                primaryCost: snapshot.selectedTurretPrimaryTraitCost,
                secondaryCost: snapshot.selectedTurretSecondaryTraitCost,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _TraitSlotButton(
                        tierText: '1차',
                        title: '무기 개조',
                        trait: primary,
                        active: _selectedTier == 1,
                        enabled: primaryChoices.isNotEmpty,
                        blockedText: primaryBlockedText,
                        onTap: () => _selectTier(1),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: _TraitSlotButton(
                        tierText: '2차',
                        title: '전투 교리',
                        trait: secondary,
                        active: _selectedTier == 2,
                        enabled: secondaryChoices.isNotEmpty,
                        blockedText: secondaryBlockedText,
                        onTap: () => _selectTier(2),
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                  child: _selectedTier == 1
                      ? _TraitTierPane(
                          tierText: '1차',
                          title: '무기 개조',
                          selectedTrait: primary,
                          blockedText: primaryBlockedText,
                          choices: primaryChoices,
                          enabled: canChoosePrimary,
                          tier: 1,
                          previewTrait: _previewTier == 1
                              ? _previewTrait
                              : null,
                          onPreview: _previewOrConfirmTrait,
                        )
                      : _TraitTierPane(
                          tierText: '2차',
                          title: '전투 교리',
                          selectedTrait: secondary,
                          blockedText: secondaryBlockedText,
                          choices: secondaryChoices,
                          enabled: canChooseSecondary,
                          tier: 2,
                          previewTrait: _previewTier == 2
                              ? _previewTrait
                              : null,
                          onPreview: _previewOrConfirmTrait,
                        ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 10),
                child: Text(
                  '선택한 특성은 이번 런 동안 변경할 수 없습니다.',
                  style: TextStyle(
                    fontSize: 10,
                    color: Color(0xFF8AA6B8),
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _primaryTraitBlockedText(GameSnapshot snapshot) {
    if (!snapshot.selectedTurretCanChoosePrimaryTrait) {
      return '1차 특성은 Lv.${snapshot.selectedTurretPrimaryTraitRequiredLevel}부터 선택할 수 있습니다.';
    }
    if (snapshot.gemShards < snapshot.selectedTurretPrimaryTraitCost) {
      return '젬 파편이 ${snapshot.selectedTurretPrimaryTraitCost - snapshot.gemShards}개 부족합니다.';
    }
    return null;
  }

  String? _secondaryTraitBlockedText(GameSnapshot snapshot) {
    if (snapshot.selectedTurretPrimaryTrait == null) {
      return '2차 특성은 1차 특성을 먼저 선택해야 합니다.';
    }
    if (!snapshot.selectedTurretCanChooseSecondaryTrait) {
      return '2차 특성은 Lv.${snapshot.selectedTurretSecondaryTraitRequiredLevel}부터 선택할 수 있습니다.';
    }
    if (snapshot.gemShards < snapshot.selectedTurretSecondaryTraitCost) {
      return '젬 파편이 ${snapshot.selectedTurretSecondaryTraitCost - snapshot.gemShards}개 부족합니다.';
    }
    return null;
  }

  void _selectTier(int tier) {
    setState(() {
      _selectedTier = tier;
      _previewTier = null;
      _previewTrait = null;
    });
  }

  void _previewOrConfirmTrait(int tier, TurretTraitType trait) {
    if (_previewTier == tier && _previewTrait == trait) {
      Navigator.of(context).pop(HudTraitSelection(tier: tier, trait: trait));
      return;
    }
    setState(() {
      _previewTier = tier;
      _previewTrait = trait;
    });
  }
}

class _TraitDialogHeader extends StatelessWidget {
  const _TraitDialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 7),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0x2263E6A5))),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF63E6A5), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE8F8FF),
              ),
              overflow: TextOverflow.clip,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _TraitSlotButton extends StatelessWidget {
  const _TraitSlotButton({
    required this.tierText,
    required this.title,
    required this.trait,
    required this.active,
    required this.enabled,
    required this.blockedText,
    required this.onTap,
  });

  final String tierText;
  final String title;
  final TurretTraitType? trait;
  final bool active;
  final bool enabled;
  final String? blockedText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final selected = trait != null;
    final borderColor = active
        ? const Color(0xCC63E6A5)
        : selected
        ? const Color(0x8863E6A5)
        : const Color(0x444A6172);
    final statusText = selected
        ? trait!.nameText
        : blockedText == null
        ? '선택 가능'
        : '대기 중';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onTap : null,
      child: Container(
        height: 54,
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: active ? const Color(0x2263E6A5) : const Color(0x7707111D),
          border: Border.all(color: borderColor, width: active ? 1.4 : 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF07111D),
                border: Border.all(
                  color: selected
                      ? _traitAccentColor(trait!)
                      : const Color(0x6663E6A5),
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: selected
                  ? Icon(
                      _traitIcon(trait!),
                      size: 15,
                      color: _traitAccentColor(trait!),
                    )
                  : Text(
                      tierText,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF63E6A5),
                      ),
                    ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8F8FF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    statusText,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? _traitAccentColor(trait!)
                          : const Color(0xFF8AA6B8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TraitTierPane extends StatelessWidget {
  const _TraitTierPane({
    required this.tierText,
    required this.title,
    required this.selectedTrait,
    required this.blockedText,
    required this.choices,
    required this.enabled,
    required this.tier,
    required this.previewTrait,
    required this.onPreview,
  });

  final String tierText;
  final String title;
  final TurretTraitType? selectedTrait;
  final String? blockedText;
  final List<TurretTraitType> choices;
  final bool enabled;
  final int tier;
  final TurretTraitType? previewTrait;
  final void Function(int tier, TurretTraitType trait) onPreview;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: selectedTrait != null
            ? const Color(0x1F63E6A5)
            : const Color(0x6607111D),
        border: Border.all(
          color: selectedTrait != null
              ? const Color(0x9963E6A5)
              : const Color(0x3333D8FF),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _TierChip(text: tierText),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                ),
              ),
              Icon(
                selectedTrait != null
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                size: 16,
                color: selectedTrait != null
                    ? const Color(0xFF63E6A5)
                    : const Color(0xFF607587),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (selectedTrait != null)
            _SelectedTraitSummary(trait: selectedTrait!)
          else ...[
            if (blockedText != null) ...[
              _TraitBlockedNotice(text: blockedText!),
              const SizedBox(height: 7),
            ],
            if (choices.isEmpty)
              _TraitLockedSummary(text: '선택 가능한 특성이 없습니다.')
            else
              for (var i = 0; i < choices.length; i++) ...[
                if (i > 0) const SizedBox(height: 6),
                _CompactTraitChoiceButton(
                  trait: choices[i],
                  enabled: enabled,
                  tier: tier,
                  previewed: previewTrait == choices[i],
                  onPreview: onPreview,
                ),
              ],
          ],
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  const _TierChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF07111D),
        border: Border.all(color: const Color(0x9963E6A5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Color(0xFF63E6A5),
        ),
      ),
    );
  }
}

class _TraitLockedSummary extends StatelessWidget {
  const _TraitLockedSummary({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x7707111D),
        border: Border.all(color: const Color(0x444A6172)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF07111D),
              border: Border.all(color: const Color(0x66607486)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.lock_outline,
              size: 15,
              color: Color(0xFF8AA6B8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8AA6B8),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactTraitChoiceButton extends StatelessWidget {
  const _CompactTraitChoiceButton({
    required this.trait,
    required this.enabled,
    required this.tier,
    required this.previewed,
    required this.onPreview,
  });

  final TurretTraitType trait;
  final bool enabled;
  final int tier;
  final bool previewed;
  final void Function(int tier, TurretTraitType trait) onPreview;

  @override
  Widget build(BuildContext context) {
    final accent = _traitAccentColor(trait);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? () => onPreview(tier, trait) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 66),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: previewed
              ? accent.withValues(alpha: 0.18)
              : enabled
              ? const Color(0xAA0B2230)
              : const Color(0x6607111D),
          border: Border.all(
            color: previewed
                ? accent
                : enabled
                ? accent.withValues(alpha: 0.54)
                : const Color(0x554A6172),
            width: previewed ? 1.4 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: enabled ? 0.13 : 0.05),
                border: Border.all(
                  color: enabled
                      ? accent.withValues(alpha: 0.78)
                      : const Color(0x55607486),
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                _traitIcon(trait),
                size: 16,
                color: enabled ? accent : const Color(0xFF607587),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    trait.nameText,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: enabled
                          ? const Color(0xFFE8F8FF)
                          : const Color(0xFFB0C4CF),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    trait.shortText,
                    maxLines: 2,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: enabled
                          ? const Color(0xFFB9D6E4)
                          : const Color(0xFF7F95A4),
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            if (previewed) ...[
              const SizedBox(width: 7),
              _TraitPreviewBadge(accent: accent),
            ],
          ],
        ),
      ),
    );
  }
}

class _TraitPreviewBadge extends StatelessWidget {
  const _TraitPreviewBadge({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF07111D),
        border: Border.all(color: accent.withValues(alpha: 0.8)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '선택',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: accent,
        ),
      ),
    );
  }
}

class HudTraitSelection {
  const HudTraitSelection({required this.tier, required this.trait});

  final int tier;
  final TurretTraitType trait;
}

class _TraitResourceStrip extends StatelessWidget {
  const _TraitResourceStrip({
    required this.gemShards,
    required this.primaryCost,
    required this.secondaryCost,
  });

  final int gemShards;
  final int primaryCost;
  final int secondaryCost;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: const Color(0x3363E6A5)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                const SizedBox(width: 15, height: 15, child: HudGemShardIcon()),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text(
                    '젬 파편',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: 11, color: Color(0xFF8AA6B8)),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$gemShards',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                _TraitCostChip(label: '1차', cost: primaryCost),
                const SizedBox(width: 5),
                _TraitCostChip(label: '2차', cost: secondaryCost),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitCostChip extends StatelessWidget {
  const _TraitCostChip({required this.label, required this.cost});

  final String label;
  final int cost;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 22,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0x1F63E6A5),
        border: Border.all(color: const Color(0x6663E6A5)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Color(0xFF8AA6B8),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$cost',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: Color(0xFF63E6A5),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedTraitSummary extends StatelessWidget {
  const _SelectedTraitSummary({required this.trait});

  final TurretTraitType trait;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0x3363E6A5),
        border: Border.all(color: const Color(0xAA63E6A5)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(_traitIcon(trait), size: 17, color: _traitAccentColor(trait)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  trait.nameText,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  trait.shortText,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFC9DCE8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TraitBlockedNotice extends StatelessWidget {
  const _TraitBlockedNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x22FFC285),
        border: Border.all(color: const Color(0x55FFC285)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline, size: 13, color: Color(0xFFFFC285)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFFFFC285),
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

IconData _traitIcon(TurretTraitType trait) {
  return switch (trait) {
    TurretTraitType.overheatMagazine => Icons.local_fire_department_outlined,
    TurretTraitType.lightweightBarrel => Icons.speed,
    TurretTraitType.shrapnelShell => Icons.blur_on,
    TurretTraitType.compressedCharge => Icons.compress,
    TurretTraitType.highHeatBurn => Icons.whatshot,
    TurretTraitType.lingeringEmbers => Icons.hourglass_bottom,
    TurretTraitType.ignitionBurst => Icons.flare,
    TurretTraitType.chainIgnition => Icons.grain,
    TurretTraitType.rapidCooling => Icons.ac_unit,
    TurretTraitType.spreadingChill => Icons.blur_circular,
    TurretTraitType.frostCrack => Icons.auto_awesome,
    TurretTraitType.coolingCycle => Icons.cyclone,
    TurretTraitType.suppressiveFire => Icons.gps_fixed,
    TurretTraitType.chainCleanup => Icons.hub_outlined,
    TurretTraitType.expandedBlastCore => Icons.blur_on,
    TurretTraitType.fractureImpact => Icons.my_location,
    TurretTraitType.deadeyeFocus => Icons.center_focus_strong,
    TurretTraitType.quickScope => Icons.flash_on,
    TurretTraitType.exposedMark => Icons.filter_center_focus,
    TurretTraitType.finishingShot => Icons.offline_bolt,
    TurretTraitType.branchCurrent => Icons.hub_outlined,
    TurretTraitType.focusedLightning => Icons.thunderstorm_outlined,
    TurretTraitType.lightningRecovery => Icons.replay_circle_filled_outlined,
    TurretTraitType.currentAmplification => Icons.electric_bolt,
  };
}

Color _traitAccentColor(TurretTraitType trait) {
  return switch (trait) {
    TurretTraitType.overheatMagazine => const Color(0xFFFFB45E),
    TurretTraitType.lightweightBarrel => const Color(0xFF8EE6FF),
    TurretTraitType.shrapnelShell => const Color(0xFFFF9A5F),
    TurretTraitType.compressedCharge => const Color(0xFFFFD166),
    TurretTraitType.highHeatBurn => const Color(0xFFFF6B45),
    TurretTraitType.lingeringEmbers => const Color(0xFFFFC15E),
    TurretTraitType.ignitionBurst => const Color(0xFFFF9D45),
    TurretTraitType.chainIgnition => const Color(0xFFFFC857),
    TurretTraitType.rapidCooling => const Color(0xFF96EAFF),
    TurretTraitType.spreadingChill => const Color(0xFF7FD8FF),
    TurretTraitType.frostCrack => const Color(0xFFB7F4FF),
    TurretTraitType.coolingCycle => const Color(0xFF7EE8D4),
    TurretTraitType.suppressiveFire => const Color(0xFF63E6A5),
    TurretTraitType.chainCleanup => const Color(0xFFD7F27C),
    TurretTraitType.expandedBlastCore => const Color(0xFFFF9A5F),
    TurretTraitType.fractureImpact => const Color(0xFFFFD166),
    TurretTraitType.deadeyeFocus => const Color(0xFFB7F4FF),
    TurretTraitType.quickScope => const Color(0xFF8EE6FF),
    TurretTraitType.exposedMark => const Color(0xFFD7F27C),
    TurretTraitType.finishingShot => const Color(0xFFFFD166),
    TurretTraitType.branchCurrent => const Color(0xFFCFA7FF),
    TurretTraitType.focusedLightning => const Color(0xFFE8FBFF),
    TurretTraitType.lightningRecovery => const Color(0xFF8CFFF3),
    TurretTraitType.currentAmplification => const Color(0xFFB98CFF),
  };
}
