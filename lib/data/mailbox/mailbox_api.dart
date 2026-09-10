import 'dart:convert';

import '../../domain/mailbox/mailbox.dart';
import '../save/online_save_transport_stub.dart'
    if (dart.library.html) '../save/online_save_transport_web.dart'
    if (dart.library.io) '../save/online_save_transport_io.dart';

class MailboxApi {
  MailboxApi({required String baseUrl, OnlineSaveHTTPClient? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  Future<MailboxPage> load(String token, {String? cursor}) async {
    final uri = _baseUri.resolve('v1/mailbox');
    final data = await _request(
      token,
      cursor == null ? uri : uri.replace(queryParameters: {'cursor': cursor}),
    );
    final mails = data['mails'];
    final next = data['nextCursor'];
    if (mails is! List ||
        mails.length > 20 ||
        (next != null && (next is! String || next.isEmpty))) {
      throw _invalidResponse();
    }
    final items = mails
        .map((value) {
          if (value is! Map<String, dynamic>) throw _invalidResponse();
          final starts = _timestamp(value['startsAt']);
          final expires = _timestamp(value['expiresAt']);
          if (!expires.isAfter(starts)) throw _invalidResponse();
          return MailboxItem(
            id: _text(value['id']),
            title: _text(value['title']),
            body: _text(value['body'], allowEmpty: true),
            freeDiamonds: _count(value['freeDiamonds']),
            moduleTickets: _count(value['moduleTickets']),
            startsAt: starts,
            expiresAt: expires,
            readAt: value['readAt'] == null
                ? null
                : _timestamp(value['readAt']),
            claimedAt: value['claimedAt'] == null
                ? null
                : _timestamp(value['claimedAt']),
          );
        })
        .toList(growable: false);
    if (items.map((item) => item.id).toSet().length != items.length) {
      throw _invalidResponse();
    }
    return MailboxPage(
      items: List.unmodifiable(items),
      serverTime: _timestamp(data['serverTime']),
      nextCursor: next as String?,
    );
  }

  Future<int> summary(String token) async {
    final data = await _request(token, _baseUri.resolve('v1/mailbox/summary'));
    return _count(data['unclaimedCount']);
  }

  Future<void> markRead(String token, String mailId) async {
    await _request(
      token,
      _baseUri.resolve('v1/mailbox/${Uri.encodeComponent(mailId)}/read'),
      post: true,
    );
  }

  Future<Map<String, dynamic>> _request(
    String token,
    Uri uri, {
    bool post = false,
  }) async {
    late final OnlineSaveHTTPResponse response;
    try {
      final headers = {'Authorization': 'Bearer $token'};
      response = post
          ? await _transport.postJSON(uri, body: '{}', headers: headers)
          : await _transport.getJSON(uri, headers: headers);
    } on OnlineSaveTransportException {
      throw const MailboxException(
        code: 'MAILBOX_NETWORK_ERROR',
        message: '우편함 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        transportFailure: true,
      );
    }
    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) data = decoded;
    } on FormatException {
      // 비 JSON 오류 응답에서도 HTTP 인증 상태 보존.
    }
    if (response.statusCode != 200 && !(post && response.statusCode == 204)) {
      throw MailboxException(
        code: data?['code'] is String
            ? data!['code'] as String
            : 'MAILBOX_REQUEST_FAILED',
        message: data?['message'] is String
            ? data!['message'] as String
            : '우편함 요청을 처리하지 못했습니다.',
        statusCode: response.statusCode,
      );
    }
    if (post && response.statusCode == 204) return const {};
    if (data == null) throw _invalidResponse();
    return data;
  }

  static int _count(Object? value) {
    if (value is! int || value < 0) throw _invalidResponse();
    return value;
  }

  static String _text(Object? value, {bool allowEmpty = false}) {
    if (value is! String || (!allowEmpty && value.isEmpty)) {
      throw _invalidResponse();
    }
    return value;
  }

  static DateTime _timestamp(Object? value) {
    final parsed = value is String ? DateTime.tryParse(value) : null;
    if (parsed == null || !parsed.isUtc) throw _invalidResponse();
    return parsed;
  }

  static MailboxException _invalidResponse() => const MailboxException(
    code: 'INVALID_MAILBOX_RESPONSE',
    message: '우편함 응답 형식이 올바르지 않습니다.',
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
      throw const FormatException('유효한 우편함 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/');
  }
}
