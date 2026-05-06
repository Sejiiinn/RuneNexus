part of 'game_hud.dart';

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final canPrepare = snapshot.phase == GamePhase.preparation;
    final canEditBoard =
        snapshot.phase == GamePhase.preparation ||
        snapshot.phase == GamePhase.wave;
    final statusText = switch (snapshot.phase) {
      GamePhase.preparation => '다음 라운드',
      GamePhase.wave => '전투 진행 중',
      GamePhase.reward => '젬 보상 선택 대기',
      GamePhase.success => '방어 성공',
      GamePhase.failure => '방어 실패',
      GamePhase.restored => '저장된 진행 대기',
    };

    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xE607111D),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _BottomSpeedControl(snapshot: snapshot, game: game),
                const Spacer(),
                _AutoStartModeButton(game: game, snapshot: snapshot),
                const SizedBox(width: 6),
                _StartWaveButton(
                  enabled: canPrepare,
                  onPressed: game.startNextWave,
                ),
              ],
            ),
            const SizedBox(height: 8),
            _PortalSummaryCard(snapshot: snapshot, statusText: statusText),
            if (snapshot.selectedTurretPoint != null && canEditBoard) ...[
              const SizedBox(height: 8),
              _GemEquipPanel(game: game, snapshot: snapshot),
            ] else if ((snapshot.selectedBuildPoint != null ||
                    snapshot.selectedBuildTurretType != null) &&
                canEditBoard) ...[
              const SizedBox(height: 8),
              _BuildSelectionPanel(game: game, snapshot: snapshot),
            ],
            const SizedBox(height: 8),
            Row(
              children: TurretType.values.map((type) {
                final definition = demoTurrets[type]!;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: _TurretButton(
                      type: type,
                      label: definition.name,
                      cost: definition.cost,
                      color: definition.color,
                      selected: snapshot.selectedBuildTurretType == type,
                      enabled: canEditBoard,
                      onPressed: () => game.previewOrBuildSelectedTile(type),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PortalSummaryCard extends StatelessWidget {
  const _PortalSummaryCard({required this.snapshot, required this.statusText});

  final GameSnapshot snapshot;
  final String statusText;

  @override
  Widget build(BuildContext context) {
    final showWave = snapshot.phase == GamePhase.preparation;
    final title = showWave ? '포탈 1' : statusText;
    final subtitle = showWave
        ? '${snapshot.previewText} · ${snapshot.round}/${snapshot.maxRound}'
        : '진행 상태 확인';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: showWave
            ? () => showModalBottomSheet<void>(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) =>
                    _PortalWaveDetailSheet(snapshot: snapshot),
              )
            : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xAA0B1B2B),
            border: Border.all(color: const Color(0x7733D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF4B245F),
                  border: Border.all(
                    color: const Color(0xFFB16DFF),
                    width: 1.4,
                  ),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(
                  Icons.filter_tilt_shift,
                  size: 18,
                  color: Color(0xFFE3B7FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFFE8F8FF),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF8FA8BA),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (showWave) _NextWaveEnemySummary(snapshot: snapshot),
              const SizedBox(width: 5),
              Icon(
                Icons.expand_less,
                size: 18,
                color: showWave
                    ? const Color(0xFF8EE6FF)
                    : const Color(0xFF627384),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextWaveEnemySummary extends StatelessWidget {
  const _NextWaveEnemySummary({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final types = snapshot.nextWaveEnemyTypes.take(3).toList();
    final hiddenCount = snapshot.nextWaveEnemyTypes.length - types.length;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...types.map(
          (type) => Padding(
            padding: const EdgeInsets.only(left: 3),
            child: SizedBox(
              width: 25,
              height: 25,
              child: _EnemyIcon(type: type, selected: false),
            ),
          ),
        ),
        if (hiddenCount > 0)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              '+$hiddenCount',
              style: const TextStyle(
                color: Color(0xFF8EE6FF),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
      ],
    );
  }
}

class _PortalWaveDetailSheet extends StatelessWidget {
  const _PortalWaveDetailSheet({required this.snapshot});

  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xF70B1827),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.filter_tilt_shift,
                  color: Color(0xFFE3B7FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '포탈 1 · ${snapshot.round}/${snapshot.maxRound} 라운드',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFFE8F8FF),
                    ),
                  ),
                ),
                SizedBox(
                  width: 32,
                  height: 32,
                  child: IconButton(
                    tooltip: '닫기',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: const Color(0xFFC6D6E4),
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0x664A6172)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.close, size: 17),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              snapshot.previewText,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8FA8BA),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: snapshot.nextWaveEnemyTypes.map((type) {
                final enemy = demoEnemies[type]!;
                final count = snapshot.nextWaveEnemyCounts[type] ?? 0;
                return _EnemyCountChip(enemy: enemy, count: count);
              }).toList(),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: snapshot.nextWaveEnemyTypes.map((type) {
                    final enemy = demoEnemies[type]!;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 7),
                      child: _EnemyDetailRow(
                        enemy: enemy,
                        count: snapshot.nextWaveEnemyCounts[type] ?? 0,
                        round: snapshot.round,
                        stageNumber: snapshot.currentStageNumber,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnemyCountChip extends StatelessWidget {
  const _EnemyCountChip({required this.enemy, required this.count});

  final EnemyDefinition enemy;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: enemy.color.withValues(alpha: 0.12),
        border: Border.all(color: enemy.color.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: _EnemyIcon(type: enemy.type, selected: false),
          ),
          const SizedBox(width: 5),
          Text(
            '${enemy.name} x$count',
            style: TextStyle(
              color: enemy.color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EnemyDetailRow extends StatelessWidget {
  const _EnemyDetailRow({
    required this.enemy,
    required this.count,
    required this.round,
    required this.stageNumber,
  });

  final EnemyDefinition enemy;
  final int count;
  final int round;
  final int stageNumber;

  @override
  Widget build(BuildContext context) {
    final maxHp = scaledEnemyMaxHp(enemy, round, stageNumber: stageNumber);
    final multiplierRows = [
      ...DamageFamily.values
          .map(
            (family) => (
              label: family.label,
              color: family.color,
              value: enemy.resistanceProfile.familyMultiplier(family),
            ),
          )
          .where((row) => row.value != 1),
      ...AttackTag.values
          .map(
            (tag) => (
              label: tag.label,
              color: tag.color,
              value: enemy.resistanceProfile.tagMultiplier(tag),
            ),
          )
          .where((row) => row.value != 1),
    ];

    return Container(
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: const Color(0xAA07111D),
        border: Border.all(color: enemy.color.withValues(alpha: 0.55)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _EnemyIcon(type: enemy.type, selected: false),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${enemy.name} x$count',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: enemy.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StatPill(label: '체력', value: maxHp.round().toString()),
              const SizedBox(width: 5),
              _StatPill(label: '속도', value: enemy.speed.round().toString()),
            ],
          ),
          if (multiplierRows.isNotEmpty) ...[
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 5,
                runSpacing: 5,
                children: multiplierRows.map((row) {
                  return _MultiplierChip(
                    label: row.label,
                    value: row.value,
                    color: row.color,
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BottomSpeedControl extends StatelessWidget {
  const _BottomSpeedControl({required this.snapshot, required this.game});

  final GameSnapshot snapshot;
  final RuneNexusGame game;

  @override
  Widget build(BuildContext context) {
    const speeds = [1.0, 2.0, 4.0];
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0x5507111D),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: speeds.map((speed) {
          final selected = snapshot.speedMultiplier == speed;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: SizedBox(
              width: 30,
              height: 32,
              child: OutlinedButton(
                onPressed: () => game.setSpeedMultiplier(speed),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  foregroundColor: selected
                      ? const Color(0xFF07111D)
                      : Colors.white,
                  backgroundColor: selected
                      ? const Color(0xFF8EE6FF)
                      : Colors.transparent,
                  side: BorderSide(
                    color: selected
                        ? const Color(0xFF8EE6FF)
                        : Colors.transparent,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: Text(
                  '${speed.toInt()}x',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AutoStartModeButton extends StatelessWidget {
  const _AutoStartModeButton({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AutoStartMode>(
      tooltip: _autoStartModeLabel(snapshot.autoStartMode),
      color: const Color(0xFF0B1827),
      offset: const Offset(0, -142),
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0x8833D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      onSelected: game.setAutoStartMode,
      itemBuilder: (context) {
        return AutoStartMode.values.map((mode) {
          final selected = snapshot.autoStartMode == mode;
          return PopupMenuItem(
            value: mode,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _autoStartModeIcon(mode),
                  size: 18,
                  color: selected
                      ? const Color(0xFF8EE6FF)
                      : const Color(0xFFB7C8D8),
                ),
                const SizedBox(width: 8),
                Text(
                  _autoStartModeLabel(mode),
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF8EE6FF)
                        : const Color(0xFFE8F8FF),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          );
        }).toList();
      },
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0x2207111D),
          border: Border.all(color: const Color(0x8833D8FF)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _autoStartModeIcon(snapshot.autoStartMode),
          size: 22,
          color: const Color(0xFF8EE6FF),
        ),
      ),
    );
  }
}

IconData _autoStartModeIcon(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => Icons.pause_rounded,
    AutoStartMode.skipBossRounds => Icons.auto_mode_rounded,
    AutoStartMode.fullAuto => Icons.all_inclusive,
  };
}

String _autoStartModeLabel(AutoStartMode mode) {
  return switch (mode) {
    AutoStartMode.pauseEachRound => '라운드마다 정지',
    AutoStartMode.skipBossRounds => '보스 제외 자동',
    AutoStartMode.fullAuto => '전부 자동',
  };
}

class _EnemyIcon extends StatelessWidget {
  const _EnemyIcon({required this.type, required this.selected});

  final EnemyType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final enemy = demoEnemies[type]!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 110),
      width: 30,
      height: 30,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: selected
            ? enemy.color.withValues(alpha: 0.16)
            : Colors.transparent,
        border: Border.all(
          color: selected ? enemy.color : Colors.transparent,
          width: 1.2,
        ),
        borderRadius: BorderRadius.circular(7),
      ),
      child: CustomPaint(
        painter: _EnemyIconPainter(color: enemy.color, type: type),
      ),
    );
  }
}

class _EnemyIconPainter extends CustomPainter {
  const _EnemyIconPainter({required this.color, required this.type});

  final Color color;
  final EnemyType type;

  @override
  void paint(Canvas canvas, Size size) {
    drawEnemyShape(
      canvas,
      size: size,
      type: type,
      color: color,
      strokeWidth: 2,
    );
  }

  @override
  bool shouldRepaint(covariant _EnemyIconPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.type != type;
  }
}

class _MultiplierChip extends StatelessWidget {
  const _MultiplierChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = value >= 1 ? color : const Color(0xFFFF8A8A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.12),
        border: Border.all(color: textColor.withValues(alpha: 0.75)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$label x${value.toStringAsFixed(2)}',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: textColor,
        ),
      ),
    );
  }
}

class _BuildSelectionPanel extends StatelessWidget {
  const _BuildSelectionPanel({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final type = snapshot.selectedBuildTurretType;
    final definition = type == null ? null : demoTurrets[type]!;
    final canInstall = snapshot.selectedBuildPoint != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xAA0B1B2B),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: definition == null
          ? const Text(
              '설치할 포탑을 선택하세요',
              style: TextStyle(fontSize: 12, color: Color(0xFFE8F8FF)),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${definition.name} 포탑',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: definition.color,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (canInstall)
                      _InstallTurretButton(
                        definition: definition,
                        enabled: snapshot.gold >= definition.cost,
                        onPressed: game.confirmBuildSelectedTile,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  definition.description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFB9D6E4),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                _TurretAttributeChips(definition: definition),
                const SizedBox(height: 6),
                _BuildTurretStats(definition: definition),
              ],
            ),
    );
  }
}

class _StartWaveButton extends StatelessWidget {
  const _StartWaveButton({required this.enabled, required this.onPressed});

  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = enabled
        ? const Color(0xFF04121D)
        : const Color(0xFF66798A);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            gradient: enabled
                ? const LinearGradient(
                    colors: [Color(0xFF8EE6FF), Color(0xFF50E6FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: enabled ? null : const Color(0x33223543),
            border: Border.all(
              color: enabled
                  ? const Color(0xFFBFF4FF)
                  : const Color(0x33485B68),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: enabled
                ? const [
                    BoxShadow(
                      color: Color(0x4433D8FF),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_arrow_rounded, size: 20, color: foreground),
              const SizedBox(width: 4),
              Text(
                '시작',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InstallTurretButton extends StatelessWidget {
  const _InstallTurretButton({
    required this.definition,
    required this.enabled,
    required this.onPressed,
  });

  final TurretDefinition definition;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final accent = definition.color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onPressed : null,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 34,
          padding: const EdgeInsets.only(left: 10, right: 7),
          decoration: BoxDecoration(
            color: enabled
                ? accent.withValues(alpha: 0.22)
                : const Color(0x33223543),
            border: Border.all(
              color: enabled
                  ? accent.withValues(alpha: 0.9)
                  : const Color(0x33485B68),
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: enabled
                ? [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_circle_outline,
                size: 16,
                color: enabled ? accent : const Color(0xFF66798A),
              ),
              const SizedBox(width: 5),
              Text(
                '설치',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: enabled
                      ? const Color(0xFFE8F8FF)
                      : const Color(0xFF66798A),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: enabled
                      ? const Color(0xBB07111D)
                      : const Color(0x44223543),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${definition.cost}G',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: enabled ? accent : const Color(0xFF66798A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildTurretStats extends StatelessWidget {
  const _BuildTurretStats({required this.definition});

  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final dps = definition.damage * definition.attackRate;
    final burnDps = definition.attackTags.contains(AttackTag.damageOverTime)
        ? definition.damage * RuneNexusGame.burnDamagePerSecondScale
        : 0.0;
    return Row(
      children: [
        _StatPill(label: '피해', value: definition.damage.toStringAsFixed(1)),
        const SizedBox(width: 5),
        _StatPill(
          label: 'DPS',
          value: dps.toStringAsFixed(1),
          valueChild: burnDps > 0
              ? RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFE8F8FF),
                    ),
                    children: [
                      TextSpan(text: dps.toStringAsFixed(1)),
                      TextSpan(
                        text: ' +${burnDps.toStringAsFixed(1)}',
                        style: const TextStyle(color: Color(0xFFFFA24A)),
                      ),
                    ],
                  ),
                )
              : null,
        ),
        if (burnDps > 0) ...[
          const SizedBox(width: 5),
          _StatPill(
            label: '화상',
            value: '${RuneNexusGame.burnDurationSeconds.toStringAsFixed(1)}초',
          ),
        ],
        const SizedBox(width: 5),
        _StatPill(label: '사거리', value: definition.range.round().toString()),
        const SizedBox(width: 5),
        _StatPill(
          label: '초당',
          value: '${definition.attackRate.toStringAsFixed(2)}회',
        ),
      ],
    );
  }
}

class _TurretAttributeChips extends StatelessWidget {
  const _TurretAttributeChips({required this.definition});

  final TurretDefinition definition;

  @override
  Widget build(BuildContext context) {
    final labels = [
      (
        label: definition.damageFamily.label,
        color: definition.damageFamily.color,
      ),
      ...definition.attackTags.map(
        (tag) => (label: tag.label, color: tag.color),
      ),
    ];

    return Wrap(
      spacing: 5,
      runSpacing: 5,
      children: labels.map((label) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: label.color.withValues(alpha: 0.12),
            border: Border.all(color: label.color.withValues(alpha: 0.75)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: label.color,
            ),
          ),
        );
      }).toList(),
    );
  }
}
