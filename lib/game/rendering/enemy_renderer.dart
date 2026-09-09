import 'dart:math' as math;
import 'dart:ui';

import '../../domain/enemy/enemy_type.dart';
import 'diamond_currency_renderer.dart';
import 'enemy_shape_renderer.dart';
import 'status_effect_sprite_cache.dart';

/// 전투 객체를 참조하지 않는 한 프레임의 표시 값.
class EnemyRenderState {
  const EnemyRenderState({
    required this.size,
    required this.type,
    required this.color,
    required this.visualOffset,
    required this.visualPhase,
    required this.facingAngle,
    required this.effectTime,
    required this.hitFlashRemaining,
    required this.hitFlashColor,
    required this.hp,
    required this.maxHp,
    required this.shield,
    required this.maxShield,
    required this.armor,
    required this.maxArmor,
    required this.isDiamondCarrier,
    required this.isBurning,
    required this.isPoisoned,
    required this.isSlowed,
    required this.hasRiftMark,
    required this.enemyCount,
  });

  final Size size;
  final EnemyType type;
  final Color color;
  final Offset visualOffset;
  final double visualPhase;
  final double facingAngle;
  final double effectTime;
  final double hitFlashRemaining;
  final Color hitFlashColor;
  final double hp;
  final double maxHp;
  final double shield;
  final double maxShield;
  final double armor;
  final double maxArmor;
  final bool isDiamondCarrier;
  final bool isBurning;
  final bool isPoisoned;
  final bool isSlowed;
  final bool hasRiftMark;
  final int enemyCount;

  bool get isDead => hp <= 0;
}

/// 적의 본체·장식·상태 표시와 재사용 Paint 소유.
class EnemyRenderer {
  final Paint _slowRimPaint = Paint()
    ..color = const Color(0xCCBFEFFF)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.7
    ..strokeCap = StrokeCap.round;
  final Paint _spritePaint = Paint()..filterQuality = FilterQuality.none;
  static const List<Offset> _burnBaseOffsets = [
    Offset(-0.31, -0.25),
    Offset(-0.11, -0.34),
    Offset(0.13, -0.31),
    Offset(0.32, -0.19),
  ];
  static const List<double> _burnPhaseOffsets = [0, 0.31, 0.62, 0.93];
  static const List<Offset> _slowShardOffsets = [
    Offset(0.34, 0),
    Offset(0, 0.34),
    Offset(-0.34, 0),
    Offset(0, -0.34),
  ];

  set slowRimStrokeWidth(double value) => _slowRimPaint.strokeWidth = value;

