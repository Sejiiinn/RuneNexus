import 'package:flutter/material.dart';

import '../ui/game/game_image_assets.dart';
import '../ui/game/game_asset_surface.dart';
import '../ui/game/game_palette.dart';

/// 업데이트 확인부터 게임 준비까지 이어지는 공통 시작 화면.
class AppStartupScreen extends StatelessWidget {
  const AppStartupScreen({
    required this.status,
    this.progress,
    this.busy = true,
    this.details,
    this.boundedDetails = false,
    super.key,
  });

  final String status;
  final double? progress;
  final bool busy;
  final Widget? details;

  /// 내부 스크롤을 가진 상세 영역에 남은 화면 높이 전달.
  final bool boundedDetails;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: GamePalette.voidBlack,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            mainMenuBackgroundAsset,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            excludeFromSemantics: true,
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0x2402070D),
                  Color(0x0002070D),
                  Color(0x9202070D),
                  Color(0xED02070D),
                ],
                stops: [0, 0.36, 0.72, 1],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = details != null;
                final topSpace = boundedDetails
                    ? 12.0
                    : (constraints.maxHeight * 0.09).clamp(24.0, 72.0);
                final coreSize = boundedDetails
                    ? (constraints.maxHeight * 0.10).clamp(48.0, 100.0)
                    : (constraints.maxHeight * (compact ? 0.20 : 0.30)).clamp(
                        100.0,
                        compact ? 160.0 : 230.0,
                      );
                final textScale =
                    MediaQuery.textScalerOf(context).scale(13) / 13;
                // 짧은 가로 화면·글자 확대 시 고정 안내와 버튼의 최소 공간 확보.
                final contentHeight = constraints.maxHeight.clamp(
                  520.0 * textScale,
                  double.infinity,
                );
                final content = Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  // 업데이트 상세는 남은 높이 안에서 노트만 스크롤.
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(
                          top: topSpace,
                          bottom: boundedDetails ? 12 : 24,
                        ),
                        child: Column(
                          children: [
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: boundedDetails ? 240 : 310,
                              ),
                              child: AspectRatio(
                                aspectRatio: 355 / 80,
                                child: Image.asset(
                                  gameLogoAsset,
                                  fit: BoxFit.contain,
                                  semanticLabel: 'Rune Nexus',
                                ),
                              ),
                            ),
                            const SizedBox(height: 18),
                            Container(
                              width: 96,
                              height: 1,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0x00E7C66A),
                                    Color(0x99E7C66A),
                                    Color(0x00E7C66A),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: boundedDetails ? 8 : 24,
                        ),
                        child: Image.asset(
                          corePassiveTreeCoreAsset,
                          width: coreSize,
                          height: coreSize,
                          excludeFromSemantics: true,
                        ),
                      ),
                      Flexible(
                        flex: boundedDetails ? 1 : 0,
                        fit: boundedDetails ? FlexFit.tight : FlexFit.loose,
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: boundedDetails
                                ? 16
                                : compact
                                ? 28
                                : 54,
                          ),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  status,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: GamePalette.textPrimary,
                                    fontSize: 14,
                                    height: 1.6,
                                    fontWeight: FontWeight.w600,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black,
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                ),
                                if (busy) ...[
                                  const SizedBox(height: 18),
                                  AppStartupProgressBar(
                                    value: progress,
                                    label: status,
                                  ),
                                ],
                                if (details != null) ...[
                                  const SizedBox(height: 20),
                                  Flexible(
                                    flex: boundedDetails ? 1 : 0,
                                    fit: boundedDetails
                                        ? FlexFit.tight
                                        : FlexFit.loose,
                                    child: DefaultTextStyle.merge(
                                      style: const TextStyle(
                                        color: GamePalette.textSecondary,
                                        fontSize: 13,
                                        height: 1.6,
                                      ),
                                      child: details!,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
                return SingleChildScrollView(
                  child: boundedDetails
                      ? SizedBox(height: contentHeight, child: content)
                      : ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: content,
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 공용 금속 프레임을 쓰는 시작 화면 액션. 긴 문구는 높이를 늘려 수용.
class AppStartupButton extends StatelessWidget {
  const AppStartupButton({
    required this.label,
    required this.onPressed,
    this.primary = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: primary
            ? GamePalette.cyanBright
            : GamePalette.textSecondary,
        disabledForegroundColor: GamePalette.textDisabled,
        overlayColor: GamePalette.cyan.withValues(alpha: 0.14),
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: primary && enabled
                        ? const [
                            Color(0xCC245567),
                            Color(0xE6102530),
                            Color(0xCC183F4E),
                          ]
                        : const [Color(0xCC111C25), Color(0xEE050B11)],
                  ),
                ),
              ),
            ),
          ),
          GameAssetSurface(
            frame: GameAssetFrame.button,
            opacity: enabled ? 1 : 0.45,
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 17),
            child: Center(child: Text(label, textAlign: TextAlign.center)),
          ),
        ],
      ),
    );
  }
}

/// 진행량이 없을 때는 광류, 측정 가능한 단계에서는 실제 비율 표시.
class AppStartupProgressBar extends StatefulWidget {
  const AppStartupProgressBar({required this.label, this.value, super.key});

  final String label;
  final double? value;

  @override
  State<AppStartupProgressBar> createState() => _AppStartupProgressBarState();
}

class _AppStartupProgressBarState extends State<AppStartupProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  void _syncAnimation() {
    if (widget.value == null && !MediaQuery.disableAnimationsOf(context)) {
      if (!_flow.isAnimating) _flow.repeat();
    } else {
      _flow.stop();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(covariant AppStartupProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  @override
  void dispose() {
    _flow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value?.clamp(0.0, 1.0);
    final reducedMotion = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      label: widget.label,
      value: value == null ? '진행 중' : '${(value * 100).round()}%',
      child: GameAssetSurface(
        frame: GameAssetFrame.button,
        padding: const EdgeInsets.all(8),
        child: SizedBox(
          height: 8,
          child: DecoratedBox(
            decoration: const BoxDecoration(color: Color(0xFF061219)),
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) => AnimatedBuilder(
                  animation: _flow,
                  builder: (context, child) {
                    final width = constraints.maxWidth;
                    return Stack(
                      children: [
                        Positioned(
                          left: value != null || reducedMotion
                              ? 0
                              : width * (1.38 * _flow.value - 0.38),
                          width: width * (value ?? (reducedMotion ? 1 : 0.38)),
                          top: 0,
                          bottom: 0,
                          child: child!,
                        ),
                      ],
                    );
                  },
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: value == null && reducedMotion
                            ? const [Color(0xFF183A46), Color(0xFF0A202B)]
                            : const [
                                Color(0xFFBFF4FF),
                                Color(0xFF50CADD),
                                Color(0xFF146781),
                              ],
                      ),
                      boxShadow: const [
                        BoxShadow(color: Color(0x9950CADD), blurRadius: 5),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
