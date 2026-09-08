import 'dart:convert';

import '../../domain/leaderboard/leaderboard.dart';
import '../save/online_save_transport_stub.dart'
    if (dart.library.html) '../save/online_save_transport_web.dart'
    if (dart.library.io) '../save/online_save_transport_io.dart';

class LeaderboardException implements Exception {
  const LeaderboardException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'LeaderboardException($code): $message';
}

class LeaderboardApi {
  LeaderboardApi({required String baseUrl, OnlineSaveHTTPClient? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  Future<LeaderboardSnapshot> load(String accessToken) async {
    final OnlineSaveHTTPResponse response;
    try {
      response = await _transport.getJSON(
        _baseUri.resolve('v1/leaderboards/progression'),
        headers: {'Authorization': 'Bearer $accessToken'},
      );
    } on OnlineSaveTransportException catch (error) {
      throw LeaderboardException(
        code: 'LEADERBOARD_NETWORK_ERROR',
        message: error.message,
      );
    }
    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) decoded = body;
    } on FormatException {
      // 비 JSON 오류 응답에서도 인증 상태 보존.
    }
    if (response.statusCode != 200) {
      throw LeaderboardException(
        code: decoded?['code'] is String
            ? decoded!['code'] as String
            : 'LEADERBOARD_REQUEST_FAILED',
        message: decoded?['message'] is String
            ? decoded!['message'] as String
            : '리더보드를 불러오지 못했습니다.',
        statusCode: response.statusCode,
      );
    }
    if (decoded == null ||
        decoded['rulesVersion'] != 1 ||
        decoded['entries'] is! List ||
        (decoded['entries'] as List).length > 100 ||
        !decoded.containsKey('myEntry')) {
      throw _invalidResponse();
    }
    final entries = (decoded['entries'] as List).map(_entry).toList();
    final mine = decoded['myEntry'] == null ? null : _entry(decoded['myEntry']);
    if (mine != null && !mine.isMe) throw _invalidResponse();
    return LeaderboardSnapshot(
      rulesVersion: 1,
      asOf: _timestamp(decoded['asOf']),
      entries: List.unmodifiable(entries),
      myEntry: mine,
    );
  }

  static LeaderboardEntry _entry(Object? value) {
    if (value is! Map<String, dynamic>) throw _invalidResponse();
    final rank = value['rank'];
    final name = value['displayName'];
    final stage = value['stageNumber'];
    final rounds = value['completedRounds'];
    final isMe = value['isMe'];
    if (rank is! int ||
        rank < 1 ||
        name is! String ||
        name.trim().isEmpty ||
        name.length > 64 ||
        stage is! int ||
        stage < 1 ||
        rounds is! int ||
        rounds < 1 ||
        rounds > 40 ||
        isMe is! bool) {
      throw _invalidResponse();
    }
    return LeaderboardEntry(
      rank: rank,
      displayName: name,
      stageNumber: stage,
      completedRounds: rounds,
      achievedAt: _timestamp(value['achievedAt']),
      isMe: isMe,
    );
  }

  static DateTime _timestamp(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null || !parsed.isUtc) throw _invalidResponse();
    return parsed;
  }

  static LeaderboardException _invalidResponse() => const LeaderboardException(
    code: 'INVALID_LEADERBOARD_RESPONSE',
    message: '리더보드 응답 형식이 올바르지 않습니다.',
  );

  static Uri _apiBaseUri(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !(uri.scheme == 'https' ||
            (uri.scheme == 'http' &&
                const ['localhost', '127.0.0.1', '::1'].contains(uri.host)))) {
      throw const FormatException('유효한 리더보드 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/');
  }
}
