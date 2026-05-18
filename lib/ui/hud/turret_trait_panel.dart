part of 'game_hud.dart';

class _TurretTraitActionButton extends StatelessWidget {
  const _TurretTraitActionButton({
    required this.snapshot,
    required this.onPressed,
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
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            backgroundColor: locked
                ? Colors.transparent
                : const Color(0x2263E6A5),
            side: BorderSide(
              color: locked
                  ? const Color(0x5533D8FF)
                  : color.withValues(alpha: 0.85),
            ),
            padding: EdgeInsets.zero,
            minimumSize: const Size(34, 30),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
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

class _TurretTraitDialog extends StatelessWidget {
  const _TurretTraitDialog({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
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

    return AlertDialog(
      backgroundColor: const Color(0xFF091624),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0x9963E6A5)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFF63E6A5), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${snapshot.selectedTurretName ?? '포탑'} 특성',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE8F8FF),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
      content: SizedBox(
        width: 340,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _TraitResourceStrip(
              gemShards: snapshot.gemShards,
              primaryCost: snapshot.selectedTurretPrimaryTraitCost,
              secondaryCost: snapshot.selectedTurretSecondaryTraitCost,
            ),
            const SizedBox(height: 12),
            if (primaryChoices.isNotEmpty)
              _TraitTierBlock(
                tierText: '1차',
                title: '무기 개조',
                selectedTrait: primary,
                blockedText: primaryBlockedText,
                choices: primaryChoices,
                enabled: canChoosePrimary,
                tier: 1,
              ),
            if (primaryChoices.isNotEmpty && secondaryChoices.isNotEmpty)
              const SizedBox(height: 10),
            if (secondaryChoices.isNotEmpty)
              _TraitTierBlock(
                tierText: '2차',
                title: '전투 교리',
                selectedTrait: secondary,
                blockedText: secondaryBlockedText,
                choices: secondaryChoices,
                enabled: canChooseSecondary,
                tier: 2,
              ),
            const SizedBox(height: 10),
            const Text(
              '선택한 특성은 이번 런 동안 변경할 수 없습니다.',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF8AA6B8),
                height: 1.25,
              ),
            ),
          ],
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
}

class _TraitSelection {
  const _TraitSelection({required this.tier, required this.trait});

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
          const SizedBox(width: 15, height: 15, child: _GemShardIcon()),
          const SizedBox(width: 6),
          const Text(
            '젬 파편',
            style: TextStyle(fontSize: 11, color: Color(0xFF8AA6B8)),
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
          const Spacer(),
          _TraitCostChip(label: '1차', cost: primaryCost),
          const SizedBox(width: 5),
          _TraitCostChip(label: '2차', cost: secondaryCost),
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

class _TraitTierBlock extends StatelessWidget {
  const _TraitTierBlock({
    required this.tierText,
    required this.title,
    required this.selectedTrait,
    required this.blockedText,
    required this.choices,
    required this.enabled,
    required this.tier,
  });

  final String tierText;
  final String title;
  final TurretTraitType? selectedTrait;
  final String? blockedText;
  final List<TurretTraitType> choices;
  final bool enabled;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final selected = selectedTrait != null;
    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: selected ? const Color(0x1F63E6A5) : const Color(0x6607111D),
        border: Border.all(
          color: selected ? const Color(0x9963E6A5) : const Color(0x3333D8FF),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0x3363E6A5)
                      : const Color(0xFF07111D),
                  border: Border.all(color: const Color(0x9963E6A5)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
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
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                size: 16,
                color: selected
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
              const SizedBox(height: 8),
            ],
            for (var i = 0; i < choices.length; i++) ...[
              if (i > 0) const SizedBox(height: 7),
              _TraitChoiceButton(
                trait: choices[i],
                enabled: enabled,
                tier: tier,
              ),
            ],
          ],
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

class _TraitChoiceButton extends StatelessWidget {
  const _TraitChoiceButton({
    required this.trait,
    required this.enabled,
    required this.tier,
  });

  final TurretTraitType trait;
  final bool enabled;
  final int tier;

  @override
  Widget build(BuildContext context) {
    final accent = _traitAccentColor(trait);
    return Opacity(
      opacity: enabled ? 1 : 0.56,
      child: OutlinedButton(
        onPressed: enabled
            ? () => Navigator.of(
                context,
              ).pop(_TraitSelection(tier: tier, trait: trait))
            : null,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFE8F8FF),
          disabledForegroundColor: const Color(0xFF8AA6B8),
          backgroundColor: enabled
              ? const Color(0x1463E6A5)
              : const Color(0x6607111D),
          side: BorderSide(
            color: enabled ? const Color(0x9963E6A5) : const Color(0x55485B68),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: enabled ? 0.18 : 0.08),
                border: Border.all(color: accent.withValues(alpha: 0.68)),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(_traitIcon(trait), size: 16, color: accent),
            ),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    trait.shortText,
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFFC9DCE8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              enabled ? Icons.add_circle_outline : Icons.lock_outline,
              size: 17,
              color: enabled
                  ? const Color(0xFF63E6A5)
                  : const Color(0xFF607587),
            ),
          ],
        ),
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
  };
}
