import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../data/account/account_profile_api.dart';
import '../data/auth/google_authentication_api.dart';
import '../data/auth/authentication_session_repository.dart';
import '../data/auth/google_web_authentication_config.dart';
import '../data/auth/online_account_session_controller.dart';
import '../data/economy/economy_api.dart';
import '../data/economy/economy_coordinator.dart';
import '../data/economy/local_economy_command_outbox_repository.dart';
import '../data/economy/weekly_reward_api.dart';
import '../data/save/account_save_bootstrap.dart';
import '../data/save/local_save_repository.dart';
import '../data/save/local_save_slot.dart';
import '../data/save/local_online_save_outbox_repository.dart';
import '../data/save/legacy_save_transfer_api.dart';
import '../data/save/online_save_api.dart';
import '../data/save/online_save_coordinator.dart';
import '../domain/account/account_profile.dart';
import '../domain/account/account_session.dart';
import '../domain/account/online_account_credentials.dart';
import '../domain/combat/game_phase.dart';
import '../domain/economy/weekly_reward_claim.dart';
import '../game/game_snapshot.dart';
import '../game/rune_nexus_game.dart';
import '../l10n/rune_nexus_localizations.dart';
import '../platform/legacy_transfer/legacy_transfer_link.dart';
import '../platform/auth/google_identity_session.dart';
import '../platform/update/app_update_service.dart';
import 'app_update_gate.dart';
import 'app_startup_screen.dart';
import '../ui/account/google_sign_in_dialog.dart';
import '../ui/account/nickname_setup_dialog.dart';
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
  checkingNickname,
  importingLegacyProgress,
  savingCurrentProgress,
  loadingAccountProgress,
  openingAccountProgress,
  connectingEconomy,
}

class _AppLoadingProgress {
  const _AppLoadingProgress({required this.label, this.value});

  final String label;
  final double? value;
}

class RuneNexusApp extends StatefulWidget {
  const RuneNexusApp({this.game, this.updateService, super.key});

  final RuneNexusGame? game;
  final AppUpdateService? updateService;

  @override
  State<RuneNexusApp> createState() => _RuneNexusAppState();
}