  void render(
    Canvas canvas,
    EnemyRenderState state, {
    required StatusEffectSpriteCache? statusEffectSprites,
    required Image? diamondCurrencyImage,
  }) {
    final body = Paint()..color = state.color;
    final outline = Paint()
      ..color = const Color(0xFF07111D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final visualOffset = state.visualOffset;
    canvas.save();
    canvas.translate(visualOffset.dx, visualOffset.dy);
    if (state.isDiamondCarrier) {
      _drawDiamondCarrierRearEffects(canvas, state);
    }
    _drawMotionEffects(canvas, state);
    _drawBody(canvas, state, body, outline);
    if (state.isDiamondCarrier) {
      _drawDiamondCarrierArmor(canvas, state, diamondCurrencyImage);
    }
    _drawBodyOverlayEffects(canvas, state);
    _drawHitFlash(canvas, state);

    if (state.isBurning) {
      _drawBurnStatus(canvas, state, statusEffectSprites!);
    }
    if (state.isPoisoned) {
      canvas.drawCircle(
        Offset(state.size.width / 2, state.size.height / 2),
        state.size.width * 0.5,
        Paint()
          ..color = const Color(0x669DFF4A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (state.isSlowed) {
      _drawSlowStatus(canvas, state, statusEffectSprites!);
    }
    if (state.hasRiftMark) {
      _drawRiftMarkStatus(canvas, state);
    }

    _drawDurabilityBars(canvas, state);
    canvas.restore();
  }

  void _drawDiamondCarrierRearEffects(Canvas canvas, EnemyRenderState state) {
    final center = Offset(state.size.width / 2, state.size.height * 0.68);
    final pulse = 0.82 + math.sin(state.effectTime * 4.2) * 0.12;
    final ringRect = Rect.fromCenter(
      center: center,
      width: state.size.width * 1.55 * pulse,
      height: state.size.height * 0.58 * pulse,
    );
    canvas.drawOval(
      ringRect,
      Paint()
        ..color = const Color(0xFF5ED8FF).withValues(alpha: 0.14)
        ..style = PaintingStyle.stroke
        ..strokeWidth = state.size.width * 0.18
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.09,
        ),
    );
    canvas.drawOval(
      ringRect,
      Paint()
        ..color = const Color(0xFFCFF4FF).withValues(alpha: 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = state.size.width * 0.055,
    );

    // 삼중 궤도 결정 파편
    for (var index = 0; index < 3; index++) {
      final angle =
          state.effectTime * 1.9 +
          state.visualPhase * math.pi * 2 +
          index * math.pi * 2 / 3;
      final shardCenter = Offset(
        state.size.width / 2 + math.cos(angle) * state.size.width * 0.72,
        state.size.height / 2 + math.sin(angle) * state.size.height * 0.34,
      );
      final shardSize = state.size.width * (index == 0 ? 0.15 : 0.11);
      final shard = Path()
        ..moveTo(shardCenter.dx, shardCenter.dy - shardSize)
        ..lineTo(shardCenter.dx + shardSize * 0.52, shardCenter.dy)
        ..lineTo(shardCenter.dx, shardCenter.dy + shardSize)
        ..lineTo(shardCenter.dx - shardSize * 0.52, shardCenter.dy)
        ..close();
      canvas.drawPath(
        shard,
        Paint()
          ..color = const Color(0xFFCFF4FF).withValues(alpha: 0.9)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            state.size.width * 0.025,
          ),
      );
      canvas.drawPath(
        shard,
        Paint()
          ..color = const Color(0xFF1F93C8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = state.size.width * 0.035,
      );
    }
  }

  void _drawDiamondCarrierArmor(
    Canvas canvas,
    EnemyRenderState state,
    Image? diamondCurrencyImage,
  ) {
    final center = Offset(state.size.width / 2, state.size.height / 2);
    final armorPaint = Paint()
      ..color = const Color(0xFF8EE6FF).withValues(alpha: 0.82)
      ..style = PaintingStyle.fill;
    final armorEdge = Paint()
      ..color = const Color(0xFFEAFBFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.size.width * 0.035
      ..strokeJoin = StrokeJoin.round;

    for (final side in [-1.0, 1.0]) {
      final plate = Path()
        ..moveTo(
          center.dx + side * state.size.width * 0.18,
          state.size.height * 0.2,
        )
        ..lineTo(
          center.dx + side * state.size.width * 0.42,
          state.size.height * 0.32,
        )
        ..lineTo(
          center.dx + side * state.size.width * 0.36,
          state.size.height * 0.56,
        )
        ..lineTo(
          center.dx + side * state.size.width * 0.16,
          state.size.height * 0.48,
        )
        ..close();
      canvas.drawPath(plate, armorPaint);
      canvas.drawPath(plate, armorEdge);
    }

    canvas.save();
    canvas.translate(state.size.width * 0.34, state.size.height * 0.25);
    drawDiamondCurrencyGlyph(
      canvas,
      Size(state.size.width * 0.32, state.size.height * 0.32),
      diamondCurrencyImage,
    );
    canvas.restore();

    final crownPaint = Paint()
      ..color = const Color(0xFFCFF4FF)
      ..style = PaintingStyle.fill;
    for (var index = -1; index <= 1; index++) {
      final x = center.dx + index * state.size.width * 0.16;
      final crystal = Path()
        ..moveTo(x, state.size.height * (index == 0 ? -0.15 : -0.04))
        ..lineTo(x + state.size.width * 0.07, state.size.height * 0.18)
        ..lineTo(x, state.size.height * 0.27)
        ..lineTo(x - state.size.width * 0.07, state.size.height * 0.18)
        ..close();
      canvas.drawPath(crystal, crownPaint);
      canvas.drawPath(crystal, armorEdge);
    }
  }

  void _drawDurabilityBars(Canvas canvas, EnemyRenderState state) {
    final barWidth = state.size.width - 2;
    const hpColor = Color(0xFFFF4E5D);
    const armorColor = Color(0xFFB7BDC8);
    const shieldColor = Color(0xFF62D9FF);
    const backgroundColor = Color(0xFF321118);
    const shieldBackgroundColor = Color(0xFF102B3A);

    if (state.maxShield > 0 && state.shield > 0) {
      final shieldRatio = (state.shield / state.maxShield)
          .clamp(0.0, 1.0)
          .toDouble();
      canvas.drawRect(
        Rect.fromLTWH(1, -9, barWidth, 3),
        Paint()..color = shieldBackgroundColor,
      );
      canvas.drawRect(
        Rect.fromLTWH(1, -9, barWidth * shieldRatio, 3),
        Paint()..color = shieldColor,
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(1, -5, barWidth, 3),
      Paint()..color = backgroundColor,
    );
    if (state.maxArmor > 0) {
      final totalDurability = math.max(1.0, state.maxHp + state.maxArmor);
      final hpWidth =
          barWidth * (state.hp / totalDurability).clamp(0.0, 1.0).toDouble();
      final armorWidth =
          barWidth * (state.armor / totalDurability).clamp(0.0, 1.0).toDouble();
      canvas.drawRect(
        Rect.fromLTWH(1, -5, hpWidth, 3),
        Paint()..color = hpColor,
      );
      if (armorWidth > 0) {
        canvas.drawRect(
          Rect.fromLTWH(1 + hpWidth, -5, armorWidth, 3),
          Paint()..color = armorColor,
        );
      }
      return;
    }

    final ratio = state.maxHp <= 0
        ? 0.0
        : (state.hp / state.maxHp).clamp(0.0, 1.0).toDouble();
    canvas.drawRect(
      Rect.fromLTWH(1, -5, barWidth * ratio, 3),
      Paint()..color = hpColor,
    );
  }

  void _drawBody(
    Canvas canvas,
    EnemyRenderState state,
    Paint body,
    Paint outline,
  ) {
    drawEnemyShape(
      canvas,
      size: Size(state.size.width, state.size.height),
      type: state.type,
      color: body.color,
      strokeWidth: outline.strokeWidth,
      facingAngle: state.facingAngle,
    );
  }

  void _drawMotionEffects(Canvas canvas, EnemyRenderState state) {
    if (state.isDead) {
      return;
    }
    switch (state.type) {
      case EnemyType.normal:
        _drawRearFlickerLight(
          canvas,
          state,
          glowColor: const Color(0xFFD7CFC0),
          coreColor: const Color(0xFFFFE6BD),
          speed: 29,
          widthScale: 0.92,
          alphaScale: 0.86,
        );
      case EnemyType.fast:
        _drawRearFlickerLight(
          canvas,
          state,
          glowColor: const Color(0xFF7CE8FF),
          coreColor: const Color(0xFFE8FBFF),
          speed: 34,
          widthScale: 1.08,
          alphaScale: 1,
        );
      case EnemyType.shielded:
        _drawRearFlickerLight(
          canvas,
          state,
          glowColor: const Color(0xFF7FDFFF),
          coreColor: const Color(0xFFEAFBFF),
          speed: 27,
          widthScale: 0.98,
          alphaScale: 0.82,
        );
      case EnemyType.armored:
      case EnemyType.tank:
        return;
      case EnemyType.boss:
      case EnemyType.shieldBoss:
      case EnemyType.forgeBoss:
        _drawBossCoreThrum(canvas, state);
        return;
    }
  }

  void _drawBodyOverlayEffects(Canvas canvas, EnemyRenderState state) {
    if (state.isDead || !state.type.isBoss) {
      return;
    }
    _drawBossCoreThrum(canvas, state, foreground: true);
  }

  void _drawRearFlickerLight(
    Canvas canvas,
    EnemyRenderState state, {
    required Color glowColor,
    required Color coreColor,
    required double speed,
    required double widthScale,
    required double alphaScale,
  }) {
    final loadFade = state.enemyCount >= 80 ? 0.5 : 1.0;
    final phase = state.effectTime * speed + state.visualPhase * math.pi * 2;
    final flicker =
        (0.62 + math.sin(phase) * 0.23 + math.sin(phase * 1.73 + 0.8) * 0.12)
            .clamp(0.22, 1.0)
            .toDouble();
    canvas.save();
    canvas.translate(state.size.width / 2, state.size.height / 2);
    canvas.rotate(state.facingAngle);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.63, 0),
        width: state.size.width * (0.44 + flicker * 0.13) * widthScale,
        height: state.size.height * 0.3,
      ),
      Paint()
        ..color = glowColor.withValues(
          alpha: 0.34 * flicker * alphaScale * loadFade,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.04,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.47, 0),
        width: state.size.width * (0.24 + flicker * 0.05) * widthScale,
        height: state.size.height * 0.15,
      ),
      Paint()
        ..color = coreColor.withValues(
          alpha: 0.46 * flicker * alphaScale * loadFade,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.018,
        ),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            -state.size.width * 0.26,
            side * state.size.height * 0.2,
          ),
          width: state.size.width * 0.105 * widthScale,
          height: state.size.height * 0.067,
        ),
        Paint()
          ..color = coreColor.withValues(
            alpha: 0.3 * flicker * alphaScale * loadFade,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            state.size.width * 0.012,
          ),
      );
    }

