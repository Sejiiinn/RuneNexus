import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_selection.dart';

void main() {
  test(
    'selection freezes display lists and preserves resolved range and clipping',
    () {
      final gems = [const Color(0xFF00ABCD)];
      final turrets = [
        BattlefieldTurretSelection(
          position: const Offset(2.5, 3.5),
          color: const Color(0xFF123456),
          range: 2.4,
          previewRange: 2.7,
          selected: true,
          auraTier: 3,
          animationPhase: 1.2,
          gemColors: gems,
          aimTarget: const Offset(3.2, 4.1),
          aimProgress: 0.75,
        ),
      ];
      final frame = BattlefieldSelection(
        logicalTileSize: 48,
        visualScale: 0.8,
        time: 9,
        rewardTargeting: true,
        rewardViewport: const Rect.fromLTWH(0, 10, 360, 420),
        turrets: turrets,
        rewardTargets: const [
          BattlefieldRewardTarget(
            position: Offset(2.5, 3.5),
            requiresReplacement: true,
          ),
        ],
      );
      gems.clear();
      turrets.clear();
      final json = frame.toJson();
      final turret = (json['turrets'] as List).single as Map;
      expect(turret['range'], 2.4);
      expect(turret['previewRange'], 2.7);
      expect(turret['gemColors'], [0xFF00ABCD]);
      expect(turret['aimTarget'], [3.2, 4.1]);
      expect(json['rewardViewport'], [0.0, 10.0, 360.0, 420.0]);
      expect(
        (json['rewardTargets'] as List).single['requiresReplacement'],
        isTrue,
      );
      expect(() => frame.turrets.clear(), throwsUnsupportedError);
    },
  );
}
