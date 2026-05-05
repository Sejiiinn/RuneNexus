part of 'game_hud.dart';

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.game,
    required this.snapshot,
    required this.selectedPreviewEnemyType,
    required this.onSelectPreviewEnemy,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final EnemyType? selectedPreviewEnemyType;
  final ValueChanged<EnemyType> onSelectPreviewEnemy;

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
                Expanded(
                  child: snapshot.phase == GamePhase.preparation
                      ? _WavePreview(
                          snapshot: snapshot,
                          selectedType: selectedPreviewEnemyType,
                          onSelectType: onSelectPreviewEnemy,
                        )
                      : Text(
                          statusText,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFE8F8FF),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: canPrepare ? game.startNextWave : null,
                  child: const Text('시작'),
                ),
              ],
            ),
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

class _WavePreview extends StatelessWidget {
  const _WavePreview({
    required this.snapshot,
    required this.selectedType,
    required this.onSelectType,
  });

  final GameSnapshot snapshot;
  final EnemyType? selectedType;
  final ValueChanged<EnemyType> onSelectType;

  @override
  Widget build(BuildContext context) {
    final selectedEnemy = selectedType == null
        ? null
        : demoEnemies[selectedType]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              '다음 라운드',
              style: TextStyle(fontSize: 13, color: Color(0xFFE8F8FF)),
            ),
            const SizedBox(width: 8),
            ...snapshot.nextWaveEnemyTypes.map((type) {
              return Padding(
                padding: const EdgeInsets.only(right: 5),
                child: GestureDetector(
                  onTap: () => onSelectType(type),
                  child: _EnemyIcon(type: type, selected: selectedType == type),
                ),
              );
            }),
          ],
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          reverseDuration: const Duration(milliseconds: 90),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: selectedEnemy == null
              ? const SizedBox.shrink()
              : Padding(
                  key: ValueKey(selectedType),
                  padding: const EdgeInsets.only(top: 8),
                  child: _EnemyPreviewPanel(
                    enemy: selectedEnemy,
                    round: snapshot.round,
                  ),
                ),
        ),
      ],
    );
  }
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

class _EnemyPreviewPanel extends StatelessWidget {
  const _EnemyPreviewPanel({required this.enemy, required this.round});

  final EnemyDefinition enemy;
  final int round;

  @override
  Widget build(BuildContext context) {
    final maxHp = scaledEnemyMaxHp(enemy, round);
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
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xF00B1B2B),
        border: Border.all(color: enemy.color.withValues(alpha: 0.65)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _EnemyIcon(type: enemy.type, selected: false),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  enemy.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: enemy.color,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _StatPill(label: '체력', value: maxHp.round().toString()),
              const SizedBox(width: 5),
              _StatPill(label: '속도', value: enemy.speed.round().toString()),
            ],
          ),
          const SizedBox(height: 7),
          if (multiplierRows.isEmpty)
            const Text(
              '피해 배율 변화 없음',
              style: TextStyle(fontSize: 11, color: Color(0xFFB9D6E4)),
            )
          else
            Wrap(
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
        ],
      ),
    );
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
                      SizedBox(
                        height: 30,
                        child: FilledButton(
                          onPressed: snapshot.gold >= definition.cost
                              ? game.confirmBuildSelectedTile
                              : null,
                          child: Text(
                            '설치 ${definition.cost}G',
                            style: const TextStyle(fontSize: 11),
                          ),
                        ),
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
