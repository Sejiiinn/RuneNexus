import 'dart:convert';

import '../../domain/economy/economy_snapshot.dart';
import '../../domain/turret/turret_type.dart';
import '../../domain/turret_module/turret_module_type.dart';
import '../save/online_save_transport_stub.dart'
    if (dart.library.html) '../save/online_save_transport_web.dart'
    if (dart.library.io) '../save/online_save_transport_io.dart';

class EconomyException implements Exception {
  const EconomyException({
    required this.code,
    required this.message,
    this.statusCode,
    this.requestId,
    this.transportFailure = false,
  });

  final String code;
  final String message;
  final int? statusCode;
  final String? requestId;
  final bool transportFailure;

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() => 'EconomyException($code): $message';
}

class EconomyApi {
  EconomyApi({required String baseUrl, OnlineSaveHTTPClient? transport})
    : _baseUri = _apiBaseUri(baseUrl),
      _transport = transport ?? OnlineSaveTransport();

  final Uri _baseUri;
  final OnlineSaveHTTPClient _transport;

  Future<EconomySnapshot> load(String accessToken) async {
    final response = await _request(
      () => _transport.getJSON(
        _baseUri.resolve('v1/economy'),
        headers: {'Authorization': 'Bearer $accessToken'},
      ),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw _responseException(response, decoded);
    }
    return _decodeSnapshot(decoded);
  }

  Future<EconomyBootstrapResult> bootstrap(
    String accessToken, {
    required String idempotencyKey,
    required String encodedBody,
  }) async {
    final decoded = await _postObject(
      accessToken,
      path: 'v1/economy/bootstrap',
      idempotencyKey: idempotencyKey,
      encodedBody: encodedBody,
    );
    final snapshot = _decodeSnapshot(_objectValue(decoded, 'economy'));
    final idMap = <String, String>{};
    final rawMap = decoded['importedLegacyIdMap'];
    if (rawMap is Map<String, dynamic>) {
      for (final entry in rawMap.entries) {
        if (entry.value is String) {
          idMap[entry.key] = entry.value as String;
        }
      }
    }
    final cleared = _stringSet(decoded['clearedEquippedIds']);
    final revision = _positiveInt(decoded['bootstrapSaveRevision']);
    if (revision == null) {
      throw _invalidResponse();
    }
    return EconomyBootstrapResult(
      snapshot: snapshot,
      importedLegacyIdMap: Map.unmodifiable(idMap),
      clearedEquippedIds: Set.unmodifiable(cleared),
      bootstrapSaveRevision: revision,
    );
  }

  Future<EconomyCommandResult> execute(
    String accessToken, {
    required String path,
    required String idempotencyKey,
    required String encodedBody,
  }) async {
    final decoded = await _postObject(
      accessToken,
      path: path,
      idempotencyKey: idempotencyKey,
      encodedBody: encodedBody,
    );
    final drawn = <EconomyModule>[];
    final rawDrawn = decoded['drawnModules'];
    if (rawDrawn is List) {
      for (final value in rawDrawn) {
        drawn.add(_decodeModule(_object(value)));
      }
    }
    final effectObject = _objectOrNull(decoded['progressionEffect']);
    return EconomyCommandResult(
      snapshot: _decodeSnapshot(_objectValue(decoded, 'economy')),
      drawnModules: List.unmodifiable(drawn),
      progressionEffect: effectObject == null
          ? null
          : _decodeEffect(effectObject),
      rewardKey: _stringValue(decoded, 'rewardKey'),
      grantedDiamonds: _nonNegativeInt(decoded['grantedDiamonds']) ?? 0,
      grantedModuleTickets:
          _nonNegativeInt(decoded['grantedModuleTickets']) ?? 0,
    );
  }

