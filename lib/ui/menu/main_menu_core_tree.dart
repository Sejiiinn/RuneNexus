part of 'main_menu_screen.dart';

const double _corePassiveTreeWorldSize = 720;
const Offset _corePassiveTreeCenter = Offset(360, 360);
const String _corePassiveTreeBackgroundAsset =
    'assets/images/core_passive_tree/tree_circuit_background.png';
const String _corePassiveTreeCoreAsset =
    'assets/images/core_passive_tree/nexus_core.png';
const String _corePassiveTreeFrameAsset =
    'assets/images/core_passive_tree/notable_hex_frame.png';

const Map<CorePassiveNodeId, ({double radius, double angle})>
_corePassiveNodePolarPositions = {
  CorePassiveNodeId.attackHaste: (radius: 110, angle: 300),
  CorePassiveNodeId.attackOutput: (radius: 110, angle: 0),
  CorePassiveNodeId.efficiencySaving: (radius: 110, angle: 60),
  CorePassiveNodeId.efficiencyDiversity: (radius: 110, angle: 120),
  CorePassiveNodeId.controlSelfRepair: (radius: 110, angle: 180),
  CorePassiveNodeId.controlThreatSense: (radius: 110, angle: 240),
  CorePassiveNodeId.attackPrecompute: (radius: 180, angle: 310),
  CorePassiveNodeId.attackFocus: (radius: 180, angle: 350),
  CorePassiveNodeId.attackGuardianBeam: (radius: 245, angle: 300),
  CorePassiveNodeId.attackRiftMark: (radius: 245, angle: 0),
  CorePassiveNodeId.attackOverclock: (radius: 300, angle: 330),
  CorePassiveNodeId.efficiencyFirstDeploy: (radius: 180, angle: 70),
  CorePassiveNodeId.efficiencyFirstLink: (radius: 180, angle: 110),
  CorePassiveNodeId.efficiencyGemSpectrum: (radius: 245, angle: 60),
  CorePassiveNodeId.efficiencySupplyRecovery: (radius: 245, angle: 120),
  CorePassiveNodeId.efficiencyCombinedFront: (radius: 300, angle: 90),
  CorePassiveNodeId.controlRetarget: (radius: 180, angle: 190),
  CorePassiveNodeId.controlRearLock: (radius: 180, angle: 230),
  CorePassiveNodeId.controlEmergencyCharge: (radius: 245, angle: 180),
  CorePassiveNodeId.controlBufferShell: (radius: 245, angle: 240),
  CorePassiveNodeId.controlFinalLine: (radius: 300, angle: 210),
  CorePassiveNodeId.hybridEmergencyCompute: (radius: 170, angle: 270),
  CorePassiveNodeId.hybridCounterFire: (radius: 245, angle: 270),
  CorePassiveNodeId.hybridResonanceLoop: (radius: 170, angle: 30),
  CorePassiveNodeId.hybridMixedFire: (radius: 245, angle: 30),
  CorePassiveNodeId.hybridSupplyBarrier: (radius: 170, angle: 150),
  CorePassiveNodeId.hybridRecoveryBudget: (radius: 245, angle: 150),
};

class _CorePassiveTreeMenu extends StatefulWidget {
  const _CorePassiveTreeMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_CorePassiveTreeMenu> createState() => _CorePassiveTreeMenuState();
}

