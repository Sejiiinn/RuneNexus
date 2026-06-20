part of 'main_menu_screen.dart';

class _TurretModuleMenu extends StatefulWidget {
  const _TurretModuleMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_TurretModuleMenu> createState() => _TurretModuleMenuState();
}

class _TurretModuleMenuState extends State<_TurretModuleMenu> {
  TurretType? _selectedTurretType;
  TurretModulePart _selectedPart = TurretModulePart.core;

  TurretType _activeTurretType(GameSnapshot snapshot) {
    final selected = _selectedTurretType;
    if (selected != null && snapshot.availableTurretTypes.contains(selected)) {
      return selected;
    }
    return snapshot.availableTurretTypes.first;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selectedTurretType = _activeTurretType(snapshot);
    final selectedTurret = gameTurrets[selectedTurretType]!;
    final equipped = _equippedModulesFor(snapshot, selectedTurretType);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.extension_outlined,
              color: GamePalette.cyan,
              size: 19,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('포탑 모듈', style: GameTextStyles.sectionTitle),
            ),
            _ModuleInfoChip(text: '모듈권 ${snapshot.turretModuleTickets}'),
          ],
        ),
        const SizedBox(height: 10),
        _ModuleDrawPanel(game: widget.game, snapshot: snapshot),
        const SizedBox(height: 12),
        _TurretModuleSelector(
          availableTurretTypes: snapshot.availableTurretTypes,
          selectedTurretType: selectedTurretType,
          onSelect: (type) {
            setState(() {
              _selectedTurretType = type;
            });
          },
        ),
        const SizedBox(height: 10),
        _TurretModuleSlots(
          turretName: selectedTurret.name,
          selectedPart: _selectedPart,
          equippedModules: equipped,
          onSelectPart: (part) {
            setState(() {
              _selectedPart = part;
            });
          },
        ),
        const SizedBox(height: 10),
        _TurretModuleCandidates(
          game: widget.game,
          snapshot: snapshot,
          turretType: selectedTurretType,
          selectedPart: _selectedPart,
        ),
      ],
    );
  }

  Map<TurretModulePart, TurretModuleInventoryItem> _equippedModulesFor(
    GameSnapshot snapshot,
    TurretType turretType,
  ) {
    final equipped = <TurretModulePart, TurretModuleInventoryItem>{};
    for (final item in snapshot.ownedTurretModules) {
      if (item.equipped && item.key.turretType == turretType) {
        equipped[item.key.part] = item;
      }
    }
    return equipped;
  }
}

class _ModuleDrawPanel extends StatelessWidget {
  const _ModuleDrawPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final pityText = snapshot.turretModuleRarePityCounter >= 15
        ? '희귀 보정 +${(snapshot.turretModuleRarePityCounter - 14) * 3}%p'
        : '희귀 보정 ${snapshot.turretModuleRarePityCounter}/15';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x3307111D),
        border: Border.all(color: const Color(0x55485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: GamePalette.goldBright,
                size: 17,
              ),
              const SizedBox(width: 7),
              const Expanded(
                child: Text('모듈 뽑기', style: GameTextStyles.sectionTitle),
              ),
              _ModuleInfoChip(text: pityText),
            ],
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: snapshot.turretModuleTickets >= 1
                      ? () => game.drawTurretModules(1)
                      : null,
                  label: '1회',
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  compact: true,
                  accentColor: GamePalette.gold,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: snapshot.turretModuleTickets >= 5
                      ? () => game.drawTurretModules(5)
                      : null,
                  label: '5회',
                  icon: const Icon(Icons.control_point_duplicate, size: 16),
                  compact: true,
                  accentColor: GamePalette.gold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurretModuleSelector extends StatelessWidget {
  const _TurretModuleSelector({
    required this.availableTurretTypes,
    required this.selectedTurretType,
    required this.onSelect,
  });

  final List<TurretType> availableTurretTypes;
  final TurretType selectedTurretType;
  final ValueChanged<TurretType> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final type in availableTurretTypes)
          _TurretModuleTurretChip(
            type: type,
            selected: selectedTurretType == type,
            onPressed: () => onSelect(type),
          ),
      ],
    );
  }
}

class _TurretModuleTurretChip extends StatelessWidget {
  const _TurretModuleTurretChip({
    required this.type,
    required this.selected,
    required this.onPressed,
  });

  final TurretType type;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final turret = gameTurrets[type]!;
    return SizedBox(
      height: 32,
      child: GameButton(
        onPressed: onPressed,
        selected: selected,
        compact: true,
        accentColor: turret.color,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.adjust, size: 13, color: turret.color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                turret.name,
                overflow: TextOverflow.clip,
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurretModuleSlots extends StatelessWidget {
  const _TurretModuleSlots({
    required this.turretName,
    required this.selectedPart,
    required this.equippedModules,
    required this.onSelectPart,
  });

  final String turretName;
  final TurretModulePart selectedPart;
  final Map<TurretModulePart, TurretModuleInventoryItem> equippedModules;
  final ValueChanged<TurretModulePart> onSelectPart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$turretName 장착 슬롯', style: GameTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final part in TurretModulePart.values) ...[
              Expanded(
                child: _TurretModuleSlotButton(
                  part: part,
                  item: equippedModules[part],
                  selected: selectedPart == part,
                  onPressed: () => onSelectPart(part),
                ),
              ),
              if (part != TurretModulePart.values.last)
                const SizedBox(width: 7),
            ],
          ],
        ),
      ],
    );
  }
}

