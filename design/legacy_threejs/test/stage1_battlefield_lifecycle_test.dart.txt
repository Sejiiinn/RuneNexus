import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rune_nexus_game.dart';
import 'package:rune_nexus/ui/hud/stage1_battlefield_view.dart';

void main() {
  testWidgets('크기 없는 전장이 첫 플랫폼 초기화 전에 제거되어도 안전하다', (tester) async {
    final game = RuneNexusGame();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          child: SizedBox(
            width: 0,
            height: 0,
            child: Stage1BattlefieldView(game: game),
          ),
        ),
      ),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(game.battlefieldProjection, isNull);
  });
}
