import 'package:flutter/material.dart';

import '../domain/combat/game_phase.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
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
          return AlertDialog(
            title: const Text('진행 중인 스테이지 종료'),
            content: Text(
              '스테이지 ${snapshot.currentStageNumber} 진행 상황을 종료하고 '
              '현재 클리어 라운드 기준으로 룬을 정산한 뒤 '
              '스테이지 $stageNumber를 시작합니다. 저장된 배치와 적 진행도는 삭제됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('취소'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('정산 후 시작'),
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
                onOpenMainMenu: () => _openMainScreen(),
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
