import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'game_save_data.dart';
import 'local_save_slot.dart';
import 'online_save_api.dart';

enum OnlineSaveOutboxPhase {
  idle,
  sending,
  retryWaiting,
  rebasing,
  suspended,
  conflict,
  blocked,
}

enum OnlineSaveRebaseStage { prepared, backupPreserved, payloadApplied }

class OnlineSaveRebaseJournal {
  const OnlineSaveRebaseJournal({
    required this.targetRevision,
    required this.targetPayloadHash,
    required this.targetServerSavedAt,
    required this.sourcePayloadHash,
    required this.stage,
  });

  final int targetRevision;
  final String targetPayloadHash;
  final DateTime targetServerSavedAt;
  final String? sourcePayloadHash;
  final OnlineSaveRebaseStage stage;

  String get rebaseId =>
      '$targetRevision:$targetPayloadHash:${sourcePayloadHash ?? 'empty'}';

  OnlineSaveRebaseJournal copyWith({
    int? targetRevision,
    String? targetPayloadHash,
    DateTime? targetServerSavedAt,
    Object? sourcePayloadHash = _unchanged,
    OnlineSaveRebaseStage? stage,
  }) {
    return OnlineSaveRebaseJournal(
      targetRevision: targetRevision ?? this.targetRevision,
      targetPayloadHash: targetPayloadHash ?? this.targetPayloadHash,
      targetServerSavedAt: targetServerSavedAt ?? this.targetServerSavedAt,
      sourcePayloadHash: identical(sourcePayloadHash, _unchanged)
          ? this.sourcePayloadHash
          : sourcePayloadHash as String?,
      stage: stage ?? this.stage,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'targetRevision': targetRevision,
      'targetPayloadHash': targetPayloadHash,
      'targetServerSavedAt': targetServerSavedAt.toUtc().toIso8601String(),
      'sourcePayloadHash': sourcePayloadHash,
      'stage': stage.name,
    };
  }

  static OnlineSaveRebaseJournal? fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final targetRevision = json['targetRevision'];
    final targetPayloadHash = json['targetPayloadHash'];
    final targetServerSavedAt = _dateTime(json['targetServerSavedAt']);
    final sourcePayloadHash = json['sourcePayloadHash'];
    final stageName = json['stage'];
    final stage = OnlineSaveRebaseStage.values.where(
      (candidate) => candidate.name == stageName,
    );
    if (targetRevision is! int ||
        targetRevision < 0 ||
        targetPayloadHash is! String ||
        !_sha256Pattern.hasMatch(targetPayloadHash) ||
        targetServerSavedAt == null ||
        (sourcePayloadHash != null &&
            (sourcePayloadHash is! String ||
                !_sha256Pattern.hasMatch(sourcePayloadHash))) ||
        stage.length != 1) {
      return null;
    }
    return OnlineSaveRebaseJournal(
      targetRevision: targetRevision,
      targetPayloadHash: targetPayloadHash,
      targetServerSavedAt: targetServerSavedAt,
      sourcePayloadHash: sourcePayloadHash as String?,
      stage: stage.single,
    );
  }
}

const Object _unchanged = Object();

class OnlineSaveWriterClaimEntry {
  const OnlineSaveWriterClaimEntry({
    required this.idempotencyKey,
    required this.encodedRequestBody,
  });

  final String idempotencyKey;
  final String encodedRequestBody;

  OnlineSaveWriterClaimRequest toRequest({
    int currentClientCompatibilityVersion =
        onlineSaveClientCompatibilityVersion,
  }) {
    return OnlineSaveWriterClaimRequest.fromPersisted(
      idempotencyKey: idempotencyKey,
      encodedBody: encodedRequestBody,
      currentClientCompatibilityVersion: currentClientCompatibilityVersion,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'idempotencyKey': idempotencyKey,
      'encodedRequestBody': encodedRequestBody,
    };
  }

  static OnlineSaveWriterClaimEntry? fromJson(
    Object? json, {
    int currentClientCompatibilityVersion =
        onlineSaveClientCompatibilityVersion,
  }) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final idempotencyKey = json['idempotencyKey'];
    final encodedRequestBody = json['encodedRequestBody'];
    if (idempotencyKey is! String || encodedRequestBody is! String) {
      return null;
    }
    try {
      OnlineSaveWriterClaimRequest.fromPersisted(
        idempotencyKey: idempotencyKey,
        encodedBody: encodedRequestBody,
        currentClientCompatibilityVersion: currentClientCompatibilityVersion,
      );
      return OnlineSaveWriterClaimEntry(
        idempotencyKey: idempotencyKey,
        encodedRequestBody: encodedRequestBody,
      );
    } on Object {
      return null;
    }
  }
}

