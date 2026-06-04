part of 'main_menu_screen.dart';

class _MainMenuBackdrop extends StatelessWidget {
  const _MainMenuBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _MainMenuBackdropPainter());
  }
}

class _MainMenuBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33143A4E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.shortestSide * 0.32,
      paint,
    );

    final linePaint = Paint()
      ..color = const Color(0x1233D8FF)
      ..strokeWidth = 1;
    const spacing = 38.0;
    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MenuLogo extends StatelessWidget {
  const _MenuLogo();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLogo = constraints.maxWidth < 430;
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.92,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!compactLogo) ...[
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: const Color(0x2233D8FF),
                          border: Border.all(color: const Color(0xAA33D8FF)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.diamond_outlined,
                          color: Color(0xFF8EE6FF),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Text(
                      l10n.appTitle,
                      style: TextStyle(
                        fontSize: compactLogo ? 20 : 23,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuQuickGlyphs extends StatelessWidget {
  const _MenuQuickGlyphs();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xAA06101A),
          border: Border.all(color: const Color(0x5533D8FF)),
          borderRadius: BorderRadius.circular(4),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuQuickGlyph(icon: Icons.menu),
              _MenuQuickGlyph(icon: Icons.map_outlined),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuQuickGlyph extends StatelessWidget {
  const _MenuQuickGlyph({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFF607486);
    return Container(
      width: 23,
      height: 23,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: ShapeDecoration(
        color: const Color(0x55101C28),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(5),
          side: BorderSide(color: color.withValues(alpha: 0.35)),
        ),
      ),
      child: Icon(icon, color: color, size: 14),
    );
  }
}

class _MenuTabs extends StatelessWidget {
  const _MenuTabs({required this.selectedTab, required this.onSelectTab});

  final MainMenuTab selectedTab;
  final ValueChanged<MainMenuTab> onSelectTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Color(0x99000000),
            blurRadius: 18,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Container(
        height: 56,
        padding: const EdgeInsets.fromLTRB(10, 5, 10, 6),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2433), Color(0xFF06101A)],
          ),
          border: Border(
            top: BorderSide(color: Color(0xAA5CF9E9)),
            bottom: BorderSide(color: Color(0x6607111D)),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0x6607111D),
            border: Border.all(color: const Color(0x4433D8FF)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-stage'),
                  icon: Icons.flag_outlined,
                  label: l10n.stageTab,
                  selected: selectedTab == MainMenuTab.stage,
                  onPressed: () => onSelectTab(MainMenuTab.stage),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-core'),
                  icon: Icons.diamond_outlined,
                  label: l10n.coreTab,
                  selected: selectedTab == MainMenuTab.core,
                  onPressed: () => onSelectTab(MainMenuTab.core),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-upgrades'),
                  icon: Icons.auto_awesome,
                  label: l10n.permanentUpgradeTab,
                  selected: selectedTab == MainMenuTab.permanentUpgrades,
                  onPressed: () => onSelectTab(MainMenuTab.permanentUpgrades),
                ),
              ),
              const _MenuTabGroove(),
              Expanded(
                child: _TabButton(
                  key: const ValueKey('main-menu-tab-research'),
                  icon: Icons.science_outlined,
                  label: l10n.researchTab,
                  selected: selectedTab == MainMenuTab.research,
                  onPressed: () => onSelectTab(MainMenuTab.research),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuTabGroove extends StatelessWidget {
  const _MenuTabGroove();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 2,
      height: 34,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              const Color(0xFF33D8FF).withValues(alpha: 0.34),
              Colors.transparent,
            ],
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x88000000),
              blurRadius: 4,
              offset: Offset(-1, 0),
            ),
          ],
        ),
      ),
    );
  }
}

class _PermanentUpgradeGroupTabs extends StatelessWidget {
  const _PermanentUpgradeGroupTabs({
    required this.selectedGroup,
    required this.onSelectGroup,
  });

