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
