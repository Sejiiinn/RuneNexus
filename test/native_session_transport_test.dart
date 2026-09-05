import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/auth/authentication_transport_io.dart';
import 'package:rune_nexus/data/save/online_save_transport_io.dart';
import 'package:rune_nexus/platform/session/session_storage_android.dart';
import 'package:rune_nexus/platform/auth/google_identity_button_stub.dart';
import 'package:rune_nexus/platform/auth/google_identity_session.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // 로컬 HTTP 서버로 네이티브 통신을 검증하기 위한 Flutter 기본 400 응답 해제.
  HttpOverrides.global = null;

  test('native auth preserves error status and retry header', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final received = server.first.then((request) async {
      expect(request.method, 'POST');
      expect(request.headers.contentType?.mimeType, 'application/json');
      expect(
        await utf8.decoder.bind(request).join(),
        '{"refreshToken":"test"}',
      );
      request.response
        ..statusCode = 429
        ..headers.set('Retry-After', '20')
        ..write('{"error":"rate_limited"}');
      await request.response.close();
    });

    final response = await AuthenticationTransport().postJSON(
      Uri.parse('http://127.0.0.1:${server.port}/v1/auth/native/refresh'),
      body: '{"refreshToken":"test"}',
    );
    await received;
    expect(response.statusCode, 429);
    expect(response.headers['retry-after'], '20');
    expect(response.body, '{"error":"rate_limited"}');
  });

  test('native save keeps bearer requests on the original host', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    var requests = 0;
    server.listen((request) async {
      requests += 1;
      expect(request.headers.value('Authorization'), 'Bearer test');
      request.response
        ..statusCode = 307
        ..headers.set('Location', 'http://127.0.0.1:${server.port}/redirected');
      await request.response.close();
    });
    final response = await OnlineSaveTransport().getJSON(
      Uri.parse('http://127.0.0.1:${server.port}/v1/save'),
      headers: {'Authorization': 'Bearer test'},
    );
    expect(response.statusCode, 307);
    expect(requests, 1);
  });

  test(
    'session storage preserves native damage and transient error codes',
    () async {
      const channel = MethodChannel('rune_nexus/session_storage');
      const storage = PlatformSessionStorage();
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(
          code: call.method == 'read'
              ? 'session_unreadable'
              : 'session_storage_unavailable',
        );
      });
      await expectLater(
        storage.read(),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'session_unreadable',
          ),
        ),
      );
      await expectLater(
        storage.write('new session'),
        throwsA(
          isA<PlatformException>().having(
            (error) => error.code,
            'code',
            'session_storage_unavailable',
          ),
        ),
      );
    },
  );

  testWidgets(
    'cancelled Google sign-in keeps login available for another account',
    (tester) async {
      const channel = MethodChannel('rune_nexus/google_identity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      var attempts = 0;
      var unavailable = 0;
      String? credential;
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.arguments, {'clientId': 'web-server-client-id'});
        attempts += 1;
        if (attempts == 1) throw PlatformException(code: 'sign_in_cancelled');
        return 'google-id-token';
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoogleIdentityButton(
              clientId: 'web-server-client-id',
              onCredential: (value) => credential = value,
              onUnavailable: () => unavailable += 1,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(unavailable, 0);
      expect(credential, isNull);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();
      expect(credential, 'google-id-token');
      expect(attempts, 2);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  test(
    'Google sign-out clears provider selection without touching session storage',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      const channel = MethodChannel('rune_nexus/google_identity');
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
      String? method;
      messenger.setMockMethodCallHandler(channel, (call) async {
        method = call.method;
        return null;
      });
      await clearGoogleIdentitySession();
      expect(method, 'clearCredentialState');
    },
  );
}
