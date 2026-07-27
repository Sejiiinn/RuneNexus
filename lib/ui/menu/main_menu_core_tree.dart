part of 'main_menu_screen.dart';

const double _corePassiveTreeWorldSize = 720;
const Offset _corePassiveTreeCenter = Offset(360, 360);
const int _corePassiveWaveIntervalMs = 200;
const int _corePassiveLineGrowMs = 340;
const int _corePassiveLineFadeMs = 160;
const int _corePassiveNodeGlowDelayMs = 280;
const int _corePassiveNodeGlowMs = 420;
const int _corePassiveDraftLineTransitionMs = 260;

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
  CorePassiveNodeId.efficiencySupplyRecovery: (radius: 180, angle: 70),
  CorePassiveNodeId.efficiencyGemSpectrum: (radius: 180, angle: 110),
  CorePassiveNodeId.efficiencyFirstDeploy: (radius: 245, angle: 60),
  CorePassiveNodeId.efficiencyFirstLink: (radius: 245, angle: 120),
  CorePassiveNodeId.efficiencyCombinedFront: (radius: 300, angle: 90),
  CorePassiveNodeId.controlRetarget: (radius: 180, angle: 190),
  CorePassiveNodeId.controlRearLock: (radius: 180, angle: 230),
  CorePassiveNodeId.controlBufferShell: (radius: 245, angle: 180),
  CorePassiveNodeId.controlEmergencyCharge: (radius: 245, angle: 240),
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

