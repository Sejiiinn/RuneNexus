part of 'main_menu_screen.dart';

const _coreTreeSpriteRoot = 'assets/images/core_passive_tree';

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
    required this.combatSkill,
    required this.onSelectCore,
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
  final CoreCombatSkill? combatSkill;
  final VoidCallback onSelectCore;

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
              child: _CorePassiveConnectionLayer(
                builder: (sprites) => _CorePassiveConnectionPainter(
                  sprites: sprites,
                  draftRanks: draftRanks,
                  draftLineRanks: draftLineRanks,
                  renderedRanks: renderedRanks,
                  allocationWaves: allocationWaves,
                  allocationElapsedMs: allocationElapsedMs,
                ),
              ),
            ),
          ),
          Positioned(
            left: 296,
            top: 296,
            width: 128,
            height: 128,
            child: _CorePassiveCenterNode(
              skill: combatSkill,
              onTap: onSelectCore,
            ),
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
  const _CorePassiveCenterNode({required this.skill, required this.onTap});

  final CoreCombatSkill? skill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final equippedSkill = skill;
    return Semantics(
      button: true,
      label: '코어 스킬 선택, ${equippedSkill?.label ?? '미장착'}',
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          key: const ValueKey('core-passive-center-select'),
          onTap: onTap,
          containedInkWell: true,
          customBorder: const CircleBorder(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(
                '$_coreTreeSpriteRoot/center_socket_v1.png',
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                excludeFromSemantics: true,
              ),
              if (equippedSkill != null)
                CoreAbilityIcon(equippedSkill, size: 54)
              else
                Image.asset(
                  corePassiveTreeCoreAsset,
                  width: 54,
                  height: 54,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  excludeFromSemantics: true,
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: ExactAssetImage(
                          '$_coreTreeSpriteRoot/skill_nameplate_v1.png',
                          scale: 2,
                        ),
                        fit: BoxFit.fill,
                        // 양끝 장식과 테두리 보존, 중앙 면만 문구 길이에 맞춰 확장.
                        centerSlice: Rect.fromLTRB(16, 4, 182, 23.5),
                      ),
                    ),
                    child: Text(
                      equippedSkill?.label ?? '스킬 선택',
                      key: const ValueKey('core-passive-center-label'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFFF4E6C8),
                        fontSize: 15,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
    final (size, aperture, frameName) = switch (definition.grade) {
      CorePassiveNodeGrade.normal => (48.0, 32.0, 'small'),
      CorePassiveNodeGrade.notable => (68.0, 46.0, 'medium'),
      CorePassiveNodeGrade.keystone => (96.0, 64.0, 'large'),
    };
    final muted = !accessible && !allocated;
    final activeOpacity = activating
        ? 0.6 + activationGlow * 0.4
        : allocated
        ? 1.0
        : planningIncrease
        ? 0.5
        : 0.0;
    return Material(
      color: Colors.transparent,
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
          child: SizedBox(
            width: size,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (selected)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1.32,
                        child: Image.asset(
                          '$_coreTreeSpriteRoot/selection_ring_v1.png',
                          key: ValueKey(
                            'core-passive-selection-${definition.id.name}',
                          ),
                          filterQuality: FilterQuality.high,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 160),
                    opacity: muted && !planned ? 0.42 : 1,
                    child: Image.asset(
                      '$_coreTreeSpriteRoot/node_frame_${frameName}_a_v1.png',
                      key: ValueKey('core-passive-frame-${definition.id.name}'),
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Positioned.fill(
                  child: AnimatedOpacity(
                    duration: activating
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    opacity: activeOpacity,
                    child: Image.asset(
                      '$_coreTreeSpriteRoot/node_frame_${frameName}_a_active_v1.png',
                      key: ValueKey(
                        'core-passive-active-frame-${definition.id.name}',
                      ),
                      filterQuality: FilterQuality.high,
                      excludeFromSemantics: true,
                    ),
                  ),
                ),
                Center(
                  child: Opacity(
                    opacity: muted && !planned ? 0.35 : 1,
                    child: CorePassiveNodeIcon(
                      definition.id,
                      // 프레임 중앙 구멍 안쪽 아이콘 여백.
                      size: aperture * 0.8,
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
