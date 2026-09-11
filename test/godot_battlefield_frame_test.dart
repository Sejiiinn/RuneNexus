import 'dart:convert';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/enemy/enemy_type.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/domain/turret/turret_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_frame.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_frame.dart';

void main() {
  test('Godot에만 종료 탄환을 합치고 발사·충돌 표시 메타데이터를 보존한다', () {
    final frame = BattlefieldFrame(
      map: MapDefinition(
        columns: 1,
        rows: 1,
        tiles: const [
          [TileType.build],
        ],
        path: const [],
      ),
      turrets: const [],
      enemies: const [],
      projectiles: const [
        BattlefieldProjectile(
          id: 13,
          type: TurretType.arrow,
          position: Offset(5, 6),
          direction: Offset(.6, .8),
          origin: Offset(2.5, 3.5),
          ownerId: 7,
          shotSequence: 9,
        ),
      ],
      finishedProjectiles: const [
        BattlefieldProjectile(
          id: 14,
          type: TurretType.cannon,
          position: Offset(7, 8),
          direction: Offset(0, 1),
          origin: Offset(4.5, 5.5),
          ownerId: 8,
          shotSequence: 12,
          isChain: true,
          finishedAt: 1.95,
          hitTarget: Offset(7, 8.4),
        ),
      ],
      time: 2,
      pixelsPerTile: 48,
      zoom: 1,
      screenCenter: Offset.zero,
      nexusHpRatio: 1,
      nexusHit: 0,
      portalAlert: 0,
    );
    final decoded =
        jsonDecode(jsonEncode(encodeGodotBattlefieldFrame(frame, sequence: 42)))
            as Map<String, dynamic>;
    expect(decoded['projectiles'], [
      [13, 5, 6, .6, .8, 'arrow', 2.5, 3.5, 7, 9, false, -1, null, null],
      [14, 7, 8, 0, 1, 'cannon', 4.5, 5.5, 8, 12, true, 1.95, 7, 8.4],
    ]);
    expect(frame.projectiles, hasLength(1));
    expect(frame.finishedProjectiles, hasLength(1));
    expect(frame.projectiles.single.finishedAt, isNull);
  });

  test('Godot positional wire 계약과 건설 후보·논리 뷰포트를 JSON 왕복 후 보존한다', () {
    final frame = BattlefieldFrame(
      map: MapDefinition(
        columns: 2,
        rows: 2,
        tiles: const [
          [TileType.build, TileType.path],
          [TileType.path, TileType.build],
        ],
        path: const [],
      ),
      turrets: const [
        BattlefieldTurret(
          id: 7,
          type: TurretType.magic,
          position: Offset(1.5, 2.5),
          aimAngle: .25,
          fireFeedback: .4,
          shotSequence: 9,
          level: 3,
        ),
      ],
      buildPreview: const BattlefieldTurret(
        id: -1,
        type: TurretType.frost,
        position: Offset(.5, .5),
        aimAngle: 0,
        fireFeedback: 0,
        level: 1,
      ),
      enemies: const [
        BattlefieldEnemy(
          id: 12,
          type: EnemyType.normal,
          position: Offset(3, 4),
          facingAngle: .5,
          scale: .7,
          phase: .2,
          hitFlash: .1,
          burning: true,
          slowed: false,
          poisoned: true,
          diamondCarrier: false,
        ),
      ],
      projectiles: const [
        BattlefieldProjectile(
          id: 13,
          type: TurretType.cannon,
          position: Offset(5, 6),
          direction: Offset(.6, .8),
        ),
      ],
      time: 2,
      pixelsPerTile: 48,
      zoom: 1.25,
      screenCenter: const Offset(130, 270),
      nexusHpRatio: .8,
      nexusHit: 0,
      portalAlert: .2,
    );
    // 실제 MethodChannel payload와 동일한 JSON 경계 통과.
    final decoded =
        jsonDecode(
              jsonEncode(
                encodeGodotBattlefieldFrame(
                  frame,
                  sequence: 42,
                  viewport: const Size(320, 640),
                ),
              ),
            )
            as Map<String, dynamic>;
    expect(decoded['seq'], 42);
    expect(decoded['map']['tiles'], ['build', 'path', 'path', 'build']);
    expect(decoded['turrets'].single, [7, 1.5, 2.5, .25, 9, .4, 'magic', 3]);
    expect(decoded['enemies'].single, [
      12,
      3,
      4,
      .5,
      .2,
      .7,
      .1,
      'normal',
      true,
      false,
      true,
      false,
    ]);
    expect(decoded['projectiles'].single, [13, 5, 6, .6, .8, 'cannon']);
    expect(decoded['buildPreview'], [-1, .5, .5, 0, 0, 0, 'frost', 1]);
    expect(decoded['viewport'], [320, 640]);
    expect(decoded['screenCenter'], [130, 270]);
    expect(decoded['pixelsPerTile'], 48);
    expect(decoded['zoom'], 1.25);
    expect(frame.turrets, hasLength(1));
    expect(
      encodeGodotBattlefieldFrame(frame, sequence: 43),
      isNot(contains('viewport')),
    );
  });
}
