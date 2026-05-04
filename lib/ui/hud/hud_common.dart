part of 'game_hud.dart';

class _TurretButton extends StatelessWidget {
  const _TurretButton({
    required this.type,
    required this.label,
    required this.cost,
    required this.color,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final TurretType type;
  final String label;
  final int cost;
  final Color color;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: enabled ? onPressed : null,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(
          color: selected ? color : const Color(0x5533D8FF),
          width: selected ? 2 : 1,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _TurretShapeIcon(type: type, color: color),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          Text('$cost G', style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _TurretShapeIcon extends StatelessWidget {
  const _TurretShapeIcon({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 20,
      child: CustomPaint(
        painter: _TurretShapePainter(type: type, color: color),
      ),
    );
  }
}

class _TurretShapePainter extends CustomPainter {
  const _TurretShapePainter({required this.type, required this.color});

  final TurretType type;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    drawTurretShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 1.4,
    );
  }

  @override
  bool shouldRepaint(_TurretShapePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8CC8D8)),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _RestoreRunOverlay extends StatefulWidget {
  const _RestoreRunOverlay({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_RestoreRunOverlay> createState() => _RestoreRunOverlayState();
}

class _RestoreRunOverlayState extends State<_RestoreRunOverlay> {
  Timer? _countdownTimer;
  int? _countdown;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    if (_countdown != null) {
      return;
    }
    setState(() {
      _countdown = 3;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      final nextValue = (_countdown ?? 1) - 1;
      if (nextValue <= 0) {
        timer.cancel();
        widget.game.continueRestoredRun();
        return;
      }

      setState(() {
        _countdown = nextValue;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final countdown = _countdown;
    final roundLabel = widget.snapshot.restoredPhase == GamePhase.wave
        ? '진행 중이던 라운드'
        : '저장된 라운드';
    if (countdown != null) {
      return Container(
        color: const Color(0x4402070D),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '곧 재개됩니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  shadows: [
                    Shadow(
                      color: Color(0xFF02070D),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$countdown',
                style: const TextStyle(
                  fontSize: 68,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF8BE9FF),
                  shadows: [
                    Shadow(
                      color: Color(0xFF02070D),
                      blurRadius: 12,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: const Color(0xAA02070D),
      child: Center(
        child: Container(
          width: 286,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xEE091624),
            border: Border.all(color: const Color(0xFF50E6FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.restore, color: Color(0xFF50E6FF), size: 38),
              const SizedBox(height: 10),
              const Text(
                '저장된 진행 발견',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0x5533D8FF)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        roundLabel,
                        style: const TextStyle(
                          color: Color(0xFF8CC8D8),
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${widget.snapshot.round}/${widget.snapshot.maxRound}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '계속 진행하시겠습니까?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFC5DCE8)),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.game.discardRestoredRun,
                      child: const Text('새로 시작'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _startCountdown,
                      child: const Text('예'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
