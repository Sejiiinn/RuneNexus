part of 'main_menu_screen.dart';

class _MainLobby extends StatelessWidget {
  const _MainLobby({
    required this.game,
    required this.snapshot,
    required this.snapshotListenable,
    required this.onSelectTab,
    required this.onStartStage,
    required this.onOpenAccount,
    required this.onClaimWeeklyReward,
    required this.onOpenMapEditor,
    required this.onOpenDebugPanel,
    this.loadLeaderboard,
    this.leaderboardRefresh,
  });

  final Future<LeaderboardSnapshot> Function()? loadLeaderboard;
  final Listenable? leaderboardRefresh;
  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueListenable<GameSnapshot>? snapshotListenable;
  final ValueChanged<MainMenuTab> onSelectTab;
  final ValueChanged<int> onStartStage;
  final VoidCallback onOpenAccount;
  final Future<void> Function(WeeklyRewardClaimTarget)? onClaimWeeklyReward;
  final VoidCallback? onOpenMapEditor;
  final VoidCallback onOpenDebugPanel;

  @override
  Widget build(BuildContext context) {
    final listenable = snapshotListenable;
    if (listenable == null) return _buildLobby(context, snapshot);
    return ValueListenableBuilder<GameSnapshot>(
      valueListenable: listenable,
      builder: (context, value, _) => _buildLobby(context, value),
    );
  }

