@TestOn('browser')
library;

// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/save/local_save_slot.dart';
import 'package:rune_nexus/data/save/online_save_outbox.dart';
import 'package:rune_nexus/data/save/online_save_outbox_file_repository_web.dart';

void main() {
  setUp(_clearKeys);
  tearDown(_clearKeys);

  test('Web 계정별 key에 Outbox를 영속 저장한다', () async {
    final repository = FileOnlineSaveOutboxRepository(
      slot: LocalSaveSlot.account(_accountId),
    );
    final state = OnlineSaveOutboxState.initial(
      accountId: _accountId,
      remoteRevision: 3,
    );

    await repository.save(state);

    expect(html.window.localStorage[_primaryKey], isNotNull);
    expect((await repository.load())?.remoteRevision, 3);
  });

  test('Web primary 손상 시 직전 정상 backup을 복구한다', () async {
    final repository = FileOnlineSaveOutboxRepository(
      slot: LocalSaveSlot.account(_accountId),
    );
    final first = OnlineSaveOutboxState.initial(
      accountId: _accountId,
      remoteRevision: 1,
    );
    await repository.save(first);
    await repository.save(first.copyWith(remoteRevision: 2));
    html.window.localStorage[_primaryKey] = '{broken';

    final restored = await repository.load();

    expect(restored?.remoteRevision, 1);
    expect(html.window.localStorage[_primaryKey], isNot('{broken'));
  });
}

const _accountId = '0198b955-3656-7c40-b3cb-87f427b90be2';
const _primaryKey = 'rune_nexus:outbox:account:$_accountId';
const _backupKey = '$_primaryKey:backup';

void _clearKeys() {
  html.window.localStorage.remove(_primaryKey);
  html.window.localStorage.remove(_backupKey);
}
