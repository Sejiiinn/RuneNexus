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
