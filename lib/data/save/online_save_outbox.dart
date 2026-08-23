import 'dart:convert';

import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'online_save_api.dart';

enum OnlineSaveOutboxPhase { idle, sending, retryWaiting, conflict, blocked }

class OnlineSaveOutboxEntry {
  const OnlineSaveOutboxEntry({
    required this.idempotencyKey,
    required this.expectedRevision,
    required this.encodedRequestBody,
    required this.payloadFingerprint,
    required this.payloadGeneration,
  });

  final String idempotencyKey;
  final int expectedRevision;
  final String encodedRequestBody;
  final String payloadFingerprint;
  final int payloadGeneration;

  OnlineSaveUpdateRequest toRequest() {
    return OnlineSaveUpdateRequest.fromPersisted(
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      encodedBody: encodedRequestBody,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'idempotencyKey': idempotencyKey,
      'expectedRevision': expectedRevision,
      'encodedRequestBody': encodedRequestBody,
      'payloadFingerprint': payloadFingerprint,
      'payloadGeneration': payloadGeneration,
    };
  }

  static OnlineSaveOutboxEntry? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final idempotencyKey = json['idempotencyKey'];
    final expectedRevision = json['expectedRevision'];
    final encodedRequestBody = json['encodedRequestBody'];
    final payloadFingerprint = json['payloadFingerprint'];
    final payloadGeneration = json['payloadGeneration'];
    if (idempotencyKey is! String ||
        expectedRevision is! int ||
        expectedRevision < 0 ||
        encodedRequestBody is! String ||
        payloadFingerprint is! String ||
        payloadFingerprint.isEmpty ||
        payloadGeneration is! int ||
        payloadGeneration < 0) {
      return null;
    }
    try {
      OnlineSaveUpdateRequest.fromPersisted(
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
        encodedBody: encodedRequestBody,
      );
    } on Object {
      return null;
    }
    return OnlineSaveOutboxEntry(
      idempotencyKey: idempotencyKey,
      expectedRevision: expectedRevision,
      encodedRequestBody: encodedRequestBody,
      payloadFingerprint: payloadFingerprint,
      payloadGeneration: payloadGeneration,
    );
  }
}

class OnlineSaveOutboxState {
  const OnlineSaveOutboxState({
    required this.accountIdBinding,
    required this.remoteRevision,
    required this.lastSyncedPayloadFingerprint,
    required this.payloadGeneration,
    required this.dirty,
    required this.inFlight,
    required this.phase,
    required this.retryCount,
    required this.nextRetryAt,
    required this.lastSyncedAt,
    required this.issueCode,
    required this.conflictRevision,
  });

  factory OnlineSaveOutboxState.initial({
    required String accountId,
    required int remoteRevision,
  }) {
    final slot = LocalSaveSlot.account(accountId);
    if (remoteRevision < 0) {
      throw ArgumentError.value(
        remoteRevision,
        'remoteRevision',
        '0 이상이어야 합니다.',
      );
    }
    return OnlineSaveOutboxState(
      accountIdBinding: slot.accountId!,
      remoteRevision: remoteRevision,
      lastSyncedPayloadFingerprint: null,
      payloadGeneration: 0,
      dirty: false,
      inFlight: null,
      phase: OnlineSaveOutboxPhase.idle,
      retryCount: 0,
      nextRetryAt: null,
      lastSyncedAt: null,
      issueCode: null,
      conflictRevision: null,
    );
  }

  static const currentVersion = 1;
  static const Object _unchanged = Object();

  final String accountIdBinding;
  final int remoteRevision;
  final String? lastSyncedPayloadFingerprint;
  final int payloadGeneration;
  final bool dirty;
  final OnlineSaveOutboxEntry? inFlight;
  final OnlineSaveOutboxPhase phase;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastSyncedAt;
  final String? issueCode;
  final int? conflictRevision;

  OnlineSaveOutboxState copyWith({
    int? remoteRevision,
    Object? lastSyncedPayloadFingerprint = _unchanged,
    int? payloadGeneration,
    bool? dirty,
    Object? inFlight = _unchanged,
    OnlineSaveOutboxPhase? phase,
    int? retryCount,
    Object? nextRetryAt = _unchanged,
    Object? lastSyncedAt = _unchanged,
    Object? issueCode = _unchanged,
    Object? conflictRevision = _unchanged,
  }) {
    return OnlineSaveOutboxState(
      accountIdBinding: accountIdBinding,
      remoteRevision: remoteRevision ?? this.remoteRevision,
      lastSyncedPayloadFingerprint:
          identical(lastSyncedPayloadFingerprint, _unchanged)
          ? this.lastSyncedPayloadFingerprint
          : lastSyncedPayloadFingerprint as String?,
      payloadGeneration: payloadGeneration ?? this.payloadGeneration,
      dirty: dirty ?? this.dirty,
      inFlight: identical(inFlight, _unchanged)
          ? this.inFlight
          : inFlight as OnlineSaveOutboxEntry?,
      phase: phase ?? this.phase,
      retryCount: retryCount ?? this.retryCount,
      nextRetryAt: identical(nextRetryAt, _unchanged)
          ? this.nextRetryAt
          : nextRetryAt as DateTime?,
      lastSyncedAt: identical(lastSyncedAt, _unchanged)
          ? this.lastSyncedAt
          : lastSyncedAt as DateTime?,
      issueCode: identical(issueCode, _unchanged)
          ? this.issueCode
          : issueCode as String?,
      conflictRevision: identical(conflictRevision, _unchanged)
          ? this.conflictRevision
          : conflictRevision as int?,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'version': currentVersion,
      'accountIdBinding': accountIdBinding,
      'remoteRevision': remoteRevision,
      'lastSyncedPayloadFingerprint': lastSyncedPayloadFingerprint,
      'payloadGeneration': payloadGeneration,
      'dirty': dirty,
      'inFlight': inFlight?.toJson(),
      'syncState': phase.name,
      'retryCount': retryCount,
      'nextRetryAt': nextRetryAt?.toUtc().toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
      'issueCode': issueCode,
      'conflictRevision': conflictRevision,
    };
  }

