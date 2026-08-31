part of 'main_menu_screen.dart';

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
        return _MenuAssetSurface(
          asset: researchSectionFrameAsset,
          scale: _menuUiAssetScale,
          centerSlice: _menuSectionFrameCenterSlice,
          padding: const EdgeInsets.all(gridPadding),
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
        child: SizedBox(
          height: 24,
          child: _MenuAssetSurface(
            asset: researchActionFrameAsset,
            scale: _menuUiAssetScale,
            centerSlice: _menuActionFrameCenterSlice,
            opacity: selected ? 1 : 0.58,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (selected)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x1633D8FF),
                      border: Border.all(color: GamePalette.cyan),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  child: _ModuleSingleLineText(
                    label,
                    alignment: Alignment.center,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected
                          ? GamePalette.textPrimary
                          : GamePalette.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
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
        child: _MenuAssetSurface(
          asset: researchCardFrameAsset,
          scale: _menuUiAssetScale,
          centerSlice: _menuCardFrameCenterSlice,
          child: Stack(
            children: [
              if (selected || item.equipped)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0x1633D8FF),
                      border: Border.all(
                        color: selected ? GamePalette.cyan : gradeColor,
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
                  ),
                ),
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
    return const _MenuAssetSurface(
      asset: researchCardFrameAsset,
      scale: _menuUiAssetScale,
      centerSlice: _menuCardFrameCenterSlice,
      opacity: 0.45,
      child: SizedBox.expand(),
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
    return SizedBox(
      height: 42,
      child: _MenuAssetSurface(
        asset: researchSlotFrameAsset,
        scale: _menuUiAssetScale,
        centerSlice: _menuSlotFrameCenterSlice,
        child: Center(
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