class _CorePassiveTreeMenuState extends State<_CorePassiveTreeMenu> {
  final TransformationController _transformationController =
      TransformationController();
  CorePassiveNodeId? _selectedNodeId;
  int _targetRank = 0;
  Size? _viewportSize;
  double _minimumScale = 1;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CorePassiveTreeMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedNodeId;
    if (selected == null) {
      return;
    }
    final oldRank = oldWidget.snapshot.corePassiveNodeRanks[selected] ?? 0;
    final newRank = widget.snapshot.corePassiveNodeRanks[selected] ?? 0;
    if (oldRank != newRank) {
      _targetRank = newRank;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CorePassivePointSummary(
          snapshot: widget.snapshot,
          l10n: l10n,
          onReset: widget.snapshot.spentCorePoints > 0
              ? () => _confirmReset(context, l10n)
              : null,
        ),
        const SizedBox(height: 8),
        Container(
          key: const ValueKey('core-passive-tree-canvas'),
          height: 430,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: const Color(0xFF04111B),
            border: Border.all(color: const Color(0x775D7182)),
            borderRadius: BorderRadius.circular(9),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewport = Size(
                constraints.maxWidth,
                constraints.maxHeight,
              );
              final fitScale =
                  math.min(
                    viewport.width / _corePassiveTreeWorldSize,
                    viewport.height / _corePassiveTreeWorldSize,
                  ) *
                  0.92;
              _synchronizeViewport(viewport, fitScale);
              return InteractiveViewer(
                key: const ValueKey('core-passive-tree-viewer'),
                transformationController: _transformationController,
                constrained: false,
                panEnabled: true,
                scaleEnabled: true,
                minScale: fitScale,
                maxScale: fitScale * 2.2,
                boundaryMargin: const EdgeInsets.all(84),
                onInteractionEnd: (_) => _centerAtMinimumScale(),
                child: _CorePassiveTreeWorld(
                  snapshot: widget.snapshot,
                  selectedNodeId: _selectedNodeId,
                  onSelectNode: _selectNode,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        _CorePassiveNodeDetails(
          snapshot: widget.snapshot,
          selectedNodeId: _selectedNodeId,
          targetRank: _targetRank,
          onDecrease: _canDecrease ? () => setState(() => _targetRank--) : null,
          onIncrease: _canIncrease ? () => setState(() => _targetRank++) : null,
          onAssign: _canAssign ? _assignTargetRank : null,
        ),
      ],
    );
  }

  bool get _canDecrease {
    final id = _selectedNodeId;
    if (id == null || _targetRank <= 0) {
      return false;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(
      widget.snapshot.corePassiveNodeRanks,
    );
    candidate[id] = _targetRank - 1;
    if (candidate[id] == 0) {
      candidate.remove(id);
    }
    return isValidCorePassiveAllocation(candidate);
  }

  bool get _canIncrease {
    final id = _selectedNodeId;
    if (id == null) {
      return false;
    }
    final definition = corePassiveNodeById(id);
    if (_targetRank >= definition.maxRank) {
      return false;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(
      widget.snapshot.corePassiveNodeRanks,
    )..[id] = _targetRank + 1;
    return corePassiveSpentPoints(candidate) <=
            widget.snapshot.totalCorePoints &&
        isValidCorePassiveAllocation(candidate);
  }

  bool get _canAssign {
    final id = _selectedNodeId;
    if (id == null) {
      return false;
    }
    final currentRank = widget.snapshot.corePassiveNodeRanks[id] ?? 0;
    if (_targetRank == currentRank) {
      return false;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(
      widget.snapshot.corePassiveNodeRanks,
    );
    if (_targetRank == 0) {
      candidate.remove(id);
    } else {
      candidate[id] = _targetRank;
    }
    return corePassiveSpentPoints(candidate) <=
            widget.snapshot.totalCorePoints &&
        isValidCorePassiveAllocation(candidate);
  }

  void _selectNode(CorePassiveNodeId id) {
    setState(() {
      _selectedNodeId = id;
      _targetRank = widget.snapshot.corePassiveNodeRanks[id] ?? 0;
    });
  }

  void _assignTargetRank() {
    final id = _selectedNodeId;
    if (id == null) {
      return;
    }
    widget.game.setCorePassiveNodeRank(id, _targetRank);
  }

  Future<void> _confirmReset(
    BuildContext context,
    RuneNexusLocalizations l10n,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.corePassiveResetTitle),
        content: Text(l10n.corePassiveResetMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              MaterialLocalizations.of(dialogContext).cancelButtonLabel,
            ),
          ),
          FilledButton(
            key: const ValueKey('core-passive-reset-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.corePassiveResetAll),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (widget.game.resetCorePassiveTree()) {
      setState(() => _targetRank = 0);
    }
  }

  void _synchronizeViewport(Size viewport, double minimumScale) {
    if (_viewportSize == viewport &&
        (_minimumScale - minimumScale).abs() < 0.0001) {
      return;
    }
    _viewportSize = viewport;
    _minimumScale = minimumScale;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _transformationController.value = _centeredTransform(
        viewport,
        minimumScale,
      );
    });
  }

  void _centerAtMinimumScale() {
    final viewport = _viewportSize;
    if (viewport == null) {
      return;
    }
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if ((currentScale - _minimumScale).abs() > 0.01) {
      return;
    }
    _transformationController.value = _centeredTransform(
      viewport,
      _minimumScale,
    );
  }

  Matrix4 _centeredTransform(Size viewport, double scale) {
    final dx = (viewport.width - _corePassiveTreeWorldSize * scale) / 2;
    final dy = (viewport.height - _corePassiveTreeWorldSize * scale) / 2;
    return Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(scale, scale, scale, 1);
  }
}

class _CorePassivePointSummary extends StatelessWidget {
  const _CorePassivePointSummary({
    required this.snapshot,
    required this.l10n,
    required this.onReset,
  });

