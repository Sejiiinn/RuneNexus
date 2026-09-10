import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/mailbox/mailbox.dart';
import 'package:rune_nexus/ui/menu/mailbox_dialog.dart';

final now = DateTime.utc(2026, 9, 10);
MailboxItem mail(String id) => MailboxItem(
  id: id,
  title: '업데이트 기념으로 보내드리는 특별한 선물 $id',
  body: '모험가 여러분께 감사드립니다.\n무료 다이아와 모듈권을 받아 주세요.',
  freeDiamonds: 100,
  moduleTickets: 3,
  startsAt: now,
  expiresAt: now.add(const Duration(days: 7)),
);
Widget harness(
  MailboxDialog child, {
  double scale = 1,
  GlobalKey? boundaryKey,
}) => RepaintBoundary(
  key: boundaryKey,
  child: MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData.dark().copyWith(
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'NotoSansKR'),
    ),
    home: Scaffold(
      body: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('게스트는 계정 연결을 안내한다', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      harness(MailboxDialog(onOpenAccount: () => opened = true)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('계정 연결'));
    expect(opened, isTrue);
  });
  testWidgets('작은 화면에서 보상 의미를 유지하며 읽음과 수령을 별도로 처리한다', (tester) async {
    const capture = bool.fromEnvironment('CAPTURE_MAILBOX');
    final boundaryKey = GlobalKey();
    tester.view.physicalSize = capture
        ? const Size(390, 844)
        : const Size(320, 568);
    if (capture) {
      await tester.runAsync(() async {
        final font = FontLoader('NotoSansKR')
          ..addFont(rootBundle.load('assets/fonts/NotoSansKR-VF.ttf'));
        await font.load();
        final icons = FontLoader('MaterialIcons')
          ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
        await icons.load();
      });
    }
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final read = <String>[];
    final claimed = <String>[];
    final pending = Completer<void>();
    await tester.pumpWidget(
      harness(
        MailboxDialog(
          load: ({cursor}) async =>
              MailboxPage(items: [mail('a')], serverTime: now),
          markRead: (id) async => read.add(id),
          claim: (id) async {
            claimed.add(id);
            await pending.future;
          },
          onOpenAccount: () {},
        ),
        scale: capture ? 1 : 1.3,
        boundaryKey: boundaryKey,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('무료 다이아 100'), findsOneWidget);
    expect(find.text('모듈권 3'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mailbox-open-a')));
    await tester.pumpAndSettle();
    expect(read, ['a']);
    expect(find.text('읽음 · 미수령'), findsOneWidget);
    if (capture) {
      await tester.runAsync(() async {
        final context = tester.element(find.byType(MailboxDialog));
        for (final image in tester.widgetList<Image>(find.byType(Image))) {
          await precacheImage(image.image, context);
        }
      });
      await tester.pumpAndSettle();
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('design/screenshots/mailbox-populated-test.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.ensureVisible(find.byKey(const ValueKey('mailbox-claim-a')));
    await tester.tap(find.byKey(const ValueKey('mailbox-claim-a')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('mailbox-claim-a')));
    await tester.pump();
    expect(claimed, ['a']);
    pending.complete();
    await tester.pumpAndSettle();
    expect(find.text('읽음 · 수령 완료'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('커서 페이지를 합치고 모두 받기는 20건으로 제한한다', (tester) async {
    final cursors = <String?>[];
    final batches = <List<String>>[];
    await tester.pumpWidget(
      harness(
        MailboxDialog(
          load: ({cursor}) async {
            cursors.add(cursor);
            return MailboxPage(
              items: List.generate(
                cursor == null ? 20 : 1,
                (i) => mail(cursor == null ? '$i' : '20'),
              ),
              nextCursor: cursor == null ? 'next' : null,
              serverTime: now,
            );
          },
          claimBatch: (ids) async {
            batches.add(ids);
            return MailboxBatchResult(
              results: ids
                  .map((id) => MailboxClaimResult(mailId: id, claimed: true))
                  .toList(),
            );
          },
          onOpenAccount: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('우편 더 보기 · 20건'),
      700,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('우편 더 보기 · 20건'));
    await tester.pumpAndSettle();
    expect(cursors, [null, 'next']);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mailbox-claim-all')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('mailbox-claim-all')));
    await tester.pumpAndSettle();
    expect(batches.single.length, 20);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('mailbox-claim-all')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('모두 받기 · 1건'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
