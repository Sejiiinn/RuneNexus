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
    final canInstallGems =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final canRemoveGems = canInstallGems;
    final canLevelUp =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final canRefund = snapshot.selectedTurretPoint != null && canLevelUp;
    final levelUpPreviewActive = snapshot.selectedTurretLevelUpPreviewActive;
    final definition = gameTurrets[snapshot.selectedTurretType]!;
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
        : gameGems[selectedInventoryGem]!;
    final selectedInventoryEquipped =
        selectedInventoryGem != null &&
        snapshot.selectedTurretGems.contains(selectedInventoryGem);
    final selectedSlotCanAcceptGem =
        selectedSlotIndex != null && canInstallGems;
    final selectedInventoryBlockReason = selectedInventoryGem == null
        ? null
        : gemEquipBlockReason(selectedInventoryGem, definition);
    final selectedInventoryInstallBlockReason = selectedInventoryEquipped
        ? '이미 이 포탑에 장착됨'
        : !selectedSlotCanAcceptGem
        ? '링크 홈을 선택하세요'
        : selectedInventoryBlockReason;
    final selectedInventoryCanInstall =
        selectedInventoryGem != null &&
        selectedSlotCanAcceptGem &&
        !selectedInventoryEquipped &&
        selectedInventoryBlockReason == null;
    final showGemInventory = selectedSlotIndex != null && canInstallGems;

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
                  levelUpPreviewActive
                      ? '${snapshot.selectedTurretName} 포탑  Lv.${snapshot.selectedTurretLevel} -> ${snapshot.selectedTurretNextLevel}'
                      : '${snapshot.selectedTurretName} 포탑  Lv.${snapshot.selectedTurretLevel}/${snapshot.selectedTurretMaxLevel}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.clip,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: _DamageSummaryRow(snapshot: snapshot)),
              const SizedBox(width: 6),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _TurretActionBar(
                    canLevelUp:
                        snapshot.selectedTurretCanLevelUp &&
                        canLevelUp &&
                        snapshot.gold >= snapshot.selectedTurretLevelUpCost,
                    levelUpLabel: snapshot.selectedTurretCanLevelUp
                        ? '${snapshot.selectedTurretLevelUpCost}G'
                        : 'MAX',
                    levelUpPreviewActive: levelUpPreviewActive,
                    onLevelUp: widget.game.previewOrLevelUpSelectedTurret,
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
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _TurretAttributeChips(definition: definition),
          if (snapshot.canSetTurretTargetPriority) ...[
            const SizedBox(height: 6),
            _TurretTargetPrioritySelector(
              priority: snapshot.selectedTurretTargetPriority,
              onSelected: widget.game.setSelectedTurretTargetPriority,
            ),
          ],
          const SizedBox(height: 6),
          _TurretStats(snapshot: snapshot, definition: definition),
          const SizedBox(height: 6),
          _TurretLinkSocketStrip(
            snapshot: snapshot,
            canInstallGems: canInstallGems,
            selectedSlotIndex: selectedSlotIndex,
            onSelectSlot: widget.game.selectSelectedTurretGemSlot,
            onUpgradeLink: widget.game.upgradeSelectedTurretLink,
          ),
          if (showGemInventory && selectedSlotGem != null) ...[
            const SizedBox(height: 6),
            _SelectedSlotGemActions(
              type: selectedSlotGem,
              turret: definition,
              onRemove: canRemoveGems
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
                      final gem = gameGems[type]!;
                      final count = snapshot.gemInventory[type]!;
                      final equipped = snapshot.selectedTurretGems.contains(
                        type,
                      );
                      final selected = selectedInventoryGem == type;
                      final blockReason = gemEquipBlockReason(type, definition);
                      final canInstall =
                          selectedSlotCanAcceptGem &&
                          !equipped &&
                          blockReason == null;
                      return _InventoryGemChip(
                        gem: gem,
                        count: count,
                        selected: selected,
                        equipped: equipped,
                        blocked: blockReason != null,
                        enabled: canInstallGems,
                        onTap: () {
                          if (!canInstallGems) {
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
                      blockReason: selectedInventoryInstallBlockReason,
                      canInstall: selectedInventoryCanInstall,
                      enabled: canInstallGems,
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
          ] else if (canInstallGems) ...[
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

class _TurretTargetPrioritySelector extends StatelessWidget {
  const _TurretTargetPrioritySelector({
    required this.priority,
    required this.onSelected,
  });

  final TurretTargetPriority priority;
  final ValueChanged<TurretTargetPriority> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.only(left: 9, right: 3),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          const Icon(Icons.ads_click, size: 14, color: Color(0xFF8EE6FF)),
          const SizedBox(width: 6),
          const Text(
            '공격 명령',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8AA6B8),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _targetPriorityLabel(priority),
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: Color(0xFFE8F8FF),
              ),
            ),
          ),
          PopupMenuButton<TurretTargetPriority>(
            tooltip: '공격 명령 변경',
            color: const Color(0xFF0B1827),
            offset: const Offset(0, -190),
            shape: RoundedRectangleBorder(
              side: const BorderSide(color: Color(0x8833D8FF)),
              borderRadius: BorderRadius.circular(8),
            ),
            onSelected: onSelected,
            itemBuilder: (context) {
              return TurretTargetPriority.values.map((value) {
                final selected = value == priority;
                return PopupMenuItem(
                  value: value,
                  child: Row(
                    children: [
                      Icon(
                        selected ? Icons.radio_button_checked : Icons.adjust,
                        size: 16,
                        color: selected
                            ? const Color(0xFF8EE6FF)
                            : const Color(0xFF607587),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _targetPriorityLabel(value),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Color(0xFFE8F8FF),
                            ),
                          ),
                          Text(
                            _targetPriorityDescription(value),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF8AA6B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            child: const SizedBox(
              height: 28,
              width: 34,
              child: Icon(
                Icons.keyboard_arrow_down,
                size: 20,
                color: Color(0xFF8EE6FF),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _targetPriorityLabel(TurretTargetPriority priority) {
  return switch (priority) {
    TurretTargetPriority.first => '선두 적',
    TurretTargetPriority.last => '후방 적',
    TurretTargetPriority.strongest => '강한 적',
    TurretTargetPriority.weakest => '약한 적',
    TurretTargetPriority.nearest => '가까운 적',
  };
}

String _targetPriorityDescription(TurretTargetPriority priority) {
  return switch (priority) {
    TurretTargetPriority.first => '경로 앞쪽 우선',
    TurretTargetPriority.last => '뒤처진 적 우선',
    TurretTargetPriority.strongest => '현재 내구도 높은 적',
    TurretTargetPriority.weakest => '현재 내구도 낮은 적',
    TurretTargetPriority.nearest => '포탑에 가까운 적',
  };
}

class _TurretActionBar extends StatelessWidget {
  const _TurretActionBar({
    required this.canLevelUp,
    required this.levelUpLabel,
    required this.levelUpPreviewActive,
    required this.onLevelUp,
    required this.canRefund,
    required this.refundLabel,
    required this.onRefund,
    this.traitButton,
  });

  final bool canLevelUp;
  final String levelUpLabel;
  final bool levelUpPreviewActive;
  final VoidCallback onLevelUp;
  final bool canRefund;
  final String refundLabel;
  final VoidCallback onRefund;
  final Widget? traitButton;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerRight,
      child: Row(
        children: [
          _TurretActionButton(
            icon: Icons.trending_up,
            label: levelUpLabel,
            color: const Color(0xFFE7C66A),
            highlighted: levelUpPreviewActive,
            onPressed: canLevelUp ? onLevelUp : null,
          ),
          const SizedBox(width: 6),
          _TurretActionButton(
            icon: Icons.sell_outlined,
            label: refundLabel,
            color: const Color(0xFFFF8A2A),
            onPressed: canRefund ? onRefund : null,
          ),
          if (traitButton != null) ...[const SizedBox(width: 6), traitButton!],
        ],
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
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final activeHighlight = enabled && highlighted;
    final foreground = enabled
        ? (activeHighlight ? const Color(0xFF07111D) : color)
        : const Color(0xFF607587);
    return SizedBox(
      height: 30,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: foreground,
          disabledForegroundColor: const Color(0xFF607587),
          backgroundColor: activeHighlight
              ? color.withValues(alpha: 0.82)
              : Colors.transparent,
          side: BorderSide(
            color: activeHighlight
                ? const Color(0xFFE8F8FF)
                : enabled
                ? color.withValues(alpha: 0.82)
                : const Color(0x5533D8FF),
            width: activeHighlight ? 1.4 : 1,
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

class _TurretStats extends StatelessWidget {
  const _TurretStats({required this.snapshot, required this.definition});

  final GameSnapshot snapshot;
  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final previewActive = snapshot.selectedTurretLevelUpPreviewActive;
    final dps = snapshot.selectedTurretAttackRate <= 0
        ? 0
        : snapshot.selectedTurretDamage * snapshot.selectedTurretAttackRate;
    final nextDps = snapshot.selectedTurretNextAttackRate <= 0
        ? 0
        : snapshot.selectedTurretNextDamage *
              snapshot.selectedTurretNextAttackRate;
    final burnDps = snapshot.selectedTurretBurnDamagePerSecond;
    final totalDps = dps + burnDps;
    final nextTotalDps =
        nextDps + snapshot.selectedTurretNextBurnDamagePerSecond;

    return Row(
      children: [
        _StatPill(
          label: '피해',
          value: snapshot.selectedTurretDamage.toStringAsFixed(1),
          valueChild: previewActive
              ? _PreviewStatValue(
                  current: snapshot.selectedTurretDamage.toStringAsFixed(1),
                  next: snapshot.selectedTurretNextDamage.toStringAsFixed(1),
                )
              : null,
        ),
        const SizedBox(width: 5),
        _StatPill(
          label: 'DPS',
          value: totalDps.toStringAsFixed(1),
          valueChild: previewActive
              ? _PreviewStatValue(
                  current: totalDps.toStringAsFixed(1),
                  next: nextTotalDps.toStringAsFixed(1),
                )
              : burnDps > 0
              ? RichText(
                  maxLines: 1,
                  overflow: TextOverflow.clip,
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
            valueChild: previewActive
                ? _PreviewStatValue(
                    current:
                        '${snapshot.selectedTurretBurnDuration.toStringAsFixed(1)}초',
                    next:
                        '${snapshot.selectedTurretNextBurnDuration.toStringAsFixed(1)}초',
                  )
                : null,
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
          valueChild: previewActive
              ? _PreviewStatValue(
                  current: snapshot.selectedTurretRange.round().toString(),
                  next: snapshot.selectedTurretNextRange.round().toString(),
                )
              : null,
        ),
        const SizedBox(width: 5),
        _StatPill(
          label: '초당',
          value: '${snapshot.selectedTurretAttackRate.toStringAsFixed(2)}회',
          valueChild: previewActive
              ? _PreviewStatValue(
                  current:
                      '${snapshot.selectedTurretAttackRate.toStringAsFixed(2)}회',
                  next:
                      '${snapshot.selectedTurretNextAttackRate.toStringAsFixed(2)}회',
                )
              : null,
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

class _PreviewStatValue extends StatelessWidget {
  const _PreviewStatValue({required this.current, required this.next});

  final String current;
  final String next;

  @override
  Widget build(BuildContext context) {
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.clip,
      text: TextSpan(
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
        children: [
          TextSpan(
            text: current,
            style: const TextStyle(color: Color(0xFF8AA6B8)),
          ),
          const TextSpan(
            text: ' -> ',
            style: TextStyle(color: Color(0xFF63E6A5)),
          ),
          TextSpan(
            text: next,
            style: const TextStyle(color: Color(0xFFE8F8FF)),
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  const _StatPill({
    required this.label,
    required this.value,
    this.valueChild,
    this.expand = true,
  });

  final String label;
  final String value;
  final Widget? valueChild;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      constraints: expand ? null : const BoxConstraints(minWidth: 58),
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
            overflow: TextOverflow.clip,
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
                  overflow: TextOverflow.clip,
                ),
          ),
        ],
      ),
    );
    if (!expand) {
      return content;
    }
    return Expanded(child: content);
  }
}

String _gemEffectText(GemType type, TurretDefinition turret) {
  return switch (type) {
    GemType.attackSpeed => turret.instantHit ? '쿨타임 40% 단축' : '초당 발사 40% 증폭',
    GemType.range => '사거리 20% 증폭',
    GemType.physicalDamage =>
      turret.damageFamily == DamageFamily.physical
          ? '물리 피해 40% 증폭'
          : '현재 적용되는 물리 피해 없음',
    GemType.elementalDamage =>
      turret.damageFamily == DamageFamily.elemental
          ? '원소 피해 40% 증폭'
          : '현재 적용되는 원소 피해 없음',
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
    GemType.explosion =>
      turret.type == TurretType.lightning
          ? '첫 대상 전기 충격파'
          : turret.splashRadius > 0
          ? '폭발 반경 25% 증폭'
          : '반경 34 폭발',
    GemType.chain =>
      turret.type == TurretType.lightning
          ? '후속 연쇄 대상 +2'
          : turret.splashRadius > 0
          ? '폭발 미적중 최대 2명에게 50% 연쇄'
          : '주변 최대 2명에게 50% 연쇄',
    GemType.criticalChance => '치명 확률 +20%p',
    GemType.aimSpeed =>
      turret.instantHit && turret.aimDuration > 0
          ? '조준 속도 75% 증가'
          : '현재 적용되는 조준 속도 없음',
    GemType.damageAmplifier => '타격 피해 25% 증폭',
    GemType.armorPiercing => '방어구 감쇄 무시',
  };
}
