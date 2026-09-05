import 'dart:convert';

import '../../domain/daily_quest/daily_quest_type.dart';
import '../../domain/economy/weekly_reward_claim.dart';
import '../save/online_save_api.dart';
import '../save/online_save_transport_stub.dart'
    if (dart.library.html) '../save/online_save_transport_web.dart'
    if (dart.library.io) '../save/online_save_transport_io.dart';

class WeeklyRewardException implements Exception {
  const WeeklyRewardException({
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
  String toString() => 'WeeklyRewardException($code): $message';
}

class WeeklyRewardApi {
  WeeklyRewardApi({required String baseUrl, OnlineSaveHTTPClient? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  Future<WeeklyRewardReceipt> claim(
    String accessToken, {
    required String idempotencyKey,
    required WeeklyRewardClaimTarget target,
  }) async {
    final body = jsonEncode({
      'period': 'weekly',
      'rewardType': switch (target.kind) {
        WeeklyRewardKind.quest => 'quest',
        WeeklyRewardKind.allComplete => 'all_complete',
        WeeklyRewardKind.attendance => 'attendance',
      },
      if (target.questType != null) 'questType': target.questType!.name,
      'clientCompatibilityVersion': onlineSaveClientCompatibilityVersion,
    });
    late final OnlineSaveHTTPResponse response;
    try {
      response = await _transport.postJSON(
        _baseUri.resolve('v1/economy/rewards/claim'),
        body: body,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': idempotencyKey,
        },
      );
    } on OnlineSaveTransportException catch (error) {
      throw WeeklyRewardException(
        code: 'WEEKLY_REWARD_NETWORK_ERROR',
        message: error.message,
        transportFailure: true,
      );
    }

    final decoded = _decodeObject(response.body);
    if (response.statusCode == 200) {
      return _decodeReceipt(decoded, expectedTarget: target);
    }
    if (response.statusCode == 409 &&
        decoded?['code'] == 'REWARD_ALREADY_CLAIMED') {
      return _decodeReceipt(
        _objectValue(decoded, 'reward'),
        expectedTarget: target,
      );
    }
    throw WeeklyRewardException(
      code: _stringValue(decoded, 'code') ?? 'WEEKLY_REWARD_REQUEST_FAILED',
      message: _stringValue(decoded, 'message') ?? '주간 보상을 수령하지 못했습니다.',
      statusCode: response.statusCode,
      requestId: _stringValue(decoded, 'requestId'),
      retryAfter: _retryAfter(response.headers['retry-after']),
    );
  }

  WeeklyRewardReceipt _decodeReceipt(
    Map<String, dynamic>? decoded, {
    required WeeklyRewardClaimTarget expectedTarget,
  }) {
    final rewardKey = _stringValue(decoded, 'rewardKey');
    final periodKey = _stringValue(decoded, 'periodKey');
    final weekKey = _nonNegativeInt(decoded?['weekKey']);
    final rewardType = _stringValue(decoded, 'rewardType');
    final questTypeName = _stringValue(decoded, 'questType');
    final diamonds = _positiveInt(decoded?['diamonds']);
    final moduleTickets = _nonNegativeInt(decoded?['moduleTickets']);
    final sourceSaveRevision = _nonNegativeInt(decoded?['sourceSaveRevision']);
    final claimedAt = DateTime.tryParse(
      _stringValue(decoded, 'claimedAt') ?? '',
    )?.toUtc();
    final target = _targetFromResponse(rewardType, questTypeName);
    if (rewardKey == null ||
        periodKey == null ||
        weekKey == null ||
        diamonds == null ||
        moduleTickets == null ||
        sourceSaveRevision == null ||
        claimedAt == null ||
        target == null ||
        target.key != expectedTarget.key) {
      throw const WeeklyRewardException(
        code: 'INVALID_WEEKLY_REWARD_RESPONSE',
        message: '주간 보상 응답 형식이 올바르지 않습니다.',
      );
    }
    return WeeklyRewardReceipt(
      rewardKey: rewardKey,
      periodKey: periodKey,
      weekKey: weekKey,
      target: target,
      diamonds: diamonds,
      moduleTickets: moduleTickets,
      sourceSaveRevision: sourceSaveRevision,
      claimedAt: claimedAt,
    );
  }

  static WeeklyRewardClaimTarget? _targetFromResponse(
    String? rewardType,
    String? questTypeName,
  ) {
    switch (rewardType) {
      case 'all_complete':
        return questTypeName == null
            ? const WeeklyRewardClaimTarget.allComplete()
            : null;
      case 'attendance':
        return questTypeName == null
            ? const WeeklyRewardClaimTarget.attendance()
            : null;
      case 'quest':
        for (final type in DailyQuestType.values) {
          if (type.name == questTypeName) {
            return WeeklyRewardClaimTarget.quest(type);
          }
        }
        return null;
      default:
        return null;
    }
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
      throw const FormatException('유효한 주간 보상 API 주소가 아닙니다.');
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

  static Map<String, dynamic>? _objectValue(
    Map<String, dynamic>? object,
    String key,
  ) {
    final value = object?[key];
    return value is Map<String, dynamic> ? value : null;
  }

  static String? _stringValue(Map<String, dynamic>? object, String key) {
    final value = object?[key];
    return value is String ? value : null;
  }

  static int? _nonNegativeInt(Object? value) {
    return value is int && value >= 0 ? value : null;
  }

  static int? _positiveInt(Object? value) {
    return value is int && value > 0 ? value : null;
  }

  static Duration? _retryAfter(String? value) {
    final seconds = int.tryParse(value ?? '');
    return seconds == null || seconds <= 0 ? null : Duration(seconds: seconds);
  }
}
