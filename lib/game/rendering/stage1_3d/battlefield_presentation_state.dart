import 'dart:ui';

import 'battlefield_projection.dart';

/// Kotlin의 전송 완료와 구분되는, 실제 Godot 렌더 프레임의 적용 확인.
class BattlefieldPresentationState {
  const BattlefieldPresentationState({
    required this.sequence,
    required this.projection,
    required this.groups,
    required this.turretLevels,
  });

  static const protocolVersion = 2;
  static const supportedGroups = {'labels', 'selection', 'effects'};

  final int sequence;
  final BattlefieldProjection projection;
  final Set<String> groups;
  final bool turretLevels;

  /// 이전 장면/화면 크기나 아직 제출하지 않은 프레임의 응답은 적용하지 않는다.
  static BattlefieldPresentationState? tryDecode(
    Map<String, dynamic> state, {
    required int sceneEpoch,
    required int viewportRevision,
    required Size viewport,
    required int lastSubmitted,
    required int lastApplied,
  }) {
    if (state['presentationVersion'] != protocolVersion ||
        state['sceneEpoch'] != sceneEpoch ||
        state['viewportRevision'] != viewportRevision) {
      return null;
    }
    final sequence = state['sequence'];
    final sourceSize = state['viewport'];
    if (sequence is! int ||
        sequence < 0 ||
        sequence < lastApplied ||
        sequence > lastSubmitted ||
        sourceSize is! List ||
        sourceSize.length != 2 ||
        !_sameDimension(sourceSize[0], viewport.width) ||
        !_sameDimension(sourceSize[1], viewport.height)) {
      return null;
    }
    final values = state['projection'];
    if (values is! Map) return null;
    Offset? axis(String name) {
      final data = values[name];
      if (data is! List || data.length != 2) return null;
      final x = data[0];
      final y = data[1];
      if (x is! num || y is! num || !x.isFinite || !y.isFinite) return null;
      return Offset(x * viewport.width, y * viewport.height);
    }

    final origin = axis('origin');
    final xAxis = axis('xAxis');
    final yAxis = axis('yAxis');
    final heightAxis = axis('heightAxis');
    if (origin == null ||
        xAxis == null ||
        yAxis == null ||
        heightAxis == null) {
      return null;
    }
    final projection = BattlefieldProjection(
      origin: origin,
      xAxis: xAxis,
      yAxis: yAxis,
      heightAxis: heightAxis,
    );
    if (projection.screenToGrid(origin) == null) return null;
    final applied = state['appliedGroups'];
    return BattlefieldPresentationState(
      sequence: sequence,
      projection: projection,
      groups: Set.unmodifiable(
        applied is List
            ? applied.whereType<String>().where(supportedGroups.contains)
            : const <String>[],
      ),
      turretLevels: state['nativeTurretLevels'] == true,
    );
  }

  // Godot JSON의 소수 직렬화에서 생기는 미세 반올림만 허용한다.
  // 실제 리사이즈는 viewportRevision과 두 크기 검사로 계속 거절한다.
  static bool _sameDimension(Object? value, double expected) =>
      value is num && value.isFinite && (value - expected).abs() < 1e-6;
}
