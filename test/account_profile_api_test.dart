import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/account/account_profile_api.dart';
import 'package:rune_nexus/data/save/online_save_transport_types.dart';
import 'package:rune_nexus/domain/account/account_profile.dart';

void main() {
  test('nickname policy validates Korean, ASCII and mixed boundaries', () {
    for (final value in [
      '가나다라마바사아',
      'abcdefghijklmnop',
      '가나다라12345678',
      ' 가나 ',
    ]) {
      expect(AccountProfile.isValidNickname(value), isTrue, reason: value);
    }
    for (final value in [
      '가나다라마바사아자',
      'abcdefghijklmnopq',
      '가나다라123456789',
      '가',
      '',
      'ab cd',
      'ㄱㄴ',
      'abc#1234',
      'ab😀',
      'éa',
    ]) {
      expect(AccountProfile.isValidNickname(value), isFalse, reason: value);
    }
  });

  test('load and set use bearer auth and preserve leading zero tag', () async {
    final transport = _Transport();
    final api = AccountProfileApi(
      baseUrl: 'https://example.com/api',
      transport: transport,
    );
    final pending = await api.load('token');
    expect(pending.hasNickname, isFalse);
    expect(
      transport.uri.toString(),
      'https://example.com/api/v1/account/profile',
    );
    expect(transport.headers['Authorization'], 'Bearer token');
    transport.body = '{"accountId":"a","nickname":"룬기사","tag":"0038"}';
    final profile = await api.setNickname('token2', nickname: ' 룬기사 ');
    expect(profile.displayName, '룬기사#0038');
    expect(
      transport.uri.toString(),
      'https://example.com/api/v1/account/nickname',
    );
    expect(transport.headers['Authorization'], 'Bearer token2');
    expect(jsonDecode(transport.requestBody!), {'nickname': '룬기사'});
  });

  test('incomplete and malformed successful profiles fail closed', () async {
    final transport = _Transport();
    final api = AccountProfileApi(
      baseUrl: 'https://example.com',
      transport: transport,
    );
    for (final body in [
      '{}',
      '{"accountId":"a"}',
      '{"accountId":"a","nickname":"가나","tag":null}',
      '{"accountId":"a","nickname":"가나","tag":38}',
      '{"accountId":"a","nickname":"가나","tag":"38"}',
      '{"accountId":"a","nickname":"invalid space","tag":"0038"}',
    ]) {
      transport.body = body;
      await expectLater(
        api.load('token'),
        throwsA(isA<AccountProfileException>()),
      );
    }
    transport.body = '{"accountId":"a","nickname":null,"tag":null}';
    await expectLater(
      api.setNickname('token', nickname: '가나'),
      throwsA(isA<AccountProfileException>()),
    );
  });

  test(
    'HTTP errors preserve auth status and nickname exhaustion code',
    () async {
      final transport = _Transport()
        ..status = 401
        ..body = '<html>Unauthorized</html>';
      final api = AccountProfileApi(
        baseUrl: 'https://example.com',
        transport: transport,
      );
      await expectLater(
        api.load('token'),
        throwsA(
          isA<AccountProfileException>().having(
            (e) => e.isUnauthorized,
            'isUnauthorized',
            true,
          ),
        ),
      );
      transport.status = 409;
      transport.body = '{"code":"NICKNAME_TAGS_EXHAUSTED","message":"full"}';
      await expectLater(
        api.setNickname('token', nickname: '가나'),
        throwsA(
          isA<AccountProfileException>().having(
            (e) => e.code,
            'code',
            'NICKNAME_TAGS_EXHAUSTED',
          ),
        ),
      );
    },
  );
}

class _Transport implements OnlineSaveHTTPClient {
  String body = '{"accountId":"a","nickname":null,"tag":null}';
  int status = 200;
  Uri? uri;
  Map<String, String> headers = {};
  String? requestBody;

  @override
  Future<OnlineSaveHTTPResponse> getJSON(
    Uri uri, {
    Map<String, String> headers = const {},
  }) async {
    this.uri = uri;
    this.headers = headers;
    return OnlineSaveHTTPResponse(statusCode: status, body: body);
  }

  @override
  Future<OnlineSaveHTTPResponse> putJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) {
    requestBody = body;
    return getJSON(uri, headers: headers);
  }

  @override
  Future<OnlineSaveHTTPResponse> postJSON(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) => throw UnimplementedError();
}
