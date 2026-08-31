part of 'main_menu_screen.dart';

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
    return Row(
      children: [
        for (final type in availableTurretTypes) ...[
          Expanded(
            child: _TurretModuleTurretToken(
              type: type,
              selected: selectedTurretType == type,
              onPressed: () => onSelect(type),
            ),
          ),
          if (type != availableTurretTypes.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _TurretModuleTurretToken extends StatelessWidget {
  const _TurretModuleTurretToken({
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: 54,
          child: GameAssetSurface(
            frame: GameAssetFrame.card,
            opacity: selected ? 1 : 0.68,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: turret.color.withValues(alpha: 0.07),
                      border: Border.all(
                        color: turret.color.withValues(alpha: 0.72),
                      ),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 5,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 27,
                        height: 27,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.asset(
                              gameIconSocketAsset,
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                              excludeFromSemantics: true,
                            ),
                            Padding(
                              padding: const EdgeInsets.all(4),
                              child: CustomPaint(
                                painter: _TurretShapePainter(
                                  type: type,
                                  color: turret.color,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 3),
                      _ModuleSingleLineText(
                        turret.name,
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                        style: GameTextStyles.withColor(
                          GameTextStyles.caption,
                          selected ? turret.color : GamePalette.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TurretModuleEquipmentStage extends StatelessWidget {
  const _TurretModuleEquipmentStage({
    required this.turretName,
    required this.turretType,
    required this.turretColor,
    required this.equippedModules,
    required this.onSelectEquippedModule,
  });

  final String turretName;
  final TurretType turretType;
  final Color turretColor;
  final Map<TurretModulePart, TurretModuleInventoryItem> equippedModules;
  final ValueChanged<TurretModuleInventoryItem> onSelectEquippedModule;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;
        final socketWidth = compact ? 116.0 : 128.0;
        final socketRight = compact ? 8.0 : 10.0;
        final socketLeft = constraints.maxWidth - socketRight - socketWidth;
        final turretSize = compact ? 104.0 : 118.0;
        final turretLeft = compact ? 14.0 : 20.0;
        final turretCenterY = _partSocketCenterY(TurretModulePart.barrel);
        final turretTop = turretCenterY - (turretSize / 2);
        final connectorTop = _partSocketCenterY(TurretModulePart.core) - 12;
        final connectorHeight =
            _partSocketCenterY(TurretModulePart.frame) -
            _partSocketCenterY(TurretModulePart.core) +
            24;
        final connectorLeft = turretLeft + turretSize - 12;
        return SizedBox(
          height: 246,
          child: GameAssetSurface(
            frame: GameAssetFrame.panel,
            child: Stack(
              children: [
                Positioned(
                  left: 10,
                  top: 9,
                  child: Text(turretName, style: GameTextStyles.sectionTitle),
                ),
                Positioned(
                  left: turretLeft,
                  top: turretTop,
                  width: turretSize,
                  height: turretSize,
                  child: _TurretPreview(
                    type: turretType,
                    color: turretColor,
                    name: turretName,
                  ),
                ),
                Positioned(
                  left: connectorLeft,
                  top: connectorTop,
                  width: socketLeft - connectorLeft + 5,
                  height: connectorHeight,
                  child: IgnorePointer(
                    child: Image.asset(
                      turretModuleConnectorAssemblyAsset,
                      key: const ValueKey('turret-module-connector-assembly'),
                      fit: BoxFit.fill,
                      filterQuality: FilterQuality.medium,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                for (final entry in _partPositions.entries)
                  Positioned(
                    top: entry.value,
                    right: socketRight,
                    width: socketWidth,
                    child: _TurretModuleSocketButton(
                      key: ValueKey('turret-module-socket-${entry.key.name}'),
                      part: entry.key,
                      item: equippedModules[entry.key],
                      selected: equippedModules[entry.key] != null,
                      onPressed: equippedModules[entry.key] == null
                          ? null
                          : () => onSelectEquippedModule(
                              equippedModules[entry.key]!,
                            ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TurretPreview extends StatelessWidget {
  const _TurretPreview({
    required this.type,
    required this.color,
    required this.name,
  });

  final TurretType type;
  final Color color;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF10212B), Color(0xFF030910)],
          stops: [0, 1],
        ),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.12), blurRadius: 12),
          const BoxShadow(
            color: Color(0xAA000000),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: CustomPaint(
              painter: _TurretShapePainter(type: type, color: color),
              child: const SizedBox.expand(),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                turretModulePreviewFrameAsset,
                key: const ValueKey('turret-module-preview-frame'),
                fit: BoxFit.contain,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: _ModuleSingleLineText(
              name,
              alignment: Alignment.center,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TurretShapePainter extends CustomPainter {
  const _TurretShapePainter({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 1.6,
    );
  }

  @override
  bool shouldRepaint(_TurretShapePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.color != color;
  }
}

class _TurretModuleSocketButton extends StatelessWidget {
  const _TurretModuleSocketButton({
    super.key,
    required this.part,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModulePart part;
  final TurretModuleInventoryItem? item;
  final bool selected;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final definition = item == null
        ? null
        : gameTurretModuleDefinitions[item.key];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: SizedBox(
          height: _moduleSocketHeight,
          child: GameAssetSurface(
            frame: GameAssetFrame.card,
            opacity: selected ? 1 : 0.76,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x1633D8FF),
                      border: Border.all(color: GamePalette.cyan),
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(part.label, style: GameTextStyles.chip),
                          ),
                          if (item != null)
                            Text(
                              item.key.grade.label,
                              style: GameTextStyles.withColor(
                                GameTextStyles.caption,
                                _gradeColor(item.key.grade),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _ModuleSingleLineText(
                        definition?.name ?? '장착 없음',
                        style: const TextStyle(
                          color: GamePalette.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _ModuleSingleLineText(
                        item == null ? '비어 있음' : '${item.options.length}옵션',
                        style: GameTextStyles.caption,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TurretModuleOptionLines extends StatelessWidget {
  const _TurretModuleOptionLines({
    required this.options,
    required this.emptyText,
    required this.style,
  });

  final List<TurretModuleOptionRoll> options;
  final String emptyText;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    if (options.isEmpty) {
      return Text(emptyText, softWrap: true, style: style);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < options.length; index++) ...[
          if (index > 0) const SizedBox(height: 2),
          Text(
            turretModuleOptionText(options[index]),
            softWrap: true,
            style: style,
          ),
        ],
      ],
    );
  }
}

class _TurretModuleDetailStrip extends StatelessWidget {
  const _TurretModuleDetailStrip({
    required this.game,
    required this.item,
    required this.turretType,
    required this.partFilter,
    required this.itemCount,
  });

  final RuneNexusGame game;
  final TurretModuleInventoryItem? item;
  final TurretType turretType;
  final TurretModulePart? partFilter;
  final int itemCount;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final definition = item == null
        ? null
        : gameTurretModuleDefinitions[item.key];
    return GameAssetSurface(
      frame: GameAssetFrame.lockedRow,
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(9),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    if (item != null) ...[
                      Text(
                        item.key.grade.label,
                        style: GameTextStyles.withColor(
                          GameTextStyles.chip,
                          _gradeColor(item.key.grade),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Expanded(
                      child: Text(
                        definition?.name ?? '선택한 모듈 없음',
                        softWrap: true,
                        style: const TextStyle(
                          color: GamePalette.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item == null
                      ? '${gameTurrets[turretType]!.name} · ${_partFilterLabel(partFilter)} · 보유 모듈 $itemCount개'
                      : '${item.key.part.label} · ${gameTurrets[item.key.turretType]!.name} · '
                            '${item.options.length}옵션${item.equipped ? ' · 장착됨' : ''}',
                  softWrap: true,
                  style: GameTextStyles.caption,
                ),
                const SizedBox(height: 4),
                _TurretModuleOptionLines(
                  options: item?.options ?? const [],
                  emptyText: '장착 효과: 비어 있음',
                  style: GameTextStyles.withColor(
                    GameTextStyles.body,
                    GamePalette.goldBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _detailAction(context),
        ],
      ),
    );
  }

  Widget _detailAction(BuildContext context) {
    final item = this.item;
    if (item == null) {
      return const SizedBox(width: 58, child: _ModuleInfoChip(text: '미선택'));
    }
    if (item.equipped) {
      return SizedBox(
        width: 58,
        child: GameButton(
          onPressed: () => game.unequipTurretModule(item.id),
          label: '해제',
          compact: true,
          variant: GameButtonVariant.ghost,
          accentColor: GamePalette.cyan,
        ),
      );
    }
    return SizedBox(
      width: 116,
      child: Row(
        children: [
          Expanded(
            child: GameButton(
              onPressed: () => game.equipTurretModule(item.id),
              label: '장착',
              compact: true,
              accentColor: GamePalette.cyan,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: GameButton(
              key: ValueKey('turret-module-disassemble-button-${item.id}'),
              onPressed: item.key.grade == TurretModuleGrade.unique
                  ? null
                  : () => _confirmDisassemble(context, item),
              label: item.key.grade == TurretModuleGrade.unique ? '보호됨' : '분해',
              compact: true,
              variant: GameButtonVariant.ghost,
              accentColor: GamePalette.gold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDisassemble(
    BuildContext context,
    TurretModuleInventoryItem item,
  ) async {
    final confirmed =
        await showGameDialog<bool>(
          context: context,
          builder: (context) => _TurretModuleDisassembleDialog(item: item),
        ) ??
        false;
    if (confirmed) {
      try {
        await game.disassembleTurretModule(item.id);
      } on Object {
        if (context.mounted) {
          _showEconomyRequestFailure(context);
        }
      }
    }
  }
}