    canvas.restore();
  }

  void _drawBossCoreThrum(
    Canvas canvas,
    EnemyRenderState state, {
    bool foreground = false,
  }) {
    final loadFade = state.enemyCount >= 80 ? 0.82 : 1.0;
    final hpRatio = state.maxHp <= 0
        ? 1.0
        : (state.hp / state.maxHp).clamp(0.0, 1.0).toDouble();
    final stress = 1 - hpRatio;
    final phase =
        state.effectTime * (5.5 + stress * 1.8) +
        state.visualPhase * math.pi * 2;
    final pulseBase = (math.sin(phase) + 1) * 0.5;
    final pulse = math.pow(pulseBase, 1.85).toDouble();
    final shimmer = (math.sin(phase * 2.25 + 0.7) + 1) * 0.5;
    final thrum = (0.42 + pulse * 0.46 + shimmer * 0.12)
        .clamp(0.0, 1.0)
        .toDouble();
    final alphaBoost = 1 + stress * 0.32;
    final ringColor = _bossPulseRingColor(state.type);
    final glowColor = _bossPulseGlowColor(state.type);
    final coreColor = _bossPulseCoreColor(state.type);
    final hotCoreColor = _bossPulseHotCoreColor(state.type);

    canvas.save();
    canvas.translate(state.size.width / 2, state.size.height / 2);
    canvas.rotate(state.facingAngle);

    if (foreground) {
      _drawBossCoreHighlights(
        canvas,
        state,
        pulse: pulse,
        thrum: thrum,
        alphaBoost: alphaBoost,
        loadFade: loadFade,
        ringColor: ringColor,
        glowColor: glowColor,
        coreColor: coreColor,
        hotCoreColor: hotCoreColor,
      );
      canvas.restore();
      return;
    }

    // 보스 동력 맥동
    canvas.drawCircle(
      Offset.zero,
      state.size.width * (0.56 + thrum * 0.045),
      Paint()
        ..color = ringColor.withValues(
          alpha: 0.32 * thrum * alphaBoost * loadFade,
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = state.size.width * (0.055 + thrum * 0.022)
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.034,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.58, 0),
        width: state.size.width * (0.58 + thrum * 0.14),
        height: state.size.height * (0.4 + thrum * 0.055),
      ),
      Paint()
        ..color = glowColor.withValues(
          alpha: 0.58 * thrum * alphaBoost * loadFade,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.07,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.46, 0),
        width: state.size.width * (0.28 + thrum * 0.07),
        height: state.size.height * (0.18 + thrum * 0.032),
      ),
      Paint()
        ..color = coreColor.withValues(
          alpha: 0.72 * thrum * alphaBoost * loadFade,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.024,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.38, 0),
        width: state.size.width * 0.11,
        height: state.size.height * 0.074,
      ),
      Paint()
        ..color = hotCoreColor.withValues(
          alpha: 0.65 * pulse * alphaBoost * loadFade,
        )
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.01,
        ),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            -state.size.width * 0.24,
            side * state.size.height * 0.25,
          ),
          width: state.size.width * (0.2 + thrum * 0.04),
          height: state.size.height * 0.088,
        ),
        Paint()
          ..color = coreColor.withValues(
            alpha: 0.56 * thrum * alphaBoost * loadFade,
          )
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            state.size.width * 0.018,
          ),
      );
    }

    canvas.restore();
  }

  void _drawBossCoreHighlights(
    Canvas canvas,
    EnemyRenderState state, {
    required double pulse,
    required double thrum,
    required double alphaBoost,
    required double loadFade,
    required Color ringColor,
    required Color glowColor,
    required Color coreColor,
    required Color hotCoreColor,
  }) {
    final ringAlpha = (0.46 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final coreAlpha = (0.95 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final ventAlpha = (0.82 * thrum * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final hotCoreAlpha = (1.0 * pulse * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    final hotVentAlpha = (0.78 * pulse * alphaBoost * loadFade)
        .clamp(0.0, 1.0)
        .toDouble();
    canvas.drawCircle(
      Offset.zero,
      state.size.width * (0.28 + thrum * 0.025),
      Paint()
        ..color = ringColor.withValues(alpha: ringAlpha)
        ..blendMode = BlendMode.plus
        ..style = PaintingStyle.stroke
        ..strokeWidth = state.size.width * 0.04
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.016,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.12, 0),
        width: state.size.width * (0.38 + thrum * 0.08),
        height: state.size.height * (0.2 + thrum * 0.035),
      ),
      Paint()
        ..color = coreColor.withValues(alpha: coreAlpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.016,
        ),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(-state.size.width * 0.12, 0),
        width: state.size.width * 0.17,
        height: state.size.height * 0.09,
      ),
      Paint()
        ..color = hotCoreColor.withValues(alpha: hotCoreAlpha)
        ..blendMode = BlendMode.plus
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          state.size.width * 0.006,
        ),
    );
    for (final side in [-1.0, 1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            state.size.width * 0.02,
            side * state.size.height * 0.22,
          ),
          width: state.size.width * (0.24 + thrum * 0.045),
          height: state.size.height * 0.105,
        ),
        Paint()
          ..color = glowColor.withValues(alpha: ventAlpha)
          ..blendMode = BlendMode.plus
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            state.size.width * 0.01,
          ),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(
            state.size.width * 0.02,
            side * state.size.height * 0.22,
          ),
          width: state.size.width * 0.082,
          height: state.size.height * 0.038,
        ),
        Paint()
          ..color = hotCoreColor.withValues(alpha: hotVentAlpha)
          ..blendMode = BlendMode.plus,
      );
    }
  }

  Color _bossPulseRingColor(EnemyType type) {
    return switch (type) {
      EnemyType.shieldBoss => const Color(0xFF67E4FF),
      EnemyType.forgeBoss => const Color(0xFFFF9D55),
      _ => const Color(0xFFFF5A66),
    };
  }

  Color _bossPulseGlowColor(EnemyType type) {
    return switch (type) {
      EnemyType.shieldBoss => const Color(0xFF9B8CFF),
      EnemyType.forgeBoss => const Color(0xFFFF6A2A),
      _ => const Color(0xFFB6394B),
    };
  }

  Color _bossPulseCoreColor(EnemyType type) {
    return switch (type) {
      EnemyType.shieldBoss => const Color(0xFFB692FF),
      EnemyType.forgeBoss => const Color(0xFF62E8D6),
      _ => const Color(0xFFFF8791),
    };
  }

  Color _bossPulseHotCoreColor(EnemyType type) {
    return switch (type) {
      EnemyType.shieldBoss => const Color(0xFFEAFBFF),
      EnemyType.forgeBoss => const Color(0xFFE9FFFA),
      _ => const Color(0xFFFFE1E5),
    };
  }

  void _drawHitFlash(Canvas canvas, EnemyRenderState state) {
    if (state.hitFlashRemaining <= 0) {
      return;
    }
    final progress = (state.hitFlashRemaining / 0.08).clamp(0.0, 1.0);
    final center = Offset(state.size.width / 2, state.size.height / 2);
    final radius = state.size.width * (0.44 + (1 - progress) * 0.12);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Color.lerp(
          state.hitFlashColor,
          const Color(0xFFFFFFFF),
          0.55,
        )!.withValues(alpha: progress * 0.34),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = state.hitFlashColor.withValues(alpha: progress * 0.82)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );
  }

  void _drawBurnStatus(
    Canvas canvas,
    EnemyRenderState state,
    StatusEffectSpriteCache statusEffectSprites,
  ) {
    final center = Offset(state.size.width / 2, state.size.height / 2);
    final emberCount = state.enemyCount >= 60 ? 2 : _burnBaseOffsets.length;
    for (var i = 0; i < emberCount; i++) {
      final phase = (state.effectTime * 3.4 + _burnPhaseOffsets[i]) % 1;
      final baseOffset = _burnBaseOffsets[i];
      final base = Offset(
        center.dx + baseOffset.dx * state.size.width,
        center.dy + baseOffset.dy * state.size.height,
      );
      final ember = base.translate(0, -phase * state.size.height * 0.34);
      final radius = state.size.width * (0.045 + (1 - phase) * 0.035);
      _drawStatusSprite(
        canvas,
        image: statusEffectSprites.burnGlow,
        center: ember,
        radius: radius * 2.2,
      );
      _drawStatusSprite(
        canvas,
        image: statusEffectSprites.burnEmber,
        center: ember,
        radius: radius,
      );
      if (i.isEven) {
        _drawStatusSprite(
          canvas,
          image: statusEffectSprites.burnSmoke,
          center: ember.translate(
            state.size.width * 0.04,
            -state.size.height * 0.1,
          ),
          radius: radius * 1.5,
          alpha: 0.22 * phase,
        );
      }
    }
  }

  void _drawSlowStatus(
    Canvas canvas,
    EnemyRenderState state,
    StatusEffectSpriteCache statusEffectSprites,
  ) {
    final center = Offset(state.size.width / 2, state.size.height / 2);
    final rimRect = Rect.fromCircle(
      center: center,
      radius: state.size.width * 0.48,
    );
    final phase = state.effectTime * 0.9;
    final rimCount = state.enemyCount >= 60 ? 2 : 3;
    for (var i = 0; i < rimCount; i++) {
      canvas.drawArc(
        rimRect,
        phase + i * math.pi * 2 / 3,
        math.pi * 0.34,
        false,
        _slowRimPaint,
      );
    }

    final shardCount = state.enemyCount >= 60 ? 2 : _slowShardOffsets.length;
    for (var i = 0; i < shardCount; i++) {
      final shardOffset = _slowShardOffsets[i];
      final shardCenter = Offset(
        center.dx + shardOffset.dx * state.size.width,
        center.dy + shardOffset.dy * state.size.height,
      );
      final shardSize = state.size.width * 0.075;
      _drawStatusSprite(
        canvas,
        image: statusEffectSprites.slowShard,
        center: shardCenter,
        radius: shardSize / 0.34,
      );
    }
  }

  void _drawRiftMarkStatus(Canvas canvas, EnemyRenderState state) {
    final center = Offset(state.size.width / 2, state.size.height / 2);
    final phase = (state.effectTime * 1.45) % 1;
    final baseRadius = state.size.width * (0.55 + phase * 0.08);
    final color = const Color(0xFFCFA7FF);
    final ringPaint = Paint()
      ..color = color.withValues(alpha: 0.58 - phase * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.size.width * 0.055
      ..strokeCap = StrokeCap.round;
    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.13)
      ..style = PaintingStyle.stroke
      ..strokeWidth = state.size.width * 0.16;
    final rect = Rect.fromCircle(center: center, radius: baseRadius);
    canvas.drawCircle(center, baseRadius, glowPaint);
    for (var i = 0; i < 4; i++) {
      canvas.drawArc(
        rect,
        phase * math.pi * 2 + i * math.pi / 2,
        math.pi * 0.26,
        false,
        ringPaint,
      );
    }
    canvas.drawLine(
      center.translate(-state.size.width * 0.16, -state.size.height * 0.16),
      center.translate(state.size.width * 0.16, state.size.height * 0.16),
      ringPaint,
    );
    canvas.drawLine(
      center.translate(state.size.width * 0.16, -state.size.height * 0.16),
      center.translate(-state.size.width * 0.16, state.size.height * 0.16),
      ringPaint,
    );
  }

  void _drawStatusSprite(
    Canvas canvas, {
    required Image image,
    required Offset center,
    required double radius,
    double alpha = 1,
  }) {
    _spritePaint.colorFilter = alpha >= 1
        ? null
        : ColorFilter.mode(
            const Color(0xFFFFFFFF).withValues(alpha: alpha),
            BlendMode.modulate,
          );
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(center: center, radius: radius),
      _spritePaint,
    );
  }
}
