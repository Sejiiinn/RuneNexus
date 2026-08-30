import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/auth/google_authentication_api.dart';
import '../data/auth/google_web_authentication_config.dart';
import '../data/auth/online_account_session_controller.dart';
import '../data/economy/weekly_reward_api.dart';
import '../data/save/account_save_bootstrap.dart';
import '../data/save/local_save_repository.dart';
import '../data/save/local_save_slot.dart';
import '../data/save/local_online_save_outbox_repository.dart';
import '../data/save/legacy_save_transfer_api.dart';
import '../data/save/online_save_api.dart';
import '../data/save/online_save_coordinator.dart';
import '../domain/account/account_session.dart';
import '../domain/account/online_account_credentials.dart';
import '../domain/combat/game_phase.dart';
import '../domain/economy/weekly_reward_claim.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../platform/legacy_transfer/legacy_transfer_link.dart';
import '../ui/account/google_sign_in_dialog.dart';
import '../ui/account/legacy_save_transfer_dialog.dart';
import '../ui/game/game_button.dart';
import '../ui/game/game_image_assets.dart';
import '../ui/game/game_icons.dart';
import '../ui/game/game_modal.dart';
import '../ui/game/game_palette.dart';
import '../ui/game/game_text_styles.dart';
import '../ui/hud/game_hud.dart';
import '../ui/menu/main_menu_screen.dart';
import '../ui/menu/map_editor_panel.dart';

enum _AppScreen { main, stage, mapEditor }

enum _AccountConnectionPhase {
  importingLegacyProgress,
  savingCurrentProgress,
  loadingAccountProgress,
  openingAccountProgress,
}

class _AppLoadingProgress {
  const _AppLoadingProgress({required this.label, this.value});

