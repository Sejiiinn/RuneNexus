import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/definitions/game_enemy_data.dart';
import '../../domain/combat/game_phase.dart';
import '../../domain/enemy/enemy_type.dart';
import '../../domain/turret/attack_tag.dart';
import '../../domain/turret/damage_family.dart';
import '../../domain/turret/turret_definition.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/enemy_shape_renderer.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';

class HudGemShardIcon extends StatelessWidget {
  const HudGemShardIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 16,
      height: 16,
      child: CustomPaint(painter: _GemShardPainter()),
    );
  }
}

class _GemShardPainter extends CustomPainter {
  const _GemShardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final shard = Path()
      ..moveTo(size.width * 0.48, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.26)
      ..lineTo(size.width * 0.78, size.height * 0.62)
      ..lineTo(size.width * 0.36, size.height * 0.94)
      ..lineTo(size.width * 0.08, size.height * 0.5)
      ..close();
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFA8FFB8), Color(0xFF28D66F), Color(0xFF0E7F47)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(shard, paint);

    final edgePaint = Paint()
      ..color = const Color(0xFFBFFFF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(shard, edgePaint);

    final facetPaint = Paint()
      ..color = const Color(0x665CFFAA)
      ..style = PaintingStyle.fill;
    final facet = Path()
      ..moveTo(size.width * 0.48, size.height * 0.08)
      ..lineTo(size.width * 0.88, size.height * 0.26)
      ..lineTo(size.width * 0.52, size.height * 0.38)
      ..close();
    canvas.drawPath(facet, facetPaint);

    final glintPaint = Paint()
      ..color = const Color(0xDDFFFFFF)
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.3, size.height * 0.32),
      Offset(size.width * 0.5, size.height * 0.16),
      glintPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GemShardPainter oldDelegate) => false;
}

String hudFormatDamageValue(double value) {
  if (value >= 1000) {
    return '${(value / 1000).toStringAsFixed(1)}K';
  }
  if (value >= 100) {
    return value.round().toString();
  }
  return value.toStringAsFixed(1);
}

class HudTurretAttributeChips extends StatelessWidget {
  const HudTurretAttributeChips({required this.definition, super.key});

  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (
        label: definition.damageFamily.label,
        color: definition.damageFamily.color,
      ),
      ...definition.attackTags.map(
        (tag) => (label: tag.label, color: tag.color),
      ),
    ];

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: label.color.withValues(alpha: 0.12),
            border: Border.all(color: label.color.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: label.color,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class HudStatPill extends StatelessWidget {
  const HudStatPill({
    required this.label,
    required this.value,
    this.valueChild,
    this.expand = true,
    this.accent,
    super.key,
  });

  final String label;
  final String value;
  final Widget? valueChild;
  final bool expand;
  // null이면 기본(시안) 스타일, 지정하면 해당 색으로 강조(예: 치명타 계열).
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent;
    final content = Container(
      constraints: expand ? null : const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        color: accentColor != null
            ? accentColor.withValues(alpha: 0.10)
            : const Color(0xAA07111D),
        border: Border.all(
          color: accentColor != null
              ? accentColor.withValues(alpha: 0.5)
              : const Color(0x3333D8FF),
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8AA6B8)),
            overflow: TextOverflow.clip,
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child:
                valueChild ??
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: accentColor ?? const Color(0xFFE8F8FF),
                  ),
                  overflow: TextOverflow.clip,
                ),
          ),
        ],
      ),
    );
    if (!expand) {
      return content;
    }
    return Expanded(child: content);
  }
}

class HudEnemyIconPainter extends CustomPainter {
  const HudEnemyIconPainter({required this.color, required this.type});

  final Color color;
  final EnemyType type;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    drawEnemyShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HudEnemyIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class HudEnemyIcon extends StatelessWidget {
  const HudEnemyIcon({
    required this.type,
    required this.selected,
    this.size = 30,
    super.key,
  });

  final EnemyType type;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final enemy = gameEnemies[type]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: size,
      height: size,
      padding: EdgeInsets.all(math.max(2, size * 0.1)),
      decoration: BoxDecoration(
        color: selected
            ? enemy.color.withValues(alpha: 0.16)
            : Colors.transparent,
        border: Border.all(
          color: selected ? enemy.color : Colors.transparent,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: CustomPaint(
        painter: HudEnemyIconPainter(color: enemy.color, type: type),
      ),
    );
  }
}

class HudTurretButton extends StatelessWidget {
  const HudTurretButton({
    required this.type,
    required this.label,
    required this.cost,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
    super.key,
  });

