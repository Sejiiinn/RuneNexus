import 'package:flame/components.dart';

/// 단일 포인터 드래그 추적과 드래그 이후 탭 억제.
class BoardGestureController {
  final Set<int> _pointers = {};
  int? _dragPointer;
  Vector2? _lastPosition;
  double _dragDistance = 0;
  bool suppressNextTap = false;

  void pointerDown(int pointer, Vector2 position) {
    _pointers.add(pointer);
    if (_pointers.length != 1) {
      _dragPointer = null;
      _lastPosition = null;
      _dragDistance = 0;
      return;
    }
    _dragPointer = pointer;
    _lastPosition = position.clone();
    _dragDistance = 0;
  }

  /// 이동 임계값 도달 이후의 현재 이벤트 변위. 이전 변위는 누적 적용하지 않음.
  Vector2? pointerMove(int pointer, Vector2 position) {
    if (_pointers.length != 1 || _dragPointer != pointer) {
      return null;
    }
    final lastPosition = _lastPosition;
    if (lastPosition == null) {
      return null;
    }
    final delta = position - lastPosition;
    _lastPosition = position.clone();
    _dragDistance += delta.length;
    if (_dragDistance < 4) {
      return null;
    }
    if (_dragDistance >= 8) {
      suppressNextTap = true;
    }
    return delta;
  }

  void pointerEnd(int pointer, {required bool clearTapSuppression}) {
    if (clearTapSuppression) {
      // 보상 대상 선택의 탭 완료 판정 이후 억제 해제.
      suppressNextTap = false;
    }
    _pointers.remove(pointer);
    if (_dragPointer == pointer) {
      _dragPointer = null;
      _lastPosition = null;
      _dragDistance = 0;
    }
  }
}