  static OnlineSaveOutboxState? fromJson(Object? json) {
    if (json is! Map<String, Object?> || json['version'] != currentVersion) {
      return null;
    }
    final accountId = json['accountIdBinding'];
    final remoteRevision = json['remoteRevision'];
    final lastSyncedPayloadFingerprint = json['lastSyncedPayloadFingerprint'];
    final payloadGeneration = json['payloadGeneration'];
    final dirty = json['dirty'];
    final phaseName = json['syncState'];
    final retryCount = json['retryCount'];
    final issueCode = json['issueCode'];
    final conflictRevision = json['conflictRevision'];
    if (accountId is! String ||
        remoteRevision is! int ||
        remoteRevision < 0 ||
        (lastSyncedPayloadFingerprint != null &&
            lastSyncedPayloadFingerprint is! String) ||
        payloadGeneration is! int ||
        payloadGeneration < 0 ||
        dirty is! bool ||
        phaseName is! String ||
        retryCount is! int ||
        retryCount < 0 ||
        (issueCode != null && issueCode is! String) ||
        (conflictRevision != null &&
            (conflictRevision is! int || conflictRevision < 0))) {
      return null;
    }

    String normalizedAccountId;
    try {
      normalizedAccountId = LocalSaveSlot.account(accountId).accountId!;
    } on ArgumentError {
      return null;
    }
    final phase = OnlineSaveOutboxPhase.values.where(
      (candidate) => candidate.name == phaseName,
    );
    if (phase.isEmpty) {
      return null;
    }
    final inFlightJson = json['inFlight'];
    final inFlight = inFlightJson == null
        ? null
        : OnlineSaveOutboxEntry.fromJson(inFlightJson);
    if ((inFlightJson != null && inFlight == null) ||
        (inFlight != null &&
            (inFlight.expectedRevision != remoteRevision ||
                inFlight.payloadGeneration > payloadGeneration))) {
      return null;
    }
    final nextRetryAt = _dateTime(json['nextRetryAt']);
    final lastSyncedAt = _dateTime(json['lastSyncedAt']);
    if ((json['nextRetryAt'] != null && nextRetryAt == null) ||
        (json['lastSyncedAt'] != null && lastSyncedAt == null)) {
      return null;
    }
    return OnlineSaveOutboxState(
      accountIdBinding: normalizedAccountId,
      remoteRevision: remoteRevision,
      lastSyncedPayloadFingerprint: lastSyncedPayloadFingerprint as String?,
      payloadGeneration: payloadGeneration,
      dirty: dirty,
      inFlight: inFlight,
      phase: phase.single,
      retryCount: retryCount,
      nextRetryAt: nextRetryAt,
      lastSyncedAt: lastSyncedAt,
      issueCode: issueCode as String?,
      conflictRevision: conflictRevision as int?,
    );
  }

  static DateTime? _dateTime(Object? value) {
    return value is String ? DateTime.tryParse(value)?.toUtc() : null;
  }
}

String onlineSavePayloadFingerprint(GameSaveData data) {
  final bytes = utf8.encode(jsonEncode(data.toJson()));
  var forward = 0x811c9dc5;
  var reverse = 0x9e3779b9;
  for (var index = 0; index < bytes.length; index++) {
    forward = _fnv1a32(forward, bytes[index]);
    reverse = _fnv1a32(reverse, bytes[bytes.length - index - 1]);
  }
  return '${bytes.length.toRadixString(16)}-'
      '${forward.toUnsigned(32).toRadixString(16).padLeft(8, '0')}-'
      '${reverse.toUnsigned(32).toRadixString(16).padLeft(8, '0')}';
}

int _fnv1a32(int hash, int byte) {
  final value = (hash ^ byte).toUnsigned(32);
  // 32-bit FNV prime 곱셈의 shift-add 표현. Web에서도 동일한 결과 유지.
  return (value +
          (value << 1) +
          (value << 4) +
          (value << 7) +
          (value << 8) +
          (value << 24))
      .toUnsigned(32);
}