class _CorePassiveTreeMenuState extends State<_CorePassiveTreeMenu>
    with TickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late final AnimationController _allocationController;
  late final AnimationController _draftLineController;
  late Map<CorePassiveNodeId, int> _draftRanks;
  Map<CorePassiveNodeId, double> _draftLineFromRanks = const {};
  Map<CorePassiveNodeId, double> _draftLineToRanks = const {};
  CorePassiveNodeId? _selectedNodeId;
  Size? _viewportSize;
  double _minimumScale = 1;
  bool _isAllocating = false;
  List<_CorePassiveAllocationWave> _allocationWaves = const [];
  Map<CorePassiveNodeId, int> _allocationTargetRanks = const {};
  int _allocationTimelineDurationMs = 0;
  bool _clampingTransform = false;
  final Set<int> _canvasPointers = <int>{};
  Offset? _canvasPointerOrigin;
  bool _canvasTapCandidate = false;
  int _selectionInteractionRevision = 0;
  int _canvasSelectionRevision = 0;

  @override
  void initState() {
    super.initState();
    _draftRanks = Map.of(widget.snapshot.corePassiveNodeRanks);
    _draftLineFromRanks = _doubleRanks(_draftRanks);
    _draftLineToRanks = _draftLineFromRanks;
    _transformationController.addListener(_clampTransformToViewport);
    _allocationController = AnimationController(vsync: this)
      ..addListener(() {
        if (mounted && _isAllocating) {
          setState(() {});
        }
      });
    _draftLineController =
        AnimationController(
          vsync: this,
          duration: const Duration(
            milliseconds: _corePassiveDraftLineTransitionMs,
          ),
          value: 1,
        )..addListener(() {
          if (mounted) {
            setState(() {});
          }
        });
  }

  @override
  void dispose() {
    _transformationController.removeListener(_clampTransformToViewport);
    _allocationController.dispose();
    _draftLineController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CorePassiveTreeMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_isAllocating ||
        mapEquals(
          oldWidget.snapshot.corePassiveNodeRanks,
          widget.snapshot.corePassiveNodeRanks,
        )) {
      return;
    }
    _draftRanks = Map.of(widget.snapshot.corePassiveNodeRanks);
    _settleDraftLineRanks(_draftRanks);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    final selectedNodeId = _selectedNodeId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CorePassivePointSummary(
          snapshot: widget.snapshot,
          draftSpentPoints: _draftSpentPoints,
          l10n: l10n,
          onCancelPlan: _hasDraftChanges && !_isAllocating
              ? _cancelDraft
              : null,
          onReset: widget.snapshot.spentCorePoints > 0 && !_isAllocating
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
              // InteractiveViewer의 종횡비 기반 자체 축소 하한 보정.
              final scaleBoundaryMargin = EdgeInsets.symmetric(
                horizontal: math.max(
                  0,
                  (viewport.width / fitScale - _corePassiveTreeWorldSize) / 2,
                ),
                vertical: math.max(
                  0,
                  (viewport.height / fitScale - _corePassiveTreeWorldSize) / 2,
                ),
              );
              _synchronizeViewport(viewport, fitScale);
              return Stack(
                children: [
                  Positioned.fill(
                    child: AbsorbPointer(
                      absorbing: _isAllocating,
                      child: Listener(
                        key: const ValueKey('core-passive-tree-empty-space'),
                        behavior: HitTestBehavior.opaque,
                        onPointerDown: _handleCanvasPointerDown,
                        onPointerMove: _handleCanvasPointerMove,
                        onPointerUp: _handleCanvasPointerUp,
                        onPointerCancel: _handleCanvasPointerCancel,
                        child: InteractiveViewer(
                          key: const ValueKey('core-passive-tree-viewer'),
                          transformationController: _transformationController,
                          constrained: false,
                          panEnabled: true,
                          scaleEnabled: true,
                          minScale: fitScale,
                          maxScale: fitScale * 2.2,
                          boundaryMargin: scaleBoundaryMargin,
                          onInteractionUpdate: (_) =>
                              _clampTransformToViewport(),
                          onInteractionEnd: (_) {
                            _clampTransformToViewport();
                            _centerAtMinimumScale();
                          },
                          child: _CorePassiveTreeWorld(
                            actualRanks: _actualRanksForRendering,
                            draftRanks: _draftRanksForRendering,
                            draftLineRanks: _draftLineRanksForRendering,
                            renderedRanks: _renderedRanks,
                            selectedNodeId: selectedNodeId,
                            allocationWaves: _allocationWaves,
                            allocationElapsedMs: _allocationElapsedMs,
                            viewportSize: viewport,
                            fitScale: fitScale,
                            onSelectNode: _selectNode,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.04),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: selectedNodeId == null
                          ? const SizedBox.shrink(
                              key: ValueKey('core-passive-node-details-closed'),
                            )
                          : Align(
                              key: const ValueKey(
                                'core-passive-node-details-open',
                              ),
                              alignment:
                                  _corePassiveNodePosition(selectedNodeId).dy >
                                      _corePassiveTreeCenter.dy
                                  ? Alignment.topCenter
                                  : Alignment.bottomCenter,
                              child: _CorePassiveNodeDetails(
                                snapshot: widget.snapshot,
                                draftRanks: _draftRanks,
                                selectedNodeId: selectedNodeId,
                                allocating: _isAllocating,
                                onDecrease: _canDecrease
                                    ? _decreaseSelectedRank
                                    : null,
                                onIncrease: _canIncrease
                                    ? _increaseSelectedRank
                                    : null,
                                onAssign: _canAssign ? _assignDraft : null,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  bool get _canDecrease {
    final id = _selectedNodeId;
    final targetRank = id == null ? 0 : (_draftRanks[id] ?? 0);
    if (_isAllocating || id == null || targetRank <= 0) {
      return false;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(_draftRanks);
    candidate[id] = targetRank - 1;
    if (candidate[id] == 0) {
      candidate.remove(id);
    }
    return isValidCorePassiveAllocation(candidate);
  }

  bool get _canIncrease {
    final id = _selectedNodeId;
    if (_isAllocating || id == null) {
      return false;
    }
    final definition = corePassiveNodeById(id);
    final targetRank = _draftRanks[id] ?? 0;
    if (targetRank >= definition.maxRank) {
      return false;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(_draftRanks)
      ..[id] = targetRank + 1;
    return corePassiveSpentPoints(candidate) <=
            widget.snapshot.totalCorePoints &&
        isValidCorePassiveAllocation(candidate);
  }

  bool get _canAssign {
    return !_isAllocating &&
        _hasDraftChanges &&
        corePassiveSpentPoints(_draftRanks) <=
            widget.snapshot.totalCorePoints &&
        isValidCorePassiveAllocation(_draftRanks);
  }

  void _selectNode(CorePassiveNodeId id) {
    _selectionInteractionRevision += 1;
    setState(() => _selectedNodeId = id);
  }

  void _handleCanvasPointerDown(PointerDownEvent event) {
    _canvasPointers.add(event.pointer);
    if (_canvasPointers.length == 1) {
      _canvasPointerOrigin = event.localPosition;
      _canvasTapCandidate = true;
      _canvasSelectionRevision = _selectionInteractionRevision;
    } else {
      _canvasTapCandidate = false;
    }
  }

  void _handleCanvasPointerMove(PointerMoveEvent event) {
    final origin = _canvasPointerOrigin;
    if (!_canvasTapCandidate || origin == null) {
      return;
    }
    if ((event.localPosition - origin).distanceSquared > 144) {
      _canvasTapCandidate = false;
    }
  }

  void _handleCanvasPointerUp(PointerUpEvent event) {
    final shouldClear = _canvasTapCandidate && _canvasPointers.length == 1;
    final selectionRevision = _canvasSelectionRevision;
    _canvasPointers.remove(event.pointer);
    if (_canvasPointers.isEmpty) {
      _canvasPointerOrigin = null;
      _canvasTapCandidate = false;
    }
    if (!shouldClear) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _selectionInteractionRevision == selectionRevision) {
        _clearSelectedNode();
      }
    });
    WidgetsBinding.instance.scheduleFrame();
  }

  void _handleCanvasPointerCancel(PointerCancelEvent event) {
    _canvasPointers.remove(event.pointer);
    if (_canvasPointers.isEmpty) {
      _canvasPointerOrigin = null;
      _canvasTapCandidate = false;
    }
  }

  void _clearSelectedNode() {
    if (_selectedNodeId == null) {
      return;
    }
    setState(() => _selectedNodeId = null);
  }

  void _increaseSelectedRank() {
    final id = _selectedNodeId;
    if (id == null) {
      return;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(_draftRanks)
      ..[id] = (_draftRanks[id] ?? 0) + 1;
    _tryReplaceDraft(candidate);
  }

  void _decreaseSelectedRank() {
    final id = _selectedNodeId;
    if (id == null) {
      return;
    }
    final candidate = Map<CorePassiveNodeId, int>.of(_draftRanks);
    final nextRank = (candidate[id] ?? 0) - 1;
    if (nextRank <= 0) {
      candidate.remove(id);
    } else {
      candidate[id] = nextRank;
    }
    _tryReplaceDraft(candidate);
  }

  void _tryReplaceDraft(Map<CorePassiveNodeId, int> candidate) {
    if (!_isValidDraft(candidate)) {
      return;
    }
    final currentLineRanks = _currentDraftLineRanks;
    setState(() {
      _draftRanks = candidate;
      _draftLineFromRanks = currentLineRanks;
      _draftLineToRanks = _doubleRanks(candidate);
    });
    _draftLineController.forward(from: 0);
  }

  bool _isValidDraft(Map<CorePassiveNodeId, int> candidate) {
    return corePassiveSpentPoints(candidate) <=
            widget.snapshot.totalCorePoints &&
        isValidCorePassiveAllocation(candidate);
  }

  void _cancelDraft() {
    _tryReplaceDraft(Map.of(widget.snapshot.corePassiveNodeRanks));
  }

  void _assignDraft() {
    final baseRanks = Map<CorePassiveNodeId, int>.of(
      widget.snapshot.corePassiveNodeRanks,
    );
    final targetRanks = Map<CorePassiveNodeId, int>.of(_draftRanks);
    final waves = _buildAllocationWaves(baseRanks, targetRanks);
    _settleDraftLineRanks(targetRanks);
    setState(() {
      _isAllocating = true;
      _allocationTargetRanks = targetRanks;
      _allocationWaves = waves;
      _allocationTimelineDurationMs = waves.isEmpty
          ? 0
          : (waves.length - 1) * _corePassiveWaveIntervalMs +
                _corePassiveNodeGlowDelayMs +
                _corePassiveNodeGlowMs;
    });
    if (!widget.game.setCorePassiveNodeRanks(targetRanks)) {
      setState(() {
        _isAllocating = false;
        _allocationWaves = const [];
        _allocationTimelineDurationMs = 0;
      });
      return;
    }
    unawaited(_playAllocationSequence());
  }

  List<_CorePassiveAllocationWave> _buildAllocationWaves(
    Map<CorePassiveNodeId, int> baseRanks,
    Map<CorePassiveNodeId, int> targetRanks,
  ) {
    final increasedNodes = CorePassiveNodeId.values
        .where((id) => (targetRanks[id] ?? 0) > (baseRanks[id] ?? 0))
        .toSet();
    final traversalWave = <CorePassiveNodeId, int>{};
    final activationWave = <CorePassiveNodeId, int>{};
    final sourceByNode = <CorePassiveNodeId, CorePassiveNodeId?>{};
    final queue = <CorePassiveNodeId>[];

    for (final id in CorePassiveNodeId.values) {
      final baseRank = baseRanks[id] ?? 0;
      final targetRank = targetRanks[id] ?? 0;
      if (baseRank > 0) {
        traversalWave[id] = baseRank >= 3 ? -1 : 0;
        queue.add(id);
        if (targetRank > baseRank) {
          activationWave[id] = 0;
        }
      } else if (targetRank > 0 && corePassiveStartingNodeIds.contains(id)) {
        traversalWave[id] = 0;
        activationWave[id] = 0;
        sourceByNode[id] = null;
        queue.add(id);
      }
    }

    var cursor = 0;
    while (cursor < queue.length) {
      final source = queue[cursor++];
      if ((targetRanks[source] ?? 0) < 3) continue;
      final nextWave = traversalWave[source]! + 1;
      for (final target in corePassiveNodeById(source).neighbors) {
        if ((targetRanks[target] ?? 0) <= 0 || (baseRanks[target] ?? 0) > 0) {
          continue;
        }
        final knownWave = traversalWave[target];
        if (knownWave != null && knownWave <= nextWave) continue;
        traversalWave[target] = nextWave;
        activationWave[target] = nextWave;
        sourceByNode[target] = source;
        queue.add(target);
      }
    }

    var maxWave = -1;
    for (final wave in activationWave.values) {
      if (wave > maxWave) maxWave = wave;
    }
    return [
      for (var wave = 0; wave <= maxWave; wave++)
        _CorePassiveAllocationWave(
          steps: [
            for (final id in CorePassiveNodeId.values)
              if (increasedNodes.contains(id) && activationWave[id] == wave)
                _CorePassiveAllocationStep(
                  nodeId: id,
                  sourceNodeId: sourceByNode[id],
                  lightsConnection: (baseRanks[id] ?? 0) == 0,
                ),
          ],
        ),
    ].where((wave) => wave.steps.isNotEmpty).toList(growable: false);
  }

  Future<void> _playAllocationSequence() async {
    if (_allocationWaves.isEmpty) {
      _finishAllocationSequence();
      return;
    }
    _allocationController.duration = Duration(
      milliseconds: _allocationTimelineDurationMs,
    );
    try {
      await _allocationController.forward(from: 0).orCancel;
    } on TickerCanceled {
      return;
    }
    _finishAllocationSequence();
  }

  void _finishAllocationSequence() {
    if (!mounted) return;
    setState(() {
      _isAllocating = false;
      _draftRanks = Map.of(_allocationTargetRanks);
      _allocationWaves = const [];
      _allocationTargetRanks = const {};
      _allocationTimelineDurationMs = 0;
    });
  }

  Future<void> _confirmReset(
    BuildContext context,
    RuneNexusLocalizations l10n,
  ) async {
    final confirmed = await showGameDialog<bool>(
      context: context,
      builder: (dialogContext) => _CorePassiveResetDialog(
        title: l10n.corePassiveResetTitle,
        message: l10n.corePassiveResetMessage,
        returnedPoints: widget.snapshot.spentCorePoints,
        returnedPointsLabel: l10n.corePassiveReturnedPoints,
        cancelLabel: MaterialLocalizations.of(dialogContext).cancelButtonLabel,
        confirmLabel: l10n.corePassiveResetAll,
      ),
    );
    if (confirmed != true) {
      return;
    }
    if (widget.game.resetCorePassiveTree()) {
      setState(() {
        _draftRanks = const {};
        _settleDraftLineRanks(const {});
      });
    }
  }

  bool get _hasDraftChanges =>
      !mapEquals(_draftRanks, widget.snapshot.corePassiveNodeRanks);

  int get _draftSpentPoints => corePassiveSpentPoints(_draftRanks);

  Map<CorePassiveNodeId, int> get _actualRanksForRendering => _isAllocating
      ? _allocationTargetRanks
      : widget.snapshot.corePassiveNodeRanks;

  Map<CorePassiveNodeId, int> get _draftRanksForRendering =>
      _isAllocating ? _allocationTargetRanks : _draftRanks;

  Map<CorePassiveNodeId, double> get _draftLineRanksForRendering =>
      _isAllocating
      ? _doubleRanks(_allocationTargetRanks)
      : _currentDraftLineRanks;

  Map<CorePassiveNodeId, int> get _renderedRanks => _isAllocating
      ? _allocationTargetRanks
      : widget.snapshot.corePassiveNodeRanks;

  double get _allocationElapsedMs =>
      _allocationController.value * _allocationTimelineDurationMs;

  Map<CorePassiveNodeId, double> get _currentDraftLineRanks {
    if (!_draftLineController.isAnimating) {
      return _draftLineToRanks;
    }
    final progress = Curves.easeInOutCubic.transform(
      _draftLineController.value,
    );
    return {
      for (final id in CorePassiveNodeId.values)
        if ((_draftLineFromRanks[id] ?? 0) != 0 ||
            (_draftLineToRanks[id] ?? 0) != 0)
          id:
              (_draftLineFromRanks[id] ?? 0) +
              ((_draftLineToRanks[id] ?? 0) - (_draftLineFromRanks[id] ?? 0)) *
                  progress,
    };
  }

  Map<CorePassiveNodeId, double> _doubleRanks(
    Map<CorePassiveNodeId, int> ranks,
  ) => {
    for (final entry in ranks.entries)
      if (entry.value > 0) entry.key: entry.value.toDouble(),
  };

  void _settleDraftLineRanks(Map<CorePassiveNodeId, int> ranks) {
    _draftLineController.stop();
    final settledRanks = _doubleRanks(ranks);
    _draftLineFromRanks = settledRanks;
    _draftLineToRanks = settledRanks;
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

  void _clampTransformToViewport() {
    final viewport = _viewportSize;
    if (viewport == null || _clampingTransform) return;
    final current = _transformationController.value;
    final scale = current.getMaxScaleOnAxis();
    final scaledWorld = _corePassiveTreeWorldSize * scale;

    double clampAxis(double translation, double viewportExtent) {
      if (scaledWorld <= viewportExtent) {
        return (viewportExtent - scaledWorld) / 2;
      }
      return translation.clamp(viewportExtent - scaledWorld, 0).toDouble();
    }

    final dx = clampAxis(current.storage[12], viewport.width);
    final dy = clampAxis(current.storage[13], viewport.height);
    if ((dx - current.storage[12]).abs() < 0.01 &&
        (dy - current.storage[13]).abs() < 0.01) {
      return;
    }
    final clamped = Matrix4.copy(current);
    clamped.storage[12] = dx;
    clamped.storage[13] = dy;
    _clampingTransform = true;
    _transformationController.value = clamped;
    _clampingTransform = false;
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

class _CorePassiveResetDialog extends StatelessWidget {
  const _CorePassiveResetDialog({
    required this.title,
    required this.message,
    required this.returnedPoints,
    required this.returnedPointsLabel,
    required this.cancelLabel,
    required this.confirmLabel,
  });

  final String title;
  final String message;
  final int returnedPoints;
  final String returnedPointsLabel;
  final String cancelLabel;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return GameModalFrame(
      key: const ValueKey('core-passive-reset-dialog'),
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: KeyedSubtree(
        key: const ValueKey('core-passive-reset-panel'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.restart_alt_rounded,
                  color: GamePalette.danger,
                  size: 21,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: GameTextStyles.title)),
              ],
            ),
            const SizedBox(height: 12),
            Text(message, style: GameTextStyles.body),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
              decoration: BoxDecoration(
                color: GamePalette.danger.withValues(alpha: 0.1),
                border: Border.all(
                  color: GamePalette.danger.withValues(alpha: 0.36),
                ),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Row(
                children: [
                  Image.asset(
                    stageRewardCoreIconAsset,
                    width: 20,
                    height: 20,
                    filterQuality: FilterQuality.medium,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      returnedPointsLabel,
                      style: GameTextStyles.caption,
                    ),
                  ),
                  Text(
                    '$returnedPoints',
                    style: GameTextStyles.withColor(
                      GameTextStyles.sectionTitle,
                      GamePalette.danger,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: GameButton(
                    key: const ValueKey('core-passive-reset-cancel'),
                    onPressed: () => Navigator.of(context).pop(false),
                    label: cancelLabel,
                    icon: const Icon(Icons.arrow_back, size: 17),
                    variant: GameButtonVariant.ghost,
                    accentColor: GamePalette.metal,
                    height: 38,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GameButton(
                    key: const ValueKey('core-passive-reset-confirm'),
                    onPressed: () => Navigator.of(context).pop(true),
                    label: confirmLabel,
                    icon: const Icon(Icons.restart_alt_rounded, size: 17),
                    variant: GameButtonVariant.danger,
                    height: 38,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CorePassiveAllocationStep {
  const _CorePassiveAllocationStep({
    required this.nodeId,
    required this.sourceNodeId,
    required this.lightsConnection,
  });

  final CorePassiveNodeId nodeId;
  final CorePassiveNodeId? sourceNodeId;
  final bool lightsConnection;
}

class _CorePassiveAllocationWave {
  const _CorePassiveAllocationWave({required this.steps});

  final List<_CorePassiveAllocationStep> steps;
}

class _CorePassivePointSummary extends StatelessWidget {
  const _CorePassivePointSummary({
    required this.snapshot,
    required this.draftSpentPoints,
    required this.l10n,
    required this.onCancelPlan,
    required this.onReset,
  });

  final GameSnapshot snapshot;
  final int draftSpentPoints;
  final RuneNexusLocalizations l10n;
  final VoidCallback? onCancelPlan;
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
                  '${l10n.corePassivePlanned} $draftSpentPoints',
                  key: const ValueKey('core-passive-planned-points'),
                  style: const TextStyle(
                    color: Color(0xFF8EE6FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${l10n.corePassiveRemainingAfterPlan} ${snapshot.totalCorePoints - draftSpentPoints}',
                  key: const ValueKey('core-passive-planned-remaining'),
                  style: const TextStyle(
                    color: Color(0xFF72E0A2),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                key: const ValueKey('core-passive-cancel-plan'),
                onPressed: onCancelPlan,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(0, 27),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.corePassiveCancelPlan,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              TextButton(
                key: const ValueKey('core-passive-reset-all'),
                onPressed: onReset,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  minimumSize: const Size(0, 27),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.corePassiveResetAll,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

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

class _CorePassiveConnectionPainter extends CustomPainter {
  const _CorePassiveConnectionPainter({
    required this.draftRanks,
    required this.draftLineRanks,
    required this.renderedRanks,
    required this.allocationWaves,
    required this.allocationElapsedMs,
  });

  final Map<CorePassiveNodeId, int> draftRanks;
  final Map<CorePassiveNodeId, double> draftLineRanks;
  final Map<CorePassiveNodeId, int> renderedRanks;
  final List<_CorePassiveAllocationWave> allocationWaves;
  final double allocationElapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    final basePaint = Paint()
      ..color = const Color(0x88455C6B)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final start in corePassiveStartingNodeIds) {
      final draftProgress = _draftPresence(start);
      _paintConnection(
        canvas,
        _corePassiveTreeCenter,
        _corePassiveNodePosition(start),
        basePaint,
        _corePassiveBranchColor(corePassiveNodeById(start).branch),
        renderedLit: (renderedRanks[start] ?? 0) > 0,
        draftLit: (draftRanks[start] ?? 0) > 0 || draftProgress > 0,
        draftProgress: draftProgress,
      );
    }
    for (final definition in corePassiveNodeDefinitions.values) {
      for (final neighbor in definition.neighbors) {
        if (definition.id.index >= neighbor.index) {
          continue;
        }
        final targetDefinition = corePassiveNodeById(neighbor);
        final accent =
            definition.branch == CorePassiveBranch.hybrid ||
                targetDefinition.branch == CorePassiveBranch.hybrid
            ? _corePassiveBranchColor(CorePassiveBranch.hybrid)
            : _corePassiveBranchColor(definition.branch);
        final definitionRendered = (renderedRanks[definition.id] ?? 0) > 0;
        final neighborRendered = (renderedRanks[neighbor] ?? 0) > 0;
        final draftProgress = math.min(
          _draftPresence(definition.id),
          _draftPresence(neighbor),
        );
        final draftFromEnd = !definitionRendered && neighborRendered
            ? true
            : definitionRendered && !neighborRendered
            ? false
            : _closerToCenter(definition.id, neighbor) == neighbor;
        _paintConnection(
          canvas,
          _corePassiveNodePosition(definition.id),
          _corePassiveNodePosition(neighbor),
          basePaint,
          accent,
          renderedLit: definitionRendered && neighborRendered,
          draftLit:
              ((draftRanks[definition.id] ?? 0) > 0 &&
                  (draftRanks[neighbor] ?? 0) > 0) ||
              draftProgress > 0,
          draftProgress: draftProgress,
          draftFromEnd: draftFromEnd,
        );
      }
    }
    if (allocationWaves.isEmpty) {
      _paintDraftReach(canvas);
    }
    if (allocationWaves.isNotEmpty) {
      _paintAllocationTimeline(canvas);
    }
  }

  void _paintDraftReach(Canvas canvas) {
    for (final id in CorePassiveNodeId.values) {
      final animatedRank = draftLineRanks[id] ?? 0;
      if (animatedRank <= (renderedRanks[id] ?? 0)) continue;
      final progress = (animatedRank / 3).clamp(0.0, 1.0);
      final definition = corePassiveNodeById(id);
      final accent = _corePassiveBranchColor(definition.branch);
      for (final neighbor in definition.neighbors) {
        if (_closerToCenter(id, neighbor) != id) continue;
        final path = _connectionPath(
          _corePassiveNodePosition(id),
          _corePassiveNodePosition(neighbor),
        );
        final metrics = path.computeMetrics().toList();
        if (metrics.isEmpty) continue;
        final metric = metrics.first;
        final reach = metric.extractPath(0, metric.length * progress);
        canvas.drawPath(
          reach,
          Paint()
            ..color = accent.withValues(alpha: 0.24)
            ..strokeWidth = 8
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawPath(
          reach,
          Paint()
            ..color = const Color(0xFFB9F5FF).withValues(alpha: 0.58)
            ..strokeWidth = 2.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
  }

  void _paintConnection(
    Canvas canvas,
    Offset start,
    Offset end,
    Paint basePaint,
    Color accent, {
    required bool renderedLit,
    required bool draftLit,
    double draftProgress = 1,
    bool draftFromEnd = false,
  }) {
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
    _paintJunction(
      canvas,
      metric,
      accent,
      renderedLit
          ? 1
          : draftLit
          ? 0.4
          : 0,
    );
    if (draftLit && !renderedLit) {
      final clampedProgress = draftProgress.clamp(0.0, 1.0);
      final draftReach = draftFromEnd
          ? metric.extractPath(
              metric.length * (1 - clampedProgress),
              metric.length,
            )
          : metric.extractPath(0, metric.length * clampedProgress);
      canvas.drawPath(
        draftReach,
        Paint()
          ..color = accent.withValues(alpha: 0.2)
          ..strokeWidth = 7
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        draftReach,
        Paint()
          ..color = const Color(0xFFB9F5FF).withValues(alpha: 0.34)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    if (!renderedLit) return;
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.38)
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = accent.withValues(alpha: 0.96)
        ..strokeWidth = 3.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  double _draftPresence(CorePassiveNodeId id) {
    return (draftLineRanks[id] ?? 0).clamp(0.0, 1.0);
  }

  void _paintAllocationTimeline(Canvas canvas) {
    for (var wave = 0; wave < allocationWaves.length; wave++) {
      final elapsed = allocationElapsedMs - wave * _corePassiveWaveIntervalMs;
      if (elapsed <= 0 ||
          elapsed >= _corePassiveLineGrowMs + _corePassiveLineFadeMs) {
        continue;
      }
      final growProgress = (elapsed / _corePassiveLineGrowMs).clamp(0.0, 1.0);
      final reachProgress = Curves.easeInOutCubic.transform(growProgress);
      final opacity = elapsed <= _corePassiveLineGrowMs
          ? Curves.easeOutCubic.transform(growProgress)
          : 1 -
                Curves.easeInCubic.transform(
                  (elapsed - _corePassiveLineGrowMs) / _corePassiveLineFadeMs,
                );
      for (final step in allocationWaves[wave].steps) {
        if (!step.lightsConnection) continue;
        final start = step.sourceNodeId == null
            ? _corePassiveTreeCenter
            : _corePassiveNodePosition(step.sourceNodeId!);
        final path = _connectionPath(
          start,
          _corePassiveNodePosition(step.nodeId),
        );
        final metrics = path.computeMetrics().toList();
        if (metrics.isEmpty) continue;
        final metric = metrics.first;
        final reach = metric.extractPath(0, metric.length * reachProgress);
        final accent = _corePassiveBranchColor(
          corePassiveNodeById(step.nodeId).branch,
        );
        canvas.drawPath(
          reach,
          Paint()
            ..color = accent.withValues(alpha: 0.48 * opacity)
            ..strokeWidth = 12
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
        );
        canvas.drawPath(
          reach,
          Paint()
            ..color = const Color(0xFFEFFFFF).withValues(alpha: opacity)
            ..strokeWidth = 3.6
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
      }
    }
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
    return !mapEquals(oldDelegate.draftRanks, draftRanks) ||
        !mapEquals(oldDelegate.draftLineRanks, draftLineRanks) ||
        !mapEquals(oldDelegate.renderedRanks, renderedRanks) ||
        oldDelegate.allocationWaves != allocationWaves ||
        oldDelegate.allocationElapsedMs != allocationElapsedMs;
  }
}

class _CorePassiveNodeDetails extends StatelessWidget {
  const _CorePassiveNodeDetails({
    required this.snapshot,
    required this.draftRanks,
    required this.selectedNodeId,
    required this.allocating,
    required this.onDecrease,
    required this.onIncrease,
    required this.onAssign,
  });

  final GameSnapshot snapshot;
  final Map<CorePassiveNodeId, int> draftRanks;
  final CorePassiveNodeId selectedNodeId;
  final bool allocating;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final VoidCallback? onAssign;

  @override
  Widget build(BuildContext context) {
    final l10n = RuneNexusLocalizations.of(context);
    final id = selectedNodeId;
    final definition = corePassiveNodeById(id);
    final currentRank = snapshot.corePassiveNodeRanks[id] ?? 0;
    final targetRank = draftRanks[id] ?? 0;
    final accessible = accessibleCorePassiveNodeIds(draftRanks).contains(id);
    final previewingFirstRank = targetRank == 0;
    final effect = l10n.corePassiveNodeEffect(
      id,
      previewingFirstRank ? 1 : targetRank,
    );
    final nextRankCost = targetRank < definition.maxRank
        ? '${definition.rankCosts[targetRank]}'
        : l10n.corePassiveMaxRank;
    final costDelta =
        corePassiveSpentPoints(draftRanks) - snapshot.spentCorePoints;
    final accent = _corePassiveBranchColor(definition.branch);

    return Container(
      key: const ValueKey('core-passive-node-details'),
      constraints: const BoxConstraints(minHeight: 182),
      padding: const EdgeInsets.all(12),
      decoration: _detailDecoration,
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
                      currentRank == targetRank
                          ? '$currentRank / ${definition.maxRank}'
                          : '${l10n.corePassivePlannedRank} $currentRank → $targetRank / ${definition.maxRank}',
                      key: const ValueKey('core-passive-selected-rank'),
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
            ),
          if (!accessible && currentRank == 0) const SizedBox(height: 6),
          _CorePassiveEffectLine(
            label: l10n.corePassiveEffect,
            value: effect,
            accent: accent,
            muted: previewingFirstRank,
            highlightNumbers: true,
          ),
          const SizedBox(height: 4),
          _CorePassiveEffectLine(
            label: l10n.corePassiveRequiredPoints,
            value: nextRankCost,
          ),
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
                        allocating
                            ? l10n.corePassiveAllocationInProgress
                            : l10n.corePassiveAssign,
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
      colors: [Color(0xD90B1B2B), Color(0xCC06101A)],
    ),
    border: Border.all(color: const Color(0x775D7182)),
    borderRadius: BorderRadius.circular(9),
  );
}

class _CorePassiveEffectLine extends StatelessWidget {
  const _CorePassiveEffectLine({
    required this.label,
    required this.value,
    this.accent,
    this.muted = false,
    this.highlightNumbers = false,
  }) : assert(!highlightNumbers || accent != null);

  final String label;
  final String value;
  final Color? accent;
  final bool muted;
  final bool highlightNumbers;

  @override
  Widget build(BuildContext context) {
    final baseColor = muted ? const Color(0xFF778995) : const Color(0xFFC8D9E2);
    final numericColor = accent?.withValues(alpha: muted ? 0.55 : 0.95);
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
          child: highlightNumbers
              ? RichText(
                  key: const ValueKey('core-passive-selected-effect'),
                  text: TextSpan(
                    style: TextStyle(
                      color: baseColor,
                      fontSize: 9,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                    children: _highlightedEffectSpans(
                      value,
                      numericColor: numericColor!,
                    ),
                  ),
                )
              : Text(
                  value,
                  style: TextStyle(
                    color: baseColor,
                    fontSize: 9,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }

  List<TextSpan> _highlightedEffectSpans(
    String text, {
    required Color numericColor,
  }) {
    final spans = <TextSpan>[];
    var offset = 0;
    for (final match in RegExp(
      r'\d+(?:\.\d+)?(?:%|초|라운드|중첩|종|회|기|HP)?',
    ).allMatches(text)) {
      if (match.start > offset) {
        spans.add(TextSpan(text: text.substring(offset, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(0),
          style: TextStyle(color: numericColor, fontWeight: FontWeight.w900),
        ),
      );
      offset = match.end;
    }
    if (offset < text.length) {
      spans.add(TextSpan(text: text.substring(offset)));
    }
    if (spans.isEmpty) {
      spans.add(TextSpan(text: text));
    }
    return spans;
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
