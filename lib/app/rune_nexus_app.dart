import 'package:flutter/material.dart';

import '../game/rune_nexus_game.dart';
import '../ui/hud/game_hud.dart';

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({super.key});

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp> {
  late final RuneNexusGame game;

  @override
  void initState() {
    super.initState();
    game = RuneNexusGame();
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
        body: GameHud(game: game),
      ),
    );
  }
}