  final GameSnapshot snapshot;
  final RuneNexusLocalizations l10n;
  final VoidCallback? onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('core-passive-point-summary'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xE60A1724),
        border: Border.all(color: const Color(0x665D7182)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.hub_outlined, color: Color(0xFF8EE6FF), size: 19),
          const SizedBox(width: 7),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  '${l10n.corePoints} ${snapshot.totalCorePoints}',
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  '${l10n.corePointsSpent} ${snapshot.spentCorePoints}',
                  style: const TextStyle(
                    color: Color(0xFFFFC66A),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l10n.corePointsAvailable} ${snapshot.availableCorePoints}',
                  style: const TextStyle(
                    color: Color(0xFF72E0A2),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const ValueKey('core-passive-reset-all'),
            onPressed: onReset,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              minimumSize: const Size(0, 34),
            ),
            child: Text(
              l10n.corePassiveResetAll,
              maxLines: 1,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _CorePassiveTreeWorld extends StatelessWidget {
  const _CorePassiveTreeWorld({
    required this.snapshot,
    required this.selectedNodeId,
    required this.onSelectNode,
  });

  final GameSnapshot snapshot;
  final CorePassiveNodeId? selectedNodeId;
  final ValueChanged<CorePassiveNodeId> onSelectNode;

  @override
  Widget build(BuildContext context) {
    final accessible = accessibleCorePassiveNodeIds(
      snapshot.corePassiveNodeRanks,
    );
    return SizedBox(
      width: _corePassiveTreeWorldSize,
      height: _corePassiveTreeWorldSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: Image.asset(
                _corePassiveTreeBackgroundAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                excludeFromSemantics: true,
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _CorePassiveConnectionPainter(
                  ranks: snapshot.corePassiveNodeRanks,
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
          rank: snapshot.corePassiveNodeRanks[definition.id] ?? 0,
          accessible: accessible,
          selected: selectedNodeId == definition.id,
          onTap: () => onSelectNode(definition.id),
        ),
      ),
    );
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
          _corePassiveTreeCoreAsset,
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
    required this.rank,
    required this.accessible,
    required this.selected,
    required this.onTap,
  });

  final CorePassiveNodeDefinition definition;
  final int rank;
  final bool accessible;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final allocated = rank > 0;
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
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: allocated
                  ? accent.withValues(alpha: 0.38)
                  : const Color(0xF012202C),
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
                    : allocated
                    ? 2.2
                    : 1.5,
              ),
              boxShadow: [
                if (allocated || selected)
                  BoxShadow(
                    color: accent.withValues(alpha: selected ? 0.62 : 0.38),
                    blurRadius: selected ? 16 : 10,
                    spreadRadius: selected ? 2 : 0,
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
                          _corePassiveTreeFrameAsset,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.medium,
                          excludeFromSemantics: true,
                        ),
                      ),
                    ),
                  ),
                Center(
                  child: Opacity(
                    opacity: muted ? 0.35 : 1,
                    child: CorePassiveNodeIcon(
                      definition.id,
                      size: size * 0.46,
                      color: muted ? const Color(0xFF7B8991) : accent,
                    ),
                  ),
                ),
                if (muted)
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
                      '$rank/${definition.maxRank}',
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CorePassiveConnectionPainter extends CustomPainter {
  const _CorePassiveConnectionPainter({required this.ranks});

  final Map<CorePassiveNodeId, int> ranks;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = const Color(0x88455C6B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final start in corePassiveStartingNodeIds) {
      _paintConnection(
        canvas,
        _corePassiveTreeCenter,
        _corePassiveNodePosition(start),
        basePaint,
        _corePassiveBranchColor(corePassiveNodeById(start).branch),
        1,
      );
    }
    for (final definition in corePassiveNodeDefinitions.values) {
      for (final neighbor in definition.neighbors) {
        if (definition.id.index >= neighbor.index) {
          continue;
        }
        final source = _closerToCenter(definition.id, neighbor);
        final target = source == definition.id ? neighbor : definition.id;
        final progress = ((ranks[source] ?? 0) / 3).clamp(0.0, 1.0);
        final targetDefinition = corePassiveNodeById(target);
        final accent =
            definition.branch == CorePassiveBranch.hybrid ||
                targetDefinition.branch == CorePassiveBranch.hybrid
            ? _corePassiveBranchColor(CorePassiveBranch.hybrid)
            : _corePassiveBranchColor(definition.branch);
        _paintConnection(
          canvas,
          _corePassiveNodePosition(source),
          _corePassiveNodePosition(target),
          basePaint,
          accent,
          progress,
        );
      }
    }
  }

  void _paintConnection(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint basePaint,
    Color accent,
    double progress,
  ) {
    final path = _connectionPath(start, end);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0x55213F50)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(path, basePaint);
    final metric = path.computeMetrics().first;
    _paintJunction(canvas, metric, accent, progress);
    if (progress <= 0) {
      return;
    }
    final litPath = metric.extractPath(0, metric.length * progress);
    canvas.drawPath(
      litPath,
      Paint()
        ..color = accent.withValues(alpha: 0.2 + progress * 0.18)
        ..strokeWidth = progress >= 1 ? 10 : 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      litPath,
      Paint()
        ..color = accent.withValues(alpha: 0.62 + progress * 0.34)
        ..strokeWidth = progress >= 1 ? 3.8 : 3
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  Path _connectionPath(Offset start, Offset end) {
    final startRadius = (start - _corePassiveTreeCenter).distance;
    final endRadius = (end - _corePassiveTreeCenter).distance;
    final path = Path()..moveTo(start.dx, start.dy);
    if ((startRadius - endRadius).abs() > 24 || startRadius < 1) {
      return path..lineTo(end.dx, end.dy);
    }

    // 같은 링의 이웃은 중심을 감싸는 회로 곡선으로 연결.
    final middle = (start + end) / 2;
    final direction = middle - _corePassiveTreeCenter;
    final control = direction.distance < 1
        ? middle
        : _corePassiveTreeCenter +
              direction / direction.distance * math.max(startRadius, endRadius);
    return path..quadraticBezierTo(control.dx, control.dy, end.dx, end.dy);
  }

  void _paintJunction(
    Canvas canvas,
    ui.PathMetric metric,
    Color accent,
    double progress,
  ) {
    final junctionOffset = metric.length * 0.52;
    final tangent = metric.getTangentForOffset(junctionOffset);
    if (tangent == null) {
      return;
    }
    final lit = progress >= 0.52;
    final radius = lit ? 5.2 : 4.1;
    final point = tangent.position;
    final diamond = Path()
      ..moveTo(point.dx, point.dy - radius)
      ..lineTo(point.dx + radius, point.dy)
      ..lineTo(point.dx, point.dy + radius)
      ..lineTo(point.dx - radius, point.dy)
      ..close();
    if (lit) {
      canvas.drawPath(
        diamond,
        Paint()
          ..color = accent.withValues(alpha: 0.28)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
      );
    }
    canvas.drawPath(
      diamond,
      Paint()
        ..color = lit ? const Color(0xFFEFFFFF) : const Color(0xFF233E4D)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      diamond,
      Paint()
        ..color = lit ? accent : const Color(0xFF587080)
        ..strokeWidth = 1.3
        ..style = PaintingStyle.stroke,
    );
  }

  CorePassiveNodeId _closerToCenter(
    CorePassiveNodeId first,
    CorePassiveNodeId second,
  ) {
    final firstDistance =
        (_corePassiveNodePosition(first) - _corePassiveTreeCenter)
            .distanceSquared;
    final secondDistance =
        (_corePassiveNodePosition(second) - _corePassiveTreeCenter)
            .distanceSquared;
    return firstDistance <= secondDistance ? first : second;
  }

  @override
  bool shouldRepaint(covariant _CorePassiveConnectionPainter oldDelegate) {
    return !mapEquals(oldDelegate.ranks, ranks);
  }
}

