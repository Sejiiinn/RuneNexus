part of 'main_menu_screen.dart';

class _CorePassiveConnectionLayer extends StatefulWidget {
  const _CorePassiveConnectionLayer({required this.builder});

  final _CorePassiveConnectionPainter Function(List<ui.Image>) builder;

  @override
  State<_CorePassiveConnectionLayer> createState() =>
      _CorePassiveConnectionLayerState();
}

class _CorePassiveConnectionLayerState
    extends State<_CorePassiveConnectionLayer> {
  static const _assets = [
    'assets/images/core_passive_tree/connection_segment_inactive_v1.png',
    'assets/images/core_passive_tree/connection_segment_v1.png',
    'assets/images/core_passive_tree/connection_junction_v1.png',
  ];
  final _images = List<ImageInfo?>.filled(_assets.length, null);
  final _streams = <ImageStream>[];
  final _listeners = <ImageStreamListener>[];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_streams.isNotEmpty) return;
    for (var index = 0; index < _assets.length; index++) {
      final stream = AssetImage(
        _assets[index],
      ).resolve(createLocalImageConfiguration(context));
      final listener = ImageStreamListener((info, synchronousCall) {
        _images[index]?.dispose();
        _images[index] = info;
        if (!synchronousCall && mounted) setState(() {});
      });
      _streams.add(stream);
      _listeners.add(listener);
      stream.addListener(listener);
    }
  }

  @override
  void dispose() {
    for (var index = 0; index < _streams.length; index++) {
      _streams[index].removeListener(_listeners[index]);
      _images[index]?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      key: const ValueKey('core-passive-connection-layer'),
      painter: widget.builder([
        for (final image in _images)
          if (image != null) image.image,
      ]),
    );
  }
}

class _CorePassiveConnectionPainter extends CustomPainter {
  const _CorePassiveConnectionPainter({
    required this.sprites,
    required this.draftRanks,
    required this.draftLineRanks,
    required this.renderedRanks,
    required this.allocationWaves,
    required this.allocationElapsedMs,
  });

  final List<ui.Image> sprites;
  final Map<CorePassiveNodeId, int> draftRanks;
  final Map<CorePassiveNodeId, double> draftLineRanks;
  final Map<CorePassiveNodeId, int> renderedRanks;
  final List<_CorePassiveAllocationWave> allocationWaves;
  final double allocationElapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    if (sprites.length != _CorePassiveConnectionLayerState._assets.length) {
      return;
    }
    for (final start in corePassiveStartingNodeIds) {
      final draftProgress = _draftPresence(start);
      _paintConnection(
        canvas,
        _corePassiveTreeCenter,
        _corePassiveNodePosition(start),
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
        _paintSpritePath(canvas, reach, lit: true, opacity: 0.58);
      }
    }
  }

  void _paintConnection(
    Canvas canvas,
    Offset start,
    Offset end, {
    required bool renderedLit,
    required bool draftLit,
    double draftProgress = 1,
    bool draftFromEnd = false,
  }) {
    final path = _connectionPath(start, end);
    _paintSpritePath(canvas, path, lit: false);
    final metric = path.computeMetrics().first;
    _paintJunction(
      canvas,
      metric,
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
      _paintSpritePath(canvas, draftReach, lit: true, opacity: 0.42);
    }
    if (renderedLit) _paintSpritePath(canvas, path, lit: true);
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
        _paintSpritePath(canvas, reach, lit: true, opacity: opacity, height: 9);
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

  // 경로를 짧은 접선 구간으로 분할하여 곡선에도 동일한 금속·발광 질감 유지.
  void _paintSpritePath(
    Canvas canvas,
    Path path, {
    required bool lit,
    double opacity = 1,
    double? height,
  }) {
    final image = sprites[lit ? 1 : 0];
    final source = lit
        ? const Rect.fromLTWH(55, 485, 1426, 54)
        : const Rect.fromLTWH(28, 239, 2120, 238);
    final paint = Paint()
      ..filterQuality = FilterQuality.medium
      ..color = Color.fromRGBO(255, 255, 255, opacity);
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 6) {
        final length = math.min(6.0, metric.length - offset);
        final tangent = metric.getTangentForOffset(offset + length / 2);
        if (tangent == null) continue;
        final crop = Rect.fromLTWH(
          source.left + source.width * offset / metric.length,
          source.top,
          source.width * length / metric.length,
          source.height,
        );
        canvas.save();
        canvas.translate(tangent.position.dx, tangent.position.dy);
        canvas.rotate(math.atan2(tangent.vector.dy, tangent.vector.dx));
        canvas.drawImageRect(
          image,
          crop,
          Rect.fromCenter(
            center: Offset.zero,
            width: length + 0.4,
            height: height ?? (lit ? 6 : 3.6),
          ),
          paint,
        );
        canvas.restore();
      }
    }
  }

  void _paintJunction(Canvas canvas, ui.PathMetric metric, double progress) {
    final tangent = metric.getTangentForOffset(metric.length * 0.52);
    if (tangent == null) return;
    canvas.drawImageRect(
      sprites[2],
      const Rect.fromLTWH(330, 160, 595, 910),
      Rect.fromCenter(center: tangent.position, width: 8, height: 12),
      Paint()
        ..filterQuality = FilterQuality.medium
        ..color = Color.fromRGBO(255, 255, 255, progress > 0.5 ? 1 : 0.45),
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
    return !listEquals(oldDelegate.sprites, sprites) ||
        !mapEquals(oldDelegate.draftRanks, draftRanks) ||
        !mapEquals(oldDelegate.draftLineRanks, draftLineRanks) ||
        !mapEquals(oldDelegate.renderedRanks, renderedRanks) ||
        oldDelegate.allocationWaves != allocationWaves ||
        oldDelegate.allocationElapsedMs != allocationElapsedMs;
  }
}
