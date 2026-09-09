import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart' show Vector2;

/// 전장 시점과 좌표 변환 소유. 입력 허용 여부·게임 단계는 호출자가 결정.
class BoardCamera {
  static const double minZoom = 1;
  static const double maxZoom = 2.1;
  static const double _basePanRatio = 0.2;

  double _zoom = minZoom;
  Vector2 _offset = Vector2.zero();
  late Vector2 _center;
  late Vector2 _boardSize;
  late double _tileSize;
  double? _gestureStartZoom;
  Vector2 _gestureStartOffset = Vector2.zero();
  Vector2 _gestureStartFocal = Vector2.zero();

  double get zoom => _zoom;
  Vector2 get offset => _offset.clone();
  Vector2 get center => _center.clone();

  void configure({
    required Vector2 center,
    required Vector2 boardSize,
    required double tileSize,
    Rect? interactionViewport,
  }) {
    _center = center.clone();
    _boardSize = boardSize.clone();
    _tileSize = tileSize;
    // 화면 크기 변경 시 현재 시점을 유지하고 새 이동 경계만 적용.
    _offset = clampOffset(
      _offset,
      _zoom,
      interactionViewport: interactionViewport,
    );
    endGesture();
  }

  void reset() {
    _zoom = minZoom;
    _offset = Vector2.zero();
    endGesture();
  }

  void beginGesture(Vector2 focal) {
    _gestureStartZoom = _zoom;
    _gestureStartOffset = _offset.clone();
    _gestureStartFocal = focal.clone();
  }

  void endGesture() {
    _gestureStartZoom = null;
  }

  void updateGesture({required double scale, required Vector2 focal}) {
    final startZoom = _gestureStartZoom;
    if (startZoom == null || !scale.isFinite || scale <= 0) {
      return;
    }
    final anchoredWorld =
        _center +
        (_gestureStartFocal - _gestureStartOffset - _center) / startZoom;
    _zoom = (startZoom * scale).clamp(minZoom, maxZoom);
    // 시작 지점의 전장 좌표가 현재 손가락 중심을 따라 이동.
    _offset = clampOffset(
      focal - _center - (anchoredWorld - _center) * _zoom,
      _zoom,
    );
  }

  void moveBy(Vector2 delta, {Rect? interactionViewport}) {
    _offset = clampOffset(
      _offset + delta,
      _zoom,
      interactionViewport: interactionViewport,
    );
  }

  /// 연출이 계산한 시점 적용. 보간 중인 위치는 다시 경계 보정하지 않음.
  void setView({required double zoom, required Vector2 offset}) {
    _zoom = zoom.clamp(minZoom, maxZoom);
    _offset = offset.clone();
  }

  Vector2 worldToScreen(Vector2 position) =>
      _center + (position - _center) * _zoom + _offset;

  Vector2 screenToWorld(Vector2 position) {
    if (_zoom == minZoom && _offset.length2 == 0) {
      return position;
    }
    return _center + (position - _offset - _center) / _zoom;
  }

  void applyTransform(Canvas canvas) {
    if (_zoom == minZoom && _offset.length2 == 0) {
      return;
    }
    canvas
      ..translate(_offset.x, _offset.y)
      ..translate(_center.x, _center.y)
      ..scale(_zoom)
      ..translate(-_center.x, -_center.y);
  }

  Vector2 panLimitForZoom(double zoom) {
    final zoomOverflow = math.max(0, zoom - minZoom);
    final basePanX = math.max(_tileSize * 0.8, _boardSize.x * _basePanRatio);
    final basePanY = math.max(_tileSize * 1.8, _boardSize.y * _basePanRatio);
    return Vector2(
      _boardSize.x * zoomOverflow / 2 + basePanX,
      _boardSize.y * zoomOverflow / 2 + basePanY,
    );
  }

  Vector2 clampOffset(
    Vector2 offset,
    double zoom, {
    Rect? interactionViewport,
  }) {
    final limit = panLimitForZoom(zoom);
    final viewport = interactionViewport;
    if (viewport != null) {
      // 설명 패널에 가려진 가장자리 포탑도 드래그로 노출 가능한 범위.
      final halfWidth = _boardSize.x * zoom / 2;
      final halfHeight = _boardSize.y * zoom / 2;
      return Vector2(
        offset.x
            .clamp(
              math.min(-limit.x, viewport.right - _center.x - halfWidth),
              math.max(limit.x, viewport.left - _center.x + halfWidth),
            )
            .toDouble(),
        offset.y
            .clamp(
              math.min(-limit.y, viewport.bottom - _center.y - halfHeight),
              math.max(limit.y, viewport.top - _center.y + halfHeight),
            )
            .toDouble(),
      );
    }
    return Vector2(
      offset.x.clamp(-limit.x, limit.x).toDouble(),
      offset.y.clamp(-limit.y, limit.y).toDouble(),
    );
  }
}
