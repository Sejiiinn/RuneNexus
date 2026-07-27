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
  TurretModulePart? _selectedPartFilter;
  String? _selectedItemId;

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
    final inventoryItems = _filteredModulesFor(
      snapshot,
      selectedTurretType,
      _selectedPartFilter,
    );
    final selectedItem = _selectedInventoryItem(inventoryItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModuleDrawPanel(
          game: widget.game,
          snapshot: snapshot,
          turretType: selectedTurretType,
          onDrawResults: widget.onDrawResults,
        ),
        const SizedBox(height: 10),
        _TurretModuleSelector(
          availableTurretTypes: snapshot.availableTurretTypes,
          selectedTurretType: selectedTurretType,
          onSelect: (type) {
            setState(() {
              _selectedTurretType = type;
              _selectedPartFilter = null;
              _selectedItemId = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _TurretModuleEquipmentStage(
          turretName: selectedTurret.name,
          turretType: selectedTurretType,
          turretColor: selectedTurret.color,
          equippedModules: equipped,
          onSelectEquippedModule: (item) {
            setState(() {
              _selectedPartFilter = item.key.part;
              _selectedItemId = item.id;
            });
          },
        ),
        const SizedBox(height: 8),
        _TurretModuleDetailStrip(
          game: widget.game,
          item: selectedItem,
          turretType: selectedTurretType,
          partFilter: _selectedPartFilter,
          itemCount: inventoryItems.length,
        ),
        const SizedBox(height: 8),
        _TurretModuleInventoryList(
          turretType: selectedTurretType,
          selectedPartFilter: _selectedPartFilter,
          selectedItemId: _selectedItemId,
          items: inventoryItems,
          onBulkDisassemble: () => _showBulkDisassembleDialog(
            context,
            selectedTurretType,
            _selectedPartFilter,
            inventoryItems,
          ),
          onSelectPartFilter: (part) {
            setState(() {
              _selectedPartFilter = part;
              _selectedItemId = null;
            });
          },
          onSelectItem: (item) => setState(() => _selectedItemId = item.id),
        ),
      ],
    );
  }

  void focusDrawResult(TurretModuleInventoryItem item) {
    setState(() {
      _selectedTurretType = item.key.turretType;
      _selectedPartFilter = null;
      _selectedItemId = item.id;
    });
  }

  TurretModuleInventoryItem? _selectedInventoryItem(
    List<TurretModuleInventoryItem> items,
  ) {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return null;
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

  List<TurretModuleInventoryItem> _filteredModulesFor(
    GameSnapshot snapshot,
    TurretType turretType,
    TurretModulePart? partFilter,
  ) {
    return List.unmodifiable(
      snapshot.ownedTurretModules.where((item) {
        return item.key.turretType == turretType &&
            (partFilter == null || item.key.part == partFilter);
      }),
    );
  }

  Future<void> _showBulkDisassembleDialog(
    BuildContext context,
    TurretType turretType,
    TurretModulePart? partFilter,
    List<TurretModuleInventoryItem> items,
  ) async {
    final selectedIds = await showGameDialog<List<String>>(
      context: context,
      builder: (context) => _TurretModuleBulkDisassembleDialog(
        scopeLabel:
            '${gameTurrets[turretType]!.name} 포탑 · ${_partFilterLabel(partFilter)}',
        items: items,
      ),
    );
    if (!mounted || selectedIds == null || selectedIds.isEmpty) {
      return;
    }
    if (selectedIds.contains(_selectedItemId)) {
      setState(() => _selectedItemId = null);
    }
    widget.game.disassembleTurretModules(selectedIds);
  }
}

class _ModuleDrawPanel extends StatelessWidget {
  const _ModuleDrawPanel({
    required this.game,
    required this.snapshot,
    required this.turretType,
    required this.onDrawResults,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final TurretType turretType;
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
                    Flexible(
                      child: _ModuleSingleLineText(
                        '$count회',
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, height: 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DiamondCurrencyIcon(
                      key: ValueKey('turret-module-draw-diamond-cost-$count'),
                      size: 10,
                    ),
                    const SizedBox(width: 2),
                    Flexible(
                      child: _ModuleSingleLineText(
                        '$diamondCost',
                        alignment: Alignment.center,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: costColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
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
                Flexible(
                  child: _ModuleSingleLineText(
                    '$count회',
                    alignment: Alignment.center,
                    textAlign: TextAlign.center,
                    style: DefaultTextStyle.of(context).style,
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _drawModules(BuildContext context, int count) async {
    final missingTickets = math.max(0, count - snapshot.turretModuleTickets);
    if (missingTickets == 0) {
      onDrawResults(game.drawTurretModules(count, turretType: turretType));
      return;
    }

    final diamondCost =
        missingTickets * RunProgression.turretModuleTicketDiamondCost;
    final confirmed = await showGameDialog<bool>(
      context: context,
      builder: (context) {
        return GameModalFrame(
          maxWidth: 340,
          tone: GameModalTone.reward,
          accentColor: GamePalette.gold,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.confirmation_number_outlined,
                    color: GamePalette.goldBright,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('모듈권 구매', style: GameTextStyles.title)),
                ],
              ),
              const SizedBox(height: 12),
              const Text('모듈권을 보충하고 뽑기를 진행합니다.', style: GameTextStyles.body),
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
                      valuePrefix: const DiamondCurrencyIcon(size: 12),
                      valueColor: _diamondCurrencyColor,
                    ),
                    const SizedBox(height: 6),
                    _ModulePurchaseSummaryRow(label: '진행 횟수', value: '$count회'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      label: '취소',
                      variant: GameButtonVariant.ghost,
                      accentColor: GamePalette.metal,
                      height: 38,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      label: '구매',
                      variant: GameButtonVariant.primary,
                      accentColor: GamePalette.gold,
                      height: 38,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
    if (confirmed == true) {
      onDrawResults(
        game.drawTurretModules(
          count,
          turretType: turretType,
          buyMissingTicketsWithDiamonds: true,
        ),
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
    final bestResult = _bestDrawResult(widget.results);
    final turretTypes = widget.results
        .map((item) => item.key.turretType)
        .toSet();
    final resultSubtitle = turretTypes.length == 1
        ? '${gameTurrets[turretTypes.single]!.name} 포탑 모듈'
        : '포탑 모듈 ${widget.results.length}개';
    return Container(
      key: const ValueKey('turret-module-draw-result-layer'),
      padding: const EdgeInsets.all(12),
      color: Colors.black.withValues(alpha: 0.80),
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
                const SizedBox(height: 3),
                Text(
                  resultSubtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: GamePalette.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                LayoutBuilder(
                  builder: (context, constraints) {
                    const cardGap = 8.0;
                    final cardWidth = math.min(
                      164.0,
                      (constraints.maxWidth - cardGap) / 2,
                    );
                    return Wrap(
                      alignment: WrapAlignment.center,
                      runAlignment: WrapAlignment.center,
                      spacing: cardGap,
                      runSpacing: 8,
                      children: [
                        for (var i = 0; i < widget.results.length; i++)
                          _TurretModuleDrawResultCard(
                            key: ValueKey('turret-module-draw-result-card-$i'),
                            item: widget.results[i],
                            width: cardWidth,
                            highlighted: identical(
                              widget.results[i],
                              bestResult,
                            ),
                          ),
                      ],
                    );
                  },
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
  const _TurretModuleDrawResultCard({
    super.key,
    required this.item,
    required this.width,
    required this.highlighted,
  });

  final TurretModuleInventoryItem item;
  final double width;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final definition = gameTurretModuleDefinitions[item.key]!;
    final gradeColor = _gradeColor(item.key.grade);
    final turretName = gameTurrets[item.key.turretType]!.name;
    return Container(
      width: width,
      height: width.clamp(148.0, 164.0),
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            gradeColor.withValues(alpha: highlighted ? 0.18 : 0.10),
            const Color(0xF505101B),
            const Color(0xFF030A12),
          ],
        ),
        border: Border.all(
          color: gradeColor.withValues(alpha: highlighted ? 1 : 0.74),
          width: highlighted ? 1.8 : 1.0,
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: gradeColor.withValues(alpha: highlighted ? 0.42 : 0.18),
            blurRadius: highlighted ? 18 : 10,
            spreadRadius: highlighted ? 2 : 0,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              key: ValueKey('turret-module-draw-grade-${item.id}'),
              height: 16,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: gradeColor.withValues(alpha: 0.16),
                border: Border.all(color: gradeColor.withValues(alpha: 0.68)),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                item.key.grade.label,
                style: TextStyle(
                  color: gradeColor,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Center(
                  child: _TurretModuleDrawEmblem(
                    part: item.key.part,
                    color: gradeColor,
                    highlighted: highlighted,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              _ModuleSingleLineText(
                definition.name,
                alignment: Alignment.center,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GamePalette.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 2),
              _ModuleSingleLineText(
                '$turretName 포탑 · ${item.key.part.label}',
                alignment: Alignment.center,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: GamePalette.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 5),
              for (var index = 0; index < item.options.length; index++) ...[
                if (index > 0) const SizedBox(height: 2),
                _TurretModuleDrawOptionChip(
                  text: turretModuleOptionText(item.options[index]),
                  color: gradeColor,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _TurretModuleDrawEmblem extends StatelessWidget {
  const _TurretModuleDrawEmblem({
    required this.part,
    required this.color,
    required this.highlighted,
  });

  final TurretModulePart part;
  final Color color;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 54,
      child: CustomPaint(
        painter: _TurretModuleDrawEmblemPainter(
          color: color,
          highlighted: highlighted,
        ),
        child: Center(
          child: _TurretModuleItemIcon(part: part, color: color, size: 34),
        ),
      ),
    );
  }
}

class _TurretModuleDrawEmblemPainter extends CustomPainter {
  const _TurretModuleDrawEmblemPainter({
    required this.color,
    required this.highlighted,
  });

  final Color color;
  final bool highlighted;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (highlighted) {
      canvas.drawCircle(
        center,
        size.shortestSide * 0.48,
        Paint()
          ..shader = RadialGradient(
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }
    final path = Path();
    for (var index = 0; index < 6; index++) {
      final angle = -math.pi / 2 + math.pi / 3 * index;
      final point = Offset(
        center.dx + math.cos(angle) * size.width * 0.40,
        center.dy + math.sin(angle) * size.height * 0.40,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.09)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: highlighted ? 0.90 : 0.58)
        ..style = PaintingStyle.stroke
        ..strokeWidth = highlighted ? 1.8 : 1.2,
    );
  }

  @override
  bool shouldRepaint(_TurretModuleDrawEmblemPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.highlighted != highlighted;
  }
}

class _TurretModuleDrawOptionChip extends StatelessWidget {
  const _TurretModuleDrawOptionChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 15,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        border: Border.all(color: color.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: _ModuleSingleLineText(
        text,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: GamePalette.textSecondary,
          fontSize: 8.5,
          fontWeight: FontWeight.w700,
          height: 1,
        ),
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

class _TurretModuleDisassembleDialog extends StatelessWidget {
  const _TurretModuleDisassembleDialog({required this.item});

  final TurretModuleInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final returnDiamonds = item.key.grade.disassembleDiamondValue;
    final gradeColor = _gradeColor(item.key.grade);
    return GameModalFrame(
      key: const ValueKey('turret-module-disassemble-dialog'),
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('모듈 분해', style: GameTextStyles.title)),
              _ModuleInfoChip(text: item.key.grade.label),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '이 모듈 분해 시 $returnDiamonds 다이아가 반환됩니다. 진행하시겠습니까?',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.13),
              border: Border.all(color: gradeColor.withValues(alpha: 0.44)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const DiamondCurrencyIcon(size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('반환 다이아', style: GameTextStyles.caption),
                ),
                Text(
                  '$returnDiamonds',
                  style: GameTextStyles.withColor(
                    GameTextStyles.sectionTitle,
                    _diamondCurrencyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-disassemble-cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                  label: '취소',
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-disassemble-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  label: '분해',
                  icon: const Icon(Icons.delete_outline, size: 17),
                  variant: GameButtonVariant.danger,
                  height: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurretModuleBulkDisassembleDialog extends StatefulWidget {
  const _TurretModuleBulkDisassembleDialog({
    required this.scopeLabel,
    required this.items,
  });

  final String scopeLabel;
  final List<TurretModuleInventoryItem> items;

  @override
  State<_TurretModuleBulkDisassembleDialog> createState() =>
      _TurretModuleBulkDisassembleDialogState();
}

class _TurretModuleBulkDisassembleDialogState
    extends State<_TurretModuleBulkDisassembleDialog> {
  final Set<TurretModuleGrade> _selectedGrades = {TurretModuleGrade.normal};
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _selectGradeItems(TurretModuleGrade.normal);
  }

  List<TurretModuleInventoryItem> get _availableItems {
    return widget.items
        .where((item) {
          return !item.equipped && item.key.grade != TurretModuleGrade.unique;
        })
        .toList(growable: false);
  }

  List<TurretModuleInventoryItem> get _visibleItems {
    return _availableItems
        .where((item) => _selectedGrades.contains(item.key.grade))
        .toList(growable: false);
  }

  List<TurretModuleInventoryItem> get _selectedItems {
    return _visibleItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
  }

  void _toggleGrade(TurretModuleGrade grade) {
    setState(() {
      if (_selectedGrades.remove(grade)) {
        _selectedItemIds.removeWhere(
          (id) => widget.items.any(
            (item) => item.id == id && item.key.grade == grade,
          ),
        );
      } else {
        _selectedGrades.add(grade);
        _selectGradeItems(grade);
      }
    });
  }

  void _selectGradeItems(TurretModuleGrade grade) {
    for (final item in widget.items) {
      if (!item.equipped && item.key.grade == grade) {
        _selectedItemIds.add(item.id);
      }
    }
  }

  void _toggleItem(String id) {
    setState(() {
      if (!_selectedItemIds.remove(id)) {
        _selectedItemIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final selectedItems = _selectedItems;
    final returnDiamonds = selectedItems.fold<int>(
      0,
      (total, item) => total + item.key.grade.disassembleDiamondValue,
    );
    final previewHeight = visibleItems.isEmpty
        ? 54.0
        : math.min(230.0, visibleItems.length * 54.0);

    return GameModalFrame(
      key: const ValueKey('turret-module-bulk-disassemble-dialog'),
      maxWidth: 360,
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      tone: GameModalTone.danger,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delete_sweep_outlined,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('모듈 일괄 분해', style: GameTextStyles.title),
              ),
              _ModuleInfoChip(text: widget.scopeLabel),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '분해할 등급을 선택하세요. 장착 모듈은 제외됩니다.',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final grade in const [
                TurretModuleGrade.normal,
                TurretModuleGrade.magic,
                TurretModuleGrade.rare,
              ])
                _TurretModuleBulkGradeChip(
                  grade: grade,
                  selected: _selectedGrades.contains(grade),
                  onPressed: () => _toggleGrade(grade),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('분해 대상 선택', style: GameTextStyles.sectionTitle),
              ),
              _ModuleInfoChip(text: '선택 ${selectedItems.length}개'),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: previewHeight,
            child: visibleItems.isEmpty
                ? const _TurretModuleEmptyInventoryHint(
                    text: '선택한 등급에 분해 가능한 모듈 없음',
                  )
                : ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return _TurretModuleBulkTargetRow(
                        key: ValueKey('turret-module-bulk-target-${item.id}'),
                        item: item,
                        selected: _selectedItemIds.contains(item.id),
                        onPressed: () => _toggleItem(item.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x2207111D),
              border: Border.all(color: const Color(0x55485B68)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const DiamondCurrencyIcon(size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('총 반환 다이아', style: GameTextStyles.caption),
                ),
                Text(
                  '$returnDiamonds',
                  key: const ValueKey('turret-module-bulk-return-diamonds'),
                  style: GameTextStyles.withColor(
                    GameTextStyles.sectionTitle,
                    _diamondCurrencyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-bulk-disassemble-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  label: '취소',
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-bulk-disassemble-confirm'),
                  onPressed: selectedItems.isEmpty
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(selectedItems.map((item) => item.id).toList()),
                  label: '일괄 분해',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  variant: GameButtonVariant.danger,
                  height: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TurretModuleBulkGradeChip extends StatelessWidget {
  const _TurretModuleBulkGradeChip({
    required this.grade,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleGrade grade;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(grade);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('turret-module-bulk-grade-${grade.name}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? gradeColor.withValues(alpha: 0.16)
                : const Color(0x2207111D),
            border: Border.all(
              color: selected
                  ? gradeColor.withValues(alpha: 0.88)
                  : const Color(0x55485B68),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 12,
                color: selected ? gradeColor : GamePalette.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                grade.label,
                style: GameTextStyles.withColor(
                  GameTextStyles.chip,
                  selected ? gradeColor : GamePalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurretModuleBulkTargetRow extends StatelessWidget {
  const _TurretModuleBulkTargetRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleInventoryItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(item.key.grade);
    final definition = gameTurretModuleDefinitions[item.key];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: selected ? 1 : 0.48,
          child: Container(
            height: 49,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? gradeColor.withValues(alpha: 0.12)
                  : const Color(0x2207111D),
              border: Border.all(
                color: selected
                    ? gradeColor.withValues(alpha: 0.72)
                    : const Color(0x55485B68),
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: _TurretModuleItemIcon(
                    part: item.key.part,
                    color: gradeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModuleSingleLineText(
                        definition?.name ?? '${item.key.grade.label} 모듈',
                        style: const TextStyle(
                          color: GamePalette.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.key.grade.label} · ${item.key.part.label} · ${item.options.length}옵션',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: GameTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: selected ? gradeColor : GamePalette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TurretModuleInventoryList extends StatelessWidget {
  const _TurretModuleInventoryList({
    required this.turretType,
    required this.selectedPartFilter,
    required this.selectedItemId,
    required this.items,
    required this.onBulkDisassemble,
    required this.onSelectPartFilter,
    required this.onSelectItem,
  });

  final TurretType turretType;
  final TurretModulePart? selectedPartFilter;
  final String? selectedItemId;
  final List<TurretModuleInventoryItem> items;
  final VoidCallback onBulkDisassemble;
  final ValueChanged<TurretModulePart?> onSelectPartFilter;
  final ValueChanged<TurretModuleInventoryItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    final turretName = gameTurrets[turretType]!.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('$turretName 모듈 인벤토리', style: GameTextStyles.sectionTitle),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: _TurretModulePartFilterChip(
                key: const ValueKey('turret-module-part-filter-all'),
                label: '전체',
                selected: selectedPartFilter == null,
                onPressed: () => onSelectPartFilter(null),
              ),
            ),
            const SizedBox(width: 5),
            for (final part in TurretModulePart.values) ...[
              Expanded(
                child: _TurretModulePartFilterChip(
                  key: ValueKey('turret-module-part-filter-${part.name}'),
                  label: part.label,
                  selected: selectedPartFilter == part,
                  onPressed: () => onSelectPartFilter(part),
                ),
              ),
              if (part != TurretModulePart.values.last)
                const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          _TurretModuleEmptyInventoryHint(
            text: selectedPartFilter == null
                ? '획득한 $turretName 모듈 없음'
                : '획득한 $turretName ${selectedPartFilter!.label} 없음',
          )
        else
          _TurretModuleInventoryGrid(
            items: items,
            selectedItemId: selectedItemId,
            onBulkDisassemble: onBulkDisassemble,
            onSelectItem: onSelectItem,
          ),
      ],
    );
  }
}

class _TurretModuleInventoryGrid extends StatelessWidget {
  const _TurretModuleInventoryGrid({
    required this.items,
    required this.selectedItemId,
    required this.onBulkDisassemble,
    required this.onSelectItem,
  });

  final List<TurretModuleInventoryItem> items;
  final String? selectedItemId;
  final VoidCallback onBulkDisassemble;
  final ValueChanged<TurretModuleInventoryItem> onSelectItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gridPadding = 8.0;
        const gap = 6.0;
        final innerWidth = math.max(
          0.0,
          constraints.maxWidth - (gridPadding * 2),
        );
        final columnCount = innerWidth < 324 ? 5 : 6;
        final trailingEmptySlotCount = items.length % columnCount == 0
            ? 0
            : columnCount - (items.length % columnCount);
        final visibleSlotCount = items.length + trailingEmptySlotCount;
        return Container(
          padding: const EdgeInsets.all(gridPadding),
          decoration: BoxDecoration(
            color: const Color(0x2207111D),
            border: Border.all(color: const Color(0x55485B68)),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ModuleSingleLineText(
                      '보유 ${items.length}개',
                      style: GameTextStyles.caption,
                    ),
                  ),
                  _ModuleActionChip(
                    key: const ValueKey('turret-module-bulk-disassemble-open'),
                    text: '일괄 분해',
                    onPressed: onBulkDisassemble,
                  ),
                ],
              ),
              const SizedBox(height: 7),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                ),
                itemCount: visibleSlotCount,
                itemBuilder: (context, index) {
                  if (index >= items.length) {
                    return const _TurretModuleEmptySlot();
                  }
                  final item = items[index];
                  return _TurretModuleInventorySlot(
                    key: ValueKey('turret-module-inventory-slot-${item.id}'),
                    item: item,
                    selected: item.id == selectedItemId,
                    onPressed: () => onSelectItem(item),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TurretModulePartFilterChip extends StatelessWidget {
  const _TurretModulePartFilterChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 24,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 7),
          decoration: BoxDecoration(
            color: selected ? const Color(0x2233D8FF) : const Color(0x2207111D),
            border: Border.all(
              color: selected ? GamePalette.cyan : const Color(0x55485B68),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: _ModuleSingleLineText(
            label,
            alignment: Alignment.center,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? GamePalette.textPrimary : GamePalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

class _TurretModuleInventorySlot extends StatelessWidget {
  const _TurretModuleInventorySlot({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleInventoryItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(item.key.grade);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: Container(
          decoration: BoxDecoration(
            color: selected
                ? const Color(0x2233D8FF)
                : item.equipped
                ? const Color(0x2233D8FF)
                : const Color(0xAA07111D),
            border: Border.all(
              color: selected
                  ? GamePalette.cyan
                  : gradeColor.withValues(alpha: item.equipped ? 0.82 : 0.62),
              width: selected ? 1.8 : 1.1,
            ),
            borderRadius: BorderRadius.circular(7),
            boxShadow: item.key.grade == TurretModuleGrade.unique
                ? [
                    BoxShadow(
                      color: gradeColor.withValues(alpha: 0.22),
                      blurRadius: 10,
                      spreadRadius: 0.5,
                    ),
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Center(
                  child: _TurretModuleItemIcon(
                    part: item.key.part,
                    color: gradeColor,
                  ),
                ),
              ),
              Positioned(
                top: 3,
                left: 3,
                child: _TurretModulePartBadge(
                  part: item.key.part,
                  color: gradeColor,
                ),
              ),
              if (item.equipped)
                Positioned(
                  top: 3,
                  right: 3,
                  child: _TurretModuleEquippedBadge(color: GamePalette.cyan),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 4,
                child: _TurretModuleOptionDots(
                  count: item.options.length,
                  color: gradeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurretModuleEmptySlot extends StatelessWidget {
  const _TurretModuleEmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x3307111D),
        border: Border.all(color: const Color(0x33485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
    );
  }
}

class _TurretModulePartBadge extends StatelessWidget {
  const _TurretModulePartBadge({required this.part, required this.color});

  final TurretModulePart part;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xAA02070D),
        border: Border.all(color: color.withValues(alpha: 0.42)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        _partShortLabel(part),
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

class _TurretModuleEquippedBadge extends StatelessWidget {
  const _TurretModuleEquippedBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 15,
      height: 14,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        border: Border.all(color: color.withValues(alpha: 0.68)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '장',
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

class _TurretModuleOptionDots extends StatelessWidget {
  const _TurretModuleOptionDots({required this.count, required this.color});

  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < count; index++) ...[
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 4),
              ],
            ),
          ),
          if (index != count - 1) const SizedBox(width: 3),
        ],
      ],
    );
  }
}

class _TurretModuleItemIcon extends StatelessWidget {
  const _TurretModuleItemIcon({
    required this.part,
    required this.color,
    this.size = 30,
  });

  final TurretModulePart part;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _TurretModulePartGlyphPainter(part: part, color: color),
      child: SizedBox.square(dimension: size),
    );
  }
}

class _TurretModulePartGlyphPainter extends CustomPainter {
  const _TurretModulePartGlyphPainter({
    required this.part,
    required this.color,
  });

  final TurretModulePart part;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    final glow = Paint()
      ..color = color.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(size.center(Offset.zero), size.shortestSide * 0.48, glow);

    switch (part) {
      case TurretModulePart.core:
        _paintCore(canvas, size, stroke, fill);
      case TurretModulePart.barrel:
        _paintBarrel(canvas, size, fill);
      case TurretModulePart.frame:
        _paintFrame(canvas, size, stroke);
    }
  }

  void _paintCore(Canvas canvas, Size size, Paint stroke, Paint fill) {
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.18,
        size.height * 0.18,
        size.width * 0.64,
        size.height * 0.64,
      ),
      const Radius.circular(5),
    );
    canvas.drawRRect(outer, stroke);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: size.center(Offset.zero),
          width: size.width * 0.28,
          height: size.height * 0.28,
        ),
        const Radius.circular(3),
      ),
      fill,
    );
    for (final x in [0.31, 0.50, 0.69]) {
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.04),
        Offset(size.width * x, size.height * 0.18),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * x, size.height * 0.82),
        Offset(size.width * x, size.height * 0.96),
        stroke,
      );
    }
    for (final y in [0.34, 0.66]) {
      canvas.drawLine(
        Offset(size.width * 0.04, size.height * y),
        Offset(size.width * 0.18, size.height * y),
        stroke,
      );
      canvas.drawLine(
        Offset(size.width * 0.82, size.height * y),
        Offset(size.width * 0.96, size.height * y),
        stroke,
      );
    }
  }

  void _paintBarrel(Canvas canvas, Size size, Paint fill) {
    final barrelWidth = size.width * 0.20;
    final barrelHeight = size.height * 0.72;
    final top = size.height * 0.08;
    for (final left in [size.width * 0.25, size.width * 0.55]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, top, barrelWidth, barrelHeight),
          const Radius.circular(4),
        ),
        fill,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.18,
          size.height * 0.65,
          size.width * 0.64,
          size.height * 0.25,
        ),
        const Radius.circular(6),
      ),
      Paint()
        ..color = color.withValues(alpha: 0.58)
        ..style = PaintingStyle.fill,
    );
  }

  void _paintFrame(Canvas canvas, Size size, Paint stroke) {
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.34, stroke);
    final center = size.center(Offset.zero);
    for (final angle in [math.pi / 4, math.pi * 3 / 4]) {
      final dx = math.cos(angle) * size.width * 0.32;
      final dy = math.sin(angle) * size.height * 0.32;
      canvas.drawLine(
        Offset(center.dx - dx, center.dy - dy),
        Offset(center.dx + dx, center.dy + dy),
        stroke,
      );
    }
    canvas.drawCircle(center, size.width * 0.08, stroke);
  }

  @override
  bool shouldRepaint(_TurretModulePartGlyphPainter oldDelegate) {
    return oldDelegate.part != part || oldDelegate.color != color;
  }
}

class _TurretModuleEmptyInventoryHint extends StatelessWidget {
  const _TurretModuleEmptyInventoryHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0x2207111D),
        border: Border.all(color: const Color(0x55485B68)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: _ModuleSingleLineText(
        text,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: GamePalette.textPrimary,
          fontSize: 12,
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
      child: _ModuleSingleLineText(
        text,
        alignment: Alignment.center,
        textAlign: TextAlign.center,
        style: GameTextStyles.caption,
      ),
    );
  }
}

class _ModuleActionChip extends StatelessWidget {
  const _ModuleActionChip({
    super.key,
    required this.text,
    required this.onPressed,
  });

  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 25,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: GamePalette.danger.withValues(alpha: 0.12),
            border: Border.all(
              color: GamePalette.danger.withValues(alpha: 0.58),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.delete_sweep_outlined,
                size: 14,
                color: GamePalette.danger,
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: GameTextStyles.withColor(
                  GameTextStyles.caption,
                  GamePalette.danger,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModuleSingleLineText extends StatelessWidget {
  const _ModuleSingleLineText(
    this.text, {
    required this.style,
    this.alignment = Alignment.centerLeft,
    this.textAlign,
  });

  final String text;
  final TextStyle style;
  final Alignment alignment;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final child = Text(
          text,
          maxLines: 1,
          softWrap: false,
          textAlign: textAlign,
          style: style,
        );
        if (!constraints.hasBoundedWidth) {
          return child;
        }
        return SizedBox(
          width: constraints.maxWidth,
          child: FittedBox(
            alignment: alignment,
            fit: BoxFit.scaleDown,
            child: child,
          ),
        );
      },
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

Color _gradeColor(TurretModuleGrade grade) {
  return switch (grade) {
    TurretModuleGrade.normal => const Color(0xFFB8C7D0),
    TurretModuleGrade.magic => const Color(0xFF72E0A2),
    TurretModuleGrade.rare => GamePalette.goldBright,
    TurretModuleGrade.unique => const Color(0xFFFF8AE8),
  };
}

String _partShortLabel(TurretModulePart part) {
  return switch (part) {
    TurretModulePart.core => '코',
    TurretModulePart.barrel => '포',
    TurretModulePart.frame => '프',
  };
}

String _partFilterLabel(TurretModulePart? part) {
  return part?.label ?? '전체';
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
  return item.key.grade.order * 1000 +
      item.options.length * 100 +
      item.acquiredOrder;
}
