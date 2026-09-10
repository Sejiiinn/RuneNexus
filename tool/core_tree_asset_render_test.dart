import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _assetRoot = 'assets/images/core_passive_tree/';

// flutter test tool/core_tree_asset_render_test.dart
// 원본 PNG를 수정하지 않는 제작 에셋 크기·알파 확인용 접촉 시트.
void main() {
  testWidgets('코어 트리 준비 에셋 기본·점등 크기 비교 렌더', (tester) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    late ui.Image connection;
    late ui.Image inactiveConnection;
    await tester.runAsync(() async {
      await (FontLoader(
        'NotoSansKR',
      )..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'))).load();
      final bytes = await rootBundle.load(
        '${_assetRoot}connection_segment_v1.png',
      );
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      connection = (await codec.getNextFrame()).image;
      codec.dispose();
      final inactiveFile = File(
        '${_assetRoot}connection_segment_inactive_v1.png',
      );
      final inactiveCodec = await ui.instantiateImageCodec(
        await inactiveFile.readAsBytes(),
      );
      inactiveConnection = (await inactiveCodec.getNextFrame()).image;
      inactiveCodec.dispose();
    });
    addTearDown(() {
      connection.dispose();
      inactiveConnection.dispose();
    });
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: Brightness.dark, fontFamily: 'NotoSansKR'),
        home: RepaintBoundary(
          key: boundaryKey,
          child: Scaffold(
            body: CustomPaint(
              painter: const _Checkerboard(),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      '코어 트리 · 기본 / 점등 에셋 비교',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Text(
                      '같은 이미지 박스에서 기본 / 점등 비교 · 체크무늬는 투명 영역 · 하단 비교는 2배 확대',
                      style: TextStyle(fontSize: 14, color: Color(0xFFB7CAD5)),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 610,
                      child: Row(
                        children: [
                          for (final item in const [
                            ('소형 A', 'small', 48.0),
                            ('중형 A', 'medium', 68.0),
                            ('대형 A', 'large', 96.0),
                          ])
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    '${item.$1}  ·  ${item.$3.toInt()} × ${item.$3.toInt()} px',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  const Row(
                                    children: [
                                      Expanded(
                                        child: Center(child: Text('기본')),
                                      ),
                                      Expanded(
                                        child: Center(child: Text('점등')),
                                      ),
                                    ],
                                  ),
                                  SizedBox(
                                    height: 120,
                                    child: Row(
                                      children: [
                                        for (final state in ['', '_active'])
                                          Expanded(
                                            child: Center(
                                              child: _png(
                                                'node_frame_${item.$2}_a${state}_v1',
                                                item.$3,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  const Text(
                                    '2배 확대 비교',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF91A8B8),
                                    ),
                                  ),
                                  Expanded(
                                    child: Row(
                                      children: [
                                        for (final state in ['', '_active'])
                                          Expanded(
                                            child: Center(
                                              child: _png(
                                                'node_frame_${item.$2}_a${state}_v1',
                                                item.$3 * 2,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF4C6576), height: 22),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(
                            child: _SupportPreview(
                              title: '연결선',
                              subtitle: '150 × 6 px · 유효 영역 사용',
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    '기본',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: 150,
                                    height: 6,
                                    child: CustomPaint(
                                      painter: _ConnectionPreview(
                                        inactiveConnection,
                                        const Rect.fromLTWH(28, 239, 2120, 238),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  const Text(
                                    '점등',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  const SizedBox(height: 10),
                                  CustomPaint(
                                    size: const Size(150, 6),
                                    painter: _ConnectionPreview(
                                      connection,
                                      const Rect.fromLTWH(55, 485, 1426, 54),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _SupportPreview(
                              title: '연결 매듭',
                              subtitle: '12 × 12 px / 오른쪽은 3배',
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _png('connection_junction_v1', 12),
                                  const SizedBox(width: 28),
                                  _png('connection_junction_v1', 36),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _SupportPreview(
                              title: '선택 링 + 중형 노드',
                              subtitle: '링 96 px · 노드 68 px',
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  _png('selection_ring_v1', 96),
                                  _png('node_frame_medium_a_v1', 68),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: _SupportPreview(
                              title: '중앙 코어 소켓',
                              subtitle: '128 × 128 px',
                              child: _png('center_socket_v1', 128),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '제작 에셋 미리보기 · 게임 화면 적용 전 · 노드 중앙에는 실제 스킬 아이콘 배치 예정',
                      style: TextStyle(fontSize: 13, color: Color(0xFFB7CAD5)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final context = tester.element(find.byType(Scaffold));
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        await precacheImage(image.image, context);
      }
    });
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File(
        'design/core_tree_concepts/production/asset-preview.png',
      );
      await output.parent.create(recursive: true);
      await output.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  });
}

Widget _png(String name, double size) => Image.asset(
  '$_assetRoot$name.png',
  width: size,
  height: size,
  fit: BoxFit.contain,
  filterQuality: FilterQuality.high,
);

class _SupportPreview extends StatelessWidget {
  const _SupportPreview({
    required this.title,
    required this.subtitle,
    required this.child,
  });
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF91A8B8)),
      ),
      Expanded(child: Center(child: child)),
    ],
  );
}

class _ConnectionPreview extends CustomPainter {
  const _ConnectionPreview(this.image, this.sourceRect);
  final ui.Image image;
  final Rect sourceRect;

  @override
  void paint(Canvas canvas, Size size) {
    // 넓은 투명 패딩을 제외한 연결선의 유효 영역.
    canvas.drawImageRect(
      image,
      sourceRect,
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.high,
    );
  }

  @override
  bool shouldRepaint(covariant _ConnectionPreview oldDelegate) =>
      image != oldDelegate.image || sourceRect != oldDelegate.sourceRect;
}

class _Checkerboard extends CustomPainter {
  const _Checkerboard();

  @override
  void paint(Canvas canvas, Size size) {
    const cell = 12.0;
    final paint = Paint();
    for (var y = 0.0; y < size.height; y += cell) {
      for (var x = 0.0; x < size.width; x += cell) {
        paint.color = ((x / cell).floor() + (y / cell).floor()).isEven
            ? const Color(0xFF102431)
            : const Color(0xFF162D3A);
        canvas.drawRect(Rect.fromLTWH(x, y, cell, cell), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _Checkerboard oldDelegate) => false;
}
