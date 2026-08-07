part of 'main_menu_screen.dart';

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: _ModuleBuildLevelPanel(
              drawCount: snapshot.turretModuleDrawCount,
            ),
          ),
          const SizedBox(width: 6),
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

class _ModuleBuildLevelPanel extends StatelessWidget {
  const _ModuleBuildLevelPanel({required this.drawCount});

  final int drawCount;

  @override
  Widget build(BuildContext context) {
    final sanitizedDrawCount = math.max(0, drawCount);
    final buildLevel = turretModuleBuildLevelForDrawCount(sanitizedDrawCount);

    return GameButton(
      key: const ValueKey('turret-module-build-level-button'),
      onPressed: () => showGameDialog<void>(
        context: context,
        builder: (context) =>
            _ModuleBuildLevelDialog(drawCount: sanitizedDrawCount),
      ),
      label: '모듈 구축 Lv.${buildLevel.level}',
      variant: GameButtonVariant.ghost,
      accentColor: GamePalette.cyan,
      compact: true,
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          const Icon(
            Icons.construction_outlined,
            size: 14,
            color: GamePalette.cyan,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(
              '모듈 구축 Lv.${buildLevel.level}',
              key: const ValueKey('turret-module-build-level-label'),
              style: const TextStyle(
                color: GamePalette.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 16,
            color: GamePalette.textMuted,
          ),
        ],
      ),
    );
  }
}

class _ModuleBuildLevelDialog extends StatefulWidget {
  const _ModuleBuildLevelDialog({required this.drawCount});

  final int drawCount;

  @override
  State<_ModuleBuildLevelDialog> createState() =>
      _ModuleBuildLevelDialogState();
}

class _ModuleBuildLevelDialogState extends State<_ModuleBuildLevelDialog> {
  late TurretModuleBuildLevelDefinition _selectedLevel;

  @override
  void initState() {
    super.initState();
    _selectedLevel = turretModuleBuildLevelForDrawCount(widget.drawCount);
  }

  @override
  Widget build(BuildContext context) {
    final currentLevel = turretModuleBuildLevelForDrawCount(widget.drawCount);
    final achievementLabel = _selectedLevel.level == 1
        ? '기본 단계'
        : '누적 ${_selectedLevel.requiredDrawCount}회 달성';
    const gradeOrder = [
      TurretModuleGrade.unique,
      TurretModuleGrade.rare,
      TurretModuleGrade.magic,
      TurretModuleGrade.normal,
    ];

    return GameModalFrame(
      maxWidth: 340,
      padding: const EdgeInsets.all(14),
      accentColor: GamePalette.cyan,
      child: Column(
        key: const ValueKey('turret-module-build-level-dialog'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(
                Icons.construction_outlined,
                size: 19,
                color: GamePalette.cyan,
              ),
              SizedBox(width: 7),
              Expanded(child: Text('모듈 구축 레벨', style: GameTextStyles.title)),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '현재 누적 ${widget.drawCount}회 · 모듈 획득 누적으로 상위 등급 확률 증가',
            style: TextStyle(
              color: GamePalette.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (
                var index = 0;
                index < gameTurretModuleBuildLevelDefinitions.length;
                index++
              ) ...[
                if (index > 0) const SizedBox(width: 4),
                Expanded(
                  child: GameButton(
                    key: ValueKey(
                      'turret-module-build-level-tab-${gameTurretModuleBuildLevelDefinitions[index].level}',
                    ),
                    onPressed: () => setState(
                      () => _selectedLevel =
                          gameTurretModuleBuildLevelDefinitions[index],
                    ),
                    label:
                        'Lv.${gameTurretModuleBuildLevelDefinitions[index].level}',
                    selected:
                        _selectedLevel ==
                        gameTurretModuleBuildLevelDefinitions[index],
                    compact: true,
                    accentColor: GamePalette.cyan,
                    height: 32,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 2,
                      vertical: 4,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('turret-module-build-level-detail'),
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
                    Text(
                      'Lv.${_selectedLevel.level}',
                      style: GameTextStyles.sectionTitle,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        achievementLabel,
                        textAlign: TextAlign.right,
                        style: GameTextStyles.caption,
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  height: 14,
                  child: _selectedLevel.level == currentLevel.level
                      ? const Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            '현재 적용 중',
                            key: ValueKey(
                              'turret-module-build-current-level-label',
                            ),
                            style: TextStyle(
                              color: GamePalette.cyan,
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 9),
                Row(
                  children: [
                    for (var index = 0; index < gradeOrder.length; index++) ...[
                      if (index > 0) const SizedBox(width: 4),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 2,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _gradeColor(
                              gradeOrder[index],
                            ).withValues(alpha: 0.08),
                            border: Border.all(
                              color: _gradeColor(
                                gradeOrder[index],
                              ).withValues(alpha: 0.34),
                            ),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Column(
                            children: [
                              Text(
                                gradeOrder[index].label,
                                style: TextStyle(
                                  color: _gradeColor(gradeOrder[index]),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedLevel.rateFor(gradeOrder[index])}%',
                                key: ValueKey(
                                  'turret-module-build-grade-rate-${_selectedLevel.level}-${gradeOrder[index].name}',
                                ),
                                style: TextStyle(
                                  color: _gradeColor(gradeOrder[index]),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GameButton(
            onPressed: () => Navigator.of(context).pop(),
            label: '닫기',
            variant: GameButtonVariant.ghost,
            accentColor: GamePalette.metal,
            height: 36,
          ),
        ],
      ),
    );
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