  Future<int> claimReward(
    String accessToken, {
    required String idempotencyKey,
    required String encodedBody,
  }) async {
    final response = await _request(
      () => _transport.postJSON(
        _baseUri.resolve('v1/economy/rewards/claim'),
        body: encodedBody,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    var decoded = _decodeObject(response.body);
    if (response.statusCode == 409 &&
        decoded?['code'] == 'REWARD_ALREADY_CLAIMED') {
      decoded = _objectValue(decoded, 'reward');
    } else if (response.statusCode != 200) {
      throw _responseException(response, decoded);
    }
    final periodNumber = _nonNegativeInt(decoded?['weekKey']);
    if (periodNumber == null) {
      throw _invalidResponse();
    }
    return periodNumber;
  }

  Future<Map<String, dynamic>> _postObject(
    String accessToken, {
    required String path,
    required String idempotencyKey,
    required String encodedBody,
  }) async {
    final response = await _request(
      () => _transport.postJSON(
        _baseUri.resolve(path),
        body: encodedBody,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Idempotency-Key': idempotencyKey,
        },
      ),
    );
    final decoded = _decodeObject(response.body);
    if (response.statusCode != 200) {
      throw _responseException(response, decoded);
    }
    if (decoded == null) {
      throw _invalidResponse();
    }
    return decoded;
  }

  Future<OnlineSaveHTTPResponse> _request(
    Future<OnlineSaveHTTPResponse> Function() operation,
  ) async {
    try {
      return await operation();
    } on OnlineSaveTransportException catch (error) {
      throw EconomyException(
        code: 'ECONOMY_NETWORK_ERROR',
        message: error.message,
        transportFailure: true,
      );
    }
  }

  EconomyException _responseException(
    OnlineSaveHTTPResponse response,
    Map<String, dynamic>? decoded,
  ) {
    return EconomyException(
      code: _stringValue(decoded, 'code') ?? 'ECONOMY_REQUEST_FAILED',
      message: _stringValue(decoded, 'message') ?? '경제 요청을 처리하지 못했습니다.',
      statusCode: response.statusCode,
      requestId: _stringValue(decoded, 'requestId'),
    );
  }

  EconomySnapshot _decodeSnapshot(Map<String, dynamic>? decoded) {
    if (decoded == null) {
      throw _invalidResponse();
    }
    final authorityEpoch = _stringValue(decoded, 'authorityEpoch');
    final authorityState = _stringValue(decoded, 'authorityState');
    final authorityVersion = _positiveInt(decoded['authorityVersion']);
    final revision = _nonNegativeInt(decoded['economyRevision']);
    final catalogVersion = _positiveInt(decoded['catalogVersion']);
    final serverTime = DateTime.tryParse(
      _stringValue(decoded, 'serverTime') ?? '',
    )?.toUtc();
    final wallet = _objectValue(decoded, 'wallet');
    final modulesObject = _objectValue(decoded, 'turretModules');
    final entitlements = _objectValue(decoded, 'entitlements');
    final free = _nonNegativeInt(wallet?['freeDiamonds']);
    final paid = _nonNegativeInt(wallet?['paidDiamonds']);
    final tickets = _nonNegativeInt(wallet?['moduleTickets']);
    final drawCount = _nonNegativeInt(modulesObject?['drawCount']);
    final purchaseCount = _nonNegativeInt(
      modulesObject?['ticketPurchaseCount'],
    );
    if (authorityEpoch == null ||
        authorityState != 'server_authoritative' ||
        authorityVersion == null ||
        revision == null ||
        catalogVersion == null ||
        serverTime == null ||
        free == null ||
        paid == null ||
        tickets == null ||
        drawCount == null ||
        purchaseCount == null ||
        entitlements?['researchSlotTwoUnlocked'] is! bool) {
      throw _invalidResponse();
    }
    final modules = <EconomyModule>[];
    final rawModules = modulesObject?['items'];
    if (rawModules is! List) {
      throw _invalidResponse();
    }
    for (final value in rawModules) {
      modules.add(_decodeModule(_object(value)));
    }
    final effects = <EconomyProgressionEffect>[];
    final rawEffects = decoded['pendingProgressionEffects'];
    if (rawEffects is! List) {
      throw _invalidResponse();
    }
    for (final value in rawEffects) {
      effects.add(_decodeEffect(_object(value)));
    }
    return EconomySnapshot(
      authorityEpoch: authorityEpoch,
      authorityState: authorityState!,
      authorityVersion: authorityVersion,
      revision: revision,
      catalogVersion: catalogVersion,
      serverTime: serverTime,
      wallet: EconomyWallet(
        freeDiamonds: free,
        paidDiamonds: paid,
        moduleTickets: tickets,
      ),
      moduleDrawCount: drawCount,
      moduleTicketPurchaseCount: purchaseCount,
      modules: List.unmodifiable(modules),
      researchSlotTwoUnlocked: entitlements!['researchSlotTwoUnlocked'] as bool,
      pendingProgressionEffects: List.unmodifiable(effects),
      claimedRewardKeys: Set.unmodifiable(
        _stringSet(decoded['claimedRewardKeys']),
      ),
    );
  }

  EconomyModule _decodeModule(Map<String, dynamic> decoded) {
    final id = _stringValue(decoded, 'id');
    final turretType = _enumValue(TurretType.values, decoded['turretType']);
    final part = _enumValue(TurretModulePart.values, decoded['part']);
    final family = _enumValue(TurretModuleFamily.values, decoded['family']);
    final grade = _enumValue(TurretModuleGrade.values, decoded['grade']);
    final order = _positiveInt(decoded['acquiredOrder']);
    final rawOptions = decoded['options'];
    if (id == null ||
        turretType == null ||
        part == null ||
        family == null ||
        grade == null ||
        order == null ||
        rawOptions is! List ||
        rawOptions.isEmpty) {
      throw _invalidResponse();
    }
    final options = <TurretModuleOptionRoll>[];
    for (final value in rawOptions) {
      final option = _object(value);
      final type = _enumValue(TurretModuleOptionType.values, option['type']);
      final amount = _positiveInt(option['value']);
      if (type == null || amount == null) {
        throw _invalidResponse();
      }
      options.add(TurretModuleOptionRoll(type: type, value: amount));
    }
    return EconomyModule(
      id: id,
      legacyItemId: _stringValue(decoded, 'legacyItemId'),
      turretType: turretType,
      part: part,
      family: family,
      grade: grade,
      options: List.unmodifiable(options),
      acquiredOrder: order,
    );
  }

  EconomyProgressionEffect _decodeEffect(Map<String, dynamic> decoded) {
    final id = _stringValue(decoded, 'id');
    final type = _stringValue(decoded, 'effectType');
    final payload = _objectValue(decoded, 'payload');
    if (id == null || type == null || payload == null) {
      throw _invalidResponse();
    }
    return EconomyProgressionEffect(
      id: id,
      effectType: type,
      payload: Map.unmodifiable(payload.cast<String, Object?>()),
    );
  }

  static EconomyException _invalidResponse() => const EconomyException(
    code: 'INVALID_ECONOMY_RESPONSE',
    message: '경제 서버 응답 형식이 올바르지 않습니다.',
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
        !_supportedScheme(uri)) {
      throw const FormatException('유효한 경제 API 주소가 아닙니다.');
    }
    return Uri.parse('$normalized/');
  }