  final _PermanentUpgradeGroup selectedGroup;
  final ValueChanged<_PermanentUpgradeGroup> onSelectGroup;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Container(
        width: 142,
        height: 42,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xF0091624),
          border: Border.all(color: const Color(0x7733D8FF)),
          borderRadius: BorderRadius.circular(10),
          boxShadow: const [
            BoxShadow(
              color: Color(0x66000000),
              blurRadius: 14,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _UpgradeGroupTabButton(
                icon: const _CombatGroupIcon(),
                label: l10n.combatUpgradeGroup,
                activeColor: const Color(0xFFFF7A7A),
                inactiveColor: const Color(0xFFB88989),
                selected: selectedGroup == _PermanentUpgradeGroup.combat,
                onPressed: () => onSelectGroup(_PermanentUpgradeGroup.combat),
              ),
            ),
            Container(width: 1, height: 24, color: const Color(0x5533D8FF)),
            Expanded(
              child: _UpgradeGroupTabButton(
                icon: const Icon(Icons.paid_outlined, size: 19),
                label: l10n.economyUpgradeGroup,
                activeColor: const Color(0xFFE7C66A),
                inactiveColor: const Color(0xFFB6A36D),
                selected: selectedGroup == _PermanentUpgradeGroup.economy,
                onPressed: () => onSelectGroup(_PermanentUpgradeGroup.economy),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CombatGroupIcon extends StatelessWidget {
  const _CombatGroupIcon();

  @override
  Widget build(BuildContext context) {
    final color = IconTheme.of(context).color;
    return SizedBox(
      width: 24,
      height: 22,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 20, color: color),
          CustomPaint(
            size: const Size(18, 18),
            painter: _SwordIconPainter(color ?? const Color(0xFFFF7A7A)),
          ),
        ],
      ),
    );
  }
}

class _SwordIconPainter extends CustomPainter {
  const _SwordIconPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.7;
    final bladeStart = Offset(size.width * 0.36, size.height * 0.72);
    final bladeEnd = Offset(size.width * 0.74, size.height * 0.24);
    canvas.drawLine(bladeStart, bladeEnd, paint);
    canvas.drawLine(
      Offset(size.width * 0.25, size.height * 0.61),
      Offset(size.width * 0.49, size.height * 0.82),
      paint,
    );
    canvas.drawLine(
      Offset(size.width * 0.31, size.height * 0.83),
      Offset(size.width * 0.22, size.height * 0.94),
      paint,
    );
    final tipPath = Path()
      ..moveTo(size.width * 0.74, size.height * 0.24)
      ..lineTo(size.width * 0.68, size.height * 0.36)
      ..lineTo(size.width * 0.83, size.height * 0.32)
      ..close();
    canvas.drawPath(tipPath, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SwordIconPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _UpgradeGroupTabButton extends StatelessWidget {
  const _UpgradeGroupTabButton({
    required this.icon,
    required this.label,
    required this.activeColor,
    required this.inactiveColor,
    required this.selected,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected ? activeColor : inactiveColor;
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashColor: activeColor.withAlpha(35),
            highlightColor: const Color(0x1422C7E8),
            child: Container(
              height: double.infinity,
              decoration: BoxDecoration(
                color: selected
                    ? activeColor.withAlpha(42)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
              ),
              alignment: Alignment.center,
              child: IconTheme(
                data: IconThemeData(color: foregroundColor),
                child: icon,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foregroundColor = selected
        ? const Color(0xFF8EE6FF)
        : const Color(0xFF88A4B3);
    final textColor = selected ? GamePalette.textPrimary : foregroundColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 88;
        final horizontalPadding = dense ? 4.0 : 8.0;
        final indicatorInset = dense ? 11.0 : 18.0;
        final iconSize = selected
            ? (dense ? 16.0 : 18.0)
            : (dense ? 15.0 : 17.0);
        final labelGap = dense ? 4.0 : 7.0;
        final fontSize = dense ? 12.0 : 13.0;

        return Semantics(
          button: true,
          selected: selected,
          label: label,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(4),
              splashColor: const Color(0x1A8EE6FF),
              highlightColor: const Color(0x1022C7E8),
              child: SizedBox.expand(
                child: Stack(
                  fit: StackFit.expand,
                  alignment: Alignment.center,
                  children: [
                    if (selected) ...[
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: Alignment.bottomCenter,
                              radius: 1.28,
                              colors: [
                                const Color(0xFF22C7E8).withValues(alpha: 0.28),
                                const Color(0xFF22C7E8).withValues(alpha: 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.42, 1],
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: indicatorInset,
                        right: indicatorInset,
                        bottom: 0,
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(2),
                            gradient: const LinearGradient(
                              colors: [
                                Color(0x008EE6FF),
                                Color(0xFF8EE6FF),
                                Color(0x008EE6FF),
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0xAA22C7E8),
                                blurRadius: 7,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: iconSize,
                            color: foregroundColor,
                            shadows: selected
                                ? const [
                                    Shadow(
                                      color: Color(0xAA22C7E8),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          SizedBox(width: labelGap),
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                label,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: fontSize,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w700,
                                ),
                              ),
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
      },
    );
  }
}
