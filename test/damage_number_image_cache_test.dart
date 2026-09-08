import 'dart:ui' as ui;

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/components/damage_number_component.dart';

const _color = Color(0xFFFF7043);

ui.Image _image(DamageNumberImageCache cache, String text) => cache.imageFor(
  text: text,
  color: _color,
  feedback: DamageNumberFeedback.neutral,
  size: Vector2(78, 28),
);

DamageNumberComponent _number(DamageNumberImageCache cache, String text) =>
    DamageNumberComponent.cached(
      position: Vector2.zero(),
      imageCache: cache,
      text: text,
      color: _color,
    );

void _render(DamageNumberComponent number) {
  final recorder = ui.PictureRecorder();
  number.render(Canvas(recorder));
  recorder.endRecording().dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('캐시 상한은 양수여야 한다', () {
    for (final limit in [0, -1]) {
      expect(
        () => DamageNumberImageCache(maxEntries: limit),
        throwsArgumentError,
      );
    }
  });

  test('최근 사용한 숫자를 재사용하고 가장 오래된 캐시 핸들을 해제한다', () {
    final cache = DamageNumberImageCache(maxEntries: 2);
    addTearDown(cache.dispose);
    final first = _image(cache, '10');
    final second = _image(cache, '20');
    expect(_image(cache, '10'), same(first));
    final third = _image(cache, '30');
    expect(first.debugDisposed, isFalse);
    expect(second.debugDisposed, isTrue);
    expect(third.debugDisposed, isFalse);
    expect(_image(cache, '20'), isNot(same(second)));
    expect(first.debugDisposed, isTrue);
  });

  test('숫자가 계속 달라져도 기본 캐시에 남는 이미지는 256개 이하이다', () {
    final cache = DamageNumberImageCache();
    final images = [for (var i = 0; i < 300; i++) _image(cache, '$i')];
    expect(images.where((image) => !image.debugDisposed), hasLength(256));
    cache.dispose();
    expect(images.every((image) => image.debugDisposed), isTrue);
    expect(cache.dispose, returnsNormally);
  });

  test('같은 숫자의 색과 피드백 및 크기는 별도 이미지로 유지한다', () {
    final cache = DamageNumberImageCache();
    addTearDown(cache.dispose);
    final neutral = _image(cache, '10');
    final weak = cache.imageFor(
      text: '10',
      color: _color,
      feedback: DamageNumberFeedback.weak,
      size: Vector2(78, 28),
    );
    final healing = cache.imageFor(
      text: '10',
      color: const Color(0xFF72E0A2),
      feedback: DamageNumberFeedback.neutral,
      size: Vector2(78, 28),
    );
    final larger = cache.imageFor(
      text: '10',
      color: _color,
      feedback: DamageNumberFeedback.neutral,
      size: Vector2(100, 28),
    );
    expect({neutral, weak, healing, larger}, hasLength(4));
    expect(larger.width, 200);
  });

  test('캐시에서 퇴출된 숫자도 표시를 유지하고 마지막 표시 종료 때 해제된다', () {
    final cache = DamageNumberImageCache(maxEntries: 1);
    addTearDown(cache.dispose);
    final original = _image(cache, '10');
    final first = _number(cache, '10');
    final second = _number(cache, '10');
    _render(first);
    _render(second);
    expect(original.debugGetOpenHandleStackTraces(), hasLength(3));
    _image(cache, '20');
    expect(original.debugDisposed, isTrue);
    expect(original.debugGetOpenHandleStackTraces(), hasLength(2));
    expect(() => _render(first), returnsNormally);
    first.onRemove();
    expect(original.debugGetOpenHandleStackTraces(), hasLength(1));
    expect(() => _render(second), returnsNormally);
    second.onRemove();
    expect(original.debugGetOpenHandleStackTraces(), isEmpty);
    expect(second.onRemove, returnsNormally);
  });

  test('게임 리소스 정리는 활성 핸들도 해제하고 뒤늦은 제거와 충돌하지 않는다', () {
    final cache = DamageNumberImageCache(maxEntries: 1);
    final original = _image(cache, '10');
    final number = _number(cache, '10');
    _render(number);
    cache.dispose();
    expect(original.debugGetOpenHandleStackTraces(), isEmpty);
    expect(number.onRemove, returnsNormally);
    expect(cache.dispose, returnsNormally);
  });

  test('표시 전에 취소된 숫자는 별도 이미지 핸들을 보유하지 않는다', () {
    final cache = DamageNumberImageCache();
    addTearDown(cache.dispose);
    final original = _image(cache, '10');
    final number = _number(cache, '10');
    number.removeFromParent();
    expect(original.debugGetOpenHandleStackTraces(), hasLength(1));
  });

  testWidgets('게임 화면을 나갔다 돌아와도 표시 중인 숫자를 그릴 수 있다', (tester) async {
    final cache = DamageNumberImageCache(maxEntries: 1);
    final original = _image(cache, '10');
    final game = FlameGame();
    final number = _number(cache, '10');
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    await game.add(number);
    await tester.pump();
    expect(number.isMounted, isTrue);
    _render(number);
    _image(cache, '20');

    await tester.pumpWidget(const SizedBox.shrink());
    expect(original.debugGetOpenHandleStackTraces(), hasLength(1));
    await tester.pumpWidget(GameWidget(game: game));
    await tester.pump();
    expect(() => _render(number), returnsNormally);
    expect(tester.takeException(), isNull);

    number.update(1);
    game.processLifecycleEvents();
    expect(original.debugGetOpenHandleStackTraces(), isEmpty);
    cache.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