  final TurretType type;
  final String label;
  final int cost;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final titleColor = enabled
        ? (selected ? color : GamePalette.textPrimary)
        : GamePalette.textDisabled;
    final costColor = enabled
        ? (selected ? color : GamePalette.textSecondary)
        : GamePalette.textDisabled;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.34),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: GameButton(
        onPressed: enabled ? onPressed : null,
        selected: selected,
        variant: selected
            ? GameButtonVariant.secondary
            : GameButtonVariant.ghost,
        accentColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _TurretShapeIcon(type: type, color: enabled ? color : costColor),
            const SizedBox(height: 2),
            SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  softWrap: false,
                  style: TextStyle(
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w500,
                    color: titleColor,
                  ),
                ),
              ),
            ),
            ScaleDownText(
              '$cost G',
              style: TextStyle(
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w400,
                color: costColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TurretShapeIcon extends StatelessWidget {
  const _TurretShapeIcon({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 20,
      child: CustomPaint(
        painter: _TurretShapePainter(type: type, color: color),
      ),
    );
  }
}

class _TurretShapePainter extends CustomPainter {
  const _TurretShapePainter({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 1.4,
    );
  }

  @override
  bool shouldRepaint(_TurretShapePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class HudRestoreRunOverlay extends StatefulWidget {
  const HudRestoreRunOverlay({
    required this.game,
    required this.snapshot,
    this.onOpenStageSelect,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final VoidCallback? onOpenStageSelect;

  @override
  State<HudRestoreRunOverlay> createState() => _RestoreRunOverlayState();
}

class _RestoreRunOverlayState extends State<HudRestoreRunOverlay> {
  Timer? _countdownTimer;
  int? _countdown;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (_countdown != null) {
      return;
    }
    setState(() {
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nextValue = (_countdown ?? 1) - 1;
      if (nextValue <= 0) {
        timer.cancel();
        widget.game.continueRestoredRun();
        return;
      }

      setState(() {
        _countdown = nextValue;
      });
    });
  }

  void _openMainMenu() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    unawaited(widget.game.saveNow());
    widget.onOpenStageSelect?.call();
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;
    final roundLabel = widget.snapshot.restoredPhase == GamePhase.wave
        ? '진행 중이던 웨이브'
        : '저장된 웨이브';
    if (countdown != null) {
      return Container(
        color: const Color(0x4402070D),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '곧 재개됩니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0xFF02070D),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$countdown',
                style: const TextStyle(
                  fontSize: 68,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8BE9FF),
                  shadows: [
                    Shadow(
                      color: Color(0xFF02070D),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xAA02070D),
      child: Center(
        child: GamePanel(
          width: 286,
          padding: const EdgeInsets.all(18),
          selected: true,
          accentColor: GamePalette.cyan,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore, color: GamePalette.cyan, size: 38),
              const SizedBox(height: 10),
              Text(
                '저장된 진행 발견',
                style: GameTextStyles.withColor(
                  GameTextStyles.title,
                  GamePalette.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x5533D8FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        roundLabel,
                        style: const TextStyle(
                          color: Color(0xFF8CC8D8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.snapshot.round}/${widget.snapshot.maxRound}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '이전 진행을 이어갈까요?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFC5DCE8)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: GameButton(
                      onPressed: widget.onOpenStageSelect == null
                          ? null
                          : _openMainMenu,
                      label: '메인 메뉴',
                      icon: const Icon(Icons.home_outlined, size: 16),
                      compact: true,
                      variant: GameButtonVariant.ghost,
                      accentColor: GamePalette.metal,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: GameButton(
                      onPressed: _startCountdown,
                      label: '재개',
                      icon: const Icon(Icons.play_arrow_rounded, size: 16),
                      compact: true,
                      variant: GameButtonVariant.primary,
                      accentColor: GamePalette.cyan,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