  Widget _buildLobby(BuildContext context, GameSnapshot value) {
    return ColoredBox(
      color: GamePalette.backdrop,
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
            // 장면의 비율을 보존하며 전체 메뉴를 화면 안에 맞출 기준 높이.
            final height = math.max(
              constraints.maxHeight,
              math.min(constraints.maxWidth, 460) /
                      _LobbyScene.sourceSize.width *
                      _LobbyScene.sourceSize.height *
                      0.5 +
                  400 +
                  (textScale - 1).clamp(0, 3) * 250 +
                  MediaQuery.paddingOf(context).vertical,
            );
            return Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(
                  width: math.min(constraints.maxWidth, 460),
                  height: height,
                  child: _buildCanvas(context, value),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCanvas(BuildContext context, GameSnapshot value) {
    final activeRun =
        value.hasStageProgress &&
        value.phase != GamePhase.success &&
        value.phase != GamePhase.failure;
    return ColoredBox(
      key: const ValueKey('main-lobby-screen'),
      color: GamePalette.backdrop,
      child: Stack(
        children: [
          const Positioned.fill(child: _LobbyScene()),
          SafeArea(
            child: Column(
              children: [
                if (_showMapEditor)
                  _MenuDebugShortcuts(
                    testPanelOpen: false,
                    onToggleTestPanel: onOpenDebugPanel,
                    onOpenMapEditor: onOpenMapEditor,
                  ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final height = constraints.maxHeight;
                      return SizedBox(
                        child: Center(
                          child: SizedBox(
                            width: math.min(constraints.maxWidth, 460),
                            height: height,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  SizedBox(
                                    height: math.max(
                                      160,
                                      constraints.maxWidth /
                                              _LobbyScene.sourceSize.width *
                                              _LobbyScene.sourceSize.height *
                                              0.5 -
                                          MediaQuery.paddingOf(context).top -
                                          6,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            key: const ValueKey(
                                              'lobby-settings',
                                            ),
                                            onPressed: () =>
                                                _openSettings(context),
                                            icon: Image.asset(
                                              lobbySettingsIconAsset,
                                              width: 28,
                                              height: 28,
                                              excludeFromSemantics: true,
                                            ),
                                            label: const Text('설정'),
                                            style: TextButton.styleFrom(
                                              foregroundColor:
                                                  GamePalette.textSecondary,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Image.asset(
                                            gameLogoAsset,
                                            width: 208,
                                            height: 52,
                                            fit: BoxFit.contain,
                                            semanticLabel: 'Rune Nexus',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    child: GameAssetSurface(
                                      frame: GameAssetFrame.panel,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 18,
                                        vertical: 18,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          Text(
                                            activeRun
                                                ? context.l10n.stageName(
                                                    value.currentStageNumber,
                                                  )
                                                : '전투 준비',
                                            textAlign: TextAlign.center,
                                            style: GameTextStyles.title,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            activeRun
                                                ? '${value.round} / ${value.maxRound} 라운드'
                                                : '도전할 스테이지를 선택하세요',
                                            textAlign: TextAlign.center,
                                            style: GameTextStyles.body,
                                          ),
                                          if (activeRun) ...[
                                            const SizedBox(height: 18),
                                            _LobbyStageButton(
                                              key: const ValueKey(
                                                'lobby-continue-run',
                                              ),
                                              label: '이어서 진행',
                                              onPressed: () => onStartStage(
                                                value.currentStageNumber,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  const SizedBox(height: 18),
                                  Center(
                                    child: SizedBox(
                                      width:
                                          248 +
                                          (MediaQuery.textScalerOf(
                                                        context,
                                                      ).scale(12) -
                                                      12)
                                                  .clamp(0, 36) *
                                              7,
                                      child: Material(
                                        color: const Color(0xAD101A24),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          side: const BorderSide(
                                            color: Color(0x407E929F),
                                          ),
                                        ),
                                        clipBehavior: Clip.antiAlias,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: _LobbyShortcut(
                                                key: const ValueKey(
                                                  'lobby-events',
                                                ),
                                                horizontal: true,
                                                label: '이벤트',
                                                asset: lobbyEventIconAsset,
                                                notification:
                                                    _dailyQuestClaimableCount(
                                                      value,
                                                    ) >
                                                    0,
                                                onPressed: () =>
                                                    _openEvents(context),
                                              ),
                                            ),
                                            const SizedBox(
                                              height: 20,
                                              child: VerticalDivider(
                                                width: 1,
                                                color: Color(0x407E929F),
                                              ),
                                            ),
                                            Expanded(
                                              child: _LobbyShortcut(
                                                key: const ValueKey(
                                                  'lobby-leaderboard',
                                                ),
                                                horizontal: true,
                                                label: '리더보드',
                                                asset:
                                                    lobbyLeaderboardIconAsset,
                                                onPressed: () =>
                                                    _openLeaderboard(context),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 28,
                                    ),
                                    child: _LobbyStageButton(
                                      key: const ValueKey('lobby-stage-select'),
                                      label: '스테이지 선택',
                                      primary: true,
                                      iconAsset: stageRewardStageIconAsset,
                                      onPressed: () =>
                                          onSelectTab(MainMenuTab.stage),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  GameAssetSurface(
                                    frame: GameAssetFrame.panel,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 6,
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        for (final item in const [
                                          (
                                            MainMenuTab.core,
                                            'core',
                                            '넥서스 코어',
                                            stageRewardCoreIconAsset,
                                          ),
                                          (
                                            MainMenuTab.permanentUpgrades,
                                            'upgrades',
                                            '영구 강화',
                                            stageRewardUpgradeIconAsset,
                                          ),
                                          (
                                            MainMenuTab.research,
                                            'research',
                                            '연구',
                                            stageRewardResearchIconAsset,
                                          ),
                                          (
                                            MainMenuTab.turretModules,
                                            'modules',
                                            '포탑 모듈',
                                            stageRewardTurretIconAsset,
                                          ),
                                        ])
                                          Expanded(
                                            child: _LobbyShortcut(
                                              key: ValueKey(
                                                'lobby-tab-${item.$2}',
                                              ),
                                              label: item.$3,
                                              asset: item.$4,
                                              onPressed: () =>
                                                  onSelectTab(item.$1),
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
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEvents(BuildContext context) async {
    final quests = await showGameDialog<bool>(
      context: context,
      builder: (context) => _LobbyDialog(
        title: '이벤트',
        children: [
          const Text('출석과 일일·주간 퀘스트 보상을 확인하세요.', style: GameTextStyles.body),
          const SizedBox(height: 16),
          _LobbyStageButton(
            label: '출석 · 퀘스트',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (quests == true && context.mounted) {
      await _openDailyQuestDialog(context, game, onClaimWeeklyReward);
    }
  }

  Future<void> _openLeaderboard(BuildContext context) async {
    final openAccount = await showGameDialog<bool>(
      context: context,
      builder: (dialogContext) => LeaderboardDialog(
        load: loadLeaderboard,
        refreshListenable: leaderboardRefresh,
        onOpenAccount: () => Navigator.of(dialogContext).pop(true),
      ),
    );
    if (openAccount == true && context.mounted) onOpenAccount();
  }

  Future<void> _openSettings(BuildContext context) async {
    final account = await showGameDialog<bool>(
      context: context,
      builder: (context) => _LobbyDialog(
        title: '설정',
        children: [
          _LobbyStageButton(
            label: context.l10n.accountAndSave,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (account == true && context.mounted) onOpenAccount();
  }
}

class _LobbyShortcut extends StatelessWidget {
  const _LobbyShortcut({
    required this.label,
    required this.onPressed,
    required this.asset,
    this.notification = false,
    this.horizontal = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final String asset;
  final bool notification;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final icon = Stack(
      clipBehavior: Clip.none,
      children: [
        Image.asset(
          asset,
          width: horizontal ? 24 : 38,
          height: horizontal ? 24 : 38,
          excludeFromSemantics: true,
        ),
        if (notification)
          Positioned(
            top: 0,
            right: -3,
            child: Semantics(
              label: '받을 보상 있음',
              child: const Icon(Icons.circle, size: 7, color: GamePalette.cyan),
            ),
          ),
      ],
    );
    final text = Text(
      label,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: GameTextStyles.body.copyWith(
        color: GamePalette.textPrimary,
        fontSize: 12,
      ),
    );
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: horizontal
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: horizontal
              ? Row(
                  children: [
                    icon,
                    const SizedBox(width: 8),
                    Expanded(child: text),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [icon, const SizedBox(height: 4), text],
                ),
        ),
      ),
    );
  }
}

class _LobbyStageButton extends StatelessWidget {
  const _LobbyStageButton({
    required this.label,
    required this.onPressed,
    this.iconAsset,
    this.primary = false,
    super.key,
  });

  final String label;
  final VoidCallback onPressed;
  final String? iconAsset;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image(
            image: gameUiAssetImageProvider(
              primary ? lobbyPrimaryButtonAsset : lobbySecondaryButtonAsset,
            ),
            // 3배 원본의 테두리·모서리를 고정하고 중앙 면만 확장.
            centerSlice: primary
                ? const Rect.fromLTRB(12, 14, 288, 42)
                : const Rect.fromLTRB(10, 11, 110, 37),
            fit: BoxFit.fill,
            excludeFromSemantics: true,
          ),
        ),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(6),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: primary ? 56 : 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (iconAsset != null) ...[
                      Image.asset(
                        iconAsset!,
                        width: 25,
                        height: 25,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 10),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: GameTextStyles.button,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LobbyDialog extends StatelessWidget {
  const _LobbyDialog({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return GameModalFrame(
      maxWidth: 360,
      maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: GameTextStyles.title)),
                GameModalCloseButton(
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _LobbyScene extends StatelessWidget {
  const _LobbyScene();

  static const sourceSize = Size(853, 1844);

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // 제단과 장치를 같은 폭 비율로 배치해 접점 유지.
          final sceneHeight =
              constraints.maxWidth / sourceSize.width * sourceSize.height;
          final floorY = sceneHeight * 0.417;
          final deviceSize = constraints.maxWidth * 0.49;
          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: constraints.maxWidth,
                height: sceneHeight,
                child: Image.asset(
                  lobbyBackgroundAsset,
                  fit: BoxFit.fill,
                  excludeFromSemantics: true,
                ),
              ),
              Positioned(
                left: (constraints.maxWidth - deviceSize) / 2,
                top: floorY - deviceSize * 0.92,
                width: deviceSize,
                height: deviceSize,
                child: Image.asset(
                  lobbyRunePedestalAsset,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
