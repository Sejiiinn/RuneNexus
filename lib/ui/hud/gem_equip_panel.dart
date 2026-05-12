part of 'game_hud.dart';

class _GemEquipPanel extends StatefulWidget {
  const _GemEquipPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_GemEquipPanel> createState() => _GemEquipPanelState();
}

class _GemEquipPanelState extends State<_GemEquipPanel> {
  GemType? _selectedInventoryGem;

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final canManageGems = snapshot.phase == GamePhase.preparation;
    final canLevelUp =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final canRefund = snapshot.selectedTurretPoint != null && canLevelUp;
    final slotText =
        '${snapshot.selectedTurretGems.length}/${snapshot.selectedTurretSlotLimit}';
    final definition = demoTurrets[snapshot.selectedTurretType]!;
    final inventory = GemType.values
        .where((type) => (snapshot.gemInventory[type] ?? 0) > 0)
        .toList();
    final selectedSlotIndex = snapshot.selectedTurretGemSlotIndex;
    final selectedSlotGem =
        selectedSlotIndex != null &&
            selectedSlotIndex < snapshot.selectedTurretGems.length
        ? snapshot.selectedTurretGems[selectedSlotIndex]
        : null;
    final selectedInventoryGem =
        selectedSlotIndex != null &&
            _selectedInventoryGem != null &&
            inventory.contains(_selectedInventoryGem)
        ? _selectedInventoryGem
        : null;
    final selectedInventoryGemDefinition = selectedInventoryGem == null
        ? null
        : demoGems[selectedInventoryGem]!;
    final selectedInventoryBlockReason = selectedInventoryGem == null
        ? null
        : gemEquipBlockReason(selectedInventoryGem, definition);
    final selectedInventoryEquipped =
        selectedInventoryGem != null &&
        snapshot.selectedTurretGems.contains(selectedInventoryGem);
    final selectedInventoryCanInstall =
        selectedInventoryGem != null &&
        !selectedInventoryEquipped &&
        selectedInventoryBlockReason == null;
    final showGemInventory = selectedSlotIndex != null && canManageGems;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.selectedTurretName} 포탑  Lv.${snapshot.selectedTurretLevel}/${snapshot.selectedTurretMaxLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _DamageSummaryRow(snapshot: snapshot)),
              const SizedBox(width: 6),
              _TurretActionBar(
                canLevelUp:
                    snapshot.selectedTurretCanLevelUp &&
                    canLevelUp &&
                    snapshot.gold >= snapshot.selectedTurretLevelUpCost,
                levelUpLabel: snapshot.selectedTurretCanLevelUp
                    ? '${snapshot.selectedTurretLevelUpCost}G'
                    : 'MAX',
                onLevelUp: widget.game.levelUpSelectedTurret,
                showLink: snapshot.selectedTurretHasLinkUpgrade,
                canUpgradeLink:
                    snapshot.selectedTurretCanUpgradeLink &&
                    canManageGems &&
                    snapshot.gold >= snapshot.selectedTurretLinkUpgradeCost,
                linkLabel: snapshot.selectedTurretCanUpgradeLink
                    ? '${snapshot.selectedTurretLinkUpgradeCost}G'
                    : 'Lv.${snapshot.selectedTurretLinkUpgradeRequiredLevel}',
                onUpgradeLink: widget.game.upgradeSelectedTurretLink,
                canRefund: canRefund,
                refundLabel: '${snapshot.selectedTurretRefundGold}G',
                onRefund: () => _confirmRefundSelectedTurret(snapshot),
                traitButton: snapshot.selectedTurretSupportsTraits
                    ? _TurretTraitActionButton(
                        snapshot: snapshot,
                        onPressed: () => _showTraitDialog(snapshot),
                      )
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _TurretAttributeChips(definition: definition),
          const SizedBox(height: 6),
          _TurretStats(snapshot: snapshot, definition: definition),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '링크 $slotText',
                style: const TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(snapshot.selectedTurretSlotLimit, (
                      index,
                    ) {
                      final type = index < snapshot.selectedTurretGems.length
                          ? snapshot.selectedTurretGems[index]
                          : null;
                      final selected = selectedSlotIndex == index;
                      final color = type == null
                          ? const Color(0xFF8AA6B8)
                          : demoGems[type]!.color;
                      final label = type == null
                          ? '${index + 1}: 빈 슬롯'
                          : '${index + 1}';

                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: OutlinedButton(
                          onPressed: canManageGems
                              ? () => widget.game.selectSelectedTurretGemSlot(
                                  index,
                                )
                              : null,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: BorderSide(
                              color: selected
                                  ? color
                                  : color.withValues(alpha: 0.55),
                              width: selected ? 2 : 1,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 30),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (type != null) ...[
                                Icon(demoGems[type]!.icon, size: 13),
                                const SizedBox(width: 4),
                              ],
                              Text(label, style: const TextStyle(fontSize: 11)),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ],
          ),
          if (showGemInventory && selectedSlotGem != null) ...[
            const SizedBox(height: 6),
            _SelectedSlotGemActions(
              type: selectedSlotGem,
              turret: definition,
              onRemove: canManageGems
                  ? widget.game.removeSelectedTurretGemSlot
                  : null,
            ),
          ],
          if (showGemInventory) ...[
            const SizedBox(height: 6),
            if (inventory.isEmpty)
              const Text(
                '보유 젬 없음',
                style: TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '보유 젬',
                    style: TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: inventory.map((type) {
                      final gem = demoGems[type]!;
                      final count = snapshot.gemInventory[type]!;
                      final equipped = snapshot.selectedTurretGems.contains(
                        type,
                      );
                      final selected = selectedInventoryGem == type;
                      final blockReason = gemEquipBlockReason(type, definition);
                      final canInstall = !equipped && blockReason == null;
                      return _InventoryGemChip(
                        gem: gem,
                        count: count,
                        selected: selected,
                        equipped: equipped,
                        blocked: blockReason != null,
                        enabled: canManageGems,
                        onTap: () {
                          if (!canManageGems) {
                            return;
                          }
                          if (selected && canInstall) {
                            widget.game.equipSelectedTurret(type);
                            setState(() {
                              _selectedInventoryGem = null;
                            });
                            return;
                          }
                          setState(() {
                            _selectedInventoryGem = type;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedInventoryGem != null &&
                      selectedInventoryGemDefinition != null) ...[
                    const SizedBox(height: 6),
                    _SelectedInventoryGemActions(
                      type: selectedInventoryGem,
                      turret: definition,
                      gem: selectedInventoryGemDefinition,
                      blockReason: selectedInventoryEquipped
                          ? '이미 이 포탑에 장착됨'
                          : selectedInventoryBlockReason,
                      canInstall: selectedInventoryCanInstall,
                      enabled: canManageGems,
                      onInstall: () {
                        widget.game.equipSelectedTurret(selectedInventoryGem);
                        setState(() {
                          _selectedInventoryGem = null;
                        });
                      },
                    ),
                  ],
                ],
              ),
          ] else if (canManageGems) ...[
            const SizedBox(height: 6),
            const Text(
              '링크를 선택하면 젬을 관리할 수 있습니다',
              style: TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmRefundSelectedTurret(GameSnapshot snapshot) async {
    final pauseCombat = snapshot.phase == GamePhase.wave;
    if (pauseCombat) {
      widget.game.pauseEngine();
    }
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _TurretRefundConfirmDialog(snapshot: snapshot),
      );
      if (!mounted || confirmed != true) {
        return;
      }

      widget.game.refundSelectedTurret();
    } finally {
      if (pauseCombat) {
        widget.game.resumeEngine();
      }
    }
  }

  Future<void> _showTraitDialog(GameSnapshot snapshot) async {
    final pauseCombat = snapshot.phase == GamePhase.wave;
    if (pauseCombat) {
      widget.game.pauseEngine();
    }
    try {
      final selected = await showDialog<_TraitSelection>(
        context: context,
        builder: (context) => _TurretTraitDialog(snapshot: snapshot),
      );
      if (!mounted || selected == null) {
        return;
      }

      if (selected.tier == 1) {
        widget.game.chooseSelectedTurretPrimaryTrait(selected.trait);
      } else {
        widget.game.chooseSelectedTurretSecondaryTrait(selected.trait);
      }
    } finally {
      if (pauseCombat) {
        widget.game.resumeEngine();
      }
    }
  }
}

class _TurretActionBar extends StatelessWidget {
  const _TurretActionBar({
    required this.canLevelUp,
    required this.levelUpLabel,
    required this.onLevelUp,
    required this.showLink,
    required this.canUpgradeLink,
    required this.linkLabel,
    required this.onUpgradeLink,
    required this.canRefund,
    required this.refundLabel,
    required this.onRefund,
    this.traitButton,
  });

  final bool canLevelUp;
  final String levelUpLabel;
  final VoidCallback onLevelUp;
  final bool showLink;
  final bool canUpgradeLink;
  final String linkLabel;
  final VoidCallback onUpgradeLink;
  final bool canRefund;
  final String refundLabel;
  final VoidCallback onRefund;
  final Widget? traitButton;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TurretActionButton(
          icon: Icons.trending_up,
          label: levelUpLabel,
          color: const Color(0xFFE7C66A),
          onPressed: canLevelUp ? onLevelUp : null,
        ),
        if (showLink) ...[
          const SizedBox(width: 6),
          _TurretActionButton(
            icon: Icons.account_tree_outlined,
            label: linkLabel,
            color: const Color(0xFF8EE6FF),
            onPressed: canUpgradeLink ? onUpgradeLink : null,
          ),
        ],
        const SizedBox(width: 6),
        _TurretActionButton(
          icon: Icons.sell_outlined,
          label: refundLabel,
          color: const Color(0xFFFF8A2A),
          onPressed: canRefund ? onRefund : null,
        ),
        if (traitButton != null) ...[const SizedBox(width: 6), traitButton!],
      ],
    );
  }
}

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
    final color = selected
        ? complete
              ? const Color(0xFF80F2B8)
              : const Color(0xFFB9F27C)
        : ready
        ? const Color(0xFFE7C66A)
        : const Color(0xFF607587);
    final badgeText = selected
        ? complete
              ? '2'
              : '1'
        : ready
        ? '!'
        : '${snapshot.selectedTurretPrimaryTraitRequiredLevel}';

    return Tooltip(
      message: '특성',
      child: SizedBox(
        width: 34,
        height: 30,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
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
                child: _TraitActionBadge(label: badgeText, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TraitActionBadge extends StatelessWidget {
  const _TraitActionBadge({required this.label, required this.color});

  final String label;
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
      child: Text(
        label,
        style: TextStyle(
          fontSize: 8,
          height: 1,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
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
        side: const BorderSide(color: Color(0x8833D8FF)),
      ),
      titlePadding: const EdgeInsets.fromLTRB(16, 14, 10, 0),
      contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      title: Row(
        children: [
          const Icon(Icons.auto_awesome, color: Color(0xFFE7C66A), size: 18),
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
            Row(
              children: [
                const Text(
                  '젬 파편',
                  style: TextStyle(fontSize: 11, color: Color(0xFF8AA6B8)),
                ),
                const SizedBox(width: 6),
                Text(
                  '${snapshot.gemShards}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                ),
                const Spacer(),
                Text(
                  '1차 ${snapshot.selectedTurretPrimaryTraitCost} · 2차 ${snapshot.selectedTurretSecondaryTraitCost}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFE7C66A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const _TraitSectionLabel(text: '1차 특성'),
            const SizedBox(height: 6),
            if (primary != null)
              _SelectedTraitSummary(trait: primary)
            else ...[
              if (primaryBlockedText != null) ...[
                _TraitBlockedNotice(text: primaryBlockedText),
                const SizedBox(height: 8),
              ],
              _TraitChoiceButton(
                trait: TurretTraitType.overheatMagazine,
                enabled: canChoosePrimary,
                tier: 1,
              ),
              const SizedBox(height: 7),
              _TraitChoiceButton(
                trait: TurretTraitType.lightweightBarrel,
                enabled: canChoosePrimary,
                tier: 1,
              ),
            ],
            const SizedBox(height: 10),
            const _TraitSectionLabel(text: '2차 특성'),
            const SizedBox(height: 6),
            if (secondary != null)
              _SelectedTraitSummary(trait: secondary)
            else ...[
              if (secondaryBlockedText != null) ...[
                _TraitBlockedNotice(text: secondaryBlockedText),
                const SizedBox(height: 8),
              ],
              _TraitChoiceButton(
                trait: TurretTraitType.suppressiveFire,
                enabled: canChooseSecondary,
                tier: 2,
              ),
              const SizedBox(height: 7),
              _TraitChoiceButton(
                trait: TurretTraitType.chainCleanup,
                enabled: canChooseSecondary,
                tier: 2,
              ),
            ],
            const SizedBox(height: 8),
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

class _TraitSectionLabel extends StatelessWidget {
  const _TraitSectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Color(0xFF8AA6B8),
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
        color: const Color(0x9907111D),
        border: Border.all(color: const Color(0x6680F2B8)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 16, color: Color(0xFF80F2B8)),
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
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFFFFC285),
        height: 1.25,
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
          side: BorderSide(
            color: enabled ? const Color(0xFF8EE6FF) : const Color(0x55485B68),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          children: [
            const Icon(Icons.auto_awesome, size: 15),
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
            Text(
              '선택',
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurretActionButton extends StatelessWidget {
  const _TurretActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final foreground = enabled ? color : const Color(0xFF607587);
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: const Color(0xFF607587),
          side: BorderSide(
            color: enabled
                ? color.withValues(alpha: 0.82)
                : const Color(0x5533D8FF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          minimumSize: const Size(44, 30),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurretRefundConfirmDialog extends StatelessWidget {
  const _TurretRefundConfirmDialog({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final gemCount = snapshot.selectedTurretGems.length;
    final traitWarning = snapshot.selectedTurretPrimaryTrait == null
        ? ''
        : '\n특성에 사용한 젬 파편은 반환되지 않습니다.';
    return AlertDialog(
      backgroundColor: const Color(0xFF102235),
      title: Text(
        '${snapshot.selectedTurretName ?? '선택한'} 포탑 환불',
        style: const TextStyle(color: Color(0xFFE8F8FF)),
      ),
      content: Text(
        '설치 및 업그레이드 비용의 75%인 '
        '${snapshot.selectedTurretRefundGold}골드를 돌려받습니다.'
        '${gemCount > 0 ? '\n장착된 젬 $gemCount개는 인벤토리로 반환됩니다.' : ''}'
        '$traitWarning',
        style: const TextStyle(color: Color(0xFFC9DCE8), height: 1.35),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('환불', style: TextStyle(color: Color(0xFFFF8A2A))),
        ),
      ],
    );
  }
}

class _DamageSummaryRow extends StatelessWidget {
  const _DamageSummaryRow({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showDamageDetailDialog(context, snapshot),
          borderRadius: BorderRadius.circular(7),
          child: Container(
            height: 30,
            padding: const EdgeInsets.only(left: 9, right: 4),
            decoration: BoxDecoration(
              color: const Color(0x9907111D),
              border: Border.all(color: const Color(0x5533D8FF)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '누적 피해',
                  style: TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
                ),
                const SizedBox(width: 7),
                Text(
                  _formatDamageValue(snapshot.selectedTurretDamageDealt),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8F8FF),
                  ),
                ),
                const SizedBox(width: 3),
                const Icon(
                  Icons.more_horiz,
                  size: 17,
                  color: Color(0xFF8EE6FF),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDamageDetailDialog(BuildContext context, GameSnapshot snapshot) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF091624),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0x8833D8FF)),
          ),
          title: const Text('피해 기록', style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DamageDetailLine(
                label: '총 피해',
                value: snapshot.selectedTurretDamageDealt,
              ),
              _DamageDetailLine(
                label: '직접 피해',
                value: snapshot.selectedTurretDirectDamageDealt,
              ),
              _DamageDetailLine(
                label: '범위 피해',
                value: snapshot.selectedTurretSplashDamageDealt,
              ),
              _DamageDetailLine(
                label: '연쇄 피해',
                value: snapshot.selectedTurretChainDamageDealt,
              ),
              _DamageDetailLine(
                label: '화상 피해',
                value: snapshot.selectedTurretBurnDamageDealt,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('닫기'),
            ),
          ],
        );
      },
    );
  }
}

class _DamageDetailLine extends StatelessWidget {
  const _DamageDetailLine({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF8AA6B8)),
            ),
          ),
          Text(
            _formatDamageValue(value),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFE8F8FF),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryGemChip extends StatelessWidget {
  const _InventoryGemChip({
    required this.gem,
    required this.count,
    required this.selected,
    required this.equipped,
    required this.blocked,
    required this.enabled,
    required this.onTap,
  });

  final GemDefinition gem;
  final int count;
  final bool selected;
  final bool equipped;
  final bool blocked;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = equipped || blocked;
    return Opacity(
      opacity: dimmed && !selected ? 0.48 : 1,
      child: SizedBox(
        width: 106,
        height: 34,
        child: OutlinedButton(
          onPressed: enabled ? onTap : null,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: BorderSide(
              color: selected ? gem.color : gem.color.withValues(alpha: 0.58),
              width: selected ? 2 : 1,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 7),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Row(
            children: [
              Icon(gem.icon, color: gem.color, size: 15),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                'x$count',
                style: const TextStyle(fontSize: 10, color: Color(0xFFB9D6E4)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedInventoryGemActions extends StatelessWidget {
  const _SelectedInventoryGemActions({
    required this.type,
    required this.turret,
    required this.gem,
    required this.blockReason,
    required this.canInstall,
    required this.enabled,
    required this.onInstall,
  });

  final GemType type;
  final TurretDefinition turret;
  final GemDefinition gem;
  final String? blockReason;
  final bool canInstall;
  final bool enabled;
  final VoidCallback onInstall;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 15),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  blockReason ?? _gemEffectText(type, turret),
                  style: TextStyle(
                    fontSize: 10,
                    color: blockReason == null
                        ? const Color(0xFFC9DCE8)
                        : const Color(0xFFFFA68A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: enabled && canInstall ? onInstall : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                disabledForegroundColor: const Color(0xFF6D7F8F),
                side: BorderSide(
                  color: canInstall ? gem.color : const Color(0x55485B68),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('장착', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedSlotGemActions extends StatelessWidget {
  const _SelectedSlotGemActions({
    required this.type,
    required this.turret,
    required this.onRemove,
  });

  final GemType type;
  final TurretDefinition turret;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final gem = demoGems[type]!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: gem.color.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          Icon(gem.icon, color: gem.color, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  gem.name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _gemEffectText(type, turret),
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFFD6ECF6),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: OutlinedButton(
              onPressed: onRemove,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Color(0xFF8AA6B8)),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              child: const Text('해제', style: TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurretStats extends StatelessWidget {
  const _TurretStats({required this.snapshot, required this.definition});

  final GameSnapshot snapshot;
  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final dps = snapshot.selectedTurretAttackRate <= 0
        ? 0
        : snapshot.selectedTurretDamage * snapshot.selectedTurretAttackRate;
    final burnDps = snapshot.selectedTurretBurnDamagePerSecond;

    return Row(
      children: [
        _StatPill(
          label: '피해',
          value: snapshot.selectedTurretDamage.toStringAsFixed(1),
        ),
        const SizedBox(width: 5),
        _StatPill(
          label: 'DPS',
          value: dps.toStringAsFixed(1),
          valueChild: burnDps > 0
              ? RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8F8FF),
                    ),
                    children: [
                      TextSpan(text: dps.toStringAsFixed(1)),
                      TextSpan(
                        text: ' +${burnDps.toStringAsFixed(1)}',
                        style: const TextStyle(color: Color(0xFFFFA24A)),
                      ),
                    ],
                  ),
                )
              : null,
        ),
        if (burnDps > 0) ...[
          const SizedBox(width: 5),
          _StatPill(
            label: '화상',
            value: '${snapshot.selectedTurretBurnDuration.toStringAsFixed(1)}초',
          ),
        ],
        if (definition.slowDuration > 0) ...[
          const SizedBox(width: 5),
          _StatPill(
            label: '감속',
            value:
                '${((1 - definition.slowMultiplier) * 100).round()}%/${definition.slowDuration.toStringAsFixed(1)}초',
          ),
        ],
        const SizedBox(width: 5),
        _StatPill(
          label: '사거리',
          value: snapshot.selectedTurretRange.round().toString(),
        ),
        const SizedBox(width: 5),
        _StatPill(
          label: '초당',
          value: '${snapshot.selectedTurretAttackRate.toStringAsFixed(2)}회',
        ),
      ],
    );
  }
}

String _formatDamageValue(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  if (value >= 100) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value, this.valueChild});

  final String label;
  final String value;
  final Widget? valueChild;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xAA07111D),
          border: Border.all(color: const Color(0x3333D8FF)),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
              overflow: TextOverflow.ellipsis,
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child:
                  valueChild ??
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _gemEffectText(GemType type, TurretDefinition turret) {
  return switch (type) {
    GemType.attackSpeed => '초당 발사 40% 증폭',
    GemType.range => '사거리 20% 증폭',
    GemType.physicalDamage =>
      turret.damageFamily == DamageFamily.physical
          ? '물리 피해 40% 증폭'
          : '현재 적용되는 물리 피해 없음',
    GemType.magicalDamage =>
      turret.damageFamily == DamageFamily.magical
          ? '마법 피해 40% 증폭'
          : '현재 적용되는 마법 피해 없음',
    GemType.lightWeapon =>
      turret.attackTags.contains(AttackTag.light)
          ? '경량화기 피해 20% 증폭, 초당 발사 20% 증폭'
          : '현재 적용되는 경량화기 피해 없음',
    GemType.heavyWeapon =>
      turret.attackTags.contains(AttackTag.heavy)
          ? '중화기 피해 30% 증폭, 효과 범위 20% 증가'
          : '현재 적용되는 중화기 피해 없음',
    GemType.damageOverTime =>
      turret.attackTags.contains(AttackTag.damageOverTime)
          ? '지속피해 30% 증폭, 지속시간 30% 증가'
          : '현재 적용되는 지속피해 없음',
    GemType.explosion => turret.splashRadius > 0 ? '폭발 반경 25% 증폭' : '반경 34 폭발',
    GemType.chain =>
      turret.splashRadius > 0 ? '폭발 미적중 최대 2명에게 50% 연쇄' : '주변 최대 2명에게 50% 연쇄',
  };
}
