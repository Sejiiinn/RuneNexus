@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/local_save_writer_lock.dart';

void main() {
  test('Web에서는 한 탭 컨텍스트만 로컬 저장 writer를 획득한다', () async {
    final first = createLocalSaveWriterLock();
    final second = createLocalSaveWriterLock();

    expect(await first.acquire(), isTrue);
    expect(await second.acquire(), isFalse);

    first.release();
    await Future<void>.delayed(Duration.zero);

    final next = createLocalSaveWriterLock();
    expect(await next.acquire(), isTrue);
    next.release();
  });
}