class OnlineSaveOutboxEntry {
  const OnlineSaveOutboxEntry({
    required this.idempotencyKey,
    required this.writerGeneration,
    required this.expectedRevision,
    required this.encodedRequestBody,
    required this.payloadFingerprint,
    required this.payloadGeneration,
  });

  final String idempotencyKey;
  final int writerGeneration;
  final int expectedRevision;
  final String encodedRequestBody;
  final String payloadFingerprint;
  final int payloadGeneration;

  String get payloadHash => payloadFingerprint;
  int get localGeneration => payloadGeneration;

  OnlineSaveUpdateRequest toRequest({
    int currentClientCompatibilityVersion =
        onlineSaveClientCompatibilityVersion,
  }) {
    return OnlineSaveUpdateRequest.fromPersisted(
      expectedRevision: expectedRevision,
      idempotencyKey: idempotencyKey,
      writerGeneration: writerGeneration,
      encodedBody: encodedRequestBody,
      currentClientCompatibilityVersion: currentClientCompatibilityVersion,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'idempotencyKey': idempotencyKey,
      'writerGeneration': writerGeneration,
      'expectedRevision': expectedRevision,
      'encodedRequestBody': encodedRequestBody,
      'payloadHash': payloadFingerprint,
      'localGeneration': payloadGeneration,
    };
  }

  static OnlineSaveOutboxEntry? fromJson(
    Object? json, {
    int currentClientCompatibilityVersion =
        onlineSaveClientCompatibilityVersion,
  }) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final idempotencyKey = json['idempotencyKey'];
    final writerGeneration = json['writerGeneration'];
    final expectedRevision = json['expectedRevision'];
    final encodedRequestBody = json['encodedRequestBody'];
    final persistedPayloadHash = json['payloadHash'];
    final payloadGeneration = json['localGeneration'];
    if (idempotencyKey is! String ||
        writerGeneration is! int ||
        writerGeneration <= 0 ||
        expectedRevision is! int ||
        expectedRevision < 0 ||
        encodedRequestBody is! String ||
        persistedPayloadHash is! String ||
        payloadGeneration is! int ||
        payloadGeneration < 0) {
      return null;
    }
    try {
      OnlineSaveUpdateRequest.fromPersisted(
        expectedRevision: expectedRevision,
        idempotencyKey: idempotencyKey,
        writerGeneration: writerGeneration,
        encodedBody: encodedRequestBody,
        currentClientCompatibilityVersion: currentClientCompatibilityVersion,
      );
      final payloadHash = persistedPayloadHash;
      if (!_sha256Pattern.hasMatch(payloadHash)) {
        return null;
      }
      return OnlineSaveOutboxEntry(
        idempotencyKey: idempotencyKey,
        writerGeneration: writerGeneration,
        expectedRevision: expectedRevision,
        encodedRequestBody: encodedRequestBody,
        payloadFingerprint: payloadHash,
        payloadGeneration: payloadGeneration,
      );
    } on Object {
      return null;
    }
  }
}