class _CorePassiveNodeDetails extends StatelessWidget {
  const _CorePassiveNodeDetails({
    required this.snapshot,
    required this.selectedNodeId,
    required this.targetRank,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAssign,
  });

  final GameSnapshot snapshot;
  final CorePassiveNodeId? selectedNodeId;
  final int targetRank;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    final id = selectedNodeId;
    if (id == null) {
      return Container(
        key: const ValueKey('core-passive-node-details-empty'),
        constraints: const BoxConstraints(minHeight: 132),
        padding: const EdgeInsets.all(14),
        decoration: _detailDecoration,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.touch_app_outlined, color: Color(0xFF8EE6FF)),
            const SizedBox(height: 7),
            Text(
              l10n.corePassiveSelectionHint,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFE8FBFF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.corePassiveGestureHint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8FA8BA), fontSize: 10),
            ),
          ],
        ),
      );
    }

    final definition = corePassiveNodeById(id);
    final currentRank = snapshot.corePassiveNodeRanks[id] ?? 0;
    final accessible = accessibleCorePassiveNodeIds(
      snapshot.corePassiveNodeRanks,
    ).contains(id);
    final currentEffect = currentRank > 0
        ? l10n.corePassiveNodeEffect(id, currentRank)
        : '—';
    final nextEffect = targetRank < definition.maxRank
        ? l10n.corePassiveNodeEffect(id, targetRank + 1)
        : l10n.corePassiveMaxRank;
    final currentCost = corePassiveCumulativeCost(id, currentRank);
    final targetCost = corePassiveCumulativeCost(id, targetRank);
    final costDelta = targetCost - currentCost;
    final accent = _corePassiveBranchColor(definition.branch);

    return Container(
      key: const ValueKey('core-passive-node-details'),
      constraints: const BoxConstraints(minHeight: 182),
      padding: const EdgeInsets.all(12),
      decoration: _detailDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  border: Border.all(color: accent.withValues(alpha: 0.75)),
                  shape: BoxShape.circle,
                ),
                child: CorePassiveNodeIcon(id, size: 22, color: accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.corePassiveNodeName(id),
                      maxLines: 2,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: Color(0xFFE8FBFF),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '$currentRank / ${definition.maxRank}',
                      style: TextStyle(
                        color: accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!accessible && currentRank == 0)
            Text(
              l10n.corePassiveUnlockHint,
              style: const TextStyle(
                color: Color(0xFFFFC66A),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            )
          else ...[
            _CorePassiveEffectLine(
              label: l10n.corePassiveCurrentEffect,
              value: currentEffect,
            ),
            const SizedBox(height: 4),
            _CorePassiveEffectLine(
              label: l10n.corePassiveNextEffect,
              value: nextEffect,
            ),
          ],
          const SizedBox(height: 9),
          Row(
            children: [
              _CorePassiveRankButton(
                key: const ValueKey('core-passive-rank-decrease'),
                icon: Icons.remove,
                onPressed: onDecrease,
              ),
              Container(
                constraints: const BoxConstraints(minWidth: 54, minHeight: 38),
                alignment: Alignment.center,
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.symmetric(horizontal: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF07131E),
                  border: Border.all(color: const Color(0x665D7182)),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  '$targetRank/${definition.maxRank}',
                  maxLines: 1,
                  style: const TextStyle(
                    color: Color(0xFFE8FBFF),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _CorePassiveRankButton(
                key: const ValueKey('core-passive-rank-increase'),
                icon: Icons.add,
                onPressed: onIncrease,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: FilledButton(
                  key: const ValueKey('core-passive-assign'),
                  onPressed: onAssign,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(70, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    backgroundColor: accent.withValues(alpha: 0.3),
                    foregroundColor: const Color(0xFFE8FBFF),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.corePassiveAssign,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (costDelta != 0)
                        Text(
                          costDelta > 0
                              ? '${l10n.corePassiveRequiredPoints} $costDelta'
                              : '${l10n.corePassiveReturnedPoints} ${-costDelta}',
                          maxLines: 1,
                          overflow: TextOverflow.fade,
                          style: const TextStyle(fontSize: 8),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration get _detailDecoration => BoxDecoration(
    gradient: const LinearGradient(
      colors: [Color(0xF20B1B2B), Color(0xF006101A)],
    ),
    border: Border.all(color: const Color(0x775D7182)),
    borderRadius: BorderRadius.circular(9),
  );
}

class _CorePassiveEffectLine extends StatelessWidget {
  const _CorePassiveEffectLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8FA8BA),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              color: Color(0xFFC8D9E2),
              fontSize: 9,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CorePassiveRankButton extends StatelessWidget {
  const _CorePassiveRankButton({
    required this.icon,
    required this.onPressed,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: IconButton.filledTonal(
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        icon: Icon(icon, size: 18),
      ),
    );
  }
}

Offset _corePassiveNodePosition(CorePassiveNodeId id) {
  final polar = _corePassiveNodePolarPositions[id]!;
  final radians = polar.angle * math.pi / 180;
  return _corePassiveTreeCenter +
      Offset(math.cos(radians), math.sin(radians)) * polar.radius;
}

Color _corePassiveBranchColor(CorePassiveBranch branch) {
  return switch (branch) {
    CorePassiveBranch.attack => const Color(0xFFFFB84D),
    CorePassiveBranch.control => const Color(0xFF56D9E8),
    CorePassiveBranch.efficiency => const Color(0xFF72E0A2),
    CorePassiveBranch.hybrid => const Color(0xFFE98BFF),
  };
}