class _RuneNexusAppState extends State<RuneNexusApp>
    with WidgetsBindingObserver {
  late RuneNexusGame game;
  bool _hasGame = false;
  bool _sessionEndRecoveryFailed = false;
  bool _sessionTransitionInProgress = false;
  late final GoogleWebAuthenticationConfig _googleAuthenticationConfig;
  late final AccountSaveBootstrapService _accountSaveBootstrapService;
  AuthenticationSessionRepository? _authenticationSessions;
  AccountProfileApi? _accountProfileApi;
  AccountProfile? _accountProfile;
  BuildContext? _nicknameDialogContext;
  OnlineSaveApi? _onlineSaveApi;
  EconomyApi? _economyApi;
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
  EconomyCoordinator? _economyCoordinator;
  Future<void>? _onlineSaveReloadOperation;
  Future<void>? _onlineSaveResumeOperation;
  bool _writerRecoveryInProgress = false;
  bool _clientUpdateRequired = false;
  _AccountConnectionPhase? _accountConnectionPhase;
  LocalSaveSlot _activeSaveSlot = LocalSaveSlot.guest;
  String? _pendingLegacyTransferToken;
  bool _legacyTransferPromptScheduled = false;
  AccountSaveBootstrapMode _accountBootstrapMode =
      AccountSaveBootstrapMode.interactiveConnect;

  AccountSession get _accountSession =>
      _onlineAccount?.presentation(_accountProfile) ??
      const AccountSession.guest();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.game != null) {
      game = widget.game!;
      _hasGame = true;
    }
    _accountSaveBootstrapService = AccountSaveBootstrapService(
      repositoryFactory: (slot) => createDefaultSaveRepository(slot: slot),
      outboxRepositoryFactory: (slot) =>
          createDefaultOnlineSaveOutboxRepository(slot: slot),
    );
    _googleAuthenticationConfig =
        GoogleWebAuthenticationConfig.fromEnvironment();
    if (_googleAuthenticationConfig.isConfigured) {
      _authenticationSessions = AuthenticationSessionRepository(
        api: GoogleAuthenticationApi(
          baseUrl: _googleAuthenticationConfig.apiBaseUrl,
          mode: kIsWeb ? AuthenticationMode.web : AuthenticationMode.native,
        ),
        apiBaseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      _accountProfileApi = AccountProfileApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      _onlineSaveApi = OnlineSaveApi(
        baseUrl: _googleAuthenticationConfig.apiBaseUrl,
      );
      _economyApi = EconomyApi(baseUrl: _googleAuthenticationConfig.apiBaseUrl);
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
    final restoresSession =
        widget.game == null && _authenticationSessions != null;
    if (!restoresSession) {
      await _restoreAccountForAppStart(context);
      if (!mounted || !context.mounted) return;
    }
    _loadingProgress.value = _AppLoadingProgress(
      label: restoresSession ? '로그인 상태와 게임 데이터 확인 중' : '게임 화면 준비 중',
      value: restoresSession ? null : 0,
    );
    // 세션 판정 전 guest 슬롯은 생성하거나 읽지 않음.
    await Future.wait([
      if (restoresSession) _restoreAccountForAppStart(context),
      precacheRuneNexusStartupImages(
        context,
        onProgress: (value) {
          if (!mounted) {
            return;
          }
          _loadingProgress.value = _AppLoadingProgress(
            label: restoresSession ? '로그인 상태와 게임 화면 준비 중' : '게임 화면 준비 중',
            value: value,
          );
        },
      ),
    ]);
    if (!mounted || !context.mounted) {
      return;
    }
    _scheduleLegacyTransferSignIn(context);
  }

  Future<void> _restoreAccountForAppStart(BuildContext context) async {
    final sessions = _authenticationSessions;
    if (widget.game == null && sessions != null) {
      var session = _onlineSession;
      if (session == null) {
        OnlineAccountCredentials? credentials;
        try {
          credentials = await sessions.restore();
        } on GoogleAuthenticationException catch (error) {
          if (!error.endsSession) rethrow;
        }
        if (!mounted || !context.mounted) return;
        if (credentials != null) {
          session = _attachOnlineSession(credentials, context);
        }
      }
      if (session != null) {
        _accountBootstrapMode = AccountSaveBootstrapMode.sessionRestore;
        if (_pendingLegacyTransferToken != null) {
          await _connectPendingLegacyTransfer(
            context: context,
            onlineSession: session,
            credentials: session.credentials!,
            duringStartup: true,
          );
        } else if (!_hasGame || _onlineSaveCoordinator == null) {
          await _connectAccountProgress(
            context: context,
            onlineSession: session,
            credentials: session.credentials!,
            duringStartup: true,
          );
        }
        if (!mounted) return;
        if (identical(session, _onlineSession)) {
          if (!_hasGame) {
            throw StateError('계정 진행 연결을 다시 확인해 주세요.');
          }
          return;
        }
        // 필수 설정 중 로그아웃한 경우에만 게스트 초기화로 진행.
        if (_onlineSession != null) {
          throw StateError('계정 세션이 변경되었습니다. 다시 확인해 주세요.');
        }
      }
    }
    if (!mounted) return;
    if (_hasGame && !_activeSaveSlot.isGuest && widget.game == null) {
      await game.saveNow();
      await _replaceGameForSlot(LocalSaveSlot.guest);
      _activeSaveSlot = LocalSaveSlot.guest;
      return;
    }
    if (!_hasGame) {
      game = _createGameForSlot(LocalSaveSlot.guest);
      _hasGame = true;
    }
    try {
      await game.prepareForAppStart();
    } on Object {
      // 저장 로드 실패를 캐시한 인스턴스는 다음 시도에서 재사용하지 않음.
      if (widget.game == null) {
        game.disposeAppResources();
        _hasGame = false;
      }
      rethrow;
    }
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
    _economyCoordinator?.dispose();
    _onlineSession?.dispose();
    _loadingProgress.dispose();
    if (_hasGame) game.disposeAppResources();
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
    final sessions = _authenticationSessions;
    if (sessions == null || _accountConnectionPhase != null) {
      return;
    }
    final credentials = await showGameDialog<OnlineAccountCredentials>(
      context: context,
      builder: (dialogContext) => GoogleSignInDialog(
        clientId: _googleAuthenticationConfig.clientId,
        authenticate: sessions.authenticate,
        description: _pendingLegacyTransferToken == null
            ? null
            : 'Google 로그인 후 기존 진행을 가져올 계정을 확인합니다.',
      ),
    );
    if (credentials == null || !mounted || !context.mounted) {
      return;
    }
    _accountBootstrapMode = AccountSaveBootstrapMode.interactiveConnect;
    final onlineSession = _attachOnlineSession(credentials, context);
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

  OnlineAccountSessionController _attachOnlineSession(
    OnlineAccountCredentials credentials,
    BuildContext context,
  ) {
    final sessions = _authenticationSessions!;
    _onlineSession?.dispose();
    _accountProfile = null;
    late final OnlineAccountSessionController onlineSession;
    onlineSession = OnlineAccountSessionController(
      credentials: credentials,
      refreshCredentials: sessions.refresh,
      revokeSession: sessions.logout,
      onCredentialsChanged: (updatedCredentials) {
        if (!mounted || !identical(_onlineSession, onlineSession)) {
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
    return onlineSession;
  }

  Future<bool> _ensureAccountNickname(
    BuildContext context,
    OnlineAccountSessionController session,
  ) async {
    final api = _accountProfileApi!;
    final accountId = session.credentials!.accountId;
    if (_accountProfile?.accountId == accountId &&
        _accountProfile!.hasNickname) {
      return true;
    }
    setState(() {
      _accountConnectionPhase = _AccountConnectionPhase.checkingNickname;
    });
    while (mounted && context.mounted && identical(_onlineSession, session)) {
      try {
        final profile = await session.runAuthenticated(
          request: api.load,
          isUnauthorized: (error) =>
              error is AccountProfileException && error.isUnauthorized,
        );
        if (!mounted ||
            !context.mounted ||
            !identical(_onlineSession, session)) {
          return false;
        }
        if (profile.accountId != accountId) {
          throw StateError('계정 프로필이 현재 로그인 계정과 일치하지 않습니다.');
        }
        AccountProfile? completed = profile;
        if (!profile.hasNickname) {
          completed = await showGameDialog<AccountProfile>(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) {
              _nicknameDialogContext = dialogContext;
              return NicknameSetupDialog(
                save: (nickname) async {
                  AccountProfile saved;
                  try {
                    saved = await session.runAuthenticated(
                      request: (token) =>
                          api.setNickname(token, nickname: nickname),
                      isUnauthorized: (error) =>
                          error is AccountProfileException &&
                          error.isUnauthorized,
                    );
                  } on AccountProfileException catch (error) {
                    if (error.code != 'NICKNAME_ALREADY_SET') rethrow;
                    // 다른 기기에서 먼저 확정한 프로필로 합류.
                    saved = await session.runAuthenticated(
                      request: api.load,
                      isUnauthorized: (error) =>
                          error is AccountProfileException &&
                          error.isUnauthorized,
                    );
                  }
                  if (!identical(_onlineSession, session) ||
                      saved.accountId != accountId ||
                      !saved.hasNickname) {
                    throw StateError('닉네임을 설정한 계정 세션을 다시 확인해 주세요.');
                  }
                  return saved;
                },
              );
            },
          );
          _nicknameDialogContext = null;
        }
        if (!mounted ||
            !context.mounted ||
            !identical(_onlineSession, session)) {
          return false;
        }
        if (completed == null) {
          await _signOut(context);
          // 로그아웃 실패 시 설정 단계 유지.
          continue;
        }
        setState(() => _accountProfile = completed);
        return true;
      } on Object {
        if (!mounted ||
            !context.mounted ||
            !identical(_onlineSession, session)) {
          return false;
        }
        final retry = await showGameDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) {
            _nicknameDialogContext = dialogContext;
            return PopScope(
              canPop: false,
              child: AlertDialog(
                title: Text(context.l10n.nicknameChecking),
                content: Text(context.l10n.nicknameProfileLoadFailed),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                    child: Text(context.l10n.signOut),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                    child: Text(context.l10n.nicknameRetry),
                  ),
                ],
              ),
            );
          },
        );
        _nicknameDialogContext = null;
        if (!mounted ||
            !context.mounted ||
            !identical(_onlineSession, session)) {
          return false;
        }
        if (retry != true) await _signOut(context);
      }
    }
    return false;
  }

  Future<void> _connectPendingLegacyTransfer({
    required BuildContext context,
    required OnlineAccountSessionController onlineSession,
    required OnlineAccountCredentials credentials,
    bool duringStartup = false,
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
      if (!await _ensureAccountNickname(context, onlineSession)) return;
      if (!mounted || !context.mounted) return;
      setState(() {
        _accountConnectionPhase =
            _AccountConnectionPhase.importingLegacyProgress;
      });
      final confirmed = await showGameDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('기존 진행을 가져올 계정 확인'),
          content: SingleChildScrollView(
            child: Text(
              '현재 게임 계정: ${_accountProfile!.displayName}\n'
              '계정 ID: ${credentials.accountId}\n\n'
              '카카오 브라우저의 기존 진행을 이 계정으로 가져옵니다. '
              '이 계정에 저장된 진행은 교체될 수 있습니다. 계정이 맞는지 확인해 주세요.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('가져오지 않기'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('이 계정에 기존 진행 가져오기'),
            ),
          ],
        ),
      );
      if (!mounted || !identical(_onlineSession, onlineSession)) return;
      if (confirmed == true) {
        await onlineSession.runAuthenticated(
          request: (accessToken) => api.consume(accessToken, token: token),
          isUnauthorized: (error) =>
              error is LegacySaveTransferException && error.isUnauthorized,
        );
        _accountBootstrapMode = AccountSaveBootstrapMode.sessionRestore;
      }
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      _pendingLegacyTransferToken = null;
      clearLegacyTransferToken();
    } on Object catch (error) {
      if (duringStartup) rethrow;
      if (!mounted ||
          !context.mounted ||
          !identical(_onlineSession, onlineSession)) {
        return;
      }
      final message = error is LegacySaveTransferException
          ? switch (error.code) {
              'LEGACY_TRANSFER_TARGET_REQUIRES_MANUAL_REVIEW' =>
                '이 Google 계정에는 구매 재화가 있거나 안전하게 백업할 수 없는 진행이 있어 자동으로 교체하지 않았습니다.',
              'LEGACY_TRANSFER_ALREADY_USED' => '이미 다른 계정에 사용된 이전 링크입니다.',
              'LEGACY_TRANSFER_INVALID' => '이전 링크가 만료되었거나 유효하지 않습니다.',
              _ when error.transportFailure =>
                '이전 서버에 연결할 수 없습니다. 같은 링크로 다시 시도해 주세요.',
              _ => error.message,
            }
          : '기존 진행 연결을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.';
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
      }
    }
    await _connectAccountProgress(
      context: context,
      onlineSession: onlineSession,
      credentials: onlineSession.credentials ?? credentials,
      duringStartup: duringStartup,
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
    bool duringStartup = false,
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
      if (!await _ensureAccountNickname(context, onlineSession)) return;
      if (!mounted || !context.mounted) return;
      setState(() {
        _accountConnectionPhase = _AccountConnectionPhase.savingCurrentProgress;
      });
      if (_hasGame) await game.saveNow();
      if (!mounted || !identical(_onlineSession, onlineSession)) {
        return;
      }
      setState(() {
        _accountConnectionPhase =
            _AccountConnectionPhase.loadingAccountProgress;
      });
      final bootstrap = await _accountSaveBootstrapService.bootstrap(
        accountId: credentials.accountId,
        mode: _accountBootstrapMode,
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
      if (!duringStartup) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(content: Text(context.l10n.accountProgressConnected)),
        );
      }
    } on Object catch (error) {
      if (duringStartup) rethrow;
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
    EconomyCoordinator? economyCoordinator;

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

      final economyApi = _economyApi;
      if (economyApi == null) {
        throw StateError('경제 API가 구성되지 않았습니다.');
      }
      if (mounted) {
        setState(() {
          _accountConnectionPhase = _AccountConnectionPhase.connectingEconomy;
        });
      }
      economyCoordinator = EconomyCoordinator(
        accountId: accountId,
        api: economyApi,
        session: onlineSession,
        saveCoordinator: coordinator,
        outboxRepository: createDefaultEconomyCommandOutboxRepository(
          slot: slot,
        ),
        game: replacement,
      );
      replacement.attachAuthoritativeEconomyCommands(economyCoordinator);
      await economyCoordinator.initialize();
    } on Object {
      economyCoordinator?.dispose();
      coordinator.dispose();
      replacement?.disposeAppResources();
      rethrow;
    }

    if (!mounted || !identical(_onlineSession, onlineSession)) {
      economyCoordinator.dispose();
      coordinator.dispose();
      replacement.disposeAppResources();
      return null;
    }
    final readyReplacement = replacement;
    final previousGame = _hasGame ? game : null;
    final previousCoordinator = _onlineSaveCoordinator;
    final previousEconomyCoordinator = _economyCoordinator;
    setState(() {
      game = readyReplacement;
      _hasGame = true;
      _screen = _AppScreen.main;
      _onlineSaveCoordinator = coordinator;
      _economyCoordinator = economyCoordinator;
    });
    previousEconomyCoordinator?.dispose();
    previousCoordinator?.dispose();
    previousGame?.disposeAppResources();
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
    } else {
      _economyCoordinator?.handleSaveSnapshotChanged(snapshot);
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
    final economyCoordinator = _economyCoordinator;
    if (economyCoordinator == null) {
      replacement.disposeAppResources();
      await coordinator.reportGameReloadFailure();
      return;
    }
    final previous = game;
    try {
      await economyCoordinator.rebindGame(replacement);
    } on Object {
      replacement.disposeAppResources();
      await coordinator.reportGameReloadFailure();
      return;
    }
    if (!mounted ||
        !identical(_onlineSaveCoordinator, coordinator) ||
        !identical(_economyCoordinator, economyCoordinator) ||
        !coordinator.snapshot.requiresGameReload) {
      if (identical(_economyCoordinator, economyCoordinator)) {
        try {
          await economyCoordinator.rebindGame(previous);
        } on Object {
          // 세션 종료와 겹친 경우 기존 종료 흐름이 coordinator를 정리한다.
        }
      }
      replacement.disposeAppResources();
      return;
    }
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
      await _economyCoordinator?.refresh();
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
    final previousEconomyCoordinator = _economyCoordinator;
    setState(() {
      game = replacement;
      _screen = _AppScreen.main;
      _onlineSaveCoordinator = null;
      _economyCoordinator = null;
    });
    previousEconomyCoordinator?.dispose();
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
    final economyCoordinator = _economyCoordinator;
    _onlineSaveCoordinator = null;
    _economyCoordinator = null;
    economyCoordinator?.dispose();
    coordinator?.dispose();
    _onlineSession = null;
    _accountProfile = null;
    final dialogContext = _nicknameDialogContext;
    if (dialogContext != null && dialogContext.mounted) {
      final route = ModalRoute.of(dialogContext);
      if (route != null && route.isActive) {
        Navigator.of(dialogContext).removeRoute(route);
      }
    }
    invalidatedSession.dispose();
    setState(() {
      _onlineAccount = null;
      _clientUpdateRequired = false;
      _accountConnectionPhase = null;
      _sessionTransitionInProgress = _hasGame;
    });
    if (_hasGame) {
      game.pauseEngine();
      unawaited(_returnToGuestAfterSessionEnd());
    }
  }

  Future<void> _returnToGuestAfterSessionEnd() async {
    try {
      if (!_activeSaveSlot.isGuest && widget.game == null) {
        await game.saveNow();
        await _replaceGameForSlot(LocalSaveSlot.guest);
      }
    } on Object {
      // 계정 게임을 guest로 표시하거나 계속 저장하지 않고 슬롯 전환 재시도.
      game.pauseEngine();
      if (mounted) {
        setState(() {
          _sessionEndRecoveryFailed = true;
          _sessionTransitionInProgress = false;
        });
      }
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _activeSaveSlot = LocalSaveSlot.guest;
      _onlineAccount = null;
      _sessionTransitionInProgress = false;
    });
  }

  Future<void> _signOut(BuildContext context) async {
    final onlineSession = _onlineSession;
    if (onlineSession == null) {
      return;
    }
    try {
      await onlineSession.logout();
      try {
        await clearGoogleIdentitySession();
      } on Object {
        // 서버/로컬 로그아웃 완료: Google 계정 선택 상태 정리 실패는 되돌리지 않음.
      }
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
      home: AppUpdateGate(
        enabled: AppUpdateService.enabled || widget.updateService != null,
        service: widget.updateService,
        child: Builder(
          builder: (appContext) {
            _initialLoad ??= _prepareForAppStart(appContext);
            return Scaffold(
              backgroundColor: const Color(0xFF07111D),
              body: FutureBuilder<void>(
                future: _initialLoad,
                builder: (context, loadState) {
                  if ((loadState.connectionState == ConnectionState.done &&
                          loadState.hasError) ||
                      _sessionEndRecoveryFailed) {
                    return _AppLoadErrorScreen(
                      onRetry: () {
                        setState(() {
                          _sessionEndRecoveryFailed = false;
                          _initialLoad = null;
                        });
                      },
                    );
                  }
                  if (loadState.connectionState != ConnectionState.done ||
                      _sessionTransitionInProgress) {
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
                      onConnectGoogle: _authenticationSessions == null
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
                        _AccountConnectionOverlay(
                          phase: accountConnectionPhase,
                        ),
                      ],
                    );
                  }
                  final clientUpdateRequired =
                      _clientUpdateRequired ||
                      coordinator?.snapshot.issueCode ==
                          'CLIENT_UPDATE_REQUIRED';
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
                            (remoteRecoveryInProgress &&
                                !remoteRecoveryBlocked),
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
      _AccountConnectionPhase.checkingNickname => l10n.nicknameChecking,
      _AccountConnectionPhase.importingLegacyProgress =>
        l10n.importingLegacyProgress,
      _AccountConnectionPhase.savingCurrentProgress =>
        l10n.savingCurrentProgress,
      _AccountConnectionPhase.loadingAccountProgress =>
        l10n.loadingAccountProgress,
      _AccountConnectionPhase.openingAccountProgress =>
        l10n.openingAccountProgress,
      _AccountConnectionPhase.connectingEconomy => '계정 경제 정보를 연결하는 중입니다.',
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

  AccountSession presentation(AccountProfile? profile) =>
      AccountSession.authenticated(
        accountId: credentials.accountId,
        displayName: profile?.accountId == credentials.accountId
            ? profile?.displayName
            : null,
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
    return ValueListenableBuilder<_AppLoadingProgress>(
      valueListenable: progressListenable,
      builder: (context, progress, _) =>
          AppStartupScreen(status: progress.label, progress: progress.value),
    );
  }
}

class _AppLoadErrorScreen extends StatelessWidget {
  const _AppLoadErrorScreen({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppStartupScreen(
      status: '초기화에 실패했습니다',
      busy: false,
      details: Column(
        children: [
          const Text(
            '로그인 상태와 진행 데이터는 보존됩니다.\n연결을 확인한 뒤 다시 시도해 주세요.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          AppStartupButton(onPressed: onRetry, label: '다시 시도'),
        ],
      ),
    );
  }
}
