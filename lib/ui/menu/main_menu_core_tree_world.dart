part of 'main_menu_screen.dart';

class _CorePassiveTreeWorld extends StatelessWidget {
  const _CorePassiveTreeWorld({
    required this.actualRanks,
    required this.draftRanks,
    required this.draftLineRanks,
    required this.renderedRanks,
    required this.selectedNodeId,
    required this.allocationWaves,
    required this.allocationElapsedMs,
    required this.viewportSize,
    required this.fitScale,
    required this.onSelectNode,
  });

  final Map<CorePassiveNodeId, int> actualRanks;
  final Map<CorePassiveNodeId, int> draftRanks;
  final Map<CorePassiveNodeId, double> draftLineRanks;
  final Map<CorePassiveNodeId, int> renderedRanks;
  final CorePassiveNodeId? selectedNodeId;
  final List<_CorePassiveAllocationWave> allocationWaves;
  final double allocationElapsedMs;
  final Size viewportSize;
  final double fitScale;
  final ValueChanged<CorePassiveNodeId> onSelectNode;

  @override
  Widget build(BuildContext context) {
    final accessible = accessibleCorePassiveNodeIds(draftRanks);
    final backgroundSize = Size(
      viewportSize.width / fitScale,
      viewportSize.height / fitScale,
    );
    return SizedBox(
      width: _corePassiveTreeWorldSize,
      height: _corePassiveTreeWorldSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: (_corePassiveTreeWorldSize - backgroundSize.width) / 2,
            top: (_corePassiveTreeWorldSize - backgroundSize.height) / 2,
            width: backgroundSize.width,
            height: backgroundSize.height,
            child: IgnorePointer(
              child: Image.asset(
                corePassiveTreeBackgroundAsset,
                key: const ValueKey('core-passive-tree-background'),
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('core-passive-connection-layer'),
                painter: _CorePassiveConnectionPainter(
                  draftRanks: draftRanks,
                  draftLineRanks: draftLineRanks,
                  renderedRanks: renderedRanks,
                  allocationWaves: allocationWaves,
                  allocationElapsedMs: allocationElapsedMs,
                ),
              ),
            ),
          ),
          const Positioned(
            left: 301,
            top: 301,
            width: 118,
            height: 118,
            child: _CorePassiveCenterNode(),
          ),
          for (final entry in corePassiveNodeDefinitions.entries)
            _positionedNode(
              context,
              entry.value,
              accessible: accessible.contains(entry.key),
            ),
        ],
      ),
    );
  }

  Widget _positionedNode(
    BuildContext context,
    CorePassiveNodeDefinition definition, {
    required bool accessible,
  }) {
    final point = _corePassiveNodePosition(definition.id);
    const hitSize = 112.0;
    return Positioned(
      left: point.dx - hitSize / 2,
      top: point.dy - hitSize / 2,
      width: hitSize,
      height: hitSize,
      child: Center(
        child: _CorePassiveNodeButton(
          definition: definition,
          actualRank: actualRanks[definition.id] ?? 0,
          draftRank: draftRanks[definition.id] ?? 0,
          renderedRank: renderedRanks[definition.id] ?? 0,
          accessible: accessible,
          selected: selectedNodeId == definition.id,
          activationProgress: _nodeActivationProgress(definition.id),
          onTap: () => onSelectNode(definition.id),
        ),
      ),
    );
  }

  double? _nodeActivationProgress(CorePassiveNodeId id) {
    for (var wave = 0; wave < allocationWaves.length; wave++) {
      if (!allocationWaves[wave].steps.any((step) => step.nodeId == id)) {
        continue;
      }
      final glowStart =
          wave * _corePassiveWaveIntervalMs + _corePassiveNodeGlowDelayMs;
      final progress =
          (allocationElapsedMs - glowStart) / _corePassiveNodeGlowMs;
      return progress >= 0 && progress < 1 ? progress : null;
    }
    return null;
  }
}

class _CorePassiveCenterNode extends StatelessWidget {
  const _CorePassiveCenterNode();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Color(0xAA20CFEF),
                blurRadius: 32,
                spreadRadius: 6,
              ),
            ],
          ),
        ),
        Image.asset(
          corePassiveTreeCoreAsset,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
          excludeFromSemantics: true,
        ),
      ],
    );
  }
}

