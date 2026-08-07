part of 'main_menu_screen.dart';

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
        final accent = _corePassiveBranchColor(definition.branch);
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
