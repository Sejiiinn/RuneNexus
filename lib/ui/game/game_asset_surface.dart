import 'package:flutter/material.dart';

import 'game_image_assets.dart';

const Rect gamePanelFrameCenterSlice = Rect.fromLTRB(14, 14, 362, 146);
const Rect gameCardFrameCenterSlice = Rect.fromLTRB(11, 11, 160, 105);
const Rect gameRowFrameCenterSlice = Rect.fromLTRB(11, 10, 346, 34);
const Rect gameLockedRowFrameCenterSlice = Rect.fromLTRB(11, 11, 346, 48);
const Rect gameButtonFrameCenterSlice = Rect.fromLTRB(8, 8, 143, 26);
const Rect gameChipFrameCenterSlice = Rect.fromLTRB(8, 7, 52, 20);

enum GameAssetFrame { panel, card, row, lockedRow, button, chip }

extension GameAssetFrameSpec on GameAssetFrame {
  String get asset => switch (this) {
    GameAssetFrame.panel => gamePanelFrameAsset,
    GameAssetFrame.card => gameCardFrameAsset,
    GameAssetFrame.row => gameRowFrameAsset,
    GameAssetFrame.lockedRow => gameLockedRowFrameAsset,
    GameAssetFrame.button => gameButtonFrameAsset,
    GameAssetFrame.chip => gameChipFrameAsset,
  };

  Rect get centerSlice => switch (this) {
    GameAssetFrame.panel => gamePanelFrameCenterSlice,
    GameAssetFrame.card => gameCardFrameCenterSlice,
    GameAssetFrame.row => gameRowFrameCenterSlice,
    GameAssetFrame.lockedRow => gameLockedRowFrameCenterSlice,
    GameAssetFrame.button => gameButtonFrameCenterSlice,
    GameAssetFrame.chip => gameChipFrameCenterSlice,
  };
}

class GameAssetSurface extends StatelessWidget {
  const GameAssetSurface({
    required this.frame,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.opacity = 1,
    this.constraints,
    this.color,
    this.imageKey,
    super.key,
  });

  final GameAssetFrame frame;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final BoxConstraints? constraints;
  final Color? color;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    final content = SizedBox(
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity: opacity,
              child: Image(
                image: gameUiAssetImageProvider(frame.asset),
                key: imageKey,
                fit: BoxFit.fill,
                centerSlice: frame.centerSlice,
                color: color,
                colorBlendMode: color == null ? null : BlendMode.modulate,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Padding(padding: padding, child: child),
        ],
      ),
    );
    final resolvedConstraints = constraints;
    if (resolvedConstraints == null) {
      return content;
    }
    return ConstrainedBox(constraints: resolvedConstraints, child: content);
  }
}
