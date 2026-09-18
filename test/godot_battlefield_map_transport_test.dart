import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/map/map_definition.dart';
import 'package:rune_nexus/domain/map/map_tile_theme.dart';
import 'package:rune_nexus/domain/map/tile_type.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/godot_battlefield_map_transport.dart';

void main() {
  MapDefinition map({MapTileTheme theme = chapterOneTileTheme}) =>
      MapDefinition(
        columns: 2,
        rows: 1,
        tiles: [
          [TileType.build, TileType.path],
        ],
        path: const [],
        tileTheme: theme,
      );

  test(
    'coalesced pending frames retain cached map until matching applied ACK',
    () {
      final transport = GodotBattlefieldMapTransport();
      final source = map();
      final first = transport.prepare(source, sceneEpoch: 7, sequence: 0);
      final latest = transport.prepare(source, sceneEpoch: 7, sequence: 9);
      expect(latest['map'], same(first['map']));
      transport.acknowledge(sceneEpoch: 6, sequence: 9, mapRevision: 1);
      transport.acknowledge(sceneEpoch: 7, sequence: 9, mapRevision: null);
      expect(
        transport.prepare(source, sceneEpoch: 7, sequence: 10),
        contains('map'),
      );
      transport.acknowledge(sceneEpoch: 7, sequence: 9, mapRevision: 1);
      expect(transport.prepare(source, sceneEpoch: 7, sequence: 11), {
        'mapRevision': 1,
      });
      expect(
        transport.prepare(source, sceneEpoch: 8, sequence: 0),
        contains('map'),
      );
    },
  );

  test(
    'same identity/size/theme tile change and theme change resend exact map',
    () {
      final transport = GodotBattlefieldMapTransport();
      final source = map();
      transport.prepare(source, sceneEpoch: 7, sequence: 0);
      transport.acknowledge(sceneEpoch: 7, sequence: 0, mapRevision: 1);
      source.tiles[0][0] = TileType.path;
      final changed = transport.prepare(source, sceneEpoch: 7, sequence: 1);
      expect(changed['mapRevision'], 2);
      expect((changed['map'] as Map)['tiles'], ['path', 'path']);
      transport.acknowledge(sceneEpoch: 7, sequence: 0, mapRevision: 1);
      expect(
        transport.prepare(source, sceneEpoch: 7, sequence: 2),
        contains('map'),
      );
      final themed = transport.prepare(
        map(theme: chapterTwoRiftTileTheme),
        sceneEpoch: 7,
        sequence: 3,
      );
      expect(themed['mapRevision'], 3);
      expect((themed['map'] as Map)['theme'], 'chapterTwoRift');
      final resized = transport.prepare(
        const MapDefinition(
          columns: 1,
          rows: 2,
          tiles: [
            [TileType.build],
            [TileType.path],
          ],
          path: [],
        ),
        sceneEpoch: 7,
        sequence: 4,
      );
      expect(resized['mapRevision'], 4);
      expect((resized['map'] as Map)['rows'], 2);
    },
  );

  test('recovery resends map and old ACK cannot cancel recovery', () {
    final transport = GodotBattlefieldMapTransport();
    final source = map();
    transport.prepare(source, sceneEpoch: 7, sequence: 0);
    transport.acknowledge(sceneEpoch: 7, sequence: 0, mapRevision: 1);
    transport.requestMap(sceneEpoch: 6, sequence: 2, mapRevision: 1);
    expect(
      transport.prepare(source, sceneEpoch: 7, sequence: 3),
      isNot(contains('map')),
    );
    transport.requestMap(sceneEpoch: 7, sequence: 3, mapRevision: 1);
    transport.acknowledge(sceneEpoch: 7, sequence: 2, mapRevision: 1);
    expect(
      transport.prepare(source, sceneEpoch: 7, sequence: 4),
      contains('map'),
    );
    transport.acknowledge(sceneEpoch: 7, sequence: 4, mapRevision: 1);
    transport.requestMap(sceneEpoch: 7, sequence: 3, mapRevision: 1);
    expect(
      transport.prepare(source, sceneEpoch: 7, sequence: 5),
      isNot(contains('map')),
    );
  });
}
