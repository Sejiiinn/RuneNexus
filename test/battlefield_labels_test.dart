import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_labels.dart';

void main() {
  test('객체 부착 표시 스냅샷은 입력 리스트 변경과 독립적이다', () {
    final source = <BattlefieldEnemyLabel>[
      const BattlefieldEnemyLabel(
        id: 4,
        position: Offset(2.5, 3.5),
        size: Size(26, 27),
        hp: 40,
        maxHp: 100,
        armor: 30,
        maxArmor: 100,
        shield: 12,
        maxShield: 24,
        effectTime: 1.5,
        enemyCount: 63,
        burning: true,
        slowed: true,
        poisoned: true,
        riftMarked: true,
        diamondCarrier: true,
      ),
    ];
    final labels = BattlefieldLabels(
      logicalTileSize: 48,
      enemies: source,
      core: const BattlefieldCoreLabel(
        position: Offset(7.5, 4.5),
        progress: 0.6,
        accent: Color(0xFFCFA7FF),
        active: true,
      ),
    );
    source.clear();
    expect(labels.enemies, hasLength(1));
    expect(() => labels.enemies.clear(), throwsUnsupportedError);
    final json = jsonDecode(jsonEncode(labels.toJson())) as Map;
    final enemy = (json['enemies'] as List).single as Map;
    expect(enemy['position'], [2.5, 3.5]);
    expect(enemy['size'], [26, 27]);
    expect(enemy['hp'], 40);
    expect(enemy['armor'], 30);
    expect(enemy['shield'], 12);
    expect(enemy['enemyCount'], 63);
    expect(enemy['effectTime'], 1.5);
    for (final flag in [
      'burning',
      'slowed',
      'poisoned',
      'riftMarked',
      'diamondCarrier',
    ]) {
      expect(enemy[flag], true);
    }
    expect(json['core']['accent'], 0xFFCFA7FF);
    expect(json['core']['progress'], 0.6);
    expect(json['logicalTileSize'], 48);
    final copy = labels.toJson();
    (copy['enemies']! as List).clear();
    expect(labels.toJson()['enemies'], hasLength(1));
  });

  test('쿨다운을 표시하지 않는 단계는 null로 명시한다', () {
    final json = BattlefieldLabels(logicalTileSize: 48, enemies: []).toJson();
    expect(json['core'], isNull);
    expect(json['enemies'], isEmpty);
  });
}
