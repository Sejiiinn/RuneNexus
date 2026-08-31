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
    return GameAssetSurface(
      frame: GameAssetFrame.panel,
      padding: const EdgeInsets.all(10),
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

    return _MenuAssetButton(
      buttonKey: ValueKey('turret-module-draw-button-$count'),
      onPressed: canDraw ? () => _drawModules(context, count) : null,
      label: '$count회 모듈 뽑기',
      compact: true,
      accentColor: GamePalette.gold,
      frameAsset: gameButtonFrameAsset,
      frameCenterSlice: gameButtonFrameCenterSlice,
      frameColor: GamePalette.gold,
      height: 36,
      width: requiresDiamonds ? 68 : 54,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      tooltip: '$count회 모듈 뽑기',
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
      await _requestDraw(context, count, buyMissingTickets: false);
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
    if (confirmed == true && context.mounted) {
      await _requestDraw(context, count, buyMissingTickets: true);
    }
  }

  Future<void> _requestDraw(
    BuildContext context,
    int count, {
    required bool buyMissingTickets,
  }) async {
    try {
      onDrawResults(
        await game.drawTurretModules(
          count,
          turretType: turretType,
          buyMissingTicketsWithDiamonds: buyMissingTickets,
        ),
      );
    } on Object {
      if (context.mounted) {
        _showEconomyRequestFailure(context);
      }
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

    return _MenuAssetButton(
      buttonKey: const ValueKey('turret-module-build-level-button'),
      onPressed: () => showGameDialog<void>(
        context: context,
        builder: (context) =>
            _ModuleBuildLevelDialog(drawCount: sanitizedDrawCount),
      ),
      label: '모듈 구축 Lv.${buildLevel.level}',
      compact: true,
      height: 36,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      tooltip: '모듈 구축 레벨 보기',
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
    final singleResult = widget.results.length == 1;
    return Container(
      key: const ValueKey('turret-module-draw-result-layer'),
      padding: const EdgeInsets.all(12),
      color: Colors.black.withValues(alpha: 0.80),
      child: Center(
        child: FadeTransition(
          opacity: _cardAnimation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(_cardAnimation),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: singleResult ? 240 : 360),
              child: GameAssetSurface(
                frame: GameAssetFrame.panel,
                imageKey: const ValueKey(
                  'turret-module-draw-result-dialog-frame',
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 22),
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
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      resultSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: GamePalette.textSecondary,
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        const cardGap = 8.0;
                        final cardWidth = singleResult
                            ? math.min(176.0, constraints.maxWidth)
                            : math.min(
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
                                key: ValueKey(
                                  'turret-module-draw-result-card-$i',
                                ),
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
                        width: 104,
                        child: _TurretModuleAssetButton(
                          imageKey: const ValueKey(
                            'turret-module-draw-result-confirm-frame',
                          ),
                          onPressed: widget.onClose,
                          label: '확인',
                          height: 34,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
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
    final cardHeight =
        width.clamp(168.0, 180.0) + math.max(0, item.options.length - 1) * 18.0;
    return SizedBox(
      width: width,
      height: cardHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: highlighted ? 0.92 : 0.70,
              child: Image(
                image: gameUiAssetImageProvider(gameCardFrameAsset),
                key: ValueKey('turret-module-draw-card-socket-${item.id}'),
                fit: BoxFit.fill,
                centerSlice: gameCardFrameCenterSlice,
                color: gradeColor,
                colorBlendMode: BlendMode.modulate,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned(
            top: 9,
            left: 10,
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
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 24),
            child: Column(
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
      dimension: 46,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Opacity(
            opacity: highlighted ? 1 : 0.72,
            child: Image(
              image: gameUiAssetImageProvider(gameIconSocketAsset),
              fit: BoxFit.fill,
              color: color,
              colorBlendMode: BlendMode.modulate,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
          ),
          Center(
            child: _TurretModuleItemIcon(part: part, color: color, size: 30),
          ),
        ],
      ),
    );
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
