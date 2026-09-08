import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'gem_rule_note.dart';

import '../../data/definitions/game_gem_data.dart';
import '../../data/definitions/game_turret_data.dart';
import '../../domain/gem/gem_equip_rules.dart';
import '../../domain/gem/gem_type.dart';
import '../../domain/turret/turret_type.dart';
import '../../game/game_snapshot.dart';
import '../../game/rendering/turret_shape_renderer.dart';
import '../../game/rune_nexus_game.dart';
import '../game/game_ui.dart';
import 'reward_overlay.dart';

class HudGemRewardTargetOverlay extends StatefulWidget {
  const HudGemRewardTargetOverlay({
    required this.game,
    required this.snapshot,
    required this.onBoardViewportChanged,
    this.topInset = 0,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueChanged<Rect> onBoardViewportChanged;
  final double topInset;

  @override
  State<HudGemRewardTargetOverlay> createState() =>
      _HudGemRewardTargetOverlayState();
}

class _HudGemRewardTargetOverlayState extends State<HudGemRewardTargetOverlay> {
  final _boardKey = GlobalKey();
  Rect? _reportedViewport;

  void _reportBoardViewport() {
    final box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (!mounted || box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect == _reportedViewport) return;
    _reportedViewport = rect;
    widget.onBoardViewportChanged(rect);
  }

  @override
  Widget build(BuildContext context) {
    final gem = widget.snapshot.pendingRewardGem;
    if (gem == null) return const SizedBox.shrink();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reportBoardViewport());
    return Padding(
      padding: EdgeInsets.fromLTRB(8, widget.topInset, 8, 40),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth > constraints.maxHeight * 1.4;
          final heading = _TargetHeading(
            snapshot: widget.snapshot,
            gem: gem,
            compact: wide,
          );
          final board = SizedBox.expand(key: _boardKey);
          return Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: wide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                width: math.min(
                                  210,
                                  constraints.maxWidth * 0.36,
                                ),
                                child: SingleChildScrollView(child: heading),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: board),
                            ],
                          )
                        : Column(
                            children: [
                              heading,
                              const SizedBox(height: 6),
                              Expanded(child: board),
                            ],
                          ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: _RewardActionButton(
                          label: '젬 다시 선택',
                          icon: Icons.arrow_back_rounded,
                          height: 44,
                          onPressed: widget.game.clearRewardGemPreview,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RewardActionButton(
                          label: '보관',
                          icon: Icons.inventory_2_outlined,
                          accent: GamePalette.cyan,
                          height: 44,
                          onPressed: widget.game.storeRewardGem,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (widget.snapshot.rewardReplacementPoint != null)
                Positioned.fill(
                  child: _ReplacementLayer(
                    game: widget.game,
                    snapshot: widget.snapshot,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _TargetHeading extends StatelessWidget {
  const _TargetHeading({
    required this.snapshot,
    required this.gem,
    required this.compact,
  });

  final GameSnapshot snapshot;
  final GemType gem;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GameAssetSurface(
          frame: GameAssetFrame.panel,
          padding: EdgeInsets.fromLTRB(
            12,
            compact ? 8 : 12,
            12,
            compact ? 8 : 10,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  GemIcon(gem, size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gameGems[gem]!.name,
                          style: GameTextStyles.sectionTitle.copyWith(
                            fontSize: compact ? 14 : 16,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          hudRewardGemEffectText(gem),
                          style: GameTextStyles.body.copyWith(
                            height: compact ? 1.2 : 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              HudGemRuleNote(type: gem),
              Padding(
                padding: EdgeInsets.symmetric(vertical: compact ? 4 : 10),
                child: const Divider(height: 1, color: Color(0x334F6877)),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  final types = snapshot.availableTurretTypes;
                  // 동일한 열 너비·그림 영역 유지. 큰 글자는 가로 스크롤로 수용.
                  final itemWidth = math.max(
                    MediaQuery.textScalerOf(context).scale(46),
                    constraints.maxWidth / math.max(1, types.length),
                  );
                  return SingleChildScrollView(
                    key: const ValueKey('gem-reward-compatible-turrets'),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final type in types)
                          SizedBox(
                            width: itemWidth,
                            child: _CompatibleTurret(type: type, gem: gem),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '장착할 타워를 선택하세요',
          style: GameTextStyles.body.copyWith(
            color: GamePalette.gold,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _CompatibleTurret extends StatelessWidget {
  const _CompatibleTurret({required this.type, required this.gem});

  final TurretType type;
  final GemType gem;

  @override
  Widget build(BuildContext context) {
    final turret = gameTurrets[type]!;
    final reason = gemEquipBlockReason(gem, turret);
    final compatible = reason == null;
    return Tooltip(
      message: reason ?? '${turret.name} 장착 가능',
      child: Semantics(
        label: '${turret.name}, ${reason ?? '장착 가능'}',
        child: Column(
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Opacity(
                      opacity: compatible ? 1 : 0.42,
                      child: CustomPaint(
                        painter: _RewardTurretPainter(type: type),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        color: Color(0xFF09131B),
                        shape: BoxShape.circle,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          compatible ? Icons.check_circle : Icons.block,
                          size: 12,
                          color: compatible
                              ? GamePalette.green
                              : GamePalette.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 5),
            Text(
              turret.name,
              textAlign: TextAlign.center,
              style: GameTextStyles.caption.copyWith(
                height: 1.4,
                color: compatible
                    ? GamePalette.textPrimary
                    : GamePalette.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReplacementLayer extends StatelessWidget {
  const _ReplacementLayer({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(260.0, constraints.maxWidth);
        final height = math.min(252.0, constraints.maxHeight);
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: game.cancelRewardGemReplacement,
                // 전장 어둡기는 게임 렌더에서 처리하여 선택한 포탑은 밝게 유지.
                child: const SizedBox.expand(),
              ),
            ),
            Positioned(
              left: (constraints.maxWidth - width) / 2,
              top: (constraints.maxHeight - height) / 2,
              width: width,
              height: height,
              child: GameAssetSurface(
                frame: GameAssetFrame.panel,
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  key: const ValueKey('gem-reward-replacement-scroll'),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          GemIcon(snapshot.pendingRewardGem!, size: 26),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${snapshot.selectedTurretName} Lv.${snapshot.selectedTurretLevel} · 홈 ${snapshot.selectedTurretGems.whereType<GemType>().length}/${snapshot.selectedTurretSlotLimit}',
                              style: GameTextStyles.sectionTitle,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('교체할 젬 선택', style: GameTextStyles.body),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          for (
                            var slot = 0;
                            slot < snapshot.selectedTurretGems.length;
                            slot++
                          )
                            if (snapshot.selectedTurretGems[slot] != null)
                              SizedBox(
                                width: 104,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 54,
                                      height: 54,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          Image.asset(gemSocketEmptyAsset),
                                          GemIcon(
                                            snapshot.selectedTurretGems[slot]!,
                                            size: 30,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      gameGems[snapshot
                                              .selectedTurretGems[slot]]!
                                          .name,
                                      textAlign: TextAlign.center,
                                      style: GameTextStyles.caption,
                                    ),
                                    const SizedBox(height: 4),
                                    _RewardActionButton(
                                      label: '이 젬과 교체',
                                      accent: GamePalette.gold,
                                      height: 40,
                                      onPressed: () =>
                                          game.replaceRewardGem(slot),
                                    ),
                                  ],
                                ),
                              ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text('교체한 젬은 보관됩니다', style: GameTextStyles.caption),
                      const SizedBox(height: 8),
                      _RewardActionButton(
                        label: '타워 다시 선택',
                        icon: Icons.arrow_back_rounded,
                        height: 40,
                        onPressed: game.cancelRewardGemReplacement,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RewardTurretPainter extends CustomPainter {
  const _RewardTurretPainter({required this.type});
  final TurretType type;

  @override
  void paint(Canvas canvas, Size size) {
    // 포신이 본체 영역 밖으로 뻗는 형태까지 포함한 공통 안전 여백.
    final extent = size.shortestSide * 0.72;
    canvas.save();
    canvas.translate((size.width - extent) / 2, (size.height - extent) / 2);
    drawTurretShape(
      canvas,
      size: Size.square(extent),
      strokeWidth: 1.2,
      type: type,
      color: gameTurrets[type]!.color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RewardTurretPainter oldDelegate) =>
      oldDelegate.type != type;
}

// 장착 화면의 금속 프레임과 입력 피드백을 함께 관리하는 전용 액션.
class _RewardActionButton extends StatelessWidget {
  const _RewardActionButton({
    required this.label,
    required this.onPressed,
    required this.height,
    this.icon,
    this.accent = GamePalette.metal,
  });

  final String label;
  final VoidCallback onPressed;
  final double height;
  final IconData? icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(const Color(0xFF12212C), accent, 0.15)!,
              const Color(0xFF071119),
            ],
          ),
          image: DecorationImage(
            image: gameUiAssetImageProvider(gameButtonFrameAsset),
            centerSlice: gameButtonFrameCenterSlice,
            fit: BoxFit.fill,
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          splashColor: accent.withValues(alpha: 0.22),
          highlightColor: accent.withValues(alpha: 0.12),
          hoverColor: accent.withValues(alpha: 0.08),
          child: SizedBox(
            width: double.infinity,
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: accent),
                    const SizedBox(width: 7),
                  ],
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        style: GameTextStyles.button.copyWith(
                          color: Color.lerp(
                            GamePalette.textPrimary,
                            accent,
                            0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