  final String label;
  final double? value;
}

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({this.game, super.key});

  final RuneNexusGame? game;

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp>
    with WidgetsBindingObserver {
  late RuneNexusGame game;
  late final GoogleWebAuthenticationConfig _googleAuthenticationConfig;
  late final AccountSaveBootstrapService _accountSaveBootstrapService;
  GoogleAuthenticationApi? _googleAuthenticationApi;
  OnlineSaveApi? _onlineSaveApi;
  WeeklyRewardApi? _weeklyRewardApi;
  LegacySaveTransferApi? _legacySaveTransferApi;
  final ValueNotifier<_AppLoadingProgress> _loadingProgress = ValueNotifier(
    const _AppLoadingProgress(label: '게임을 시작하는 중'),
  );
  Future<void>? _initialLoad;
  _AppScreen _screen = _AppScreen.main;
  MainMenuTab _selectedMainMenuTab = MainMenuTab.stage;
  _OnlineAccountState? _onlineAccount;
  OnlineAccountSessionController? _onlineSession;
  OnlineSaveCoordinator? _onlineSaveCoordinator;
  Future<void>? _onlineSaveReloadOperation;
  Future<void>? _onlineSaveResumeOperation;
  bool _writerRecoveryInProgress = false;
  bool _clientUpdateRequired = false;
  _AccountConnectionPhase? _accountConnectionPhase;
  LocalSaveSlot _activeSaveSlot = LocalSaveSlot.guest;
  String? _pendingLegacyTransferToken;
  bool _legacyTransferPromptScheduled = false;

  AccountSession get _accountSession =>
      _onlineAccount?.presentation ?? const AccountSession.guest();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    game = widget.game ?? _createGameForSlot(LocalSaveSlot.guest);
    _accountSaveBootstrapService = AccountSaveBootstrapService(
      repositoryFactory: (slot) => createDefaultSaveRepository(slot: slot),
      outboxRepositoryFactory: (slot) =>
          createDefaultOnlineSaveOutboxRepository(slot: slot),
    );
    _googleAuthenticationConfig =
        GoogleWebAuthenticationConfig.fromEnvironment();
    if (_googleAuthenticationConfig.isConfigured) {
      _googleAuthenticationApi = GoogleAuthenticationApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      _onlineSaveApi = OnlineSaveApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      _weeklyRewardApi = WeeklyRewardApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      if (_googleAuthenticationConfig.legacyLocalTransferEnabled) {
        _legacySaveTransferApi = LegacySaveTransferApi(
          baseUrl: _googleAuthenticationConfig.apiBaseUrl,
        );
        final token = readLegacyTransferToken();
        if (token != null && LegacySaveTransferApi.isValidToken(token)) {
          _pendingLegacyTransferToken = token;
        }
      }
    }
  }

  RuneNexusGame _createGameForSlot(
    LocalSaveSlot slot, {
    OnlineSaveCoordinator? onlineSaveCoordinator,
  }) {
    return RuneNexusGame(
      saveRepository: createDefaultSaveRepository(slot: slot),
      onlineSaveRepository: onlineSaveCoordinator,
    );
  }

  Future<void> _prepareForAppStart(BuildContext context) async {
    await game.prepareForAppStart();
    if (!mounted || !context.mounted) {
      return;
    }
    _loadingProgress.value = const _AppLoadingProgress(
      label: '이미지 에셋 로드 중',
      value: 0,
    );
    await precacheRuneNexusStartupImages(
      context,
      onProgress: (value) {
        if (!mounted) {
          return;
        }
        _loadingProgress.value = _AppLoadingProgress(
          label: '이미지 에셋 로드 중',
          value: value,
        );
      },
    );
    if (!mounted || !context.mounted) {
      return;
    }
    _scheduleLegacyTransferSignIn(context);
  }

  void _scheduleLegacyTransferSignIn(BuildContext context) {
    if (_pendingLegacyTransferToken == null || _legacyTransferPromptScheduled) {
      return;
    }
    _legacyTransferPromptScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && context.mounted && _onlineSession == null) {
        unawaited(_connectGoogle(context));
      }
    });
  }

  void _openMainScreen({MainMenuTab tab = MainMenuTab.stage}) {
    setState(() {
      _screen = _AppScreen.main;
      _selectedMainMenuTab = tab;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineSaveCoordinator?.dispose();
    _onlineSession?.dispose();
    _loadingProgress.dispose();
    game.disposeAppResources();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed ||
        _onlineSaveResumeOperation != null) {
      return;
    }
    final coordinator = _onlineSaveCoordinator;
    if (coordinator == null) {
      return;
    }
    _resumeOnlineSaveInForeground(coordinator);
  }

  void _resumeOnlineSaveInForeground(OnlineSaveCoordinator coordinator) {
    if (_onlineSaveResumeOperation != null) {
      return;
    }
    final recoveringWriter =
        coordinator.snapshot.phase == OnlineSaveCoordinatorPhase.suspended;
    if (recoveringWriter && mounted) {
      setState(() {
        _writerRecoveryInProgress = true;
      });
    }
    final operation = coordinator.resumeForeground();
    _onlineSaveResumeOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_onlineSaveResumeOperation, operation)) {
          _onlineSaveResumeOperation = null;
          if (_writerRecoveryInProgress && mounted) {
            setState(() {
              _writerRecoveryInProgress = false;
            });
          }
        }
      }),
    );
  }

  bool _activeRunInProgress(GameSnapshot snapshot) {
    return snapshot.hasStageProgress &&
        snapshot.phase != GamePhase.success &&
        snapshot.phase != GamePhase.failure;
  }

  Future<bool> _confirmActiveRunSettlement({
    required BuildContext dialogContext,
    required GameSnapshot snapshot,
    required int nextStageNumber,
  }) async {
    final confirmed = await showGameDialog<bool>(
      context: dialogContext,
      builder: (context) {
        return _ActiveRunSettlementDialog(
          snapshot: snapshot,
          nextStageNumber: nextStageNumber,
        );
      },
    );
    return confirmed == true;
  }

  Future<void> _enterStageScreen() async {
    if (!mounted) {
      return;
    }
    setState(() {
      _screen = _AppScreen.stage;
    });
    if (game.snapshotNotifier.value.phase != GamePhase.restored) {
      game.resumeEngine();
    }
  }

  Future<void> _connectGoogle(BuildContext context) async {
    final authenticationApi = _googleAuthenticationApi;
    if (authenticationApi == null || _accountConnectionPhase != null) {
      return;
    }
    final credentials = await showGameDialog<OnlineAccountCredentials>(
      context: context,
      builder: (dialogContext) => GoogleSignInDialog(
        clientId: _googleAuthenticationConfig.clientId,
        authenticate: authenticationApi.authenticate,
        description: _pendingLegacyTransferToken == null
            ? null
            : 'Google 로그인을 완료하면 카카오 브라우저에서 가져온 기존 진행을 이 계정에 연결합니다.',
      ),
    );
    if (credentials == null || !mounted || !context.mounted) {
      return;
    }
    _onlineSession?.dispose();
    late final OnlineAccountSessionController onlineSession;
    onlineSession = OnlineAccountSessionController(
      credentials: credentials,
      refreshCredentials: authenticationApi.refresh,
      revokeSession: (refreshToken, accessToken) =>
          authenticationApi.logout(refreshToken, accessToken: accessToken),
      onCredentialsChanged: (updatedCredentials) {
        if (!mounted) {
          return;
        }
        setState(() {
          final current = _onlineAccount;
          _onlineAccount = _OnlineAccountState(
            credentials: updatedCredentials,
            syncStatus:
                current?.syncStatus ?? OnlineSaveSyncStatus.actionRequired,
            lastSyncedAt: current?.lastSyncedAt,
            pendingSaveCount: current?.pendingSaveCount ?? 0,
            issueMessage: current?.issueMessage,
          );
        });
      },
      onSessionInvalidated: () {
        _handleSessionInvalidated(onlineSession);
      },
    );
    _onlineSession = onlineSession;
    setState(() {
      _onlineAccount = _OnlineAccountState(
        credentials: credentials,
        syncStatus: OnlineSaveSyncStatus.actionRequired,
        issueMessage: context.l10n.syncActionRequired,
      );
    });
    if (_pendingLegacyTransferToken != null) {
      await _connectPendingLegacyTransfer(
        context: context,
        onlineSession: onlineSession,
        credentials: credentials,
      );
      return;
    }
    await _connectAccountProgress(
      context: context,
      onlineSession: onlineSession,
      credentials: credentials,
    );
  }

  Future<void> _connectPendingLegacyTransfer({
    required BuildContext context,
    required OnlineAccountSessionController onlineSession,
    required OnlineAccountCredentials credentials,
  }) async {
    final api = _legacySaveTransferApi;
    final token = _pendingLegacyTransferToken;
    if (api == null || token == null || _accountConnectionPhase != null) {
      return;
    }
    setState(() {
      _accountConnectionPhase = _AccountConnectionPhase.importingLegacyProgress;
    });
    try {
      await onlineSession.runAuthenticated(
        request: (accessToken) => api.consume(accessToken, token: token),
        isUnauthorized: (error) =>
            error is LegacySaveTransferException && error.isUnauthorized,
      );
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      _pendingLegacyTransferToken = null;
      clearLegacyTransferToken();
    } on LegacySaveTransferException catch (error) {
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      final message = switch (error.code) {
        'LEGACY_TRANSFER_TARGET_REQUIRES_MANUAL_REVIEW' =>
          '이 Google 계정에는 구매 재화가 있거나 안전하게 백업할 수 없는 진행이 있어 자동으로 교체하지 않았습니다.',
        'LEGACY_TRANSFER_ALREADY_USED' => '이미 다른 계정에 사용된 이전 링크입니다.',
        'LEGACY_TRANSFER_INVALID' => '이전 링크가 만료되었거나 유효하지 않습니다.',
        _ when error.transportFailure =>
          '이전 서버에 연결할 수 없습니다. 같은 링크로 다시 시도해 주세요.',
        _ => error.message,
      };
      setState(() {
        _onlineAccount = _OnlineAccountState(
          credentials: onlineSession.credentials ?? credentials,
          syncStatus: OnlineSaveSyncStatus.actionRequired,
          issueMessage: message,
        );
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
      return;
    } finally {
      if (mounted && identical(_onlineSession, onlineSession)) {
        setState(() {
          _accountConnectionPhase = null;
        });
      } else {
        _accountConnectionPhase = null;
      }
    }
    await _connectAccountProgress(
      context: context,
      onlineSession: onlineSession,
      credentials: onlineSession.credentials ?? credentials,
    );
  }

  Future<void> _openLegacyTransferDialog(BuildContext context) {
    return showGameDialog<void>(
      context: context,
      builder: (_) =>
          LegacySaveTransferDialog(createTransfer: _createLegacyTransferDraft),
    );
  }

  Future<LegacySaveTransferDraft> _createLegacyTransferDraft() async {
    final api = _legacySaveTransferApi;
    if (api == null || !_activeSaveSlot.isGuest || widget.game != null) {
      throw const LegacySaveTransferException(
        code: 'LEGACY_TRANSFER_UNAVAILABLE',
        message: '현재 환경에서는 기존 진행 이전을 사용할 수 없습니다.',
      );
    }
    await game.saveNow();
    final data = await createDefaultSaveRepository(
      slot: LocalSaveSlot.guest,
    ).load();
    if (data == null) {
      throw const LegacySaveTransferException(
        code: 'LEGACY_TRANSFER_SAVE_NOT_FOUND',
        message: '이전할 로컬 진행 데이터를 찾지 못했습니다.',
      );
    }
    return api.create(data);
  }

  Future<void> _connectAccountProgress({
    required BuildContext context,
    required OnlineAccountSessionController onlineSession,
    required OnlineAccountCredentials credentials,
  }) async {
    final onlineSaveApi = _onlineSaveApi;
    if (onlineSaveApi == null || _accountConnectionPhase != null) {
      return;
    }
    setState(() {
      _clientUpdateRequired = false;
      _accountConnectionPhase = _AccountConnectionPhase.savingCurrentProgress;
    });
    try {
      await game.saveNow();
      if (!mounted || !identical(_onlineSession, onlineSession)) {
        return;
      }
      setState(() {
        _accountConnectionPhase =
            _AccountConnectionPhase.loadingAccountProgress;
      });
      final bootstrap = await _accountSaveBootstrapService.bootstrap(
        accountId: credentials.accountId,
        loadRemote: () => onlineSession.runAuthenticated(
          request: onlineSaveApi.load,
          isUnauthorized: (error) =>
              error is OnlineSaveException && error.isUnauthorized,
        ),
      );
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      setState(() {
        _accountConnectionPhase =
            _AccountConnectionPhase.openingAccountProgress;
      });
      final coordinator = await _activateAccountSave(
        bootstrap: bootstrap,
        onlineSession: onlineSession,
        onlineSaveApi: onlineSaveApi,
      );
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession) ||
          coordinator == null) {
        return;
      }
      final activeCredentials = onlineSession.credentials ?? credentials;
      setState(() {
        _activeSaveSlot = bootstrap.activeSlot;
        _onlineAccount = _onlineAccountStateFor(
          activeCredentials,
          coordinator.snapshot,
        );
      });
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(context.l10n.accountProgressConnected)),
      );
    } on Object catch (error) {
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      final requiresClientUpdate =
          error is OnlineSaveException &&
          error.code == 'CLIENT_UPDATE_REQUIRED';
      final issueMessage = requiresClientUpdate
          ? context.l10n.clientUpdateRequiredDescription
          : context.l10n.accountProgressConnectionFailed;
      setState(() {
        _clientUpdateRequired = requiresClientUpdate;
        _activeSaveSlot = LocalSaveSlot.guest;
        _onlineAccount = _OnlineAccountState(
          credentials: onlineSession.credentials ?? credentials,
          syncStatus: OnlineSaveSyncStatus.actionRequired,
          issueMessage: issueMessage,
        );
      });
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(issueMessage)));
    } finally {
      if (mounted && identical(_onlineSession, onlineSession)) {
        setState(() {
          _accountConnectionPhase = null;
        });
      } else {
        _accountConnectionPhase = null;
      }
    }
  }

  Future<OnlineSaveCoordinator?> _activateAccountSave({
    required AccountSaveBootstrapResult bootstrap,
    required OnlineAccountSessionController onlineSession,
    required OnlineSaveClient onlineSaveApi,
  }) async {
    if (widget.game != null) {
      throw StateError('외부에서 주입된 게임의 저장 슬롯은 교체할 수 없습니다.');
    }
    final slot = bootstrap.activeSlot;
    final accountId = slot.accountId;
    if (accountId == null) {
      throw StateError('계정 저장 연결에는 account 슬롯이 필요합니다.');
    }

    final saveRepository = createDefaultSaveRepository(slot: slot);
    final outboxRepository = createDefaultOnlineSaveOutboxRepository(
      slot: slot,
    );
    late final OnlineSaveCoordinator coordinator;
    coordinator = OnlineSaveCoordinator(
      accountId: accountId,
      client: onlineSaveApi,
      session: onlineSession,
      initialRevision: bootstrap.remoteRevision,
      outboxRepository: outboxRepository,
      loadPersistedCheckpoint: saveRepository.load,
      persistedSaveRepository: saveRepository,
      beforeRemoteRebase: () async {
        if (identical(_onlineSaveCoordinator, coordinator)) {
          game.pauseEngine();
          await game.quiesceLocalSavesForRemoteRebase();
        }
      },
      resumeLocalSaves: () {
        if (identical(_onlineSaveCoordinator, coordinator)) {
          game.resumeLocalSavesAfterRemoteRebaseFailure();
        }
      },
      onSnapshotChanged: (snapshot) {
        _handleOnlineSaveSnapshot(coordinator, snapshot);
      },
    );
    RuneNexusGame? replacement;

    try {
      await coordinator.initialize();

      replacement = RuneNexusGame(
        saveRepository: saveRepository,
        onlineSaveRepository: coordinator,
      );
      await replacement.prepareForAppStart();
      coordinator.acknowledgeGameReload();

      final persistedAccountData = await saveRepository.load();
      final requiresClientUpdate =
          coordinator.snapshot.issueCode == 'CLIENT_UPDATE_REQUIRED';
      if (persistedAccountData == null && requiresClientUpdate) {
        throw const OnlineSaveException(
          code: 'CLIENT_UPDATE_REQUIRED',
          message: '최신 버전에서 계정 진행을 사용할 수 있습니다.',
          statusCode: 426,
        );
      }
      if (requiresClientUpdate) {
        replacement.pauseEngine();
        await replacement.quiesceLocalSavesForRemoteRebase();
      }
      final canInitializeEmptyAccount =
          bootstrap.source == AccountSaveBootstrapSource.newAccount ||
          (bootstrap.source == AccountSaveBootstrapSource.existingOutbox &&
              coordinator.snapshot.phase == OnlineSaveCoordinatorPhase.idle &&
              coordinator.snapshot.remoteRevision == 0 &&
              coordinator.snapshot.pendingSaveCount == 0);
      if (persistedAccountData == null && !canInitializeEmptyAccount) {
        throw StateError('복구할 계정 진행 데이터를 찾지 못했습니다.');
      }
      if (persistedAccountData == null) {
        await replacement.saveNow();
        final initialData = await saveRepository.load();
        if (initialData == null) {
          throw StateError('새 계정 진행의 초기 저장 데이터를 만들지 못했습니다.');
        }
        await coordinator.enqueuePersistedCheckpoint(initialData);
      }
    } on Object {
      coordinator.dispose();
      replacement?.disposeAppResources();
      rethrow;
    }

    if (!mounted || !identical(_onlineSession, onlineSession)) {
      coordinator.dispose();
      replacement.disposeAppResources();
      return null;
    }
    final readyReplacement = replacement;
    final previousGame = game;
    final previousCoordinator = _onlineSaveCoordinator;
    setState(() {
      game = readyReplacement;
      _screen = _AppScreen.main;
      _onlineSaveCoordinator = coordinator;
    });
    previousCoordinator?.dispose();
    previousGame.disposeAppResources();
    return coordinator;
  }

  void _handleOnlineSaveSnapshot(
    OnlineSaveCoordinator coordinator,
    OnlineSaveCoordinatorSnapshot snapshot,
  ) {
    if (!mounted || !identical(_onlineSaveCoordinator, coordinator)) {
      return;
    }
    final current = _onlineAccount;
    final credentials = _onlineSession?.credentials ?? current?.credentials;
    if (credentials == null || credentials.accountId != coordinator.accountId) {
      return;
    }
    final pausesAccountPlay =
        snapshot.phase == OnlineSaveCoordinatorPhase.suspended ||
        snapshot.phase == OnlineSaveCoordinatorPhase.rebasing ||
        snapshot.issueCode == 'CLIENT_UPDATE_REQUIRED';
    setState(() {
      _onlineAccount = _onlineAccountStateFor(credentials, snapshot);
      if (pausesAccountPlay) {
        _screen = _AppScreen.main;
      }
    });
    if (pausesAccountPlay) {
      game.pauseEngine();
    }
    if (snapshot.requiresGameReload) {
      _startOnlineSaveGameReload(coordinator);
    }
  }

  void _startOnlineSaveGameReload(OnlineSaveCoordinator coordinator) {
    if (_onlineSaveReloadOperation != null) {
      return;
    }
    final operation = _reloadGameAfterRemoteRebase(coordinator);
    _onlineSaveReloadOperation = operation;
    unawaited(
      operation.whenComplete(() {
        if (identical(_onlineSaveReloadOperation, operation)) {
          _onlineSaveReloadOperation = null;
        }
      }),
    );
  }

  Future<void> _reloadGameAfterRemoteRebase(
    OnlineSaveCoordinator coordinator,
  ) async {
    if (!mounted || !identical(_onlineSaveCoordinator, coordinator)) {
      return;
    }
    final slot = LocalSaveSlot.account(coordinator.accountId);
    final replacement = _createGameForSlot(
      slot,
      onlineSaveCoordinator: coordinator,
    );
    try {
      await replacement.prepareForAppStart();
    } on Object {
      replacement.disposeAppResources();
      await coordinator.reportGameReloadFailure();
      return;
    }
    if (!mounted ||
        !identical(_onlineSaveCoordinator, coordinator) ||
        !coordinator.snapshot.requiresGameReload) {
      replacement.disposeAppResources();
      return;
    }
    final previous = game;
    setState(() {
      game = replacement;
      _screen = _AppScreen.main;
    });
    previous.disposeAppResources();
    coordinator.acknowledgeGameReload();
  }

  Future<void> _claimWeeklyReward(WeeklyRewardClaimTarget target) async {
    final api = _weeklyRewardApi;
    final session = _onlineSession;
    final coordinator = _onlineSaveCoordinator;
    if (api == null ||
        session == null ||
        coordinator == null ||
        _activeSaveSlot.isGuest) {
      throw const WeeklyRewardClaimFailure(
        'Google 계정을 연결한 뒤 주간 보상을 받을 수 있습니다.',
      );
    }
    if (_clientUpdateRequired ||
        coordinator.snapshot.issueCode == 'CLIENT_UPDATE_REQUIRED') {
      throw const WeeklyRewardClaimFailure('최신 버전으로 업데이트한 뒤 주간 보상을 받아 주세요.');
    }

    if (!await game.saveAccountCheckpoint()) {
      throw const WeeklyRewardClaimFailure(
        '계정 진행을 저장하지 못했습니다. 저장 상태를 확인한 뒤 다시 시도해 주세요.',
      );
    }
    await coordinator.currentAttempt;
    if (!identical(coordinator, _onlineSaveCoordinator)) {
      throw const WeeklyRewardClaimFailure('계정 진행이 변경되어 보상 수령을 중단했습니다.');
    }
    final saveState = coordinator.snapshot;
    if (saveState.phase != OnlineSaveCoordinatorPhase.idle ||
        saveState.pendingSaveCount != 0 ||
        saveState.hasPendingRemoteRebase ||
        saveState.requiresGameReload) {
      throw const WeeklyRewardClaimFailure('계정 진행 동기화를 마친 뒤 다시 시도해 주세요.');
    }

    // 401 재인증 후에도 동일 요청으로 판정되도록 key를 한 번만 생성한다.
    final idempotencyKey = createOnlineSaveIdempotencyKey();
    try {
      final receipt = await session.runAuthenticated(
        request: (accessToken) => api.claim(
          accessToken,
          idempotencyKey: idempotencyKey,
          target: target,
        ),
        isUnauthorized: (error) =>
            error is WeeklyRewardException && error.isUnauthorized,
      );
      if (!identical(session, _onlineSession) ||
          !identical(coordinator, _onlineSaveCoordinator)) {
        throw const WeeklyRewardClaimFailure('계정 세션이 변경되어 보상 수령을 중단했습니다.');
      }
      final applied = game.applyWeeklyRewardReceipt(receipt);
      if (!applied && !_isWeeklyRewardLocallyClaimed(target)) {
        throw const WeeklyRewardClaimFailure(
          '주간 진행 정보가 갱신되었습니다. 임무 화면을 다시 열어 주세요.',
        );
      }
      if (applied) {
        if (!await game.saveAccountCheckpoint()) {
          throw const WeeklyRewardClaimFailure(
            '보상은 확인됐지만 계정 저장이 지연되고 있습니다. 잠시 후 다시 확인해 주세요.',
          );
        }
      }
    } on WeeklyRewardClaimFailure {
      rethrow;
    } on WeeklyRewardException catch (error) {
      final message = switch (error.code) {
        'SAVE_WRITER_REPLACED' => '다른 기기의 진행을 확인한 뒤 다시 시도해 주세요.',
        'SAVE_SYNC_REQUIRED' => '계정 진행 동기화를 마친 뒤 다시 시도해 주세요.',
        'WEEKLY_REWARD_PERIOD_MISMATCH' => '주간 임무가 갱신되었습니다. 임무 화면을 다시 열어 주세요.',
        'WEEKLY_REWARD_NOT_ELIGIBLE' => '현재 서버에 저장된 진행으로는 이 보상을 받을 수 없습니다.',
        _ when error.transportFailure => '보상 서버에 연결할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        _ => error.message,
      };
      throw WeeklyRewardClaimFailure(message);
    } on Object {
      throw const WeeklyRewardClaimFailure(
        '주간 보상을 확인하지 못했습니다. 잠시 후 다시 시도해 주세요.',
      );
    }
  }

  bool _isWeeklyRewardLocallyClaimed(WeeklyRewardClaimTarget target) {
    final snapshot = game.snapshotNotifier.value;
    return switch (target.kind) {
      WeeklyRewardKind.quest => snapshot.claimedWeeklyQuestRewards.contains(
        target.questType,
      ),
      WeeklyRewardKind.allComplete => snapshot.weeklyQuestAllCompleteClaimed,
      WeeklyRewardKind.attendance => snapshot.weeklyAttendanceRewardClaimed,
    };
  }

  _OnlineAccountState _onlineAccountStateFor(
    OnlineAccountCredentials credentials,
    OnlineSaveCoordinatorSnapshot snapshot,
  ) {
    final syncStatus = switch (snapshot.phase) {
      OnlineSaveCoordinatorPhase.idle => OnlineSaveSyncStatus.synchronized,
      OnlineSaveCoordinatorPhase.sending ||
      OnlineSaveCoordinatorPhase.rebasing => OnlineSaveSyncStatus.syncing,
      OnlineSaveCoordinatorPhase.retryWaiting => OnlineSaveSyncStatus.offline,
      OnlineSaveCoordinatorPhase.suspended ||
      OnlineSaveCoordinatorPhase.conflict ||
      OnlineSaveCoordinatorPhase.blocked ||
      OnlineSaveCoordinatorPhase.disposed =>
        OnlineSaveSyncStatus.actionRequired,
    };
    final issueMessage = switch (snapshot.phase) {
      OnlineSaveCoordinatorPhase.conflict => context.l10n.saveSyncConflict,
      OnlineSaveCoordinatorPhase.suspended => context.l10n.saveSyncBlocked,
      OnlineSaveCoordinatorPhase.blocked => context.l10n.saveSyncBlocked,
      OnlineSaveCoordinatorPhase.disposed => context.l10n.saveSyncBlocked,
      _ => null,
    };
    return _OnlineAccountState(
      credentials: credentials,
      syncStatus: syncStatus,
      lastSyncedAt: snapshot.lastSyncedAt,
      pendingSaveCount: snapshot.pendingSaveCount,
      issueMessage: issueMessage,
    );
  }

  Future<void> _replaceGameForSlot(LocalSaveSlot slot) async {
    if (widget.game != null) {
      throw StateError('외부에서 주입된 게임의 저장 슬롯은 교체할 수 없습니다.');
    }
    final replacement = _createGameForSlot(slot);
    try {
      await replacement.prepareForAppStart();
    } on Object {
      replacement.disposeAppResources();
      rethrow;
    }
    if (!mounted) {
      replacement.disposeAppResources();
      return;
    }
    final previous = game;
    final previousCoordinator = _onlineSaveCoordinator;
    setState(() {
      game = replacement;
      _screen = _AppScreen.main;
      _onlineSaveCoordinator = null;
    });
    previousCoordinator?.dispose();
    previous.disposeAppResources();
  }

  void _handleSessionInvalidated(
    OnlineAccountSessionController invalidatedSession,
  ) {
    if (!mounted || !identical(_onlineSession, invalidatedSession)) {
      return;
    }
    final coordinator = _onlineSaveCoordinator;
    _onlineSaveCoordinator = null;
    coordinator?.dispose();
    _onlineSession = null;
    setState(() {
      _clientUpdateRequired = false;
      _accountConnectionPhase = null;
    });
    unawaited(_returnToGuestAfterSessionEnd());
  }

  Future<void> _returnToGuestAfterSessionEnd() async {
    try {
      if (!_activeSaveSlot.isGuest && widget.game == null) {
        await game.saveNow();
        await _replaceGameForSlot(LocalSaveSlot.guest);
      }
    } on Object {
      // 계정 슬롯은 보존되어 있으므로 다음 앱 시작에서 guest 슬롯을 다시 연다.
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _activeSaveSlot = LocalSaveSlot.guest;
      _onlineAccount = null;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    final onlineSession = _onlineSession;
    if (onlineSession == null) {
      return;
    }
    try {
      await onlineSession.logout();
    } on Object {
      if (!mounted || !context.mounted) {
        return;
      }
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(context.l10n.signOutFailed)));
    }
  }

  Future<void> _startStage(
    int stageNumber,
    GameSnapshot snapshot,
    BuildContext dialogContext,
  ) async {
    final activeRunInProgress = _activeRunInProgress(snapshot);
    final switchingStage =
        activeRunInProgress && stageNumber != snapshot.currentStageNumber;

    if (switchingStage) {
      final confirmed = await _confirmActiveRunSettlement(
        dialogContext: dialogContext,
        snapshot: snapshot,
        nextStageNumber: stageNumber,
      );
      if (!confirmed || !mounted) {
        return;
      }
      await game.settleCurrentRunAsFailure();
      game.startStage(stageNumber);
      await game.saveNow();
    } else if (!activeRunInProgress ||
        snapshot.phase == GamePhase.success ||
        snapshot.phase == GamePhase.failure ||
        stageNumber != snapshot.currentStageNumber) {
      game.startStage(stageNumber);
      await game.saveNow();
    }
    await _enterStageScreen();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rune Nexus',
      locale: const Locale('ko'),
      supportedLocales: RuneNexusLocalizations.supportedLocales,
      localizationsDelegates: const [
        RuneNexusLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2ED3FF),
          brightness: Brightness.dark,
        ),
        fontFamily: 'NotoSansKR',
        fontFamilyFallback: const ['sans-serif'],
        useMaterial3: true,
      ),
      home: Builder(
        builder: (appContext) {
          _initialLoad ??= _prepareForAppStart(appContext);
          return Scaffold(
            backgroundColor: const Color(0xFF07111D),
            body: FutureBuilder<void>(
              future: _initialLoad,
              builder: (context, loadState) {
                if (loadState.hasError) {
                  return const _AppLoadErrorScreen();
                }
                if (loadState.connectionState != ConnectionState.done) {
                  return _AppLoadingScreen(
                    progressListenable: _loadingProgress,
                  );
                }
                late final Widget content;
                if (_screen == _AppScreen.stage) {
                  content = GameHud(
                    game: game,
                    onOpenStageSelect: () => _openMainScreen(),
                    onOpenPermanentUpgrades: () =>
                        _openMainScreen(tab: MainMenuTab.permanentUpgrades),
                    onStartStage: (stageNumber) => _startStage(
                      stageNumber,
                      game.snapshotNotifier.value,
                      context,
                    ),
                  );
                } else if (_screen == _AppScreen.mapEditor) {
                  content = _MapEditorScreen(
                    initialStageNumber:
                        game.snapshotNotifier.value.currentStageNumber,
                    onBack: () => _openMainScreen(),
                  );
                } else {
                  content = MainMenuScreen(
                    game: game,
                    snapshot: game.snapshotNotifier.value,
                    snapshotListenable: game.snapshotNotifier,
                    selectedTab: _selectedMainMenuTab,
                    onSelectTab: (tab) {
                      setState(() {
                        _selectedMainMenuTab = tab;
                      });
                    },
                    onStartStage: (stageNumber) => _startStage(
                      stageNumber,
                      game.snapshotNotifier.value,
                      context,
                    ),
                    accountSession: _accountSession,
                    onConnectGoogle: _googleAuthenticationApi == null
                        ? null
                        : () => _connectGoogle(context),
                    onCreateLegacyTransfer:
                        _legacySaveTransferApi == null ||
                            !_activeSaveSlot.isGuest ||
                            widget.game != null
                        ? null
                        : () => _openLegacyTransferDialog(context),
                    onSignOut: _onlineSession == null
                        ? null
                        : () => _signOut(context),
                    onSyncAccount:
                        _onlineSession == null || !_activeSaveSlot.isGuest
                        ? null
                        : () => _pendingLegacyTransferToken != null
                              ? _connectPendingLegacyTransfer(
                                  context: context,
                                  onlineSession: _onlineSession!,
                                  credentials: _onlineAccount!.credentials,
                                )
                              : _connectAccountProgress(
                                  context: context,
                                  onlineSession: _onlineSession!,
                                  credentials: _onlineAccount!.credentials,
                                ),
                    onClaimWeeklyReward:
                        _onlineSession == null || _activeSaveSlot.isGuest
                        ? null
                        : _claimWeeklyReward,
                    onOpenMapEditor: () {
                      setState(() {
                        _screen = _AppScreen.mapEditor;
                      });
                    },
                  );
                }
                final coordinator = _onlineSaveCoordinator;
                final accountConnectionPhase = _accountConnectionPhase;
                if (accountConnectionPhase != null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(child: content),
                      _AccountConnectionOverlay(phase: accountConnectionPhase),
                    ],
                  );
                }
                final clientUpdateRequired =
                    _clientUpdateRequired ||
                    coordinator?.snapshot.issueCode == 'CLIENT_UPDATE_REQUIRED';
                if (clientUpdateRequired) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      IgnorePointer(child: content),
                      _ClientUpdateRequiredOverlay(
                        onSignOut: _onlineSession == null
                            ? null
                            : () => _signOut(context),
                      ),
                    ],
                  );
                }
                final writerSuspended =
                    coordinator?.snapshot.phase ==
                    OnlineSaveCoordinatorPhase.suspended;
                final remoteRecoveryInProgress =
                    (coordinator?.snapshot.hasPendingRemoteRebase ?? false) ||
                    (coordinator?.snapshot.requiresGameReload ?? false);
                final remoteRecoveryBlocked =
                    remoteRecoveryInProgress &&
                    coordinator?.snapshot.phase ==
                        OnlineSaveCoordinatorPhase.blocked;
                if (!writerSuspended &&
                    !_writerRecoveryInProgress &&
                    !remoteRecoveryInProgress) {
                  return content;
                }
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    IgnorePointer(child: content),
                    _WriterRecoveryOverlay(
                      recovering:
                          _writerRecoveryInProgress ||
                          (remoteRecoveryInProgress && !remoteRecoveryBlocked),
                      blocked: remoteRecoveryBlocked,
                      onResume: coordinator == null
                          ? null
                          : () => _resumeOnlineSaveInForeground(coordinator),
                      onSignOut:
                          !remoteRecoveryBlocked || _onlineSession == null
                          ? null
                          : () => _signOut(context),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _ClientUpdateRequiredOverlay extends StatelessWidget {
  const _ClientUpdateRequiredOverlay({required this.onSignOut});

  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: const Color(0xE607111D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GameModalFrame(
            maxWidth: 420,
            tone: GameModalTone.danger,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.clientUpdateRequiredTitle,
                  style: GameTextStyles.title,
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.clientUpdateRequiredDescription,
                  style: GameTextStyles.body,
                ),
                if (onSignOut != null) ...[
                  const SizedBox(height: 16),
                  GameButton(
                    onPressed: onSignOut,
                    label: l10n.signOut,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    variant: GameButtonVariant.ghost,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountConnectionOverlay extends StatelessWidget {
  const _AccountConnectionOverlay({required this.phase});

  final _AccountConnectionPhase phase;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final description = switch (phase) {
      _AccountConnectionPhase.importingLegacyProgress =>
        l10n.importingLegacyProgress,
      _AccountConnectionPhase.savingCurrentProgress =>
        l10n.savingCurrentProgress,
      _AccountConnectionPhase.loadingAccountProgress =>
        l10n.loadingAccountProgress,
      _AccountConnectionPhase.openingAccountProgress =>
        l10n.openingAccountProgress,
    };
    return ColoredBox(
      color: const Color(0xD907111D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GameModalFrame(
            maxWidth: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.connectingAccountProgress,
                  style: GameTextStyles.title,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(description, style: GameTextStyles.body),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WriterRecoveryOverlay extends StatelessWidget {
  const _WriterRecoveryOverlay({
    required this.recovering,
    required this.blocked,
    required this.onResume,
    required this.onSignOut,
  });

  final bool recovering;
  final bool blocked;
  final VoidCallback? onResume;
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ColoredBox(
      color: const Color(0xD907111D),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GameModalFrame(
            maxWidth: 420,
            tone: GameModalTone.danger,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.writerReplacedTitle, style: GameTextStyles.title),
                const SizedBox(height: 10),
                Text(
                  l10n.writerReplacedDescription,
                  style: GameTextStyles.body,
                ),
                const SizedBox(height: 16),
                GameButton(
                  onPressed: recovering || blocked ? null : onResume,
                  label: blocked
                      ? l10n.saveSyncBlocked
                      : recovering
                      ? l10n.loadingLatestProgress
                      : l10n.loadLatestProgress,
                  icon: recovering
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.cloud_download_outlined, size: 18),
                ),
                if (onSignOut != null) ...[
                  const SizedBox(height: 8),
                  GameButton(
                    onPressed: onSignOut,
                    label: l10n.signOut,
                    icon: const Icon(Icons.logout_rounded, size: 17),
                    variant: GameButtonVariant.ghost,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OnlineAccountState {
  const _OnlineAccountState({
    required this.credentials,
    required this.syncStatus,
    this.lastSyncedAt,
    this.pendingSaveCount = 0,
    this.issueMessage,
  });

  final OnlineAccountCredentials credentials;
  final OnlineSaveSyncStatus syncStatus;
  final DateTime? lastSyncedAt;
  final int pendingSaveCount;
  final String? issueMessage;

  AccountSession get presentation => AccountSession.authenticated(
    accountId: credentials.accountId,
    identities: const [
      AccountIdentity(
        provider: AccountIdentityProvider.google,
        displayName: 'Google',
      ),
    ],
    syncStatus: syncStatus,
    lastSyncedAt: lastSyncedAt,
    pendingSaveCount: pendingSaveCount,
    issueMessage: issueMessage,
  );
}

class _ActiveRunSettlementDialog extends StatelessWidget {
  const _ActiveRunSettlementDialog({
    required this.snapshot,
    required this.nextStageNumber,
  });

  final GameSnapshot snapshot;
  final int nextStageNumber;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return GameModalFrame(
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.flag_outlined,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.endActiveStageTitle,
                  style: GameTextStyles.title,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.endActiveStageBody(
              currentStageNumber: snapshot.currentStageNumber,
              nextStageNumber: nextStageNumber,
              runeReward: snapshot.projectedFailureRuneReward,
            ),
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x3302070D),
              border: Border.all(color: const Color(0x558FA8BA)),
              borderRadius: BorderRadius.circular(GamePalette.radius),
            ),
            child: Row(
              children: [
                const RuneCurrencyIcon(size: 17),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '+${snapshot.projectedFailureRuneReward} ${l10n.runes}',
                    style: GameTextStyles.withColor(
                      GameTextStyles.sectionTitle,
                      GamePalette.goldBright,
                    ),
                  ),
                ),
                Text(
                  '${l10n.stageName(snapshot.currentStageNumber)} -> '
                  '${l10n.stageName(nextStageNumber)}',
                  style: GameTextStyles.withColor(
                    GameTextStyles.caption,
                    GamePalette.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  label: l10n.cancel,
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  label: l10n.settleAndStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 17),
                  variant: GameButtonVariant.primary,
                  accentColor: GamePalette.cyan,
                  height: 38,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MapEditorScreen extends StatelessWidget {
  const _MapEditorScreen({
    required this.initialStageNumber,
    required this.onBack,
  });

  final int initialStageNumber;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF07111D),
      child: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: _AppBackdrop()),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 64, 16, 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xF0091624),
                      border: Border.all(color: const Color(0x9933D8FF)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 20,
                          offset: Offset(0, 12),
                        ),
                      ],
                    ),
                    child: DebugMapEditorPanel(
                      initialStageNumber: initialStageNumber,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              left: 16,
              child: SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  tooltip: '메인 메뉴',
                  onPressed: onBack,
                  style: IconButton.styleFrom(
                    foregroundColor: const Color(0xFFE8FBFF),
                    backgroundColor: const Color(0xE607111D),
                    side: const BorderSide(color: Color(0x6650E6FF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  const _AppBackdrop();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AppBackdropPainter());
  }
}

class _AppBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x33143A4E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(size.width * 0.5, size.height * 0.28),
      size.shortestSide * 0.32,
      paint,
    );

    final linePaint = Paint()
      ..color = const Color(0x1233D8FF)
      ..strokeWidth = 1;
    const spacing = 38.0;
    for (var x = -spacing; x < size.width + spacing; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x + 90, size.height), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppLoadingScreen extends StatelessWidget {
  const _AppLoadingScreen({required this.progressListenable});

  final ValueListenable<_AppLoadingProgress> progressListenable;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF07111D),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.24),
            radius: 0.9,
            colors: [Color(0xFF123144), Color(0xFF0A1B29), Color(0xFF07111D)],
            stops: [0, 0.38, 1],
          ),
        ),
        child: Stack(
          children: [
            const Align(alignment: Alignment(0, -0.24), child: _AppBootCore()),
            Positioned.fill(
              child: SafeArea(
                top: false,
                left: false,
                right: false,
                minimum: const EdgeInsets.only(bottom: 42),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 36),
                    child: ValueListenableBuilder<_AppLoadingProgress>(
                      valueListenable: progressListenable,
                      builder: (context, progress, _) {
                        final value = progress.value;
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              progress.label,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFB9D6E4),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            Semantics(
                              label: '게임 시작 진행률',
                              value: value == null
                                  ? null
                                  : '${(value * 100).round()}%',
                              child: _AppBootProgressBar(value: value),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppBootCore extends StatefulWidget {
  const _AppBootCore();

  @override
  State<_AppBootCore> createState() => _AppBootCoreState();
}

class _AppBootCoreState extends State<_AppBootCore>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 240,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: _AppBootAmbientPainter()),
            ),
          ),
          SizedBox.square(
            dimension: 58,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final phase = _controller.value;
                final pulse =
                    0.94 + math.sin(phase * math.pi * 2 * 1.27) * 0.06;
                return CustomPaint(
                  painter: _AppBootCorePainter(
                    rotation: phase * math.pi * 2,
                    pulse: pulse,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AppBootAmbientPainter extends CustomPainter {
  const _AppBootAmbientPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    // 코어 주변 저강도 공간광.
    canvas.drawCircle(
      center,
      98,
      Paint()
        ..color = const Color(0x122ED3FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 22
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22),
    );
    final ringGlowPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6);
    final ringPaint = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    ringGlowPaint.color = const Color(0x0A5EE2FF);
    canvas.drawCircle(center, 118, ringGlowPaint);
    ringPaint.color = const Color(0x105EE2FF);
    canvas.drawCircle(center, 118, ringPaint);
    ringGlowPaint.color = const Color(0x07E7C66A);
    canvas.drawCircle(center, 88, ringGlowPaint);
    ringPaint.color = const Color(0x0AE7C66A);
    canvas.drawCircle(center, 88, ringPaint);
    ringGlowPaint.color = const Color(0x0C5EE2FF);
    canvas.drawCircle(center, 44, ringGlowPaint);
    ringPaint.color = const Color(0x125EE2FF);
    canvas.drawCircle(center, 44, ringPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AppBootCorePainter extends CustomPainter {
  const _AppBootCorePainter({required this.rotation, required this.pulse});

  final double rotation;
  final double pulse;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    const orbitRadius = 28.0;
    canvas.drawCircle(
      center,
      orbitRadius,
      Paint()
        ..color = const Color(0x348EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final orbitRect = Rect.fromCircle(center: center, radius: orbitRadius);
    final arcStart = -math.pi / 2 + rotation;
    const arcSweep = 1.8;
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0x428EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.2),
    );
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0x708EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.8),
    );
    canvas.drawArc(
      orbitRect,
      arcStart,
      arcSweep,
      false,
      Paint()
        ..color = const Color(0xD98EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );

    final sparkAngle = arcStart + arcSweep;
    final sparkCenter = center.translate(
      math.cos(sparkAngle) * orbitRadius,
      math.sin(sparkAngle) * orbitRadius,
    );
    canvas.drawCircle(
      sparkCenter,
      4,
      Paint()
        ..color = const Color(0x70E7C66A)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5),
    );
    canvas.drawCircle(
      sparkCenter,
      1.6,
      Paint()
        ..color = const Color(0xE6E7C66A)
        ..isAntiAlias = true,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(pulse);
    canvas.rotate(math.pi / 4);
    final diamond = RRect.fromRectAndRadius(
      const Rect.fromLTWH(-9, -9, 18, 18),
      const Radius.circular(1.5),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0x528EE6FF)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0xC20F3E52)
        ..isAntiAlias = true,
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0x428EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.6),
    );
    canvas.drawRRect(
      diamond,
      Paint()
        ..color = const Color(0xD98EE6FF)
        ..isAntiAlias = true
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-3.5, -3.5, 7, 7),
        const Radius.circular(1),
      ),
      Paint()
        ..color = const Color(0xE6E8FBFF)
        ..isAntiAlias = true
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.8),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AppBootCorePainter oldDelegate) {
    return oldDelegate.rotation != rotation || oldDelegate.pulse != pulse;
  }
}

class _AppBootProgressBar extends StatefulWidget {
  const _AppBootProgressBar({required this.value});

  final double? value;

  @override
  State<_AppBootProgressBar> createState() => _AppBootProgressBarState();
}

class _AppBootProgressBarState extends State<_AppBootProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void didUpdateWidget(covariant _AppBootProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value == null && widget.value != null) {
      _controller.stop();
    } else if (oldWidget.value != null && widget.value == null) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 286),
      child: Container(
        width: double.infinity,
        height: 5,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: const Color(0x172ED3FF),
          border: Border.all(color: const Color(0x245EE2FF)),
          borderRadius: BorderRadius.circular(999),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final value = widget.value;
            if (value != null) {
              return Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0).toDouble(),
                  child: const _AppBootProgressFill(),
                ),
              );
            }
            return AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final trackWidth = constraints.maxWidth;
                final fillWidth = trackWidth * 0.38;
                final offset =
                    -fillWidth +
                    (trackWidth + fillWidth) *
                        Curves.easeInOut.transform(_controller.value);
                return Stack(
                  children: [
                    Transform.translate(
                      offset: Offset(offset, 0),
                      child: SizedBox(
                        width: fillWidth,
                        child: const _AppBootProgressFill(),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _AppBootProgressFill extends StatelessWidget {
  const _AppBootProgressFill();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0x008EE6FF),
            Color(0xFF8EE6FF),
            Color(0xFFE8FBFF),
            Color(0x008EE6FF),
          ],
          stops: [0, 0.46, 0.58, 1],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _AppLoadErrorScreen extends StatelessWidget {
  const _AppLoadErrorScreen();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Color(0xFF07111D),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Color(0xFFFF8A80), size: 38),
            SizedBox(height: 14),
            Text(
              '초기화에 실패했습니다',
              style: TextStyle(
                color: Color(0xFFFFE8E5),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6),
            Text(
              '앱을 다시 시작해 주세요',
              style: TextStyle(color: Color(0xFFBFA19D), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
