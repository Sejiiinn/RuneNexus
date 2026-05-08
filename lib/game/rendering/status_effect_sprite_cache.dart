import 'dart:ui';

class StatusEffectSpriteCache {
  StatusEffectSpriteCache._({
    required this.burnEmber,
    required this.burnGlow,
    required this.burnSmoke,
    required this.slowShard,
  });

  final Image burnEmber;
  final Image burnGlow;
  final Image burnSmoke;
  final Image slowShard;

  static StatusEffectSpriteCache create() {
    return StatusEffectSpriteCache._(
      burnEmber: _circleSprite(const Color(0xFFFFA23A)),
      burnGlow: _circleSprite(const Color(0x66FF5A1F)),
      burnSmoke: _circleSprite(const Color(0xFF746A63)),
      slowShard: _slowShardSprite(),
    );
  }

  void dispose() {
    burnEmber.dispose();
    burnGlow.dispose();
    burnSmoke.dispose();
    slowShard.dispose();
  }

  static Image _circleSprite(Color color) {
    const size = 32.0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawCircle(
      const Offset(size / 2, size / 2),
      size / 2,
      Paint()..color = color,
    );
    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }

  static Image _slowShardSprite() {
    const size = 32.0;
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final center = const Offset(size / 2, size / 2);
    final shardSize = size * 0.34;
    final paint = Paint()
      ..color = const Color(0xFFE8FBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      center.translate(-shardSize, 0),
      center.translate(shardSize, 0),
      paint,
    );
    canvas.drawLine(
      center.translate(0, -shardSize),
      center.translate(0, shardSize),
      paint,
    );

    final picture = recorder.endRecording();
    final image = picture.toImageSync(size.toInt(), size.toInt());
    picture.dispose();
    return image;
  }
}
