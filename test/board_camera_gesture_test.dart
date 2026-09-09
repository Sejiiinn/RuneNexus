import 'helpers/widget_test_helpers.dart';

Future<RuneNexusGame> _mountGame(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  final game = RuneNexusGame(saveRepository: MemorySaveRepository());
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: GameHud(game: game)),
    ),
  );
  await pumpGameFrames(tester, frameCount: 10);
  await tester.runAsync(() => game.loaded.timeout(const Duration(seconds: 10)));
  await pumpGameFrames(tester);
  return game;
}

void main() {
  testWidgets('diagonal pinch keeps zooming out when finger distance shrinks', (
    tester,
  ) async {
    final game = await _mountGame(tester);
    game.handleTrackpadZoomStart(
      const PointerPanZoomStartEvent(position: Offset(200, 400)),
    );
    game.handleTrackpadZoomUpdate(
      const PointerPanZoomUpdateEvent(position: Offset(200, 400), scale: 1.8),
    );
    final first = await tester.startGesture(const Offset(100, 390), pointer: 1);
    final second = await tester.startGesture(
      const Offset(300, 410),
      pointer: 2,
    );
    await first.moveTo(const Offset(120, 392));
    await second.moveTo(const Offset(280, 408));
    await tester.pump();
    final before = game.debugBoardZoom();
    // 두 점 사이 거리는 감소하지만 수직 간격은 증가하는 대각 핀치.
    await first.moveTo(const Offset(140, 385));
    await second.moveTo(const Offset(260, 415));
    await tester.pump();
    expect(game.debugBoardZoom(), lessThan(before));
    expect(game.debugBoardZoom(), lessThan(1.8));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('two finger translation follows the moving pinch center', (
    tester,
  ) async {
    final game = await _mountGame(tester);
    final first = await tester.startGesture(const Offset(100, 400), pointer: 1);
    final second = await tester.startGesture(
      const Offset(300, 400),
      pointer: 2,
    );
    await first.moveBy(const Offset(-20, 0));
    await second.moveBy(const Offset(20, 0));
    await tester.pump();
    final zoom = game.debugBoardZoom();
    final offset = game.debugBoardOffset();
    await first.moveBy(const Offset(0, 25));
    await second.moveBy(const Offset(0, 25));
    await tester.pump();
    expect(game.debugBoardZoom(), closeTo(zoom, 0.001));
    expect(game.debugBoardOffset().x, closeTo(offset.x, 0.001));
    expect(game.debugBoardOffset().y, closeTo(offset.y + 25, 0.001));
    await first.up();
    await second.up();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('pinch resumes from current camera after pointer changes', (
    tester,
  ) async {
    final game = await _mountGame(tester);
    final first = await tester.startGesture(const Offset(100, 400), pointer: 1);
    await first.moveBy(const Offset(0, 30));
    await tester.pump();
    expect(game.debugBoardOffset().y, greaterThan(0));
    final second = await tester.startGesture(
      const Offset(300, 430),
      pointer: 2,
    );
    await first.moveBy(const Offset(-20, 0));
    await second.moveBy(const Offset(20, 0));
    await tester.pump();
    final beforeLift = game.debugBoardZoom();
    expect(beforeLift, greaterThan(1));
    await second.up();
    await tester.pump();
    expect(game.debugBoardZoom(), beforeLift);
    final replacement = await tester.startGesture(
      const Offset(280, 430),
      pointer: 3,
    );
    await first.moveBy(const Offset(5, 0));
    await replacement.moveBy(const Offset(-5, 0));
    await tester.pump();
    expect(game.debugBoardZoom(), lessThan(beforeLift));
    expect(game.debugBoardZoom(), greaterThan(beforeLift * 0.9));
    await first.up();
    await replacement.up();
    await tester.pump(const Duration(milliseconds: 100));
  });

  testWidgets('trackpad zoom and pan pass through the HUD once', (
    tester,
  ) async {
    final game = await _mountGame(tester);
    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.trackpad,
    );
    await gesture.panZoomStart(const Offset(200, 400));
    await gesture.panZoomUpdate(const Offset(200, 400), scale: 1.2);
    await gesture.panZoomUpdate(const Offset(200, 400), scale: 1.5);
    await tester.pump();
    expect(game.debugBoardZoom(), closeTo(1.5, 0.001));
    final offset = game.debugBoardOffset();
    await gesture.panZoomUpdate(
      const Offset(200, 400),
      scale: 1.5,
      pan: const Offset(15, 20),
    );
    await tester.pump();
    expect(game.debugBoardZoom(), closeTo(1.5, 0.001));
    expect(game.debugBoardOffset().x, closeTo(offset.x + 15, 0.001));
    expect(game.debugBoardOffset().y, closeTo(offset.y + 20, 0.001));
    await gesture.panZoomEnd();
    await tester.pump(const Duration(milliseconds: 100));
  });
}
