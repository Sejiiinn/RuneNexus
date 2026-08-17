import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/auth/google_authentication_api.dart';
import '../data/auth/google_web_authentication_config.dart';
import '../domain/account/account_session.dart';
import '../domain/account/online_account_credentials.dart';
import '../domain/combat/game_phase.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../ui/account/google_sign_in_dialog.dart';
import '../ui/game/game_button.dart';
import '../ui/game/game_image_assets.dart';
import '../ui/game/game_icons.dart';
import '../ui/game/game_modal.dart';
import '../ui/game/game_palette.dart';
import '../ui/game/game_text_styles.dart';
import '../ui/hud/game_hud.dart';
import '../ui/menu/main_menu_screen.dart';
import '../ui/menu/map_editor_panel.dart';

enum _AppScreen { main, stage, mapEditor }

class _AppLoadingProgress {
  const _AppLoadingProgress({required this.label, this.value});

  final String label;
  final double? value;
}

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({this.game, super.key});

  final RuneNexusGame? game;

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp> {
  late final RuneNexusGame game;
  late final GoogleWebAuthenticationConfig _googleAuthenticationConfig;
  GoogleAuthenticationApi? _googleAuthenticationApi;
  final ValueNotifier<_AppLoadingProgress> _loadingProgress = ValueNotifier(
    const _AppLoadingProgress(label: '게임을 시작하는 중'),
  );
  Future<void>? _initialLoad;
  _AppScreen _screen = _AppScreen.main;
  MainMenuTab _selectedMainMenuTab = MainMenuTab.stage;
  _OnlineAccountState? _onlineAccount;

  AccountSession get _accountSession =>
      _onlineAccount?.presentation ?? const AccountSession.guest();

  @override
  void initState() {
    super.initState();
    game = widget.game ?? RuneNexusGame();
    _googleAuthenticationConfig =
        GoogleWebAuthenticationConfig.fromEnvironment();
    if (_googleAuthenticationConfig.isConfigured) {
      _googleAuthenticationApi = GoogleAuthenticationApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
    }
  }

  Future<void> _prepareForAppStart(BuildContext context) async {
    await game.prepareForAppStart();
    if (!mounted || !context.mounted) {
      return;
    }
    _loadingProgress.value = const _AppLoadingProgress(
      label: '이미지 에셋 로드 중',
      value: 0,
    );
    await precacheRuneNexusStartupImages(
      context,
      onProgress: (value) {
        if (!mounted) {
          return;
        }
        _loadingProgress.value = _AppLoadingProgress(
          label: '이미지 에셋 로드 중',
          value: value,
        );
      },
    );
  }

  void _openMainScreen({MainMenuTab tab = MainMenuTab.stage}) {
    setState(() {
      _screen = _AppScreen.main;
      _selectedMainMenuTab = tab;
    });
  }

  @override
  void dispose() {
    _loadingProgress.dispose();
    game.disposeAppResources();
    super.dispose();
  }

  bool _activeRunInProgress(GameSnapshot snapshot) {
    return snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
  }

  Future<bool> _confirmActiveRunSettlement({
    required BuildContext dialogContext,
    required GameSnapshot snapshot,
    required int nextStageNumber,
  }) async {
    final confirmed = await showGameDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return _ActiveRunSettlementDialog(
          snapshot: snapshot,
          nextStageNumber: nextStageNumber,
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _enterStageScreen() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _screen = _AppScreen.stage;
    });
    if (game.snapshotNotifier.value.phase != GamePhase.restored) {
      game.resumeEngine();
    }
  }

  Future<void> _connectGoogle(BuildContext context) async {
    final authenticationApi = _googleAuthenticationApi;
    if (authenticationApi == null) {
      return;
    }
    final credentials = await showGameDialog<OnlineAccountCredentials>(
      context: context,
      builder: (dialogContext) => GoogleSignInDialog(
        clientId: _googleAuthenticationConfig.clientId,
        authenticate: authenticationApi.authenticate,
      ),
    );
    if (credentials == null || !mounted || !context.mounted) {
      return;
    }
    setState(() {
      _onlineAccount = _OnlineAccountState(credentials);
    });
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(context.l10n.googleSignInConnected)),
    );
  }

  Future<void> _startStage(
    int stageNumber,
    GameSnapshot snapshot,
    BuildContext dialogContext,
  ) async {
    final activeRunInProgress = _activeRunInProgress(snapshot);
    final switchingStage =
        activeRunInProgress && stageNumber != snapshot.currentStageNumber;

    if (switchingStage) {
      final confirmed = await _confirmActiveRunSettlement(
        dialogContext: dialogContext,
        snapshot: snapshot,
        nextStageNumber: stageNumber,
      );
      if (!confirmed || !mounted) {
        return;
      }
      await game.settleCurrentRunAsFailure();
      game.startStage(stageNumber);
      await game.saveNow();
    } else if (!activeRunInProgress ||
        snapshot.phase == GamePhase.success ||
        snapshot.phase == GamePhase.failure ||
        stageNumber != snapshot.currentStageNumber) {
      game.startStage(stageNumber);
      await game.saveNow();
    }
    await _enterStageScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rune Nexus',
      locale: const Locale('ko'),
      supportedLocales: RuneNexusLocalizations.supportedLocales,
      localizationsDelegates: const [
        RuneNexusLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ED3FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['sans-serif'],
        useMaterial3: true,
      ),
      home: Builder(
        builder: (appContext) {
          _initialLoad ??= _prepareForAppStart(appContext);
          return Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: FutureBuilder<void>(
              future: _initialLoad,
              builder: (context, loadState) {
                if (loadState.hasError) {
                  return const _AppLoadErrorScreen();
                }
                if (loadState.connectionState != ConnectionState.done) {
                  return _AppLoadingScreen(
                    progressListenable: _loadingProgress,
                  );
                }
                if (_screen == _AppScreen.stage) {
                  return GameHud(
                    game: game,
                    onOpenStageSelect: () => _openMainScreen(),
                    onOpenPermanentUpgrades: () =>
                        _openMainScreen(tab: MainMenuTab.permanentUpgrades),
                    onStartStage: (stageNumber) => _startStage(
                      stageNumber,
                      game.snapshotNotifier.value,
                      context,
                    ),
                  );
                }
                if (_screen == _AppScreen.mapEditor) {
                  return _MapEditorScreen(
                    initialStageNumber:
                        game.snapshotNotifier.value.currentStageNumber,
                    onBack: () => _openMainScreen(),
                  );
                }
                return MainMenuScreen(
                  game: game,
                  snapshot: game.snapshotNotifier.value,
                  snapshotListenable: game.snapshotNotifier,
                  selectedTab: _selectedMainMenuTab,
                  onSelectTab: (tab) {
                    setState(() {
                      _selectedMainMenuTab = tab;
                    });
                  },
                  onStartStage: (stageNumber) => _startStage(
                    stageNumber,
                    game.snapshotNotifier.value,
                    context,
                  ),
                  accountSession: _accountSession,
                  onConnectGoogle: _googleAuthenticationApi == null
                      ? null
                      : () => _connectGoogle(context),
                  onOpenMapEditor: () {
                    setState(() {
                      _screen = _AppScreen.mapEditor;
                    });
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _OnlineAccountState {
  const _OnlineAccountState(this.credentials);

  final OnlineAccountCredentials credentials;

  AccountSession get presentation => AccountSession.authenticated(
    accountId: credentials.accountId,
    identities: const [
      AccountIdentity(
        provider: AccountIdentityProvider.google,
        displayName: 'Google',
      ),
    ],
    syncStatus: OnlineSaveSyncStatus.offline,
  );
}

class _ActiveRunSettlementDialog extends StatelessWidget {
  const _ActiveRunSettlementDialog({
    required this.snapshot,
    required this.nextStageNumber,
  });

  final GameSnapshot snapshot;
  final int nextStageNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameModalFrame(
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.endActiveStageTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.endActiveStageBody(
              currentStageNumber: snapshot.currentStageNumber,
              nextStageNumber: nextStageNumber,
              runeReward: snapshot.projectedFailureRuneReward,
            ),
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x3302070D),
              border: Border.all(color: const Color(0x558FA8BA)),
              borderRadius: BorderRadius.circular(GamePalette.radius),
            ),
            child: Row(
              children: [
                const RuneCurrencyIcon(size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+${snapshot.projectedFailureRuneReward} ${l10n.runes}',
                    style: GameTextStyles.withColor(
                      GameTextStyles.sectionTitle,
                      GamePalette.goldBright,
                    ),
                  ),
                ),
                Text(
                  '${l10n.stageName(snapshot.currentStageNumber)} -> '
                  '${l10n.stageName(nextStageNumber)}',
                  style: GameTextStyles.withColor(
                    GameTextStyles.caption,
                    GamePalette.textMuted,
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
                  onPressed: () => Navigator.of(context).pop(false),
                  label: l10n.cancel,
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  label: l10n.settleAndStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  variant: GameButtonVariant.primary,
                  accentColor: GamePalette.cyan,
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

class _MapEditorScreen extends StatelessWidget {
  const _MapEditorScreen({
    required this.initialStageNumber,
    required this.onBack,
  });

  final int initialStageNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111D),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _AppBackdrop()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xF0091624),
                      border: Border.all(color: const Color(0x9933D8FF)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 20,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: DebugMapEditorPanel(
                      initialStageNumber: initialStageNumber,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: '메인 메뉴',
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFE8FBFF),
                    backgroundColor: const Color(0xE607111D),
                    side: const BorderSide(color: Color(0x6650E6FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AppBackdropPainter());
  }
}

class _AppBackdropPainter extends CustomPainter {
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

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen({required this.progressListenable});

  final ValueListenable<_AppLoadingProgress> progressListenable;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07111D),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.24),
            radius: 0.9,
            colors: [
              Color(0xFF123144),
              Color(0xFF0A1B29),
              Color(0xFF07111D),
            ],
            stops: [0, 0.38, 1],
          ),
        ),
        child: Stack(
          children: [
            const Align(
              alignment: Alignment(0, -0.24),
              child: _AppBootCore(),
            ),
            Positioned.fill(
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                minimum: const EdgeInsets.only(bottom: 42),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: ValueListenableBuilder<_AppLoadingProgress>(
                      valueListenable: progressListenable,
                      builder: (context, progress, _) {
                        final value = progress.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              progress.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB9D6E4),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Semantics(
                              label: '게임 시작 진행률',
                              value: value == null
                                  ? null
                                  : '${(value * 100).round()}%',
                              child: _AppBootProgressBar(value: value),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBootCore extends StatefulWidget {
  const _AppBootCore();

  @override
  State<_AppBootCore> createState() => _AppBootCoreState();
}

class _AppBootCoreState extends State<_AppBootCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AppBootAmbientPainter()),
            ),
          ),
          SizedBox.square(
            dimension: 58,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final phase = _controller.value;
                final pulse =
                    0.94 + math.sin(phase * math.pi * 2 * 1.27) * 0.06;
                return CustomPaint(
                  painter: _AppBootCorePainter(
                    rotation: phase * math.pi * 2,
                    pulse: pulse,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBootAmbientPainter extends CustomPainter {
  const _AppBootAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 코어 주변 저강도 공간광.
    canvas.drawCircle(
      center,
      98,
      Paint()
        ..color = const Color(0x122ED3FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    final ringGlowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    final ringPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    ringGlowPaint.color = const Color(0x0A5EE2FF);
    canvas.drawCircle(center, 118, ringGlowPaint);
    ringPaint.color = const Color(0x105EE2FF);
    canvas.drawCircle(center, 118, ringPaint);
    ringGlowPaint.color = const Color(0x07E7C66A);
    canvas.drawCircle(center, 88, ringGlowPaint);
    ringPaint.color = const Color(0x0AE7C66A);
    canvas.drawCircle(center, 88, ringPaint);
    ringGlowPaint.color = const Color(0x0C5EE2FF);
    canvas.drawCircle(center, 44, ringGlowPaint);
    ringPaint.color = const Color(0x125EE2FF);
    canvas.drawCircle(center, 44, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppBootCorePainter extends CustomPainter {
  const _AppBootCorePainter({required this.rotation, required this.pulse});

  final double rotation;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const orbitRadius = 28.0;
    canvas.drawCircle(
      center,
      orbitRadius,
      Paint()
        ..color = const Color(0x348EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final orbitRect = Rect.fromCircle(center: center, radius: orbitRadius);
    final arcStart = -math.pi / 2 + rotation;
    const arcSweep = 1.8;
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0x428EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0x708EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0xD98EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );

    final sparkAngle = arcStart + arcSweep;
    final sparkCenter = center.translate(
      math.cos(sparkAngle) * orbitRadius,
      math.sin(sparkAngle) * orbitRadius,
    );
    canvas.drawCircle(
      sparkCenter,
      4,
      Paint()
        ..color = const Color(0x70E7C66A)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawCircle(
      sparkCenter,
      1.6,
      Paint()
        ..color = const Color(0xE6E7C66A)
        ..isAntiAlias = true,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulse);
    canvas.rotate(math.pi / 4);
    final diamond = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -9, 18, 18),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0x528EE6FF)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0xC20F3E52)
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0x428EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0xD98EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.5, -3.5, 7, 7),
        const Radius.circular(1),
      ),
      Paint()
        ..color = const Color(0xE6E8FBFF)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppBootCorePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
  }
}

class _AppBootProgressBar extends StatefulWidget {
  const _AppBootProgressBar({required this.value});

  final double? value;

  @override
  State<_AppBootProgressBar> createState() => _AppBootProgressBarState();
}

class _AppBootProgressBarState extends State<_AppBootProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AppBootProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == null && widget.value != null) {
      _controller.stop();
    } else if (oldWidget.value != null && widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 286),
      child: Container(
        width: double.infinity,
        height: 5,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x172ED3FF),
          border: Border.all(color: const Color(0x245EE2FF)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final value = widget.value;
            if (value != null) {
              return Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0).toDouble(),
                  child: const _AppBootProgressFill(),
                ),
              );
            }
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final trackWidth = constraints.maxWidth;
                final fillWidth = trackWidth * 0.38;
                final offset =
                    -fillWidth +
                    (trackWidth + fillWidth) *
                        Curves.easeInOut.transform(_controller.value);
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: SizedBox(
                        width: fillWidth,
                        child: const _AppBootProgressFill(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AppBootProgressFill extends StatelessWidget {
  const _AppBootProgressFill();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x008EE6FF),
            Color(0xFF8EE6FF),
            Color(0xFFE8FBFF),
            Color(0x008EE6FF),
          ],
          stops: [0, 0.46, 0.58, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _AppLoadErrorScreen extends StatelessWidget {
  const _AppLoadErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF07111D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 38),
            SizedBox(height: 14),
            Text(
              '초기화에 실패했습니다',
              style: TextStyle(
                color: Color(0xFFFFE8E5),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '앱을 다시 시작해 주세요',
              style: TextStyle(color: Color(0xFFBFA19D), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
