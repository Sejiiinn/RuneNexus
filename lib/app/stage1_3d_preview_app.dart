import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/save/online_save_repository.dart';
import '../data/save/save_repository.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../ui/hud/game_hud.dart';

/// 개발용 실제 전투 세션. 진행과 재화는 앱 수명 동안 메모리에만 보관.
class Stage1ThreeDPreviewApp extends StatefulWidget {
  const Stage1ThreeDPreviewApp({super.key});

  @override
  State<Stage1ThreeDPreviewApp> createState() => _Stage1ThreeDPreviewAppState();
}

class _Stage1ThreeDPreviewAppState extends State<Stage1ThreeDPreviewApp> {
  late final RuneNexusGame _game;

  @override
  void initState() {
    super.initState();
    _game = RuneNexusGame(
      transparentBackground: true,
      saveRepository: MemorySaveRepository(),
      onlineSaveRepository: const NoopOnlineSaveRepository(),
    );
  }

  @override
  void dispose() {
    _game.pauseEngine();
    _game.disposeAppResources();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rune Nexus · 스테이지 1 3D 테스트',
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
        backgroundColor: const Color(0xFF29383E),
        body: GameHud(
          game: _game,
          stage1ThreeD: true,
          onStartStage: (_) => _game.startStage(1),
        ),
      ),
    );
  }
}
