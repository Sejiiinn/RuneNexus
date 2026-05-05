import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../domain/combat/game_phase.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../ui/hud/game_hud.dart';
import '../ui/menu/main_menu_screen.dart';

enum _AppScreen { main, stage }

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({super.key});

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp> {
  late final RuneNexusGame game;
  _AppScreen _screen = _AppScreen.main;
  MainMenuTab _selectedMainMenuTab = MainMenuTab.stage;

  @override
  void initState() {
    super.initState();
    game = RuneNexusGame();
    game.prepareSavedStateForMenu();
  }

  void _openMainScreen({MainMenuTab tab = MainMenuTab.stage}) {
    setState(() {
      _screen = _AppScreen.main;
      _selectedMainMenuTab = tab;
    });
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
        useMaterial3: true,
      ),
      home: Scaffold(
        backgroundColor: const Color(0xFF07111D),
        body: ValueListenableBuilder(
          valueListenable: game.snapshotNotifier,
          builder: (context, snapshot, _) {
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
            return MainMenuScreen(
              game: game,
              snapshot: snapshot,
              selectedTab: _selectedMainMenuTab,
              onSelectTab: (tab) {
                setState(() {
                  _selectedMainMenuTab = tab;
                });
              },
              onStartStage: (stageNumber) => _startStage(stageNumber, snapshot),
            );
          },
        ),
      ),
    );
  }
}
