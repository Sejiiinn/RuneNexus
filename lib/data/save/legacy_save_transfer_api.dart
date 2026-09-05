import 'dart:convert';

import 'game_save_data.dart';
import 'online_save_api.dart';
import 'online_save_transport_stub.dart'
    if (dart.library.html) 'online_save_transport_web.dart'
    if (dart.library.io) 'online_save_transport_io.dart';

class LegacySaveTransferException implements Exception {
  const LegacySaveTransferException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.retryAfter,
    this.transportFailure = false,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final Duration? retryAfter;
  final bool transportFailure;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'LegacySaveTransferException($code): $message';
}

class LegacySaveTransferDraft {
  const LegacySaveTransferDraft({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

class LegacySaveTransferConsumeResult {
  const LegacySaveTransferConsumeResult({
    required this.revision,
    required this.serverSavedAt,
  });

  final int revision;
  final DateTime serverSavedAt;
}

class LegacySaveTransferApi {
  LegacySaveTransferApi({
    required String baseUrl,
    OnlineSaveHTTPClient? transport,
  }) : _baseUri = _apiBaseUri(baseUrl),
       _transport = transport ?? OnlineSaveTransport();

  static final RegExp _tokenPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  static bool isValidToken(String value) => _tokenPattern.hasMatch(value);

  Future<LegacySaveTransferDraft> create(GameSaveData data) async {
    final response = await _post(
      _baseUri.resolve('v1/legacy-save-transfers'),
      body: jsonEncode({
        'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
        'data': data.toJson(),
      }),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 201) {
      throw _responseException(
        response,
        decoded,
        fallbackMessage: '기존 진행 이전 링크를 만들지 못했습니다.',
      );
    }
    final token = _stringValue(decoded, 'token');
    final expiresAt = DateTime.tryParse(
      _stringValue(decoded, 'expiresAt') ?? '',
    )?.toUtc();
    if (token == null || !isValidToken(token) || expiresAt == null) {
      throw const LegacySaveTransferException(
        code: 'INVALID_LEGACY_TRANSFER_RESPONSE',
        message: '기존 진행 이전 응답 형식이 올바르지 않습니다.',
      );
    }
    return LegacySaveTransferDraft(token: token, expiresAt: expiresAt);
  }

  Future<LegacySaveTransferConsumeResult> consume(
    String accessToken, {
    required String token,
  }) async {
    if (!isValidToken(token)) {
      throw const LegacySaveTransferException(
        code: 'LEGACY_TRANSFER_INVALID',
        message: '이전 링크가 유효하지 않습니다.',
      );
    }
    final response = await _post(
      _baseUri.resolve('v1/legacy-save-transfers/consume'),
      body: jsonEncode({'token': token}),
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw _responseException(
        response,
        decoded,
        fallbackMessage: '기존 진행을 계정에 연결하지 못했습니다.',
      );
    }
    final revision = _positiveInt(decoded?['revision']);
    final serverSavedAt = DateTime.tryParse(
      _stringValue(decoded, 'serverSavedAt') ?? '',
    )?.toUtc();
    if (revision == null || serverSavedAt == null) {
      throw const LegacySaveTransferException(
        code: 'INVALID_LEGACY_TRANSFER_RESPONSE',
        message: '기존 진행 연결 응답 형식이 올바르지 않습니다.',
      );
    }
    return LegacySaveTransferConsumeResult(
      revision: revision,
      serverSavedAt: serverSavedAt,
    );
  }

  Future<OnlineSaveHTTPResponse> _post(
    Uri uri, {
    required String body,
    Map<String, String> headers = const {},
  }) async {
    try {
      return await _transport.postJSON(uri, body: body, headers: headers);
    } on OnlineSaveTransportException catch (error) {
      throw LegacySaveTransferException(
        code: 'LEGACY_TRANSFER_NETWORK_ERROR',
        message: error.message,
        transportFailure: true,
      );
    }
  }

  LegacySaveTransferException _responseException(
    OnlineSaveHTTPResponse response,
    Map<String, dynamic>? decoded, {
    required String fallbackMessage,
  }) {
    return LegacySaveTransferException(
      code: _stringValue(decoded, 'code') ?? 'LEGACY_TRANSFER_FAILED',
      message: _stringValue(decoded, 'message') ?? fallbackMessage,
      statusCode: response.statusCode,
      requestId: _stringValue(decoded, 'requestId'),
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  static Uri _apiBaseUri(String baseUrl) {
    final normalized = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    final uri = Uri.tryParse(normalized);
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !_supportedScheme(uri)) {
      throw const FormatException('유효한 기존 진행 이전 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/');
  }

  static bool _supportedScheme(Uri uri) {
    if (uri.scheme == 'https') {
      return true;
    }
    if (uri.scheme != 'http') {
      return false;
    }
    return uri.host == 'localhost' ||
        uri.host == '127.0.0.1' ||
        uri.host == '::1';
  }

  static Map<String, dynamic>? _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }

  static String? _stringValue(Map<String, dynamic>? object, String key) {
    final value = object?[key];
    return value is String ? value : null;
  }

  static int? _positiveInt(Object? value) {
    return value is int && value > 0 ? value : null;
  }

  static Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}
