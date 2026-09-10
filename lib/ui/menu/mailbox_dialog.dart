import 'package:flutter/material.dart';

import '../../domain/mailbox/mailbox.dart';
import '../game/game_ui.dart';

class MailboxLobbyButton extends StatefulWidget {
  const MailboxLobbyButton({
    this.load,
    this.loadSummary,
    this.markRead,
    this.claim,
    this.claimBatch,
    required this.onOpenAccount,
    required this.builder,
    super.key,
  });
  final Future<MailboxPage> Function({String? cursor})? load;
  final Future<int> Function()? loadSummary;
  final Future<void> Function(String)? markRead;
  final Future<void> Function(String)? claim;
  final Future<MailboxBatchResult> Function(List<String>)? claimBatch;
  final VoidCallback onOpenAccount;
  final Widget Function(
    BuildContext context,
    int? count,
    VoidCallback? onPressed,
  )
  builder;

  @override
  State<MailboxLobbyButton> createState() => _MailboxLobbyButtonState();
}

class _MailboxLobbyButtonState extends State<MailboxLobbyButton>
    with WidgetsBindingObserver {
  int? _count;
  int _request = 0;
  bool _open = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_open) _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    try {
      final count = await widget.loadSummary?.call();
      if (mounted && request == _request) setState(() => _count = count);
    } catch (_) {
      // 조회 실패를 미수령 0건으로 표시하지 않음.
      if (mounted && request == _request) setState(() => _count = null);
    }
  }

  Future<void> _show() async {
    setState(() => _open = true);
    final account = await showGameDialog<bool>(
      context: context,
      builder: (context) => MailboxDialog(
        load: widget.load,
        markRead: widget.markRead,
        claim: widget.claim,
        claimBatch: widget.claimBatch,
        onOpenAccount: () => Navigator.of(context).pop(true),
      ),
    );
    if (!mounted) return;
    setState(() => _open = false);
    if (account == true) widget.onOpenAccount();
    _refresh();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _count, _open ? null : _show);
}

class MailboxDialog extends StatefulWidget {
  const MailboxDialog({
    this.load,
    this.markRead,
    this.claim,
    this.claimBatch,
    required this.onOpenAccount,
    super.key,
  });
  final Future<MailboxPage> Function({String? cursor})? load;
  final Future<void> Function(String)? markRead;
  final Future<void> Function(String)? claim;
  final Future<MailboxBatchResult> Function(List<String>)? claimBatch;
  final VoidCallback onOpenAccount;
  @override
  State<MailboxDialog> createState() => _MailboxDialogState();
}

class _MailboxDialogState extends State<MailboxDialog> {
  final List<MailboxItem> _items = [];
  final Set<String> _read = {};
  final Set<String> _claimed = {};
  String? _cursor;
  String? _expanded;
  String? _error;
  String? _notice;
  bool _busy = false;
  bool _needsAccount = false;
  DateTime _serverTime = DateTime.now();
  final Stopwatch _elapsed = Stopwatch();

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool _expired(MailboxItem item) =>
      !item.expiresAt.isAfter(_serverTime.add(_elapsed.elapsed));
  bool _isClaimed(MailboxItem item) =>
      item.isClaimed || _claimed.contains(item.id);
  bool _isRead(MailboxItem item) => item.isRead || _read.contains(item.id);
  void _failure(Object error) {
    _error = error is MailboxException
        ? error.message
        : '서버에 연결하지 못했습니다. 잠시 후 다시 시도해 주세요.';
    if (error is MailboxException &&
        (error.statusCode == 401 ||
            error.statusCode == 403 ||
            error.code == 'MAILBOX_SESSION_CHANGED')) {
      _needsAccount = true;
      _items.clear();
    }
  }