class _TurretModuleSlotButton extends StatelessWidget {
  const _TurretModuleSlotButton({
    required this.part,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModulePart part;
  final TurretModuleInventoryItem? item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final definition = item == null
        ? null
        : gameTurretModuleDefinitions[item.key];
    final borderColor = selected ? GamePalette.cyan : const Color(0x55485B68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 76,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: selected ? const Color(0x2233D8FF) : const Color(0x2207111D),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(part.label, style: GameTextStyles.chip),
              const Spacer(),
              Text(
                definition?.name ?? '비어 있음',
                maxLines: 2,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: GamePalette.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                item == null ? '장착 없음' : _moduleGradeStarText(item),
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: GameTextStyles.caption,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurretModuleCandidates extends StatelessWidget {
  const _TurretModuleCandidates({
    required this.game,
    required this.snapshot,
    required this.turretType,
    required this.selectedPart,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final TurretType turretType;
  final TurretModulePart selectedPart;

  @override
  Widget build(BuildContext context) {
    final family = turretModuleFamilyFor(turretType, selectedPart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${selectedPart.label} 후보', style: GameTextStyles.sectionTitle),
        const SizedBox(height: 8),
        for (final grade in TurretModuleGrade.values) ...[
          _TurretModuleCandidateTile(
            game: game,
            item: _itemFor(grade, family),
            keyData: TurretModuleKey(
              turretType: turretType,
              part: selectedPart,
              family: family,
              grade: grade,
            ),
          ),
          if (grade != TurretModuleGrade.values.last) const SizedBox(height: 7),
        ],
      ],
    );
  }

  TurretModuleInventoryItem? _itemFor(
    TurretModuleGrade grade,
    TurretModuleFamily family,
  ) {
    for (final item in snapshot.ownedTurretModules) {
      if (item.key.turretType == turretType &&
          item.key.part == selectedPart &&
          item.key.family == family &&
          item.key.grade == grade) {
        return item;
      }
    }
    return null;
  }
}

class _TurretModuleCandidateTile extends StatelessWidget {
  const _TurretModuleCandidateTile({
    required this.game,
    required this.item,
    required this.keyData,
  });

  final RuneNexusGame game;
  final TurretModuleInventoryItem? item;
  final TurretModuleKey keyData;

  @override
  Widget build(BuildContext context) {
    final definition = gameTurretModuleDefinitions[keyData]!;
    final owned = item != null;
    final effect = item == null
        ? definition.effect
        : effectiveTurretModuleEffect(item!);
    final canFuse =
        item != null &&
        item!.shards >= turretModuleFusionShardCost &&
        !(item!.key.grade == TurretModuleGrade.rare &&
            item!.stars >= turretModuleMaxStars);
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: owned ? const Color(0x3307111D) : const Color(0x2207111D),
        border: Border.all(
          color: item?.equipped == true
              ? GamePalette.cyan
              : const Color(0x55485B68),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        children: [
          _ModuleGradeBadge(grade: keyData.grade),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  definition.name,
                  style: const TextStyle(
                    color: GamePalette.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  owned ? _moduleGradeStarText(item!) : keyData.grade.label,
                  style: GameTextStyles.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  turretModuleEffectText(effect),
                  maxLines: 2,
                  overflow: TextOverflow.clip,
                  style: GameTextStyles.body,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 64, child: _candidateAction(canFuse)),
        ],
      ),
    );
  }

  Widget _candidateAction(bool canFuse) {
    final item = this.item;
    if (item == null) {
      return const _ModuleInfoChip(text: '미보유');
    }
    if (canFuse) {
      return GameButton(
        onPressed: () => game.fuseTurretModule(item.key),
        label: '합성',
        compact: true,
        accentColor: GamePalette.green,
      );
    }
    if (item.equipped) {
      return const _ModuleInfoChip(text: '장착 중');
    }
    return GameButton(
      onPressed: () => game.equipTurretModule(item.key),
      label: '장착',
      compact: true,
      accentColor: GamePalette.cyan,
    );
  }
}

class _ModuleGradeBadge extends StatelessWidget {
  const _ModuleGradeBadge({required this.grade});

  final TurretModuleGrade grade;

  @override
  Widget build(BuildContext context) {
    final color = switch (grade) {
      TurretModuleGrade.normal => const Color(0xFF8FA8BA),
      TurretModuleGrade.magic => const Color(0xFF8EE6FF),
      TurretModuleGrade.rare => GamePalette.goldBright,
    };
    final label = switch (grade) {
      TurretModuleGrade.normal => '일',
      TurretModuleGrade.magic => '마',
      TurretModuleGrade.rare => '희',
    };
    return Container(
      width: 32,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        border: Border.all(color: color.withValues(alpha: 0.82)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ModuleInfoChip extends StatelessWidget {
  const _ModuleInfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 25,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 7),
      decoration: BoxDecoration(
        color: const Color(0x2207111D),
        border: Border.all(color: const Color(0x55485B68)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: GameTextStyles.caption,
      ),
    );
  }
}

String _moduleGradeStarText(TurretModuleInventoryItem item) {
  return '${item.key.grade.label} ${item.stars}성 · 조각 ${item.shards}/$turretModuleFusionShardCost';
}
