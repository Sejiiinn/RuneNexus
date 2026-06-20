part of 'main_menu_screen.dart';

class _TurretModuleMenu extends StatefulWidget {
  const _TurretModuleMenu({
    required this.game,
    required this.snapshot,
    required this.onDrawResults,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueChanged<List<TurretModuleInventoryItem>> onDrawResults;

  @override
  State<_TurretModuleMenu> createState() => _TurretModuleMenuState();
}

class _TurretModuleMenuState extends State<_TurretModuleMenu> {
  TurretType? _selectedTurretType;
  TurretModulePart _selectedPart = TurretModulePart.core;
  TurretModuleGrade _selectedGrade = TurretModuleGrade.rare;

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
    final selectedFamily = turretModuleFamilyFor(
      selectedTurretType,
      _selectedPart,
    );
    final selectedKey = TurretModuleKey(
      turretType: selectedTurretType,
      part: _selectedPart,
      family: selectedFamily,
      grade: _selectedGrade,
    );
    final selectedItem = _moduleFor(snapshot, selectedKey);

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
        _ModuleDrawPanel(
          game: widget.game,
          snapshot: snapshot,
          onDrawResults: widget.onDrawResults,
        ),
        const SizedBox(height: 10),
        _TurretModuleSelector(
          availableTurretTypes: snapshot.availableTurretTypes,
          selectedTurretType: selectedTurretType,
          onSelect: (type) {
            setState(() {
              _selectedTurretType = type;
              _selectedGrade = TurretModuleGrade.rare;
            });
          },
        ),
        const SizedBox(height: 10),
        _TurretModuleEquipmentStage(
          turretName: selectedTurret.name,
          turretType: selectedTurretType,
          turretColor: selectedTurret.color,
          selectedPart: _selectedPart,
          equippedModules: equipped,
          onSelectPart: (part) {
            setState(() {
              _selectedPart = part;
              _selectedGrade =
                  equipped[part]?.key.grade ?? TurretModuleGrade.rare;
            });
          },
        ),
        const SizedBox(height: 8),
        _TurretModuleDetailStrip(
          game: widget.game,
          item: selectedItem,
          keyData: selectedKey,
        ),
        const SizedBox(height: 8),
        _TurretModuleCandidates(
          snapshot: snapshot,
          turretType: selectedTurretType,
          selectedPart: _selectedPart,
          selectedGrade: _selectedGrade,
          onSelectGrade: (grade) {
            setState(() {
              _selectedGrade = grade;
            });
          },
        ),
      ],
    );
  }

  void focusDrawResult(TurretModuleInventoryItem item) {
    setState(() {
      _selectedTurretType = item.key.turretType;
      _selectedPart = item.key.part;
      _selectedGrade = item.key.grade;
    });
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
  const _ModuleDrawPanel({
    required this.game,
    required this.snapshot,
    required this.onDrawResults,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueChanged<List<TurretModuleInventoryItem>> onDrawResults;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0x3307111D),
        border: Border.all(color: const Color(0x55485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
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
          _drawButton(context, 1, Icons.add_circle_outline),
          const SizedBox(width: 6),
          _drawButton(context, 5, Icons.control_point_duplicate),
        ],
      ),
    );
  }

  Widget _drawButton(BuildContext context, int count, IconData icon) {
    final missingTickets = math.max(0, count - snapshot.turretModuleTickets);
    final diamondCost =
        missingTickets * RunProgression.turretModuleTicketDiamondCost;
    final canDraw = missingTickets == 0 || snapshot.diamonds >= diamondCost;
    final requiresDiamonds = diamondCost > 0;
    final costColor = canDraw
        ? _diamondCurrencyColor
        : GamePalette.textDisabled;

    return GameButton(
      key: ValueKey('turret-module-draw-button-$count'),
      onPressed: canDraw ? () => _drawModules(context, count) : null,
      compact: true,
      accentColor: GamePalette.gold,
      height: 36,
      width: requiresDiamonds ? 68 : 54,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      child: requiresDiamonds
          ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 12),
                    const SizedBox(width: 3),
                    Text(
                      '$count회',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: const TextStyle(fontSize: 10, height: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.diamond_outlined,
                      key: ValueKey('turret-module-draw-diamond-cost-$count'),
                      size: 10,
                      color: costColor,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '$diamondCost',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        color: costColor,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13),
                const SizedBox(width: 3),
                Text('$count회', maxLines: 1, overflow: TextOverflow.clip),
              ],
            ),
    );
  }

  Future<void> _drawModules(BuildContext context, int count) async {
    final missingTickets = math.max(0, count - snapshot.turretModuleTickets);
    if (missingTickets == 0) {
      onDrawResults(game.drawTurretModules(count));
      return;
    }

    final diamondCost =
        missingTickets * RunProgression.turretModuleTicketDiamondCost;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0B1725),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: const BorderSide(color: Color(0xAAE7C66A)),
          ),
          title: const Text(
            '모듈권 구매',
            style: TextStyle(
              color: GamePalette.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '모듈권을 보충하고 뽑기를 진행합니다.',
                style: TextStyle(
                  color: GamePalette.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: const Color(0x3307111D),
                  border: Border.all(color: const Color(0x55485B68)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Column(
                  children: [
                    _ModulePurchaseSummaryRow(
                      label: '보유 모듈권',
                      value: '${snapshot.turretModuleTickets}장',
                    ),
                    const SizedBox(height: 6),
                    _ModulePurchaseSummaryRow(
                      label: '구매 모듈권',
                      value: '$missingTickets장',
                    ),
                    const SizedBox(height: 7),
                    Container(height: 1, color: const Color(0x33485B68)),
                    const SizedBox(height: 7),
                    _ModulePurchaseSummaryRow(
                      label: '결제',
                      value: '$diamondCost',
                      valuePrefix: const Icon(
                        Icons.diamond_outlined,
                        size: 12,
                        color: _diamondCurrencyColor,
                      ),
                      valueColor: _diamondCurrencyColor,
                    ),
                    const SizedBox(height: 6),
                    _ModulePurchaseSummaryRow(label: '진행 횟수', value: '$count회'),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: 76,
              child: GameButton(
                onPressed: () => Navigator.of(context).pop(false),
                label: '취소',
                compact: true,
                variant: GameButtonVariant.ghost,
                accentColor: GamePalette.metal,
              ),
            ),
            SizedBox(
              width: 76,
              child: GameButton(
                onPressed: () => Navigator.of(context).pop(true),
                label: '구매',
                compact: true,
                variant: GameButtonVariant.primary,
                accentColor: GamePalette.gold,
              ),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      onDrawResults(
        game.drawTurretModules(count, buyMissingTicketsWithDiamonds: true),
      );
    }
  }
}

class _TurretModuleDrawResultLayer extends StatefulWidget {
  const _TurretModuleDrawResultLayer({
    required this.results,
    required this.onClose,
  });

  final List<TurretModuleInventoryItem> results;
  final VoidCallback onClose;

  @override
  State<_TurretModuleDrawResultLayer> createState() =>
      _TurretModuleDrawResultLayerState();
}

class _TurretModuleDrawResultLayerState
    extends State<_TurretModuleDrawResultLayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  )..forward();
  late final Animation<double> _cardAnimation = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('turret-module-draw-result-layer'),
      padding: const EdgeInsets.all(12),
      color: Colors.black.withValues(alpha: 0.72),
      child: Center(
        child: FadeTransition(
          opacity: _cardAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(_cardAnimation),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '획득 결과',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: GamePalette.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  runAlignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < widget.results.length; i++)
                      _TurretModuleDrawResultCard(
                        key: ValueKey('turret-module-draw-result-card-$i'),
                        item: widget.results[i],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: 96,
                    child: GameButton(
                      onPressed: widget.onClose,
                      label: '확인',
                      compact: true,
                      accentColor: GamePalette.gold,
                    ),
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

class _TurretModuleDrawResultCard extends StatelessWidget {
  const _TurretModuleDrawResultCard({super.key, required this.item});

  final TurretModuleInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final definition = gameTurretModuleDefinitions[item.key]!;
    final gradeColor = _gradeColor(item.key.grade);
    return Container(
      width: 122,
      height: 86,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xEE07111D),
        border: Border.all(color: gradeColor.withValues(alpha: 0.86)),
        borderRadius: BorderRadius.circular(7),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withValues(alpha: 0.24),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item.key.grade.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              color: gradeColor,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            gameTurrets[item.key.turretType]!.name,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: GameTextStyles.caption,
          ),
          const SizedBox(height: 3),
          Text(
            item.key.part.label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: GameTextStyles.caption,
          ),
          const SizedBox(height: 3),
          Text(
            definition.name,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: const TextStyle(
              color: GamePalette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
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
              Text(
                turret.name,
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

class _TurretModuleEquipmentStage extends StatelessWidget {
  const _TurretModuleEquipmentStage({
    required this.turretName,
    required this.turretType,
    required this.turretColor,
    required this.selectedPart,
    required this.equippedModules,
    required this.onSelectPart,
  });

  final String turretName;
  final TurretType turretType;
  final Color turretColor;
  final TurretModulePart selectedPart;
  final Map<TurretModulePart, TurretModuleInventoryItem> equippedModules;
  final ValueChanged<TurretModulePart> onSelectPart;

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
                    selectedPart: selectedPart,
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
                    part: entry.key,
                    item: equippedModules[entry.key],
                    selected: selectedPart == entry.key,
                    onPressed: () => onSelectPart(entry.key),
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
            bottom: 14,
            child: Text(
              name,
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
    required this.selectedPart,
    required this.socketWidth,
    required this.socketRight,
  });

  final TurretModulePart selectedPart;
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
      final selected = selectedPart == part;
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
    return oldDelegate.selectedPart != selectedPart ||
        oldDelegate.socketWidth != socketWidth ||
        oldDelegate.socketRight != socketRight;
  }
}

class _TurretModuleSocketButton extends StatelessWidget {
  const _TurretModuleSocketButton({
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
    final effect = item == null ? null : effectiveTurretModuleEffect(item);
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
              Text(
                definition?.name ?? '장착 없음',
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: const TextStyle(
                  color: GamePalette.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                effect == null ? '비어 있음' : turretModuleEffectText(effect),
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

class _TurretModuleDetailStrip extends StatelessWidget {
  const _TurretModuleDetailStrip({
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
    final effect = owned
        ? effectiveTurretModuleEffect(item!)
        : definition.effect;
    final accentColor = owned ? _gradeColor(keyData.grade) : GamePalette.metal;
    final canFuse =
        item != null &&
        item!.shards >= turretModuleFusionShardCost &&
        !(item!.key.grade == TurretModuleGrade.rare &&
            item!.stars >= turretModuleMaxStars);

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: owned
            ? accentColor.withValues(alpha: 0.13)
            : const Color(0x2207111D),
        border: Border.all(
          color: item?.equipped == true
              ? GamePalette.cyan
              : accentColor.withValues(alpha: owned ? 0.48 : 0.36),
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
                    Text(
                      keyData.grade.label,
                      style: GameTextStyles.withColor(
                        GameTextStyles.chip,
                        _gradeColor(keyData.grade),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        definition.name,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
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
                  '${keyData.part.label} · ${gameTurrets[keyData.turretType]!.name} · '
                  '${owned ? _moduleGradeStarText(item!) : '아직 보유하지 않음'}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: GameTextStyles.caption,
                ),
                const SizedBox(height: 4),
                Text(
                  '장착 효과: ${turretModuleEffectText(effect)}',
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: GameTextStyles.withColor(
                    GameTextStyles.body,
                    GamePalette.goldBright,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(width: 58, child: _detailAction(canFuse)),
        ],
      ),
    );
  }

  Widget _detailAction(bool canFuse) {
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

class _TurretModuleCandidates extends StatelessWidget {
  const _TurretModuleCandidates({
    required this.snapshot,
    required this.turretType,
    required this.selectedPart,
    required this.selectedGrade,
    required this.onSelectGrade,
  });

  final GameSnapshot snapshot;
  final TurretType turretType;
  final TurretModulePart selectedPart;
  final TurretModuleGrade selectedGrade;
  final ValueChanged<TurretModuleGrade> onSelectGrade;

  @override
  Widget build(BuildContext context) {
    final family = turretModuleFamilyFor(turretType, selectedPart);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('${selectedPart.label} 장착 모듈', style: GameTextStyles.sectionTitle),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final grade in TurretModuleGrade.values) ...[
              Expanded(
                child: _TurretModuleCandidateChip(
                  grade: grade,
                  part: selectedPart,
                  item: _itemFor(grade, family),
                  selected: selectedGrade == grade,
                  onPressed: () => onSelectGrade(grade),
                ),
              ),
              if (grade != TurretModuleGrade.values.last)
                const SizedBox(width: 7),
            ],
          ],
        ),
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

class _TurretModuleCandidateChip extends StatelessWidget {
  const _TurretModuleCandidateChip({
    required this.grade,
    required this.part,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleGrade grade;
  final TurretModulePart part;
  final TurretModuleInventoryItem? item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final item = this.item;
    final owned = item != null;
    final gradeColor = _gradeColor(grade);
    final borderColor = selected
        ? GamePalette.cyan
        : item?.equipped == true
        ? GamePalette.cyan.withValues(alpha: 0.58)
        : owned
        ? gradeColor.withValues(alpha: 0.58)
        : const Color(0x55485B68);
    final iconColor = owned
        ? gradeColor
        : GamePalette.textDisabled.withValues(alpha: 0.78);
    final starText = _moduleStarText(item?.stars ?? 0);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          height: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x2233D8FF)
                : owned
                ? const Color(0x3307111D)
                : const Color(0x1A07111D),
            border: Border.all(color: borderColor, width: selected ? 1.6 : 1.1),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Text(
                    grade.label,
                    style: GameTextStyles.withColor(
                      GameTextStyles.chip,
                      gradeColor,
                    ),
                  ),
                  const Spacer(),
                  _ModuleOwnershipBadge(
                    label: _moduleOwnershipLabel(item),
                    owned: owned,
                    equipped: item?.equipped == true,
                  ),
                ],
              ),
              const Spacer(),
              Icon(_partIcon(part), color: iconColor, size: 25),
              const Spacer(),
              SizedBox(
                height: 12,
                child: Center(
                  child: starText.isEmpty
                      ? const SizedBox.shrink()
                      : Text(
                          starText,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: const TextStyle(
                            color: GamePalette.goldBright,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 3),
              owned ? _ShardMeter(item: item) : const _MissingModuleHint(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleOwnershipBadge extends StatelessWidget {
  const _ModuleOwnershipBadge({
    required this.label,
    required this.owned,
    required this.equipped,
  });

  final String label;
  final bool owned;
  final bool equipped;

  @override
  Widget build(BuildContext context) {
    final color = equipped
        ? GamePalette.cyan
        : owned
        ? GamePalette.green
        : GamePalette.textDisabled;
    return Container(
      height: 17,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: owned ? 0.13 : 0.08),
        border: Border.all(color: color.withValues(alpha: owned ? 0.5 : 0.32)),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.clip,
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}

class _ShardMeter extends StatelessWidget {
  const _ShardMeter({required this.item});

  final TurretModuleInventoryItem? item;

  @override
  Widget build(BuildContext context) {
    final shards = item?.shards ?? 0;
    final progress = (shards / turretModuleFusionShardCost).clamp(0.0, 1.0);
    return Container(
      height: 12,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0x33485B68),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Stack(
        children: [
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(color: GamePalette.cyan.withValues(alpha: 0.62)),
          ),
          Center(
            child: Text(
              '$shards/$turretModuleFusionShardCost',
              style: const TextStyle(
                color: GamePalette.textPrimary,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingModuleHint extends StatelessWidget {
  const _MissingModuleHint();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 12,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x22485B68),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Text(
        '획득 필요',
        style: TextStyle(
          color: GamePalette.textDisabled,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          height: 1,
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

class _ModulePurchaseSummaryRow extends StatelessWidget {
  const _ModulePurchaseSummaryRow({
    required this.label,
    required this.value,
    this.valuePrefix,
    this.valueColor = GamePalette.textPrimary,
  });

  final String label;
  final String value;
  final Widget? valuePrefix;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: GameTextStyles.caption)),
        if (valuePrefix != null) ...[valuePrefix!, const SizedBox(width: 3)],
        Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

const Map<TurretModulePart, double> _partPositions = {
  TurretModulePart.core: 16,
  TurretModulePart.barrel: 90,
  TurretModulePart.frame: 164,
};

const double _moduleSocketHeight = 66;
const double _moduleLinkHubGap = 52;
const double _moduleLinkLaneGap = 24;

double _partSocketCenterY(TurretModulePart part) {
  return _partPositions[part]! + (_moduleSocketHeight / 2);
}

TurretModuleInventoryItem? _moduleFor(
  GameSnapshot snapshot,
  TurretModuleKey key,
) {
  for (final item in snapshot.ownedTurretModules) {
    if (item.key == key) {
      return item;
    }
  }
  return null;
}

Color _gradeColor(TurretModuleGrade grade) {
  return switch (grade) {
    TurretModuleGrade.normal => const Color(0xFFB8C7D0),
    TurretModuleGrade.magic => const Color(0xFF72E0A2),
    TurretModuleGrade.rare => GamePalette.goldBright,
  };
}

IconData _partIcon(TurretModulePart part) {
  return switch (part) {
    TurretModulePart.core => Icons.memory_outlined,
    TurretModulePart.barrel => Icons.speed_outlined,
    TurretModulePart.frame => Icons.account_tree_outlined,
  };
}

String _moduleGradeStarText(TurretModuleInventoryItem item) {
  final starLabel = item.stars > 0 ? '${item.stars}성' : '보유';
  return '${item.key.grade.label} $starLabel · 조각 ${item.shards}/$turretModuleFusionShardCost';
}

String _moduleStarText(int stars) {
  final clampedStars = stars.clamp(0, turretModuleMaxStars).toInt();
  if (clampedStars == 0) {
    return '';
  }
  return List.filled(clampedStars, '★').join();
}

String _moduleOwnershipLabel(TurretModuleInventoryItem? item) {
  if (item == null) {
    return '미보유';
  }
  if (item.equipped) {
    return '장착 중';
  }
  return '보유';
}

TurretModuleInventoryItem? _bestDrawResult(
  List<TurretModuleInventoryItem> results,
) {
  TurretModuleInventoryItem? best;
  for (final result in results) {
    if (best == null ||
        _drawResultPriority(result) > _drawResultPriority(best)) {
      best = result;
    }
  }
  return best;
}

int _drawResultPriority(TurretModuleInventoryItem item) {
  final gradePriority = switch (item.key.grade) {
    TurretModuleGrade.normal => 0,
    TurretModuleGrade.magic => 1,
    TurretModuleGrade.rare => 2,
  };
  final acquisitionPriority =
      item.shards == 0 || item.shards >= turretModuleFusionShardCost ? 1 : 0;
  return gradePriority * 10 + acquisitionPriority;
}