class OnlineSaveOutboxState {
  const OnlineSaveOutboxState({
    required this.accountIdBinding,
    required this.clientInstanceId,
    required this.writerGeneration,
    required this.writerClaim,
    required this.remoteRevision,
    required this.lastSyncedPayloadFingerprint,
    required this.payloadGeneration,
    required this.dirty,
    required this.inFlight,
    required this.rebase,
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
      clientInstanceId: null,
      writerGeneration: null,
      writerClaim: null,
      remoteRevision: remoteRevision,
      lastSyncedPayloadFingerprint: null,
      payloadGeneration: 0,
      dirty: false,
      inFlight: null,
      rebase: null,
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
  final String? clientInstanceId;
  final int? writerGeneration;
  final OnlineSaveWriterClaimEntry? writerClaim;
  final int remoteRevision;
  final String? lastSyncedPayloadFingerprint;
  final int payloadGeneration;
  final bool dirty;
  final OnlineSaveOutboxEntry? inFlight;
  final OnlineSaveRebaseJournal? rebase;
  final OnlineSaveOutboxPhase phase;
  final int retryCount;
  final DateTime? nextRetryAt;
  final DateTime? lastSyncedAt;
  final String? issueCode;
  final int? conflictRevision;

  int get baseRevision => remoteRevision;
  String? get basePayloadHash => lastSyncedPayloadFingerprint;
  int get localGeneration => payloadGeneration;

  bool get requiresResolutionBeforeRebase =>
      dirty ||
      inFlight != null ||
      writerClaim != null ||
      rebase != null ||
      phase != OnlineSaveOutboxPhase.idle;

  OnlineSaveOutboxState copyWith({
    Object? clientInstanceId = _unchanged,
    Object? writerGeneration = _unchanged,
    Object? writerClaim = _unchanged,
    int? remoteRevision,
    Object? lastSyncedPayloadFingerprint = _unchanged,
    int? payloadGeneration,
    bool? dirty,
    Object? inFlight = _unchanged,
    Object? rebase = _unchanged,
    OnlineSaveOutboxPhase? phase,
    int? retryCount,
    Object? nextRetryAt = _unchanged,
    Object? lastSyncedAt = _unchanged,
    Object? issueCode = _unchanged,
    Object? conflictRevision = _unchanged,
  }) {
    return OnlineSaveOutboxState(
      accountIdBinding: accountIdBinding,
      clientInstanceId: identical(clientInstanceId, _unchanged)
          ? this.clientInstanceId
          : clientInstanceId as String?,
      writerGeneration: identical(writerGeneration, _unchanged)
          ? this.writerGeneration
          : writerGeneration as int?,
      writerClaim: identical(writerClaim, _unchanged)
          ? this.writerClaim
          : writerClaim as OnlineSaveWriterClaimEntry?,
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
      rebase: identical(rebase, _unchanged)
          ? this.rebase
          : rebase as OnlineSaveRebaseJournal?,
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
      'clientInstanceId': clientInstanceId,
      'writerGeneration': writerGeneration,
      'writerClaim': writerClaim?.toJson(),
      'baseRevision': remoteRevision,
      'basePayloadHash': lastSyncedPayloadFingerprint,
      'localGeneration': payloadGeneration,
      'dirty': dirty,
      'inFlight': inFlight?.toJson(),
      'rebase': rebase?.toJson(),
      'syncState': phase.name,
      'retryCount': retryCount,
      'nextRetryAt': nextRetryAt?.toUtc().toIso8601String(),
      'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
      'issueCode': issueCode,
      'conflictRevision': conflictRevision,
    };
  }

  static OnlineSaveOutboxState? fromJson(
    Object? json, {
    int currentClientCompatibilityVersion =
        onlineSaveClientCompatibilityVersion,
  }) {
    if (json is! Map<String, Object?>) {
      return null;
    }
    final version = json['version'];
    if (version != currentVersion) {
      return null;
    }
    final accountId = json['accountIdBinding'];
    final clientInstanceId = json['clientInstanceId'];
    final writerGeneration = json['writerGeneration'];
    final remoteRevision = json['baseRevision'];
    final lastSyncedPayloadFingerprint = json['basePayloadHash'];
    final payloadGeneration = json['localGeneration'];
    final dirty = json['dirty'];
    final phaseName = json['syncState'];
    final retryCount = json['retryCount'];
    final issueCode = json['issueCode'];
    final conflictRevision = json['conflictRevision'];
    if (accountId is! String ||
        remoteRevision is! int ||
        remoteRevision < 0 ||
        (lastSyncedPayloadFingerprint != null &&
            (lastSyncedPayloadFingerprint is! String ||
                !_sha256Pattern.hasMatch(lastSyncedPayloadFingerprint))) ||
        (clientInstanceId != null &&
            (clientInstanceId is! String ||
                !_uuidPattern.hasMatch(clientInstanceId))) ||
        (writerGeneration != null &&
            (writerGeneration is! int || writerGeneration <= 0)) ||
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
        : OnlineSaveOutboxEntry.fromJson(
            inFlightJson,
            currentClientCompatibilityVersion:
                currentClientCompatibilityVersion,
          );
    final writerClaimJson = json['writerClaim'];
    final writerClaim = writerClaimJson == null
        ? null
        : OnlineSaveWriterClaimEntry.fromJson(
            writerClaimJson,
            currentClientCompatibilityVersion:
                currentClientCompatibilityVersion,
          );
    final rebaseJson = json['rebase'];
    final rebase = rebaseJson == null
        ? null
        : OnlineSaveRebaseJournal.fromJson(rebaseJson);
    if ((inFlightJson != null && inFlight == null) ||
        (writerClaimJson != null && writerClaim == null) ||
        (rebaseJson != null && rebase == null) ||
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
      clientInstanceId: clientInstanceId as String?,
      writerGeneration: writerGeneration as int?,
      writerClaim: writerClaim,
      remoteRevision: remoteRevision,
      lastSyncedPayloadFingerprint: lastSyncedPayloadFingerprint as String?,
      payloadGeneration: payloadGeneration,
      dirty: dirty,
      inFlight: inFlight,
      rebase: rebase,
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
  return onlineSavePayloadHash(data);
}

String onlineSavePayloadHash(GameSaveData data) {
  final canonicalPayload = jsonEncode(data.toJson());
  return sha256.convert(utf8.encode(canonicalPayload)).toString();
}

final RegExp _sha256Pattern = RegExp(r'^[0-9a-f]{64}$');
final RegExp _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  caseSensitive: false,
);

DateTime? _dateTime(Object? value) {
  return value is String ? DateTime.tryParse(value)?.toUtc() : null;
}
