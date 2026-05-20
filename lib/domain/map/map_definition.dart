import 'grid_point.dart';
import 'map_tile_theme.dart';
import 'tile_type.dart';

class MapDefinition {
  const MapDefinition({
    required this.columns,
    required this.rows,
    required this.tiles,
    required this.path,
    this.tileTheme = chapterOneTileTheme,
  });

  final int columns;
  final int rows;
  final List<List<TileType>> tiles;
  final List<GridPoint> path;
  final MapTileTheme tileTheme;

  TileType tileAt(GridPoint point) {
    return tiles[point.y][point.x];
  }

  bool contains(GridPoint point) {
    return point.x >= 0 && point.x < columns && point.y >= 0 && point.y < rows;
  }

  bool canBuildAt(GridPoint point) {
    return contains(point) && tileAt(point) == TileType.build;
  }
}
