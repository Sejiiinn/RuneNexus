class GridPoint {
  const GridPoint(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) {
    return other is GridPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}
