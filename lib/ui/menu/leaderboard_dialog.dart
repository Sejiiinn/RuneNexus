import 'package:flutter/material.dart';

import '../../data/leaderboard/leaderboard_api.dart';
import '../../domain/leaderboard/leaderboard.dart';
import '../game/game_button.dart';
import '../game/game_image_assets.dart';
import '../game/game_modal.dart';
import '../game/game_palette.dart';

class LeaderboardDialog extends StatefulWidget {
  const LeaderboardDialog({
    required this.load,
    required this.onOpenAccount,
    this.refreshListenable,
    super.key,
  });

  final Future<LeaderboardSnapshot> Function()? load;
  final VoidCallback onOpenAccount;
  final Listenable? refreshListenable;

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog>
    with WidgetsBindingObserver {
  LeaderboardSnapshot? _snapshot;
  String? _error;
  bool _loading = false;
  bool _needsAccount = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.refreshListenable?.addListener(_invalidate);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant LeaderboardDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshListenable != widget.refreshListenable) {
      oldWidget.refreshListenable?.removeListener(_invalidate);
      widget.refreshListenable?.addListener(_invalidate);
    }
    if (oldWidget.load != widget.load) _invalidate();
  }

  @override
  void dispose() {
    _request++;
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshListenable?.removeListener(_invalidate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  void _invalidate() {
    // 계정 전환 중 이전 계정의 순위 노출 방지.
    _snapshot = null;
    _refresh();
  }

  Future<void> _refresh() async {
    final request = ++_request;
    final load = widget.load;
    setState(() {
      _loading = load != null;
      _needsAccount = load == null;
      _error = null;
      if (load == null) _snapshot = null;
    });
    if (load == null) return;
    try {
      final snapshot = await load();
      if (!mounted || request != _request) return;
      setState(() {
        _snapshot = snapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(() {
        _loading = false;
        if (error is LeaderboardException &&
            (error.isUnauthorized ||
                error.statusCode == 403 ||
                error.code == 'LEADERBOARD_SESSION_CHANGED')) {
          _snapshot = null;
          _needsAccount = true;
          _error = '계정 상태가 변경되었습니다. 다시 로그인해 주세요.';
        } else {
          _error = '순위를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final height = (media.size.height - media.padding.vertical) * 0.84;
    final snapshot = _snapshot;
    final landscape = media.size.width > media.size.height;
    return GameModalFrame(
      maxWidth: landscape ? 720 : 460,
      maxHeight: height,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      padding: const EdgeInsets.all(14),
      accentColor: GamePalette.metal,
      child: SizedBox(
        key: const ValueKey('leaderboard-content'),
        height: height,
        child: DefaultTextStyle(
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
            fontSize: 13,
            height: 1.3,
            color: GamePalette.textPrimary,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Image.asset(
                    lobbyLeaderboardIconAsset,
                    width: 36,
                    height: 36,
                    excludeFromSemantics: true,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '리더보드',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        color: GamePalette.cyanBright,
                      ),
                    ),
                  ),
                  if (landscape)
                    IconButton(
                      tooltip: '순위 새로고침',
                      onPressed: _loading || widget.load == null
                          ? null
                          : _refresh,
                      icon: const Icon(Icons.refresh, color: GamePalette.cyan),
                    ),
                  IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: GamePalette.metal),
                  ),
                ],
              ),
              if (!landscape)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '전체 순위 · TOP 100',
                        style: const TextStyle(
                          fontSize: 11,
                          color: GamePalette.textMuted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '순위 새로고침',
                      onPressed: _loading || widget.load == null
                          ? null
                          : _refresh,
                      icon: Icon(
                        Icons.refresh,
                        color: _loading || widget.load == null
                            ? GamePalette.textDisabled
                            : GamePalette.cyan,
                      ),
                    ),
                  ],
                ),
              const Divider(color: GamePalette.stone),
              Expanded(
                child: Scrollbar(
                  child: ListView(
                    key: const ValueKey('leaderboard-list'),
                    padding: const EdgeInsets.only(bottom: 8),
                    children: [
                      if (landscape) const Text('전체 순위 · TOP 100'),
                      if (snapshot != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            '${_timestamp(snapshot.asOf)} 기준',
                            style: const TextStyle(
                              fontSize: 11,
                              color: GamePalette.textMuted,
                            ),
                          ),
                        ),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Tooltip(
                          triggerMode: TooltipTriggerMode.tap,
                          message:
                              '최고 스테이지와 완료 라운드로 순위를 정합니다. 같은 진행도는 서버에서 먼저 확정된 기록이 앞섭니다.',
                          child: Text(
                            '동일 기록은 먼저 달성한 순 · 서버 확정 시각 기준',
                            style: TextStyle(
                              fontSize: 11,
                              color: GamePalette.textSecondary,
                            ),
                          ),
                        ),
                      ),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              semanticsLabel: '순위 불러오는 중',
                              color: GamePalette.cyan,
                            ),
                          ),
                        ),
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: const TextStyle(color: GamePalette.warning),
                          ),
                        ),
                      if (_needsAccount) ...[
                        const Text('계정을 연결하면 전체 순위와 내 순위를 확인할 수 있습니다.'),
                        const SizedBox(height: 12),
                        GameButton(
                          onPressed: widget.onOpenAccount,
                          child: const Text(
                            '계정 연결',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ] else if (_error != null && !_loading)
                        GameButton(
                          onPressed: _refresh,
                          child: const Text(
                            '다시 시도',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      if (snapshot != null && snapshot.entries.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Text('아직 등록된 순위가 없습니다. 첫 기록에 도전해 보세요.'),
                        ),
                      if (snapshot != null)
                        for (final entry in snapshot.entries.take(100))
                          _LeaderboardRow(entry: entry),
                    ],
                  ),
                ),
              ),
              const Divider(color: GamePalette.stone),
              const Text(
                '내 순위',
                key: ValueKey('leaderboard-my-rank'),
                style: TextStyle(
                  color: GamePalette.cyan,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              if (snapshot?.myEntry case final entry?)
                _LeaderboardRow(entry: entry, footer: true)
              else
                Text(
                  _needsAccount
                      ? '계정 연결 후 확인할 수 있습니다.'
                      : _loading
                      ? '내 기록을 확인하고 있습니다.'
                      : snapshot == null
                      ? '순위를 불러오면 내 기록이 표시됩니다.'
                      : '아직 등록된 기록이 없습니다. 플레이 완료 후 서버 동기화가 끝나면 순위에 반영됩니다.',
                  style: const TextStyle(
                    fontSize: 12,
                    color: GamePalette.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _timestamp(DateTime value, {bool seconds = false}) {
  final local = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}.${two(local.month)}.${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}${seconds ? ':${two(local.second)}' : ''}';
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, this.footer = false});

  final LeaderboardEntry entry;
  final bool footer;

  @override
  Widget build(BuildContext context) {
    final accent = entry.isMe || footer
        ? GamePalette.cyan
        : GamePalette.textPrimary;
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: '서버 확정 · ${_timestamp(entry.achievedAt, seconds: true)}',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: footer ? 10 : 4,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: footer ? GamePalette.cyan.withValues(alpha: 0.06) : null,
          border: footer
              ? Border.all(color: GamePalette.cyan.withValues(alpha: 0.3))
              : const Border(bottom: BorderSide(color: Color(0x332F5367))),
          borderRadius: footer ? BorderRadius.circular(4) : null,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked =
                constraints.maxWidth < 300 ||
                (MediaQuery.textScalerOf(context).scale(13) > 18 &&
                    constraints.maxWidth < 560);
            final name = Text(
              entry.displayName,
              style: TextStyle(
                color: accent,
                fontSize: footer && stacked ? 11 : 13,
                fontWeight: FontWeight.w700,
              ),
            );
            final record = Text(
              '스테이지 ${entry.stageNumber}\n${entry.completedRounds} / 40 라운드',
              textAlign: stacked ? TextAlign.start : TextAlign.end,
              style: TextStyle(
                fontSize: stacked ? 11 : 12,
                color: GamePalette.textSecondary,
              ),
            );
            final identity = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(minWidth: 28),
                  child: Text(
                    '${entry.rank}',
                    style: TextStyle(
                      color: entry.rank <= 3 ? GamePalette.gold : accent,
                      fontSize: footer && stacked ? 14 : 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: name),
                if (!stacked) ...[const SizedBox(width: 8), record],
              ],
            );
            return stacked
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [identity, const SizedBox(height: 3), record],
                  )
                : identity;
          },
        ),
      ),
    );
  }
}