class _CorePassiveNodeButton extends StatelessWidget {
  const _CorePassiveNodeButton({
    required this.definition,
    required this.actualRank,
    required this.draftRank,
    required this.renderedRank,
    required this.accessible,
    required this.selected,
    required this.activationProgress,
    required this.onTap,
  });

  final CorePassiveNodeDefinition definition;
  final int actualRank;
  final int draftRank;
  final int renderedRank;
  final bool accessible;
  final bool selected;
  final double? activationProgress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allocated = renderedRank > 0;
    final planned = draftRank != actualRank;
    final planningIncrease = draftRank > actualRank;
    final activating = activationProgress != null;
    final activationGlow = activationProgress == null
        ? 0.0
        : activationProgress! < 0.45
        ? Curves.easeOutCubic.transform(activationProgress! / 0.45)
        : 1 - Curves.easeInCubic.transform((activationProgress! - 0.45) / 0.55);
    final accent = _corePassiveBranchColor(definition.branch);
    final size = switch (definition.grade) {
      CorePassiveNodeGrade.normal => 48.0,
      CorePassiveNodeGrade.notable => 58.0,
      CorePassiveNodeGrade.keystone => 70.0,
    };
    final muted = !accessible && !allocated;
    final framed = definition.grade != CorePassiveNodeGrade.normal;
    final frameColor = selected
        ? const Color(0xFFFFFFFF)
        : muted
        ? const Color(0xFF75838C)
        : accent;
    final nodeColor = allocated
        ? accent.withValues(alpha: 0.38)
        : planningIncrease
        ? accent.withValues(alpha: 0.2)
        : const Color(0xF012202C);
    return Material(
      color: nodeColor,
      shape: const CircleBorder(),
      animationDuration: const Duration(milliseconds: 160),
      child: Semantics(
        button: true,
        selected: selected,
        label: RuneNexusLocalizations.of(
          context,
        ).corePassiveNodeName(definition.id),
        child: InkResponse(
          key: ValueKey('core-passive-node-${definition.id.name}'),
          radius: 54,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          splashColor: accent.withAlpha(55),
          highlightColor: accent.withAlpha(32),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(
                color: framed
                    ? Colors.transparent
                    : selected
                    ? const Color(0xFFE8FBFF)
                    : muted
                    ? const Color(0xFF52616A)
                    : accent.withValues(alpha: accessible ? 0.9 : 0.45),
                width: selected
                    ? 3
                    : allocated || planned
                    ? 2.2
                    : 1.5,
              ),
              boxShadow: [
                if (allocated || planned || selected || activating)
                  BoxShadow(
                    color: accent.withValues(
                      alpha: activating
                          ? 0.18 + activationGlow * 0.6
                          : selected
                          ? 0.62
                          : planned
                          ? 0.5
                          : 0.38,
                    ),
                    blurRadius: activating
                        ? 8 + activationGlow * 20
                        : selected
                        ? 16
                        : 10,
                    spreadRadius: activating
                        ? activationGlow * 2
                        : selected
                        ? 2
                        : 0,
                  ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (framed)
                  Positioned.fill(
                    child: Transform.scale(
                      scale: definition.grade == CorePassiveNodeGrade.keystone
                          ? 1.22
                          : 1.16,
                      child: ColorFiltered(
                        colorFilter: ColorFilter.mode(
                          frameColor,
                          BlendMode.modulate,
                        ),
                        child: Image.asset(
                          corePassiveTreeFrameAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Opacity(
                    opacity: muted && !planned ? 0.35 : 1,
                    child: CorePassiveNodeIcon(
                      definition.id,
                      size: size * 0.46,
                      color: muted ? const Color(0xFF7B8991) : accent,
                    ),
                  ),
                ),
                if (muted && !planned)
                  const Center(
                    child: Icon(
                      Icons.lock_outline,
                      color: Color(0xFFC2CCD1),
                      size: 18,
                    ),
                  ),
                Positioned(
                  right: -7,
                  bottom: -5,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 25,
                      minHeight: 19,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF061019),
                      border: Border.all(color: accent.withValues(alpha: 0.75)),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Text(
                      planned
                          ? '$actualRank→$draftRank/${definition.maxRank}'
                          : '$renderedRank/${definition.maxRank}',
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                if (activating)
                  Positioned.fill(
                    key: ValueKey(
                      'core-passive-activation-${definition.id.name}',
                    ),
                    child: const IgnorePointer(child: SizedBox.expand()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
