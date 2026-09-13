import 'dart:ui';

/// Read-only presentation snapshot. Simulation time and positions stay in Dart.
abstract interface class BattlefieldEffectSource {
  BattlefieldEffect? battlefieldEffect(int id, Offset origin, double tileSize);
}

class BattlefieldEffects {
  BattlefieldEffects({
    required List<BattlefieldEffect> items,
    this.shake = Offset.zero,
  }) : items = List.unmodifiable(items);
  final List<BattlefieldEffect> items;
  final Offset shake;
  Map<String, Object> toJson() => {
    'shake': [shake.dx, shake.dy],
    'items': items.map((item) => item.toJson()).toList(growable: false),
  };
}

class BattlefieldEffect {
  BattlefieldEffect({
    required this.id,
    required this.kind,
    required this.age,
    required this.duration,
    required this.position,
    required this.tileSize,
    this.color = const Color(0xFFFFFFFF),
    this.radius = 0,
    this.visualScale = 1,
    this.text = '',
    this.feedback = 'neutral',
    this.motion = 'rise',
    this.style = '',
    this.enemyType = '',
    this.enemyTypeIndex = 0,
    this.hasImage = false,
    this.screenOffset = Offset.zero,
    List<Offset> points = const [],
  }) : points = List.unmodifiable(points);

  final int id;
  final String kind;
  final double age;
  final double duration;

  /// Positions and points use continuous tile coordinates; sizes use source px.
  final Offset position;
  final double tileSize;
  final Color color;
  final double radius;
  final double visualScale;
  final String text;
  final String feedback;
  final String motion;
  final String style;
  final String enemyType;
  final int enemyTypeIndex;
  final bool hasImage;
  final Offset screenOffset;
  final List<Offset> points;

  Map<String, Object> toJson() => {
    'id': id,
    'kind': kind,
    'age': age,
    'duration': duration,
    'x': position.dx,
    'y': position.dy,
    'tileSize': tileSize,
    'color': color.toARGB32(),
    'radius': radius,
    'scale': visualScale,
    'text': text,
    'feedback': feedback,
    'motion': motion,
    'style': style,
    'enemyType': enemyType,
    'enemyTypeIndex': enemyTypeIndex,
    'hasImage': hasImage,
    'screenOffset': [screenOffset.dx, screenOffset.dy],
    'points': points.map((p) => [p.dx, p.dy]).toList(growable: false),
  };
}

Offset battlefieldEffectPosition(
  Offset point,
  Offset origin,
  double tileSize,
) => (point - origin) / tileSize;