  static bool _supportedScheme(Uri uri) =>
      uri.scheme == 'https' ||
      (uri.scheme == 'http' &&
          (uri.host == 'localhost' ||
              uri.host == '127.0.0.1' ||
              uri.host == '::1'));

  static Map<String, dynamic>? _decodeObject(String source) {
    try {
      return _objectOrNull(jsonDecode(source));
    } on FormatException {
      return null;
    }
  }

  static Map<String, dynamic> _object(Object? value) {
    final decoded = _objectOrNull(value);
    if (decoded == null) {
      throw _invalidResponse();
    }
    return decoded;
  }

  static Map<String, dynamic>? _objectOrNull(Object? value) =>
      value is Map<String, dynamic> ? value : null;

  static Map<String, dynamic>? _objectValue(
    Map<String, dynamic>? value,
    String key,
  ) => _objectOrNull(value?[key]);

  static String? _stringValue(Map<String, dynamic>? value, String key) {
    final result = value?[key];
    return result is String && result.isNotEmpty ? result : null;
  }

  static int? _nonNegativeInt(Object? value) =>
      value is int && value >= 0 ? value : null;

  static int? _positiveInt(Object? value) =>
      value is int && value > 0 ? value : null;

  static T? _enumValue<T extends Enum>(List<T> values, Object? name) {
    if (name is! String) {
      return null;
    }
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }
    return null;
  }

  static Set<String> _stringSet(Object? value) => value is List
      ? value.whereType<String>().where((item) => item.isNotEmpty).toSet()
      : <String>{};
}
