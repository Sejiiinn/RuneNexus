class EconomyPendingCommand {
  const EconomyPendingCommand({
    required this.kind,
    required this.path,
    required this.idempotencyKey,
    required this.encodedBody,
    required this.createdAtMillis,
  });

  final String kind;
  final String path;
  final String idempotencyKey;
  final String encodedBody;
  final int createdAtMillis;

  Map<String, Object?> toJson() => {
    'kind': kind,
    'path': path,
    'idempotencyKey': idempotencyKey,
    'encodedBody': encodedBody,
    'createdAtMillis': createdAtMillis,
  };

  static EconomyPendingCommand? fromJson(Object? json) {
    if (json is! Map<String, Object?> ||
        json['kind'] is! String ||
        json['path'] is! String ||
        json['idempotencyKey'] is! String ||
        json['encodedBody'] is! String ||
        json['createdAtMillis'] is! int) {
      return null;
    }
    final command = EconomyPendingCommand(
      kind: json['kind']! as String,
      path: json['path']! as String,
      idempotencyKey: json['idempotencyKey']! as String,
      encodedBody: json['encodedBody']! as String,
      createdAtMillis: json['createdAtMillis']! as int,
    );
    if (command.kind.isEmpty ||
        !command.path.startsWith('v1/economy/') ||
        command.idempotencyKey.isEmpty ||
        command.encodedBody.isEmpty ||
        command.createdAtMillis < 0) {
      return null;
    }
    return command;
  }
}

class EconomyPendingRunReward {
  const EconomyPendingRunReward({
    required this.runId,
    required this.stageNumber,
    required this.completedRounds,
    required this.success,
    required this.pendingDiamonds,
    this.firstClearModuleTickets = 0,
    required this.createdAtMillis,
  });

  final String runId;
  final int stageNumber;
  final int completedRounds;
  final bool success;
  final int pendingDiamonds;
  final int firstClearModuleTickets;
  final int createdAtMillis;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'stageNumber': stageNumber,
    'completedRounds': completedRounds,
    'success': success,
    'pendingDiamonds': pendingDiamonds,
    'firstClearModuleTickets': firstClearModuleTickets,
    'createdAtMillis': createdAtMillis,
  };

  static EconomyPendingRunReward? fromJson(Object? json) {
    if (json is! Map<String, Object?> ||
        json['runId'] is! String ||
        json['stageNumber'] is! int ||
        json['completedRounds'] is! int ||
        json['success'] is! bool ||
        json['pendingDiamonds'] is! int ||
        json['createdAtMillis'] is! int) {
      return null;
    }
    final result = EconomyPendingRunReward(
      runId: json['runId']! as String,
      stageNumber: json['stageNumber']! as int,
      completedRounds: json['completedRounds']! as int,
      success: json['success']! as bool,
      pendingDiamonds: json['pendingDiamonds']! as int,
      firstClearModuleTickets: json['firstClearModuleTickets'] is int
          ? json['firstClearModuleTickets']! as int
          : 0,
      createdAtMillis: json['createdAtMillis']! as int,
    );
    if (result.runId.isEmpty ||
        result.stageNumber <= 0 ||
        result.completedRounds < 0 ||
        result.pendingDiamonds < 0 ||
        result.firstClearModuleTickets < 0 ||
        result.createdAtMillis < 0) {
      return null;
    }
    return result;
  }
}

class EconomyCommandOutboxState {
  const EconomyCommandOutboxState({
    required this.accountIdBinding,
    required this.inFlight,
    required this.pendingRewards,
  });

  static const currentVersion = 1;

  final String accountIdBinding;
  final EconomyPendingCommand? inFlight;
  final List<EconomyPendingRunReward> pendingRewards;

  factory EconomyCommandOutboxState.initial(String accountId) =>
      EconomyCommandOutboxState(
        accountIdBinding: accountId.toLowerCase(),
        inFlight: null,
        pendingRewards: const [],
      );

  EconomyCommandOutboxState copyWith({
    Object? inFlight = _unchanged,
    List<EconomyPendingRunReward>? pendingRewards,
  }) {
    return EconomyCommandOutboxState(
      accountIdBinding: accountIdBinding,
      inFlight: identical(inFlight, _unchanged)
          ? this.inFlight
          : inFlight as EconomyPendingCommand?,
      pendingRewards: List.unmodifiable(pendingRewards ?? this.pendingRewards),
    );
  }

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'accountIdBinding': accountIdBinding,
    'inFlight': inFlight?.toJson(),
    'pendingRewards': pendingRewards.map((item) => item.toJson()).toList(),
  };

  static EconomyCommandOutboxState? fromJson(Object? json) {
    if (json is! Map<String, Object?> ||
        json['version'] != currentVersion ||
        json['accountIdBinding'] is! String ||
        json['pendingRewards'] is! List) {
      return null;
    }
    final accountId = (json['accountIdBinding']! as String).toLowerCase();
    final inFlight = json['inFlight'] == null
        ? null
        : EconomyPendingCommand.fromJson(json['inFlight']);
    final rewards = <EconomyPendingRunReward>[];
    for (final value in json['pendingRewards']! as List) {
      final command = EconomyPendingRunReward.fromJson(value);
      if (command == null) {
        return null;
      }
      rewards.add(command);
    }
    if (accountId.isEmpty || (json['inFlight'] != null && inFlight == null)) {
      return null;
    }
    return EconomyCommandOutboxState(
      accountIdBinding: accountId,
      inFlight: inFlight,
      pendingRewards: List.unmodifiable(rewards),
    );
  }
}

const Object _unchanged = Object();
