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
    final borderColor = selected ? GamePalette.cyan : const Color(0x55485B68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? const Color(0x2233D8FF) : const Color(0x2207111D),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 25,
                height: 25,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: turret.color.withValues(alpha: 0.12),
                  border: Border.all(
                    color: turret.color.withValues(alpha: 0.7),
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: CustomPaint(
                    painter: _TurretShapePainter(
                      type: type,
                      color: turret.color,
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              _ModuleSingleLineText(
                turret.name,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
                style: GameTextStyles.caption,
              ),
            ],
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
        final turretSize = compact ? 104.0 : 118.0;
        return Container(
          height: 246,
          decoration: BoxDecoration(
            color: const Color(0x3307111D),
            border: Border.all(color: const Color(0x55485B68)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _EquipmentLinkPainter(
                    selectedParts: equippedModules.keys.toSet(),
                    socketWidth: socketWidth,
                    socketRight: compact ? 8 : 10,
                  ),
                ),
              ),
              Positioned(
                left: 10,
                top: 9,
                child: Text(turretName, style: GameTextStyles.sectionTitle),
              ),
              Positioned(
                left: compact ? 14 : 20,
                top: 76,
                width: turretSize,
                height: turretSize,
                child: _TurretPreview(
                  type: turretType,
                  color: turretColor,
                  name: turretName,
                ),
              ),
              for (final entry in _partPositions.entries)
                Positioned(
                  top: entry.value,
                  right: compact ? 8 : 10,
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
        color: const Color(0x5507111D),
        border: Border.all(color: color.withValues(alpha: 0.48)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: CustomPaint(
              painter: _TurretShapePainter(type: type, color: color),
              child: const SizedBox.expand(),
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

class _EquipmentLinkPainter extends CustomPainter {
  const _EquipmentLinkPainter({
    required this.selectedParts,
    required this.socketWidth,
    required this.socketRight,
  });

  final Set<TurretModulePart> selectedParts;
  final double socketWidth;
  final double socketRight;

  @override
  void paint(Canvas canvas, Size size) {
    final socketLeft = size.width - socketRight - socketWidth;
    final hubX = math.max(8.0, socketLeft - _moduleLinkHubGap);
    final laneX = math.max(8.0, socketLeft - _moduleLinkLaneGap);
    final hubY = _partSocketCenterY(TurretModulePart.barrel);
    final busStartY = _partSocketCenterY(TurretModulePart.core);
    final busEndY = _partSocketCenterY(TurretModulePart.frame);
    final busPaint = Paint()
      ..color = GamePalette.metal.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final basePath = Path()
      ..moveTo(hubX, hubY)
      ..lineTo(laneX, hubY)
      ..moveTo(laneX, busStartY)
      ..lineTo(laneX, busEndY);
    for (final part in TurretModulePart.values) {
      final socketCenterY = _partSocketCenterY(part);
      basePath
        ..moveTo(laneX, socketCenterY)
        ..lineTo(socketLeft, socketCenterY);
    }
    canvas.drawPath(basePath, busPaint);

    for (final part in TurretModulePart.values) {
      final socketCenterY = _partSocketCenterY(part);
      final selected = selectedParts.contains(part);
      final path = Path()
        ..moveTo(hubX, hubY)
        ..lineTo(laneX, hubY)
        ..lineTo(laneX, socketCenterY)
        ..lineTo(socketLeft, socketCenterY);
      if (selected) {
        final glowPaint = Paint()
          ..color = GamePalette.cyan.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.2
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, glowPaint);
      }
      final linePaint = Paint()
        ..color = (selected ? GamePalette.cyan : GamePalette.metal).withValues(
          alpha: selected ? 0.72 : 0.26,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 1.8 : 1.0
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, linePaint);
      final end = Offset(socketLeft - 1, socketCenterY);
      final nodePaint = Paint()
        ..color = (selected ? GamePalette.cyan : GamePalette.metal).withValues(
          alpha: selected ? 0.82 : 0.34,
        );
      canvas.drawCircle(end, selected ? 3.4 : 2.2, nodePaint);
      if (selected) {
        canvas.drawCircle(
          Offset(hubX, hubY),
          2.7,
          Paint()..color = GamePalette.cyan.withValues(alpha: 0.72),
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EquipmentLinkPainter oldDelegate) {
    return oldDelegate.selectedParts != selectedParts ||
        oldDelegate.socketWidth != socketWidth ||
        oldDelegate.socketRight != socketRight;
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
    final borderColor = selected ? GamePalette.cyan : const Color(0x55485B68);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: _moduleSocketHeight,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: selected ? const Color(0x2233D8FF) : const Color(0xCC07111D),
            border: Border.all(color: borderColor),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(part.label, style: GameTextStyles.chip)),
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
    final accentColor = item == null
        ? GamePalette.metal
        : _gradeColor(item.key.grade);

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: item != null
            ? accentColor.withValues(alpha: 0.13)
            : const Color(0x2207111D),
        border: Border.all(
          color: item?.equipped == true
              ? GamePalette.cyan
              : accentColor.withValues(alpha: item != null ? 0.48 : 0.36),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
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
              onPressed: () => _confirmDisassemble(context, item),
              label: '분해',
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
      game.disassembleTurretModule(item.id);
    }
  }
}
