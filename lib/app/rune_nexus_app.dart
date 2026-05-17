import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/combat/game_phase.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../ui/hud/game_hud.dart';
import '../ui/menu/main_menu_screen.dart';
import '../ui/menu/map_editor_panel.dart';

enum _AppScreen { main, stage, mapEditor }

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({this.game, super.key});

  final RuneNexusGame? game;

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp> {
  late final RuneNexusGame game;
  late final Future<void> _initialLoad;
  _AppScreen _screen = _AppScreen.main;
  MainMenuTab _selectedMainMenuTab = MainMenuTab.stage;

  @override
  void initState() {
    super.initState();
    game = widget.game ?? RuneNexusGame();
    _initialLoad = Future<void>.delayed(Duration.zero, game.prepareForAppStart);
  }

  void _openMainScreen({MainMenuTab tab = MainMenuTab.stage}) {
    setState(() {
      _screen = _AppScreen.main;
      _selectedMainMenuTab = tab;
    });
  }

  @override
  void dispose() {
    game.disposeAppResources();
    super.dispose();
  }

  Future<void> _startStage(int stageNumber, GameSnapshot snapshot) async {
    final activeRunInProgress =
        snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
    final switchingStage =
        activeRunInProgress && stageNumber != snapshot.currentStageNumber;

    if (switchingStage) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) {
          final l10n = context.l10n;
          return AlertDialog(
            title: Text(l10n.endActiveStageTitle),
            content: Text(
              l10n.endActiveStageBody(
                currentStageNumber: snapshot.currentStageNumber,
                nextStageNumber: stageNumber,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.settleAndStart),
              ),
            ],
          );
        },
      );
      if (confirmed != true || !mounted) {
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
      home: Scaffold(
        backgroundColor: const Color(0xFF07111D),
        body: FutureBuilder<void>(
          future: _initialLoad,
          builder: (context, loadState) {
            if (loadState.hasError) {
              return const _AppLoadErrorScreen();
            }
            if (loadState.connectionState != ConnectionState.done) {
              return const _AppLoadingScreen();
            }
            if (_screen == _AppScreen.stage) {
              return GameHud(
                game: game,
                onOpenStageSelect: () => _openMainScreen(),
                onOpenPermanentUpgrades: () =>
                    _openMainScreen(tab: MainMenuTab.permanentUpgrades),
                onStartStage: (stageNumber) =>
                    _startStage(stageNumber, game.snapshotNotifier.value),
              );
            }
            if (_screen == _AppScreen.mapEditor) {
              return _MapEditorScreen(
                initialStageNumber:
                    game.snapshotNotifier.value.currentStageNumber,
                onBack: () => _openMainScreen(),
              );
            }
            return ValueListenableBuilder(
              valueListenable: game.snapshotNotifier,
              builder: (context, snapshot, _) {
                return MainMenuScreen(
                  game: game,
                  snapshot: snapshot,
                  selectedTab: _selectedMainMenuTab,
                  onSelectTab: (tab) {
                    setState(() {
                      _selectedMainMenuTab = tab;
                    });
                  },
                  onStartStage: (stageNumber) =>
                      _startStage(stageNumber, snapshot),
                  onOpenMapEditor: () {
                    setState(() {
                      _screen = _AppScreen.mapEditor;
                    });
                  },
                );
              },
            );
          },
        ),
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
  const _AppLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07111D),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.55),
            radius: 1.05,
            colors: [Color(0xFF102A3A), Color(0xFF07111D)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 58),
              const _RuneNexusLoadingLogo(),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.fromLTRB(36, 0, 36, 42),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '전투 이펙트 리소스를 불러오는 중',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFB9D6E4),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: const LinearProgressIndicator(
                        minHeight: 8,
                        backgroundColor: Color(0x332ED3FF),
                        color: Color(0xFF8EE6FF),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RuneNexusLoadingLogo extends StatelessWidget {
  const _RuneNexusLoadingLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 112,
          height: 112,
          child: CustomPaint(painter: _RuneNexusLogoPainter()),
        ),
        const SizedBox(height: 18),
        const Text(
          'RUNE NEXUS',
          style: TextStyle(
            color: Color(0xFFE8FBFF),
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: 2.6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '룬 넥서스 준비 중',
          style: TextStyle(
            color: Color(0xFF7DB8C8),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }
}

class _RuneNexusLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide * 0.42;

    final outer = Paint()
      ..color = const Color(0xFF153447)
      ..style = PaintingStyle.fill;
    final rim = Paint()
      ..color = const Color(0xFF8EE6FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.035;
    final rune = Paint()
      ..color = const Color(0xFFE7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.shortestSide * 0.05
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawCircle(center, radius, outer);
    canvas.drawCircle(center, radius, rim);

    final diamond = Path()
      ..moveTo(center.dx, center.dy - radius * 0.78)
      ..lineTo(center.dx + radius * 0.42, center.dy)
      ..lineTo(center.dx, center.dy + radius * 0.78)
      ..lineTo(center.dx - radius * 0.42, center.dy)
      ..close();
    canvas.drawPath(diamond, rune);

    canvas.drawLine(
      center.translate(0, -radius * 0.42),
      center.translate(0, radius * 0.42),
      rune,
    );
    canvas.drawLine(
      center.translate(-radius * 0.28, 0),
      center.translate(radius * 0.28, 0),
      rune,
    );

    canvas.drawCircle(
      center,
      radius * 0.16,
      Paint()..color = const Color(0xFF8EE6FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