  Future<void> _load({bool more = false}) async {
    final load = widget.load;
    if (load == null) {
      setState(() => _needsAccount = true);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final page = await load(cursor: more ? _cursor : null);
      if (!mounted) return;
      setState(() {
        if (!more) _items.clear();
        final known = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => !known.contains(item.id)));
        _cursor = page.nextCursor;
        _serverTime = page.serverTime;
        _elapsed
          ..reset()
          ..start();
      });
    } catch (error) {
      if (mounted) setState(() => _failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _open(MailboxItem item) async {
    setState(() => _expanded = _expanded == item.id ? null : item.id);
    if (_expanded == null || _isRead(item) || widget.markRead == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.markRead!(item.id);
      if (mounted) setState(() => _read.add(item.id));
    } catch (error) {
      if (mounted) setState(() => _failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _receive(List<String> ids, {bool batch = false}) async {
    setState(() {
      _busy = true;
      _error = null;
      _notice = null;
    });
    try {
      if (batch) {
        final result = await widget.claimBatch!(ids);
        if (!mounted) return;
        setState(() {
          for (final item in result.results) {
            if (item.claimed) {
              _claimed.add(item.mailId);
              _read.add(item.mailId);
            }
          }
          final failures = result.results
              .where((item) => !item.claimed)
              .toList();
          _notice = '${result.results.length - failures.length}건 수령 완료';
          if (failures.isNotEmpty) {
            _error =
                '${failures.length}건을 받지 못했습니다. ${failures.first.message ?? '목록을 새로고침한 뒤 다시 시도해 주세요.'}';
          }
        });
      } else {
        await widget.claim!(ids.single);
        if (!mounted) return;
        setState(() {
          _claimed.add(ids.single);
          _read.add(ids.single);
          _notice = '보상을 받았습니다.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _failure(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final height =
        (MediaQuery.sizeOf(context).height -
            MediaQuery.paddingOf(context).vertical) *
        .86;
    final available = _items
        .where((item) => !_isClaimed(item) && !_expired(item))
        .take(20)
        .map((item) => item.id)
        .toList();
    return PopScope(
      canPop: !_busy,
      child: GameModalFrame(
        maxWidth: 480,
        maxHeight: height,
        insetPadding: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        child: SizedBox(
          height: height,
          child: DefaultTextStyle(
            style: GameTextStyles.body.copyWith(
              fontFamily: Theme.of(context).textTheme.bodyMedium?.fontFamily,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text('우편함', style: GameTextStyles.title),
                    ),
                    IconButton(
                      tooltip: '우편 새로고침',
                      onPressed: _busy || _needsAccount ? null : () => _load(),
                      icon: const Icon(Icons.refresh, color: GamePalette.cyan),
                    ),
                    IconButton(
                      tooltip: '닫기',
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: GamePalette.metal),
                    ),
                  ],
                ),
                const Divider(color: GamePalette.stone),
                Expanded(
                  child: ListView(
                    key: const ValueKey('mailbox-list'),
                    children: [
                      if (_needsAccount) ...[
                        const Text('계정을 연결하면 운영 선물과 보상을 받을 수 있습니다.'),
                        const SizedBox(height: 12),
                        GameButton(
                          onPressed: widget.onOpenAccount,
                          child: const Text(
                            '계정 연결',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'NotoSansKR'),
                          ),
                        ),
                      ] else ...[
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: const TextStyle(color: GamePalette.warning),
                          ),
                          GameButton(
                            onPressed: _busy ? null : () => _load(),
                            child: const Text(
                              '다시 시도',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'NotoSansKR'),
                            ),
                          ),
                        ],
                        if (_notice != null)
                          Text(
                            _notice!,
                            style: const TextStyle(
                              color: GamePalette.cyanBright,
                            ),
                          ),
                        if (_busy)
                          const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: GamePalette.cyan,
                                semanticsLabel: '우편 처리 중',
                              ),
                            ),
                          ),
                        if (!_busy && _error == null && _items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              '도착한 우편이 없습니다.',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'NotoSansKR'),
                            ),
                          ),
                        for (final item in _items) _row(item),
                        if (_cursor != null)
                          GameButton(
                            onPressed: _busy ? null : () => _load(more: true),
                            child: const Text(
                              '우편 더 보기 · 20건',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'NotoSansKR'),
                            ),
                          ),
                        if (_items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          const Text(
                            '불러온 우편 중 최대 20건을 받습니다. 남은 우편은 더 보기로 확인하세요.',
                            style: TextStyle(
                              color: GamePalette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 6),
                          GameButton(
                            key: const ValueKey('mailbox-claim-all'),
                            onPressed:
                                _busy ||
                                    available.isEmpty ||
                                    widget.claimBatch == null
                                ? null
                                : () => _receive(available, batch: true),
                            child: Text(
                              '모두 받기 · ${available.length}건',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontFamily: 'NotoSansKR'),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(MailboxItem item) {
    final expanded = _expanded == item.id;
    final claimed = _isClaimed(item);
    final expired = _expired(item);
    final localExpiry = item.expiresAt.toLocal();
    final expiry =
        '${localExpiry.year}.${localExpiry.month.toString().padLeft(2, '0')}.${localExpiry.day.toString().padLeft(2, '0')} ${localExpiry.hour.toString().padLeft(2, '0')}:${localExpiry.minute.toString().padLeft(2, '0')}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GameAssetSurface(
        frame: GameAssetFrame.card,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextButton(
              key: ValueKey('mailbox-open-${item.id}'),
              onPressed: _busy ? null : () => _open(item),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
                foregroundColor: GamePalette.textPrimary,
              ),
              child: Text(item.title, style: GameTextStyles.sectionTitle),
            ),
            Text(
              '${_isRead(item) ? '읽음' : '안 읽음'} · ${claimed
                  ? '수령 완료'
                  : expired
                  ? '기한 만료'
                  : '미수령'}',
              style: TextStyle(
                color: claimed || expired
                    ? GamePalette.textMuted
                    : GamePalette.cyan,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                if (item.freeDiamonds > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const DiamondCurrencyIcon(size: 22),
                      const SizedBox(width: 5),
                      Flexible(child: Text('무료 다이아 ${item.freeDiamonds}')),
                    ],
                  ),
                if (item.moduleTickets > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        turretModuleTicketIconAsset,
                        width: 22,
                        height: 22,
                        excludeFromSemantics: true,
                      ),
                      const SizedBox(width: 5),
                      Flexible(child: Text('모듈권 ${item.moduleTickets}')),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '$expiry까지',
              style: const TextStyle(
                fontSize: 12,
                color: GamePalette.textSecondary,
              ),
            ),
            if (expanded) ...[
              const Divider(color: GamePalette.stone),
              Text(item.body),
              const SizedBox(height: 10),
            ],
            if (!claimed && !expired)
              GameButton(
                key: ValueKey('mailbox-claim-${item.id}'),
                onPressed: _busy || widget.claim == null
                    ? null
                    : () => _receive([item.id]),
                child: const Text(
                  '받기',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontFamily: 'NotoSansKR'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
