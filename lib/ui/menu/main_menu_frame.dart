part of 'main_menu_screen.dart';

class _MainMenuBackdrop extends StatelessWidget {
  const _MainMenuBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          mainMenuBackgroundAsset,
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x1002070D), Color(0x3807111D), Color(0x7802070D)],
              stops: [0, 0.5, 1],
            ),
          ),
        ),
      ],
    );
  }
}

class _MenuLogo extends StatelessWidget {
  const _MenuLogo();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compactLogo = constraints.maxWidth < 430;
        final narrowLogo = constraints.maxWidth < 390;
        return IgnorePointer(
          child: Center(
            child: Opacity(
              opacity: 0.92,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Image.asset(
                  gameLogoAsset,
                  width: narrowLogo ? 152 : (compactLogo ? 176 : 208),
                  height: narrowLogo ? 44 : (compactLogo ? 48 : 56),
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: context.l10n.appTitle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MenuResourceBar extends StatelessWidget {
  const _MenuResourceBar({
    required this.selectedTab,
    required this.runes,
    required this.diamonds,
    required this.turretModuleTickets,
    required this.accountSession,
    required this.onOpenAccount,
    super.key,
  });

  final MainMenuTab selectedTab;
  final int runes;
  final int diamonds;
  final int turretModuleTickets;
  final AccountSession accountSession;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC0D2433), Color(0xE606101A)],
        ),
        border: Border(bottom: BorderSide(color: Color(0x665CF9E9))),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (selectedTab == MainMenuTab.core) ...[
            const _MenuCoreTitleIcon(),
            const SizedBox(width: 8),
            const Text(
              '넥서스 코어',
              key: ValueKey('menu-resource-title'),
              style: TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ] else if (selectedTab == MainMenuTab.permanentUpgrades) ...[
            const Icon(
              Icons.grid_view_rounded,
              color: Color(0xFF8EE6FF),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              context.l10n.upgradeBoard,
              key: const ValueKey('menu-resource-title'),
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ] else if (selectedTab == MainMenuTab.research) ...[
            const Icon(
              Icons.science_outlined,
              color: Color(0xFF8EE6FF),
              size: 18,
            ),
            const SizedBox(width: 7),
            Text(
              context.l10n.researchBoard,
              key: const ValueKey('menu-resource-title'),
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ] else if (selectedTab == MainMenuTab.turretModules) ...[
            const Icon(
              Icons.extension_outlined,
              color: Color(0xFF8EE6FF),
              size: 18,
            ),
            const SizedBox(width: 7),
            const Text(
              '포탑 모듈',
              key: ValueKey('menu-resource-title'),
              style: TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
          const Spacer(),
          _AccountEntryButton(
            session: accountSession,
            onPressed: onOpenAccount,
            compact: true,
          ),
          const SizedBox(width: 7),
          RuneBalanceCard(
            key: const ValueKey('menu-currency-balance'),
            runes: runes,
            diamonds: diamonds,
            secondaryCurrencyIcon: selectedTab == MainMenuTab.turretModules
                ? Image.asset(
                    turretModuleTicketIconAsset,
                    key: const ValueKey('menu-turret-module-ticket-icon'),
                    width: 13,
                    height: 13,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    semanticLabel: '모듈권',
                  )
                : null,
            secondaryCurrencyValue: selectedTab == MainMenuTab.turretModules
                ? turretModuleTickets
                : null,
            compact: true,
            frameless: true,
          ),
        ],
      ),
    );
  }
}

class _MenuCoreTitleIcon extends StatelessWidget {
  const _MenuCoreTitleIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const ShapeDecoration(
        gradient: RadialGradient(
          colors: [
            Color(0xFFE8FBFF),
            Color(0xFF8EE6FF),
            Color(0xFF155876),
            Color(0xFF06101A),
          ],
          stops: [0, 0.32, 0.66, 1],
        ),
        shape: StarBorder.polygon(sides: 6, pointRounding: 0.12),
        shadows: [BoxShadow(color: Color(0x6622C7E8), blurRadius: 10)],
      ),
      child: const Icon(
        Icons.diamond_outlined,
        color: Color(0xFFFFFFFF),
        size: 15,
      ),
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
        child: Row(
          children: [
            Expanded(
              child: _TabButton(
                key: const ValueKey('main-menu-tab-stage'),
                icon: const _MainMenuTabAssetIcon(
                  asset: stageRewardStageIconAsset,
                ),
                label: l10n.stageTab,
                selected: selectedTab == MainMenuTab.stage,
                onPressed: () => onSelectTab(MainMenuTab.stage),
              ),
            ),
            const _MenuTabGroove(),
            Expanded(
              child: _TabButton(
                key: const ValueKey('main-menu-tab-core'),
                icon: const _MainMenuTabAssetIcon(
                  asset: stageRewardCoreIconAsset,
                ),
                label: l10n.coreTab,
                selected: selectedTab == MainMenuTab.core,
                onPressed: () => onSelectTab(MainMenuTab.core),
              ),
            ),
            const _MenuTabGroove(),
            Expanded(
              child: _TabButton(
                key: const ValueKey('main-menu-tab-upgrades'),
                icon: const _MainMenuTabAssetIcon(
                  asset: stageRewardUpgradeIconAsset,
                ),
                label: l10n.permanentUpgradeTab,
                selected: selectedTab == MainMenuTab.permanentUpgrades,
                onPressed: () => onSelectTab(MainMenuTab.permanentUpgrades),
              ),
            ),
            const _MenuTabGroove(),
            Expanded(
              child: _TabButton(
                key: const ValueKey('main-menu-tab-research'),
                icon: const _MainMenuTabAssetIcon(
                  asset: stageRewardResearchIconAsset,
                ),
                label: l10n.researchTab,
                selected: selectedTab == MainMenuTab.research,
                onPressed: () => onSelectTab(MainMenuTab.research),
              ),
            ),
            const _MenuTabGroove(),
            Expanded(
              child: _TabButton(
                key: const ValueKey('main-menu-tab-modules'),
                icon: const _MainMenuTabAssetIcon(
                  asset: stageRewardTurretIconAsset,
                ),
                label: l10n.turretModuleTab,
                selected: selectedTab == MainMenuTab.turretModules,
                onPressed: () => onSelectTab(MainMenuTab.turretModules),
              ),
            ),
          ],
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
      child: SizedBox(
        width: 138,
        height: 43,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image(
              image: gameUiAssetImageProvider(gameSegmentedControlFrameAsset),
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
              excludeFromSemantics: true,
            ),
            Padding(
              padding: const EdgeInsets.all(5),
              child: Row(
                children: [
                  Expanded(
                    child: _UpgradeGroupTabButton(
                      icon: const _CombatGroupIcon(),
                      label: l10n.combatUpgradeGroup,
                      activeColor: const Color(0xFFFF7A7A),
                      inactiveColor: const Color(0xFFB88989),
                      selectedAsset: gameSegmentSelectedCyanAsset,
                      selected: selectedGroup == _PermanentUpgradeGroup.combat,
                      onPressed: () =>
                          onSelectGroup(_PermanentUpgradeGroup.combat),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: const Color(0x5533D8FF),
                  ),
                  Expanded(
                    child: _UpgradeGroupTabButton(
                      icon: const GoldCurrencyIcon(size: 19),
                      label: l10n.economyUpgradeGroup,
                      activeColor: const Color(0xFFE7C66A),
                      inactiveColor: const Color(0xFFB6A36D),
                      selectedAsset: gameSegmentSelectedGoldAsset,
                      selected: selectedGroup == _PermanentUpgradeGroup.economy,
                      onPressed: () =>
                          onSelectGroup(_PermanentUpgradeGroup.economy),
                    ),
                  ),
                ],
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
    required this.selectedAsset,
    required this.selected,
    required this.onPressed,
  });

  final Widget icon;
  final String label;
  final Color activeColor;
  final Color inactiveColor;
  final String selectedAsset;
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
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (selected)
                  Image(
                    image: gameUiAssetImageProvider(selectedAsset),
                    fit: BoxFit.fill,
                    filterQuality: FilterQuality.medium,
                    excludeFromSemantics: true,
                  ),
                Align(
                  alignment: Alignment.center,
                  child: IconTheme(
                    data: IconThemeData(color: foregroundColor),
                    child: icon,
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

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget icon;
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
                          IconTheme(
                            data: IconThemeData(
                              color: foregroundColor,
                              size: iconSize,
                              shadows: selected
                                  ? const [
                                      Shadow(
                                        color: Color(0xAA22C7E8),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Opacity(
                              opacity: selected ? 1 : 0.68,
                              child: icon,
                            ),
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

class _MainMenuTabAssetIcon extends StatelessWidget {
  const _MainMenuTabAssetIcon({required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    final size = IconTheme.of(context).size ?? 18;
    return Image.asset(
      asset,
      width: size + 5,
      height: size + 5,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
