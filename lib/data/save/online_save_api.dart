import 'dart:convert';

import 'game_save_data.dart';
import 'online_save_transport_stub.dart'
    if (dart.library.html) 'online_save_transport_web.dart';

abstract interface class OnlineSaveClient {
  Future<OnlineSaveSnapshot?> load(String accessToken);

  Future<OnlineSaveUpdateResult> update(
    String accessToken,
    OnlineSaveUpdateRequest request,
  );
}

class OnlineSaveSnapshot {
  const OnlineSaveSnapshot({
    required this.revision,
    required this.serverSavedAt,
    required this.data,
  });

  final int revision;
  final DateTime serverSavedAt;
  final GameSaveData data;
}

class OnlineSaveUpdateResult {
  const OnlineSaveUpdateResult({
    required this.revision,
    required this.serverSavedAt,
  });

  final int revision;
  final DateTime serverSavedAt;
}

class OnlineSaveUpdateRequest {
  factory OnlineSaveUpdateRequest({
    required int expectedRevision,
    required String idempotencyKey,
    required GameSaveData data,
  }) {
    return OnlineSaveUpdateRequest._(
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      encodedBody: jsonEncode({
        'expectedRevision': expectedRevision,
        'data': data.toJson(),
      }),
    );
  }

  factory OnlineSaveUpdateRequest.fromPersisted({
    required int expectedRevision,
    required String idempotencyKey,
    required String encodedBody,
  }) {
    final decoded = _decodeObject(encodedBody);
    final dataJson = decoded?['data'];
    if (decoded?['expectedRevision'] != expectedRevision ||
        !GameSaveData.isCanonicalVersion2Envelope(dataJson) ||
        GameSaveData.fromJson(dataJson) == null) {
      throw const FormatException('영속 온라인 저장 요청 본문이 올바르지 않습니다.');
    }
    return OnlineSaveUpdateRequest._(
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      encodedBody: encodedBody,
    );
  }

  OnlineSaveUpdateRequest._({
    required this.expectedRevision,
    required String idempotencyKey,
    required this.encodedBody,
  }) : idempotencyKey = idempotencyKey.trim() {
    if (expectedRevision < 0) {
      throw ArgumentError.value(
        expectedRevision,
        'expectedRevision',
        '0 이상이어야 합니다.',
      );
    }
    if (!_uuidPattern.hasMatch(this.idempotencyKey)) {
      throw ArgumentError.value(
        idempotencyKey,
        'idempotencyKey',
        '유효한 UUID가 아닙니다.',
      );
    }
  }

  static final RegExp _uuidPattern = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
    caseSensitive: false,
  );

  final int expectedRevision;
  final String idempotencyKey;
  final String encodedBody;

  static Map<String, dynamic>? _decodeObject(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } on FormatException {
      return null;
    }
  }
}

class OnlineSaveException implements Exception {
  const OnlineSaveException({
    required this.code,
    required this.message,
    this.requestId,
    this.statusCode,
    this.currentRevision,
    this.retryAfter,
    this.transportFailure = false,
  });

  final String code;
  final String message;
  final String? requestId;
  final int? statusCode;
  final int? currentRevision;
  final Duration? retryAfter;
  final bool transportFailure;

  bool get isUnauthorized => statusCode == 401;

  bool get isRetryable =>
      transportFailure ||
      statusCode == 408 ||
      statusCode == 429 ||
      (statusCode != null && statusCode! >= 500);

  @override
  String toString() => 'OnlineSaveException($code): $message';
}

class OnlineSaveApi implements OnlineSaveClient {
  OnlineSaveApi({required String baseUrl, OnlineSaveTransport? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveTransport _transport;

  @override
  Future<OnlineSaveSnapshot?> load(String accessToken) async {
    final response = await _performRequest(
      () => _transport.getJSON(
        _baseUri.resolve('v1/save'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode == 404 &&
        _stringValue(decoded, 'code') == 'SAVE_NOT_FOUND') {
      return null;
    }
    if (response.statusCode != 200) {
      throw _responseException(
        response,
        decoded,
        fallbackMessage: '원격 저장 데이터를 불러오지 못했습니다.',
      );
    }

    final revision = _nonNegativeInt(decoded?['revision']);
    final serverSavedAt = _dateTimeValue(decoded, 'serverSavedAt');
    final dataJson = decoded?['data'];
    final data = GameSaveData.fromJson(dataJson);
    if (revision == null ||
        serverSavedAt == null ||
        !GameSaveData.isCanonicalVersion2Envelope(dataJson) ||
        data == null) {
      throw const OnlineSaveException(
        code: 'INVALID_SAVE_RESPONSE',
        message: '원격 저장 응답 형식이 올바르지 않습니다.',
      );
    }
    return OnlineSaveSnapshot(
      revision: revision,
      serverSavedAt: serverSavedAt,
      data: data,
    );
  }

  @override
  Future<OnlineSaveUpdateResult> update(
    String accessToken,
    OnlineSaveUpdateRequest request,
  ) async {
    final response = await _performRequest(
      () => _transport.putJSON(
        _baseUri.resolve('v1/save'),
        body: request.encodedBody,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': request.idempotencyKey,
        },
      ),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw _responseException(
        response,
        decoded,
        fallbackMessage: '원격 저장 데이터를 갱신하지 못했습니다.',
      );
    }

    final revision = _nonNegativeInt(decoded?['revision']);
    final serverSavedAt = _dateTimeValue(decoded, 'serverSavedAt');
    if (revision == null ||
        revision != request.expectedRevision + 1 ||
        serverSavedAt == null) {
      throw const OnlineSaveException(
        code: 'INVALID_SAVE_RESPONSE',
        message: '원격 저장 갱신 응답 형식이 올바르지 않습니다.',
      );
    }
    return OnlineSaveUpdateResult(
      revision: revision,
      serverSavedAt: serverSavedAt,
    );
  }

  Future<OnlineSaveHTTPResponse> _performRequest(
    Future<OnlineSaveHTTPResponse> Function() request,
  ) async {
    try {
      return await request();
    } on OnlineSaveTransportException catch (error) {
      throw OnlineSaveException(
        code: 'SAVE_NETWORK_ERROR',
        message: error.message,
        transportFailure: true,
      );
    }
  }

  OnlineSaveException _responseException(
    OnlineSaveHTTPResponse response,
    Map<String, dynamic>? decoded, {
    required String fallbackMessage,
  }) {
    return OnlineSaveException(
      code: _stringValue(decoded, 'code') ?? 'SAVE_REQUEST_FAILED',
      message: _stringValue(decoded, 'message') ?? fallbackMessage,
      requestId: _stringValue(decoded, 'requestId'),
      statusCode: response.statusCode,
      currentRevision: _nonNegativeInt(decoded?['currentRevision']),
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
      throw const FormatException('유효한 온라인 저장 API 주소가 아닙니다.');
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

  static int? _nonNegativeInt(Object? value) {
    return value is int && value >= 0 ? value : null;
  }

  static DateTime? _dateTimeValue(Map<String, dynamic>? object, String key) {
    final value = _stringValue(object, key);
    return value == null ? null : DateTime.tryParse(value)?.toUtc();
  }

  static Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    if (seconds == null || seconds <= 0) {
      return null;
    }
    return Duration(seconds: seconds);
  }
}
