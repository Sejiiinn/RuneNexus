import 'dart:convert';

import '../../domain/account/account_profile.dart';
import '../save/online_save_transport_stub.dart'
    if (dart.library.html) '../save/online_save_transport_web.dart'
    if (dart.library.io) '../save/online_save_transport_io.dart';

class AccountProfileException implements Exception {
  const AccountProfileException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;
  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'AccountProfileException($code): $message';
}

class AccountProfileApi {
  AccountProfileApi({required String baseUrl, OnlineSaveHTTPClient? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  Future<AccountProfile> load(String accessToken) => _request(
    () => _transport.getJSON(
      _baseUri.resolve('v1/account/profile'),
      headers: {'Authorization': 'Bearer $accessToken'},
    ),
  );

  Future<AccountProfile> setNickname(
    String accessToken, {
    required String nickname,
  }) async {
    final profile = await _request(
      () => _transport.putJSON(
        _baseUri.resolve('v1/account/nickname'),
        body: jsonEncode({'nickname': nickname.trim()}),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    if (!profile.hasNickname) throw _invalidResponse();
    return profile;
  }

  Future<AccountProfile> _request(
    Future<OnlineSaveHTTPResponse> Function() operation,
  ) async {
    final OnlineSaveHTTPResponse response;
    try {
      response = await operation();
    } on OnlineSaveTransportException catch (error) {
      throw AccountProfileException(
        code: 'PROFILE_NETWORK_ERROR',
        message: error.message,
      );
    }
    Map<String, dynamic>? decoded;
    try {
      final body = jsonDecode(response.body);
      if (body is Map<String, dynamic>) decoded = body;
    } on FormatException {
      // 비 JSON 오류 응답도 HTTP 상태 보존.
    }
    if (response.statusCode != 200) {
      throw AccountProfileException(
        code: decoded?['code'] is String
            ? decoded!['code'] as String
            : 'PROFILE_REQUEST_FAILED',
        message: decoded?['message'] is String
            ? decoded!['message'] as String
            : '계정 프로필 요청을 처리하지 못했습니다.',
        statusCode: response.statusCode,
      );
    }
    final accountId = decoded?['accountId'];
    final nickname = decoded?['nickname'];
    final tag = decoded?['tag'];
    if (accountId is! String ||
        accountId.isEmpty ||
        decoded == null ||
        !decoded.containsKey('nickname') ||
        !decoded.containsKey('tag')) {
      throw _invalidResponse();
    }
    if (nickname == null && tag == null) {
      return AccountProfile(accountId: accountId);
    }
    if (nickname is! String ||
        nickname != nickname.trim() ||
        !AccountProfile.isValidNicknameFormat(nickname) ||
        tag is! String ||
        !RegExp(r'^[0-9]{4}$').hasMatch(tag)) {
      throw _invalidResponse();
    }
    return AccountProfile(accountId: accountId, nickname: nickname, tag: tag);
  }

  static AccountProfileException _invalidResponse() =>
      const AccountProfileException(
        code: 'INVALID_PROFILE_RESPONSE',
        message: '계정 프로필 응답 형식이 올바르지 않습니다.',
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
      throw const FormatException('유효한 계정 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/');
  }
}
