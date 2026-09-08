import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:rune_nexus/data/save/online_save_api.dart';
import 'package:rune_nexus/data/save/online_save_outbox.dart';

import 'helpers/widget_test_helpers.dart';

void main() {
  const configured =
      String.fromEnvironment('GOOGLE_WEB_CLIENT_ID') != '' &&
      String.fromEnvironment('RUNE_NEXUS_API_BASE_URL') != '';
  const sessionChannel = MethodChannel('rune_nexus/session_storage');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');

  group(
    '인증 구성 활성화 시작 경계',
    () {
      testWidgets('닉네임 설정 전 저장 접근을 막고 저장 성공 후 연결한다', (tester) async {
        final api = await _installNicknameSession(tester);
        api.pendingProfile = Completer<Map<String, Object?>>();
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(tester, () => api.profileReads == 1);
        expect(api.gameRequests, isEmpty);
        expect(api.pathRequests, 0);
        expect(find.byType(MainMenuScreen), findsNothing);

        api.pendingProfile!.complete(api.profile);
        await _pumpUntil(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        await tester.binding.handlePopRoute();
        await tester.tapAt(const Offset(4, 4));
        await tester.pump();
        expect(find.byType(TextField), findsOneWidget);
        expect(api.gameRequests, isEmpty);
        expect(api.pathRequests, 0);

        await tester.enterText(find.byType(TextField), '룬마스터');
        await tester.tap(find.text('저장하고 시작하기'));
        await _pumpUntil(tester, () => api.gameRequests.isNotEmpty);
        expect(api.nicknameWrites, 1);
        expect(api.profile['nickname'], '룬마스터');
        expect(api.profile['tag'], '0382');
        expect(find.byType(TextField), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      for (final alreadyNamed in [false, true]) {
        testWidgets('기존 닉네임 차단 outbox 재개: 설정 완료=$alreadyNamed', (tester) async {
          final request = OnlineSaveWriterClaimRequest(
            idempotencyKey: '0198b955-3656-7c40-b3cb-87f427b90be3',
            clientInstanceId: '0198b955-3656-7c40-b3cb-87f427b90be4',
            clientBuild: 'android:previous',
          );
          final outbox =
              OnlineSaveOutboxState.initial(
                accountId: _nicknameAccountId,
                remoteRevision: 1,
              ).copyWith(
                clientInstanceId: request.clientInstanceId,
                dirty: true,
                phase: OnlineSaveOutboxPhase.blocked,
                issueCode: 'NICKNAME_REQUIRED',
                writerClaim: OnlineSaveWriterClaimEntry(
                  idempotencyKey: request.idempotencyKey,
                  encodedRequestBody: request.encodedBody,
                ),
              );
          final api = await _installNicknameSession(
            tester,
            restoredOutbox: outbox,
          );
          if (alreadyNamed) {
            api.profile.addAll({'nickname': '룬기사', 'tag': '0007'});
          }
          await tester.pumpWidget(const RuneNexusApp());
          if (!alreadyNamed) {
            await _pumpUntil(
              tester,
              () => find.byType(TextField).evaluate().isNotEmpty,
            );
            expect(api.gameRequests, isEmpty);
            await tester.enterText(find.byType(TextField), '룬기사');
            await tester.tap(find.text('저장하고 시작하기'));
          }
          await _pumpUntil(
            tester,
            () => api.gameRequests.contains('POST /v1/save/writer'),
          );
          expect(api.writerBody, request.encodedBody);
          expect(find.byType(TextField), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        }, variant: TargetPlatformVariant({TargetPlatform.android}));
      }

      testWidgets('설정된 닉네임 계정은 입력 없이 저장 연결을 시작한다', (tester) async {
        final api = await _installNicknameSession(tester);
        api.profile.addAll({'nickname': '룬기사', 'tag': '0007'});
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(tester, () => api.gameRequests.isNotEmpty);
        expect(api.profileReads, 1);
        expect(api.nicknameWrites, 0);
        expect(find.byType(TextField), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      testWidgets('프로필 조회 실패 후 재시도해도 미설정 계정 저장을 읽지 않는다', (tester) async {
        final api = await _installNicknameSession(tester);
        api.profileFailure = true;
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(
          tester,
          () => find.text('다시 시도').evaluate().isNotEmpty,
        );
        expect(api.gameRequests, isEmpty);
        expect(api.pathRequests, 0);
        api.profileFailure = false;
        await tester.tap(find.text('다시 시도'));
        await _pumpUntil(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        expect(api.profileReads, 2);
        expect(api.gameRequests, isEmpty);
        expect(api.pathRequests, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      testWidgets('복원 중 닉네임 설정에서 로그아웃하면 게스트로 진입한다', (tester) async {
        final api = await _installNicknameSession(tester);
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        await tester.tap(find.text('로그아웃'));
        await pumpUntilLoadedApp(tester);
        expect(api.logouts, 1);
        expect(api.gameRequests, isEmpty);
        expect(api.nicknameWrites, 0);
        expect(find.byType(TextField), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      testWidgets('닉네임 저장 응답 유실 후 재시도는 같은 태그로 연결한다', (tester) async {
        final api = await _installNicknameSession(tester);
        api.loseNicknameResponse = true;
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        await tester.enterText(find.byType(TextField), '룬마스터');
        await tester.tap(find.text('저장하고 시작하기'));
        await _pumpUntil(
          tester,
          () =>
              api.nicknameWrites == 1 &&
              find.text('저장하고 시작하기').evaluate().isNotEmpty,
        );
        expect(api.gameRequests, isEmpty);
        expect(api.pathRequests, 0);
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '룬마스터',
        );
        final assignedTag = api.profile['tag'];
        await tester.tap(find.text('저장하고 시작하기'));
        await _pumpUntil(tester, () => api.gameRequests.isNotEmpty);
        expect(api.nicknameWrites, 2);
        expect(api.profile['tag'], assignedTag);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      testWidgets('세션 무효화 뒤 늦은 닉네임 저장 결과는 게스트를 변경하지 않는다', (tester) async {
        final api = await _installNicknameSession(tester);
        api.accessLifetime = const Duration(seconds: 65);
        api.pendingNickname = Completer<void>();
        await tester.pumpWidget(const RuneNexusApp());
        await _pumpUntil(
          tester,
          () => find.byType(TextField).evaluate().isNotEmpty,
        );
        await tester.enterText(find.byType(TextField), '룬마스터');
        await tester.tap(find.text('저장하고 시작하기'));
        await _pumpUntil(tester, () => api.nicknameWrites == 1);
        api.refreshInvalid = true;
        await tester.pump(const Duration(seconds: 6));
        await pumpUntilLoadedApp(tester);
        expect(api.logouts, 1);
        expect(find.byType(TextField), findsNothing);
        expect(api.gameRequests, isEmpty);
        api.pendingNickname!.complete();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.byType(MainMenuScreen), findsOneWidget);
        expect(find.text('룬마스터#0382'), findsNothing);
        expect(api.gameRequests, isEmpty);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }, variant: TargetPlatformVariant({TargetPlatform.android}));

      testWidgets(
        '세션 판정 전에는 게스트 저장을 읽지 않고 세션 없음 확인 뒤 진입한다',
        (tester) async {
          late Directory directory;
          await tester.runAsync(() async {
            directory = await Directory.systemTemp.createTemp(
              'rune_nexus_gate_',
            );
            final saveFile = File('${directory.path}/saves/guest/save_v2.json');
            await saveFile.parent.create(recursive: true);
            await saveFile.writeAsString(
              jsonEncode({
                'version': 2,
                'savedAtMillis': 100,
                'preferences': <String, Object?>{},
                'progression': {'runes': 2468},
                'turretModules': <String, Object?>{},
                'activeRun': null,
              }),
            );
          });
          addTearDown(() => directory.delete(recursive: true));
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          final sessionRead = Completer<String?>();
          var sessionReads = 0;
          var pathRequests = 0;
          messenger.setMockMethodCallHandler(sessionChannel, (call) async {
            expect(call.method, 'read');
            sessionReads++;
            return sessionRead.future;
          });
          messenger.setMockMethodCallHandler(pathChannel, (call) async {
            expect(call.method, 'getApplicationSupportDirectory');
            pathRequests++;
            return directory.path;
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(sessionChannel, null);
            messenger.setMockMethodCallHandler(pathChannel, null);
          });

          await tester.pumpWidget(const RuneNexusApp());
          await tester.pump(const Duration(seconds: 1));

          expect(sessionReads, 1);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          expect(find.text('초기화에 실패했습니다'), findsNothing);

          sessionRead.complete(null);
          await pumpUntilLoadedApp(tester);

          expect(pathRequests, 1);
          expect(
            tester
                .widget<MainMenuScreen>(find.byType(MainMenuScreen))
                .game
                .snapshotNotifier
                .value
                .runes,
            2468,
          );
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({TargetPlatform.android}),
      );

      testWidgets(
        '세션 저장소 일시 장애와 재시도 중에도 게스트 진입을 막는다',
        (tester) async {
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          var sessionReads = 0;
          var pathRequests = 0;
          messenger.setMockMethodCallHandler(sessionChannel, (call) async {
            expect(call.method, 'read');
            sessionReads++;
            throw PlatformException(code: 'session_storage_unavailable');
          });
          messenger.setMockMethodCallHandler(pathChannel, (call) async {
            pathRequests++;
            throw StateError('세션 장애 중 게스트 저장소를 조회하면 안 됩니다.');
          });
          addTearDown(() {
            messenger.setMockMethodCallHandler(sessionChannel, null);
            messenger.setMockMethodCallHandler(pathChannel, null);
          });

          await tester.pumpWidget(const RuneNexusApp());
          await _pumpUntilError(tester);

          expect(sessionReads, 1);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          await tester.tap(find.text('다시 시도'));
          await tester.pump();
          await _pumpUntilError(tester);

          expect(sessionReads, 2);
          expect(pathRequests, 0);
          expect(find.byType(MainMenuScreen), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        variant: TargetPlatformVariant({TargetPlatform.android}),
      );
    },
    skip: configured
        ? false
        : 'GOOGLE_WEB_CLIENT_ID와 RUNE_NEXUS_API_BASE_URL dart-define이 필요한 인증 시작 통합 테스트',
  );
}

Future<void> _pumpUntilError(WidgetTester tester) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (find.text('초기화에 실패했습니다').evaluate().isNotEmpty) return;
  }
  fail('세션 저장소 오류 화면이 표시되지 않았습니다.');
}

const _nicknameAccountId = '0198b955-3656-7c40-b3cb-87f427b90be2';

Future<_NicknameHTTP> _installNicknameSession(
  WidgetTester tester, {
  OnlineSaveOutboxState? restoredOutbox,
}) async {
  final api = _NicknameHTTP();
  final previous = HttpOverrides.current;
  HttpOverrides.global = api;
  late Directory directory;
  await tester.runAsync(() async {
    directory = await Directory.systemTemp.createTemp('rune_nexus_nickname_');
    if (restoredOutbox != null) {
      final slot = Directory(
        '${directory.path}/saves/accounts/$_nicknameAccountId',
      );
      await slot.create(recursive: true);
      await File(
        '${slot.path}/outbox.json',
      ).writeAsString(jsonEncode(restoredOutbox.toJson()));
      await File('${slot.path}/save_v2.json').writeAsString(
        jsonEncode({
          'version': 2,
          'savedAtMillis': 100,
          'preferences': <String, Object?>{},
          'progression': {'runes': 2468},
          'turretModules': <String, Object?>{},
          'activeRun': null,
        }),
      );
    }
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const sessionChannel = MethodChannel('rune_nexus/session_storage');
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  const googleChannel = MethodChannel('rune_nexus/google_identity');
  String? session = jsonEncode({
    'version': 1,
    'apiBaseUrl': const String.fromEnvironment('RUNE_NEXUS_API_BASE_URL'),
    'accountId': _nicknameAccountId,
    'refreshToken': 'stored-refresh',
    'logoutPending': false,
  });
  messenger.setMockMethodCallHandler(sessionChannel, (call) async {
    switch (call.method) {
      case 'read':
        return session;
      case 'write':
        session = (call.arguments as Map)['value'] as String;
        return null;
      case 'delete':
        session = null;
        return null;
    }
    throw StateError('Unexpected session operation: ${call.method}');
  });
  messenger.setMockMethodCallHandler(pathChannel, (call) async {
    api.pathRequests++;
    return directory.path;
  });
  messenger.setMockMethodCallHandler(googleChannel, (_) async => null);
  addTearDown(() async {
    HttpOverrides.global = previous;
    messenger.setMockMethodCallHandler(sessionChannel, null);
    messenger.setMockMethodCallHandler(pathChannel, null);
    messenger.setMockMethodCallHandler(googleChannel, null);
    await directory.delete(recursive: true);
  });
  return api;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var i = 0; i < 150; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 16));
    if (condition()) return;
  }
  fail('닉네임 계정 흐름이 예상 단계에 도달하지 않았습니다.');
}

// 앱이 실제 인증·프로필 transport를 통과하도록 HTTP 경계만 대체.
class _NicknameHTTP extends HttpOverrides {
  final profile = <String, Object?>{
    'accountId': _nicknameAccountId,
    'nickname': null,
    'tag': null,
  };
  Completer<Map<String, Object?>>? pendingProfile;
  bool profileFailure = false;
  bool loseNicknameResponse = false;
  bool refreshInvalid = false;
  Duration accessLifetime = const Duration(hours: 1);
  Completer<void>? pendingNickname;
  int profileReads = 0;
  int nicknameWrites = 0;
  int logouts = 0;
  int pathRequests = 0;
  final gameRequests = <String>[];
  String? writerBody;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      _NicknameClient(this);

  Future<HttpClientResponse> respond(
    String method,
    Uri uri,
    String body,
  ) async {
    if (uri.path.endsWith('/refresh')) {
      if (refreshInvalid) {
        return _NicknameResponse(401, {
          'code': 'REFRESH_TOKEN_INVALID',
          'message': '세션 만료',
        });
      }
      return _NicknameResponse(200, {
        'account': {'id': _nicknameAccountId},
        'accessToken': 'test-access',
        'accessExpiresAt': DateTime.now()
            .toUtc()
            .add(accessLifetime)
            .toIso8601String(),
        'refreshToken': 'rotated-refresh',
      });
    }
    if (uri.path.endsWith('/logout')) {
      logouts++;
      return _NicknameResponse(204, null);
    }
    if (uri.path == '/v1/account/profile') {
      profileReads++;
      if (profileFailure) {
        return _NicknameResponse(503, {
          'code': 'PROFILE_UNAVAILABLE',
          'message': '프로필 조회 실패',
        });
      }
      return _NicknameResponse(
        200,
        pendingProfile == null ? profile : await pendingProfile!.future,
      );
    }
    if (uri.path == '/v1/account/nickname') {
      expect(method, 'PUT');
      nicknameWrites++;
      if (pendingNickname != null) await pendingNickname!.future;
      profile.addAll({
        'nickname': (jsonDecode(body) as Map)['nickname'],
        'tag': '0382',
      });
      if (loseNicknameResponse) {
        loseNicknameResponse = false;
        throw const SocketException('저장은 완료되었으나 응답 유실');
      }
      return _NicknameResponse(200, profile);
    }
    // 저장 연결의 첫 호출까지만 검증하고 이후 서버 상태는 명시적 실패 처리.
    if (uri.path == '/v1/save/writer') writerBody = body;
    gameRequests.add('$method ${uri.path}');
    return _NicknameResponse(503, {
      'code': 'SERVICE_UNAVAILABLE',
      'message': '테스트 저장 서버 일시 중단',
    });
  }
}

class _NicknameClient implements HttpClient {
  _NicknameClient(this.api);
  final _NicknameHTTP api;
  @override
  Future<HttpClientRequest> postUrl(Uri uri) => openUrl('POST', uri);
  @override
  Future<HttpClientRequest> openUrl(String method, Uri uri) async =>
      _NicknameRequest(api, method, uri);
  @override
  void close({bool force = false}) {}
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NicknameRequest implements HttpClientRequest {
  _NicknameRequest(this.api, this.method, this.uri);
  final _NicknameHTTP api;
  @override
  final String method;
  @override
  final Uri uri;
  final _body = StringBuffer();
  @override
  final HttpHeaders headers = _NicknameHeaders();
  @override
  void write(Object? object) => _body.write(object);
  @override
  Future<HttpClientResponse> close() =>
      api.respond(method, uri, _body.toString());
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NicknameHeaders implements HttpHeaders {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _NicknameResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _NicknameResponse(this.statusCode, Object? body)
    : _stream = Stream.value(
        body == null ? <int>[] : utf8.encode(jsonEncode(body)),
      );
  final Stream<List<int>> _stream;
  @override
  final int statusCode;
  @override
  final HttpHeaders headers = _NicknameHeaders();
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => _stream.listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
