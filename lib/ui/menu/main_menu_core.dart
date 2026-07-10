part of 'main_menu_screen.dart';

enum _CoreAbilityTab { combatSkill, passive }

enum _CoreMenuSelection { combatSkillSlot, passiveSlotOne, passiveSlotTwo }

abstract final class _CoreUiStyle {
  static const Color panelLine = Color(0x885D7182);
  static const Color panelGlow = Color(0x4422C7E8);
  static const Color itemBase = Color(0xE60A1724);
  static const Color badgeBase = Color(0xAA111E2D);
  static const Color lockedLine = Color(0x55485B68);
  static const double panelRadius = 7;
}

class _CoreMenu extends StatefulWidget {
  const _CoreMenu({required this.game, required this.snapshot});

  final RuneNexusGame game;
  final GameSnapshot snapshot;

  @override
  State<_CoreMenu> createState() => _CoreMenuState();
}

class _CoreMenuState extends State<_CoreMenu> {
  _CoreAbilityTab _selectedTab = _CoreAbilityTab.combatSkill;
  _CoreMenuSelection _selected = _CoreMenuSelection.combatSkillSlot;
  String _selectedAbilityName = '수호 광선';

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final compact = mediaSize.height < 760 || mediaSize.width < 480;
    final selectedPassiveSlotIndex = switch (_selected) {
      _CoreMenuSelection.passiveSlotOne => 0,
      _CoreMenuSelection.passiveSlotTwo => 1,
      _CoreMenuSelection.combatSkillSlot => 0,
    };
    final selectedAbility = _selectedCoreAbilityData(
      snapshot: widget.snapshot,
      tab: _selectedTab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CoreSocketStage(
          snapshot: widget.snapshot,
          compact: compact,
          selected: _selected,
          onUnlockPassiveSlot: () => _confirmUnlockCorePassiveSlot(
            context,
            game: widget.game,
            snapshot: widget.snapshot,
          ),
          onSelect: (selection) {
            setState(() {
              _selected = selection;
              _selectedTab = switch (selection) {
                _CoreMenuSelection.combatSkillSlot =>
                  _CoreAbilityTab.combatSkill,
                _CoreMenuSelection.passiveSlotOne ||
                _CoreMenuSelection.passiveSlotTwo => _CoreAbilityTab.passive,
              };
              final nextPassiveSlotIndex = switch (_selected) {
                _CoreMenuSelection.passiveSlotOne => 0,
                _CoreMenuSelection.passiveSlotTwo => 1,
                _CoreMenuSelection.combatSkillSlot => 0,
              };
              _selectedAbilityName = _defaultSelectedAbilityName(
                snapshot: widget.snapshot,
                tab: _selectedTab,
                selectedPassiveSlotIndex: nextPassiveSlotIndex,
              );
            });
          },
        ),
        SizedBox(height: compact ? 7 : 9),
        _CoreSelectedAbilityPanel(
          data: selectedAbility,
          selectedTab: _selectedTab,
          compact: compact,
          onAction: () => _performSelectedAbilityAction(selectedAbility),
        ),
        SizedBox(height: compact ? 7 : 9),
        _CoreAbilityLibrary(
          snapshot: widget.snapshot,
          selectedTab: _selectedTab,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          compact: compact,
          onSelectTab: (tab) {
            setState(() {
              _selectedTab = tab;
              _selected = tab == _CoreAbilityTab.combatSkill
                  ? _CoreMenuSelection.combatSkillSlot
                  : _selected == _CoreMenuSelection.passiveSlotTwo
                  ? _CoreMenuSelection.passiveSlotTwo
                  : _CoreMenuSelection.passiveSlotOne;
              final nextPassiveSlotIndex = switch (_selected) {
                _CoreMenuSelection.passiveSlotOne => 0,
                _CoreMenuSelection.passiveSlotTwo => 1,
                _CoreMenuSelection.combatSkillSlot => 0,
              };
              _selectedAbilityName = _defaultSelectedAbilityName(
                snapshot: widget.snapshot,
                tab: _selectedTab,
                selectedPassiveSlotIndex: nextPassiveSlotIndex,
              );
            });
          },
          selectedAbilityName: selectedAbility.name,
          onSelectAbility: (ability) {
            setState(() => _selectedAbilityName = ability.name);
          },
        ),
      ],
    );
  }

  _CoreAbilityData _selectedCoreAbilityData({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: tab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    for (final ability in abilities) {
      if (ability.name == _selectedAbilityName) {
        return ability;
      }
    }
    return abilities.firstWhere(
      (ability) =>
          ability.name ==
          _defaultSelectedAbilityName(
            snapshot: snapshot,
            tab: tab,
            selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ),
      orElse: () => abilities.first,
    );
  }

  String _defaultSelectedAbilityName({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: tab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    if (tab == _CoreAbilityTab.passive) {
      final slotted = _corePassiveAt(snapshot, selectedPassiveSlotIndex);
      if (slotted != null) {
        return abilities
            .firstWhere(
              (ability) => ability.passiveAbility == slotted,
              orElse: () => abilities.first,
            )
            .name;
      }
      return abilities
          .firstWhere(
            (ability) =>
                ability.enabled && !ability.equipped && !ability.locked,
            orElse: () => abilities.first,
          )
          .name;
    }
    return abilities.first.name;
  }

  void _performSelectedAbilityAction(_CoreAbilityData ability) {
    final combatSkill = ability.combatSkill;
    if (combatSkill != null) {
      if (ability.locked || !ability.enabled) {
        return;
      }
      if (ability.equipped) {
        widget.game.unequipCoreCombatSkill();
        return;
      }
      widget.game.equipCoreCombatSkill(combatSkill);
      return;
    }

    final passive = ability.passiveAbility;
    if (passive == null || ability.locked || !ability.enabled) {
      return;
    }
    if (ability.equipped) {
      final slotIndex = widget.snapshot.corePassiveSlots.indexOf(passive);
      if (slotIndex >= 0) {
        widget.game.unequipCorePassiveAbility(slotIndex);
      }
      return;
    }
    final selectedPassiveSlotIndex = switch (_selected) {
      _CoreMenuSelection.passiveSlotOne => 0,
      _CoreMenuSelection.passiveSlotTwo => 1,
      _CoreMenuSelection.combatSkillSlot => 0,
    };
    widget.game.equipCorePassiveAbility(passive, selectedPassiveSlotIndex);
  }
}

class _CoreSocketStage extends StatelessWidget {
  const _CoreSocketStage({
    required this.snapshot,
    required this.compact,
    required this.selected,
    required this.onUnlockPassiveSlot,
    required this.onSelect,
  });

  final GameSnapshot snapshot;
  final bool compact;
  final _CoreMenuSelection selected;
  final Future<bool> Function() onUnlockPassiveSlot;
  final ValueChanged<_CoreMenuSelection> onSelect;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final dense = constraints.maxWidth < 370;
        final stageHeight = compact ? 178.0 : 224.0;
        final skillWidth = dense ? 108.0 : 122.0;
        final passiveGap = dense ? 8.0 : 10.0;
        final passiveWidth = dense ? 112.0 : 126.0;
        final combatSkill = snapshot.coreCombatSkill;
        final hasCombatSkill = combatSkill != null;
        return Container(
          key: const ValueKey('core-socket-board'),
          padding: EdgeInsets.all(dense ? 8 : 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xD00B1B2B), Color(0xE806101A)],
            ),
            border: Border.all(color: const Color(0x775D7182), width: 1.2),
            borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
            boxShadow: const [
              BoxShadow(
                color: Color(0x77000000),
                blurRadius: 16,
                offset: Offset(0, 9),
              ),
              BoxShadow(color: _CoreUiStyle.panelGlow, blurRadius: 18),
            ],
          ),
          child: SizedBox(
            height: stageHeight,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _CoreSocketStagePainter(
                      compact: compact,
                      dense: dense,
                      passiveSlotCount: snapshot.corePassiveSlotCount,
                      passiveSlotOne: _corePassiveAt(snapshot, 0),
                      passiveSlotTwo: _corePassiveAt(snapshot, 1),
                    ),
                    child: Center(
                      child: _CoreBodyGlyph(size: compact ? 84 : 96),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SizedBox(
                      width: skillWidth,
                      child: _CoreSocketButton(
                        key: const ValueKey('core-combat-skill-slot'),
                        kind: '전투 스킬',
                        icon: switch (combatSkill) {
                          CoreCombatSkill.guardianBeam => Icons.auto_awesome,
                          CoreCombatSkill.riftMark => Icons.blur_on,
                          null => Icons.add,
                        },
                        label: combatSkill?.label ?? '빈 슬롯',
                        state: switch (combatSkill) {
                          CoreCombatSkill.guardianBeam => '5초마다 자동 발동',
                          CoreCombatSkill.riftMark => '10초마다 자동 발동',
                          null => '스킬을 장착하세요',
                        },
                        accent: hasCombatSkill
                            ? const Color(0xFF8EE6FF)
                            : const Color(0xFF8FA8BA),
                        prominent: true,
                        compact: compact,
                        empty: !hasCombatSkill,
                        muted: !hasCombatSkill,
                        selected:
                            selected == _CoreMenuSelection.combatSkillSlot,
                        onTap: () =>
                            onSelect(_CoreMenuSelection.combatSkillSlot),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: passiveWidth,
                        child: _CorePassiveSlotButton(
                          index: 0,
                          ability: _corePassiveAt(snapshot, 0),
                          locked: snapshot.corePassiveSlotCount <= 0,
                          unlockCost: snapshot.corePassiveSlotUnlockCost,
                          unlockable: false,
                          compact: compact,
                          selected:
                              selected == _CoreMenuSelection.passiveSlotOne,
                          onTap: () =>
                              onSelect(_CoreMenuSelection.passiveSlotOne),
                        ),
                      ),
                      SizedBox(width: passiveGap),
                      SizedBox(
                        width: passiveWidth,
                        child: _CorePassiveSlotButton(
                          index: 1,
                          ability: _corePassiveAt(snapshot, 1),
                          locked: snapshot.corePassiveSlotCount <= 1,
                          unlockCost: snapshot.corePassiveSlotUnlockCost,
                          unlockable: snapshot.canUnlockCorePassiveSlot,
                          compact: compact,
                          selected:
                              selected == _CoreMenuSelection.passiveSlotTwo,
                          onTap: () async {
                            if (snapshot.corePassiveSlotCount <= 1 &&
                                snapshot.canUnlockCorePassiveSlot) {
                              final unlocked = await onUnlockPassiveSlot();
                              if (unlocked) {
                                onSelect(_CoreMenuSelection.passiveSlotTwo);
                              }
                              return;
                            }
                            onSelect(_CoreMenuSelection.passiveSlotTwo);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoreSocketStagePainter extends CustomPainter {
  const _CoreSocketStagePainter({
    required this.compact,
    required this.dense,
    required this.passiveSlotCount,
    required this.passiveSlotOne,
    required this.passiveSlotTwo,
  });

  final bool compact;
  final bool dense;
  final int passiveSlotCount;
  final CorePassiveAbility? passiveSlotOne;
  final CorePassiveAbility? passiveSlotTwo;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final gap = dense ? 8.0 : 10.0;
    final topWidth = dense ? 108.0 : 122.0;
    final topHeight = compact ? 46.0 : 56.0;
    final passiveHeight = compact ? 44.0 : 54.0;
    final passiveWidth = dense ? 112.0 : 126.0;
    final passiveLeft = (size.width - passiveWidth * 2 - gap) / 2;
    final topSocket = Offset(center.dx, size.height * 0.28);
    final bottomHub = Offset(center.dx, size.height * 0.65);
    final leftSocket = Offset(
      passiveLeft + passiveWidth / 2,
      size.height * 0.83,
    );
    final rightSocket = Offset(
      passiveLeft + passiveWidth + gap + passiveWidth / 2,
      size.height * 0.83,
    );
    final passiveOneAccent = _passiveSlotAccent(passiveSlotOne);
    final passiveTwoAccent = _passiveSlotAccent(passiveSlotTwo);
    final ringPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..color = const Color(0x5533D8FF);
    canvas.drawCircle(
      center,
      math.min(size.shortestSide * 0.42, 52),
      ringPaint,
    );
    canvas.drawCircle(center, 43, ringPaint..color = const Color(0x2AE7C66A));
    final mainLinkPaint = Paint()
      ..color = const Color(0xAA72E0A2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(topSocket, center, mainLinkPaint);
    canvas.drawLine(center, bottomHub, mainLinkPaint);
    canvas.drawLine(
      bottomHub,
      leftSocket,
      mainLinkPaint..color = passiveOneAccent.withValues(alpha: 0.66),
    );
    canvas.drawLine(
      bottomHub,
      rightSocket,
      mainLinkPaint..color = passiveTwoAccent.withValues(alpha: 0.66),
    );

    _drawSocketFrame(
      canvas,
      Rect.fromLTWH((size.width - topWidth) / 2, 0, topWidth, topHeight),
      accent: const Color(0xFF8EE6FF),
    );
    _drawSocketFrame(
      canvas,
      Rect.fromLTWH(
        passiveLeft,
        size.height - passiveHeight,
        passiveWidth,
        passiveHeight,
      ),
      accent: passiveOneAccent,
      muted: passiveSlotCount <= 0 || passiveSlotOne == null,
    );
    _drawSocketFrame(
      canvas,
      Rect.fromLTWH(
        passiveLeft + passiveWidth + gap,
        size.height - passiveHeight,
        passiveWidth,
        passiveHeight,
      ),
      accent: passiveTwoAccent,
      muted: passiveSlotCount <= 1 || passiveSlotTwo == null,
    );
  }

  Color _passiveSlotAccent(CorePassiveAbility? ability) {
    return switch (ability) {
      CorePassiveAbility.selfRepair => const Color(0xFF72E0A2),
      CorePassiveAbility.costSavingDesign => const Color(0xFFFFC66A),
      CorePassiveAbility.skillAcceleration => const Color(0xFF8EE6FF),
      null => const Color(0xFF8FA8BA),
    };
  }

  void _drawSocketFrame(
    Canvas canvas,
    Rect rect, {
    required Color accent,
    bool muted = false,
  }) {
    const bevel = 10.0;
    final frame = Path()
      ..moveTo(rect.left + bevel, rect.top)
      ..lineTo(rect.right - bevel, rect.top)
      ..lineTo(rect.right, rect.top + bevel)
      ..lineTo(rect.right, rect.bottom - bevel)
      ..lineTo(rect.right - bevel, rect.bottom)
      ..lineTo(rect.left + bevel, rect.bottom)
      ..lineTo(rect.left, rect.bottom - bevel)
      ..lineTo(rect.left, rect.top + bevel)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: muted ? 0.02 : 0.05),
          const Color(0x00000000),
        ],
      ).createShader(rect);
    canvas.drawPath(frame, fillPaint);

    final borderPaint = Paint()
      ..color = accent.withValues(alpha: muted ? 0.34 : 0.58)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(frame, borderPaint);

    final insetPaint = Paint()
      ..color = accent.withValues(alpha: muted ? 0.16 : 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    final inset = rect.deflate(6);
    final insetFrame = Path()
      ..moveTo(inset.left + bevel * 0.62, inset.top)
      ..lineTo(inset.right - bevel * 0.62, inset.top)
      ..lineTo(inset.right, inset.top + bevel * 0.62)
      ..lineTo(inset.right, inset.bottom - bevel * 0.62)
      ..lineTo(inset.right - bevel * 0.62, inset.bottom)
      ..lineTo(inset.left + bevel * 0.62, inset.bottom)
      ..lineTo(inset.left, inset.bottom - bevel * 0.62)
      ..lineTo(inset.left, inset.top + bevel * 0.62)
      ..close();
    canvas.drawPath(insetFrame, insetPaint);
  }

  @override
  bool shouldRepaint(covariant _CoreSocketStagePainter oldDelegate) {
    return oldDelegate.compact != compact ||
        oldDelegate.dense != dense ||
        oldDelegate.passiveSlotCount != passiveSlotCount ||
        oldDelegate.passiveSlotOne != passiveSlotOne ||
        oldDelegate.passiveSlotTwo != passiveSlotTwo;
  }
}

class _CoreBodyGlyph extends StatelessWidget {
  const _CoreBodyGlyph({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _NexusCoreGlyphPainter()),
      ),
    );
  }
}

class _NexusCoreGlyphPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.shortestSide;
    final center = Offset(size.width / 2, size.height / 2);
    final shadowPaint = Paint()
      ..color = const Color(0xAA000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    final basePaint = Paint()..color = const Color(0xFF172535);
    const gemColor = Color(0xFF8EE6FF);
    const strokeColor = Color(0xFFD6F6FF);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + unit * 0.35),
        width: unit * 0.72,
        height: unit * 0.18,
      ),
      shadowPaint,
    );

    final pedestal = Rect.fromCenter(
      center: Offset(center.dx, center.dy + unit * 0.26),
      width: unit * 0.66,
      height: unit * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pedestal, Radius.circular(unit * 0.04)),
      Paint()..color = const Color(0xFF0A111A),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        pedestal.deflate(unit * 0.035),
        Radius.circular(unit * 0.03),
      ),
      basePaint,
    );

    final leftBrace = Path()
      ..moveTo(center.dx - unit * 0.27, center.dy + unit * 0.03)
      ..lineTo(center.dx - unit * 0.36, center.dy - unit * 0.15)
      ..lineTo(center.dx - unit * 0.18, center.dy - unit * 0.27)
      ..lineTo(center.dx - unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final rightBrace = Path()
      ..moveTo(center.dx + unit * 0.27, center.dy + unit * 0.03)
      ..lineTo(center.dx + unit * 0.36, center.dy - unit * 0.15)
      ..lineTo(center.dx + unit * 0.18, center.dy - unit * 0.27)
      ..lineTo(center.dx + unit * 0.08, center.dy + unit * 0.02)
      ..close();
    final bracePaint = Paint()..color = const Color(0xCC203B4B);
    canvas.drawPath(leftBrace, bracePaint);
    canvas.drawPath(rightBrace, bracePaint);

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy - unit * 0.13),
        width: unit * 0.64,
        height: unit * 0.44,
      ),
      Paint()..color = gemColor.withValues(alpha: 0.1),
    );

    final gem = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final leftFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx - unit * 0.22, center.dy - unit * 0.08)
      ..close();
    final topFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy - unit * 0.16)
      ..close();
    final rightFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.16)
      ..lineTo(center.dx + unit * 0.22, center.dy - unit * 0.08)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..close();
    final innerFace = Path()
      ..moveTo(center.dx, center.dy - unit * 0.42)
      ..lineTo(center.dx - unit * 0.08, center.dy - unit * 0.07)
      ..lineTo(center.dx, center.dy + unit * 0.22)
      ..lineTo(center.dx + unit * 0.08, center.dy - unit * 0.07)
      ..close();

    canvas.drawPath(gem, Paint()..color = gemColor);
    canvas.drawPath(leftFace, Paint()..color = const Color(0xFF39A9CF));
    canvas.drawPath(topFace, Paint()..color = const Color(0xFFE8FBFF));
    canvas.drawPath(rightFace, Paint()..color = const Color(0xFF147AA0));
    canvas.drawPath(innerFace, Paint()..color = const Color(0x55FFFFFF));
    canvas.drawPath(
      gem,
      Paint()
        ..color = strokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.03
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      Path()
        ..moveTo(center.dx - unit * 0.11, center.dy - unit * 0.05)
        ..lineTo(center.dx, center.dy - unit * 0.18)
        ..lineTo(center.dx + unit * 0.11, center.dy - unit * 0.05),
      Paint()
        ..color = const Color(0xAAE7C66A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = unit * 0.024
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CorePassiveSlotButton extends StatelessWidget {
  const _CorePassiveSlotButton({
    required this.index,
    required this.ability,
    required this.locked,
    required this.unlockCost,
    required this.unlockable,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final CorePassiveAbility? ability;
  final bool locked;
  final int unlockCost;
  final bool unlockable;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (locked) {
      return _CorePassiveSlotUnlockButton(
        index: index,
        unlockCost: unlockCost,
        unlockable: unlockable,
        compact: compact,
        selected: selected,
        onTap: onTap,
      );
    }
    final equipped = ability != null;
    final passiveIcon = switch (ability) {
      CorePassiveAbility.selfRepair => Icons.healing_outlined,
      CorePassiveAbility.costSavingDesign => Icons.construction_outlined,
      CorePassiveAbility.skillAcceleration => Icons.speed_outlined,
      null => Icons.add,
    };
    final passiveAccent = switch (ability) {
      CorePassiveAbility.selfRepair => const Color(0xFF72E0A2),
      CorePassiveAbility.costSavingDesign => const Color(0xFFFFC66A),
      CorePassiveAbility.skillAcceleration => const Color(0xFF8EE6FF),
      null => const Color(0xFF8FA8BA),
    };
    return _CoreSocketButton(
      kind: '패시브 ${index + 1}',
      icon: passiveIcon,
      label: ability?.label ?? '빈 슬롯',
      state: equipped
          ? (switch (ability) {
              CorePassiveAbility.selfRepair => '5라운드마다 체력 회복',
              CorePassiveAbility.costSavingDesign => '건설 비용 15% 감소',
              CorePassiveAbility.skillAcceleration => '전투 스킬 쿨타임 10% 감소',
              null => '패시브를 장착하세요',
            })
          : '패시브를 장착하세요',
      accent: passiveAccent,
      compact: true,
      empty: !equipped,
      muted: !equipped,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _CorePassiveSlotUnlockButton extends StatelessWidget {
  const _CorePassiveSlotUnlockButton({
    required this.index,
    required this.unlockCost,
    required this.unlockable,
    required this.compact,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final int unlockCost;
  final bool unlockable;
  final bool compact;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = unlockable
        ? const Color(0xFFE7C66A)
        : const Color(0xFF8FA8BA);
    final label = unlockable ? '해금 가능' : '잠김';
    final state = unlockable ? '$unlockCost 다이아 소모' : '$unlockCost 다이아 필요';
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: compact ? 44 : 54,
        padding: EdgeInsets.fromLTRB(
          compact ? 6 : 8,
          compact ? 5 : 6,
          compact ? 6 : 8,
          compact ? 5 : 6,
        ),
        decoration: ShapeDecoration(
          color: unlockable ? const Color(0x22E7C66A) : const Color(0x1A8FA8BA),
          shape: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(
              color: selected
                  ? accent.withValues(alpha: 0.95)
                  : accent.withValues(alpha: unlockable ? 0.72 : 0.42),
              width: selected ? 1.4 : 1.0,
            ),
          ),
          shadows: selected
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.18),
                    blurRadius: 11,
                    spreadRadius: 0.5,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CoreSlotKindLabel(
              label: '패시브 ${index + 1}',
              compact: compact,
              selected: selected,
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  unlockable ? Icons.lock_open_outlined : Icons.lock_outline,
                  color: accent,
                  size: compact ? 10 : 13,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: unlockable
                          ? const Color(0xFFE8FBFF)
                          : const Color(0xFFB4C7D2),
                      fontSize: compact ? 8 : 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              state,
              maxLines: 1,
              overflow: TextOverflow.clip,
              style: TextStyle(
                color: accent,
                fontSize: compact ? 7 : 9,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoreSocketButton extends StatelessWidget {
  const _CoreSocketButton({
    super.key,
    required this.kind,
    required this.icon,
    required this.label,
    required this.state,
    required this.onTap,
    this.accent = const Color(0xFF8EE6FF),
    this.prominent = false,
    this.compact = false,
    this.empty = false,
    this.muted = false,
    this.selected = false,
  });

  final String kind;
  final IconData icon;
  final String label;
  final String state;
  final VoidCallback onTap;
  final Color accent;
  final bool prominent;
  final bool compact;
  final bool empty;
  final bool muted;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final effectiveAccent = muted ? const Color(0xFF8FA8BA) : accent;
    final selectedAccent = muted ? const Color(0xFFB4C7D2) : accent;
    final foreground = empty
        ? const Color(0xFFBFD0D8)
        : GamePalette.textPrimary;
    final iconSize = compact
        ? prominent
              ? 10.0
              : 9.0
        : prominent
        ? 14.0
        : 12.0;
    final slotHeight = prominent
        ? (compact ? 46.0 : 56.0)
        : (compact ? 44.0 : 54.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: slotHeight,
        decoration: selected
            ? ShapeDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    selectedAccent.withValues(alpha: 0.18),
                    selectedAccent.withValues(alpha: 0.06),
                  ],
                ),
                shape: BeveledRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: selectedAccent.withValues(alpha: 0.95),
                    width: 1.4,
                  ),
                ),
                shadows: [
                  BoxShadow(
                    color: selectedAccent.withValues(alpha: 0.18),
                    blurRadius: 11,
                    spreadRadius: 0.5,
                  ),
                ],
              )
            : null,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            compact ? 6 : 8,
            compact ? 5 : 6,
            compact ? 6 : 8,
            compact ? 5 : 6,
          ),
          child: compact
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CoreSlotKindLabel(
                      label: kind,
                      compact: true,
                      selected: selected,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: effectiveAccent, size: iconSize),
                        const SizedBox(width: 3),
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(
                              color: foreground,
                              fontSize: prominent ? 8 : 7,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CoreSlotKindLabel(
                      label: kind,
                      compact: false,
                      selected: selected,
                    ),
                    const Spacer(),
                    Container(
                      width: prominent ? 20 : 18,
                      height: prominent ? 20 : 18,
                      decoration: ShapeDecoration(
                        color: effectiveAccent.withValues(
                          alpha: empty ? 0.04 : 0.1,
                        ),
                        shape: StarBorder.polygon(
                          sides: prominent ? 6 : 8,
                          pointRounding: 0.08,
                          side: BorderSide(
                            color: effectiveAccent.withValues(alpha: 0.72),
                            width: 1.1,
                          ),
                        ),
                      ),
                      child: Icon(icon, color: effectiveAccent, size: iconSize),
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          color: foreground,
                          fontSize: prominent ? 10 : 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _CoreSlotKindLabel extends StatelessWidget {
  const _CoreSlotKindLabel({
    required this.label,
    required this.compact,
    required this.selected,
  });

  final String label;
  final bool compact;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.clip,
      style: TextStyle(
        color: selected ? const Color(0xFFE8FBFF) : const Color(0xFFD2E3EA),
        fontSize: compact ? 8 : 10,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CoreStatusBadge extends StatelessWidget {
  const _CoreStatusBadge({
    required this.label,
    required this.color,
    this.disabled = false,
  });

  final String label;
  final Color color;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: disabled ? const Color(0x66101922) : _CoreUiStyle.badgeBase,
        shape: StadiumBorder(
          side: BorderSide(
            color: color.withValues(alpha: disabled ? 0.38 : 0.7),
          ),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: disabled ? const Color(0xFF7A8D9A) : color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CoreActionCta extends StatelessWidget {
  const _CoreActionCta({
    required this.label,
    required this.color,
    required this.secondary,
  });

  final String label;
  final Color color;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final foreground = secondary ? const Color(0xFFB4C7D2) : color;
    return Container(
      height: 26,
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      decoration: ShapeDecoration(
        color: foreground.withValues(alpha: secondary ? 0.06 : 0.1),
        shape: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(7),
          side: BorderSide(color: foreground.withValues(alpha: 0.72)),
        ),
        shadows: [
          BoxShadow(
            color: foreground.withValues(alpha: secondary ? 0.04 : 0.1),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            secondary ? Icons.remove : Icons.add,
            color: foreground,
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreSelectedAbilityPanel extends StatelessWidget {
  const _CoreSelectedAbilityPanel({
    required this.data,
    required this.selectedTab,
    required this.compact,
    required this.onAction,
  });

  final _CoreAbilityData data;
  final _CoreAbilityTab selectedTab;
  final bool compact;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final actionEnabled =
        (data.combatSkill != null || data.passiveAbility != null) &&
        data.enabled &&
        !data.locked;
    final detailText = data.descriptionLines.isEmpty
        ? data.state
        : data.descriptionLines.join('\n');
    final actionLabel = data.passiveAbility == null
        ? data.equipped
              ? '해제'
              : data.actionLabel
        : data.equipped
        ? '해제'
        : data.actionLabel;
    return Container(
      key: const ValueKey('core-selected-ability-panel'),
      constraints: BoxConstraints(minHeight: compact ? 86 : 98),
      padding: EdgeInsets.fromLTRB(
        compact ? 9 : 11,
        compact ? 8 : 10,
        compact ? 9 : 11,
        compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xF20B1B2B), Color(0xE606101A)],
        ),
        border: Border.all(color: _CoreUiStyle.panelLine),
        borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 12,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 44 : 50,
            height: compact ? 44 : 50,
            decoration: ShapeDecoration(
              color: data.accent.withValues(alpha: data.locked ? 0.06 : 0.16),
              shape: StarBorder.polygon(
                sides: 6,
                pointRounding: 0.08,
                side: BorderSide(
                  color: data.accent.withValues(
                    alpha: data.locked ? 0.26 : 0.7,
                  ),
                ),
              ),
            ),
            child: Icon(data.icon, color: data.accent, size: compact ? 22 : 25),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(
                          color: Color(0xFFE8FBFF),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  detailText,
                  style: const TextStyle(
                    color: Color(0xFFB4C7D2),
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    height: 1.14,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          actionEnabled
              ? GestureDetector(
                  key: const ValueKey('core-selected-ability-action'),
                  behavior: HitTestBehavior.opaque,
                  onTap: onAction,
                  child: _CoreActionCta(
                    label: actionLabel,
                    color: data.accent,
                    secondary: data.equipped,
                  ),
                )
              : _CoreStatusBadge(
                  label: data.locked ? data.actionLabel : actionLabel,
                  color: data.locked ? const Color(0xFF8FA8BA) : data.accent,
                  disabled: data.locked,
                ),
        ],
      ),
    );
  }
}

class _CoreAbilityLibrary extends StatelessWidget {
  const _CoreAbilityLibrary({
    required this.snapshot,
    required this.selectedTab,
    required this.selectedPassiveSlotIndex,
    required this.compact,
    required this.onSelectTab,
    required this.selectedAbilityName,
    required this.onSelectAbility,
  });

  final GameSnapshot snapshot;
  final _CoreAbilityTab selectedTab;
  final int selectedPassiveSlotIndex;
  final bool compact;
  final ValueChanged<_CoreAbilityTab> onSelectTab;
  final String selectedAbilityName;
  final ValueChanged<_CoreAbilityData> onSelectAbility;

  @override
  Widget build(BuildContext context) {
    final abilities = _CoreAbilityData.forTab(
      snapshot: snapshot,
      tab: selectedTab,
      selectedPassiveSlotIndex: selectedPassiveSlotIndex,
    );
    final libraryHeight = compact ? 158.0 : 188.0;
    return Container(
      height: libraryHeight,
      padding: EdgeInsets.all(compact ? 8 : 10),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xF20B1B2B), Color(0xF006101A)],
        ),
        border: Border.all(color: _CoreUiStyle.panelLine),
        borderRadius: BorderRadius.circular(_CoreUiStyle.panelRadius),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _CoreAbilityTabButton(
                  label: '전투 스킬',
                  selected: selectedTab == _CoreAbilityTab.combatSkill,
                  onTap: () => onSelectTab(_CoreAbilityTab.combatSkill),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _CoreAbilityTabButton(
                  label: '패시브',
                  selected: selectedTab == _CoreAbilityTab.passive,
                  onTap: () => onSelectTab(_CoreAbilityTab.passive),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 7,
                mainAxisSpacing: 7,
                childAspectRatio: 0.95,
              ),
              itemCount: abilities.length,
              itemBuilder: (context, index) {
                return _CoreAbilityCard(
                  data: abilities[index],
                  selected: abilities[index].name == selectedAbilityName,
                  onTap: () => onSelectAbility(abilities[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoreAbilityTabButton extends StatelessWidget {
  const _CoreAbilityTabButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: BeveledRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          height: 30,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [Color(0xFF123C4E), Color(0xFF071B29)]
                  : const [Color(0xAA15283A), Color(0xAA081421)],
            ),
            shape: BeveledRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(
                color: selected
                    ? const Color(0xCC8EE6FF)
                    : const Color(0x5533D8FF),
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? GamePalette.textPrimary
                  : const Color(0xFF8FA8BA),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreAbilityCard extends StatelessWidget {
  const _CoreAbilityCard({
    required this.data,
    required this.selected,
    required this.onTap,
  });

  final _CoreAbilityData data;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = data.locked || (!data.enabled && !data.equipped);
    final borderColor = data.equipped
        ? data.accent.withValues(alpha: 0.82)
        : selected
        ? const Color(0xCC8EE6FF)
        : data.locked
        ? _CoreUiStyle.lockedLine
        : const Color(0x6633D8FF);
    final textColor = data.locked
        ? const Color(0xFF7A8D9A)
        : GamePalette.textPrimary;
    return Opacity(
      opacity: disabled ? 0.68 : 1,
      child: Material(
        key: ValueKey('core-ability-${data.name}'),
        color: Colors.transparent,
        child: InkWell(
          customBorder: BeveledRectangleBorder(
            borderRadius: BorderRadius.circular(7),
          ),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.fromLTRB(5, 7, 5, 6),
            decoration: ShapeDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: data.equipped
                    ? [
                        data.accent.withValues(alpha: 0.22),
                        const Color(0xE606101A),
                      ]
                    : const [_CoreUiStyle.itemBase, Color(0xDD06101A)],
              ),
              shape: BeveledRectangleBorder(
                borderRadius: BorderRadius.circular(7),
                side: BorderSide(color: borderColor, width: 1.1),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: ShapeDecoration(
                    color: data.accent.withValues(
                      alpha: data.locked ? 0.06 : 0.18,
                    ),
                    shape: StarBorder.polygon(
                      sides: 6,
                      pointRounding: 0.08,
                      side: BorderSide(
                        color: data.accent.withValues(
                          alpha: data.locked ? 0.24 : 0.68,
                        ),
                      ),
                    ),
                  ),
                  child: Icon(data.icon, color: data.accent, size: 18),
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Center(
                    child: Text(
                      data.name,
                      maxLines: 2,
                      overflow: TextOverflow.clip,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        height: 1.08,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoreAbilityData {
  const _CoreAbilityData({
    required this.icon,
    required this.name,
    required this.state,
    required this.actionLabel,
    required this.accent,
    this.descriptionLines = const [],
    this.combatSkill,
    this.passiveAbility,
    this.equipped = false,
    this.locked = false,
    this.enabled = false,
  });

  final IconData icon;
  final String name;
  final String state;
  final String actionLabel;
  final Color accent;
  final List<String> descriptionLines;
  final CoreCombatSkill? combatSkill;
  final CorePassiveAbility? passiveAbility;
  final bool equipped;
  final bool locked;
  final bool enabled;

  static List<_CoreAbilityData> forTab({
    required GameSnapshot snapshot,
    required _CoreAbilityTab tab,
    required int selectedPassiveSlotIndex,
  }) {
    final riftMarkUnlocked = snapshot.unlockedStageCount >= 6;
    return switch (tab) {
      _CoreAbilityTab.combatSkill => [
        _CoreAbilityData(
          icon: Icons.auto_awesome,
          name: '수호 광선',
          state: '5초마다 자동 발동',
          descriptionLines: const [
            '5초마다 가장 앞선 적에게 1초간 광선 피해. 포탑 화력이 높을수록 피해 증가.',
          ],
          actionLabel: snapshot.coreCombatSkill == CoreCombatSkill.guardianBeam
              ? '장착중'
              : '장착',
          accent: const Color(0xFF8EE6FF),
          combatSkill: CoreCombatSkill.guardianBeam,
          equipped: snapshot.coreCombatSkill == CoreCombatSkill.guardianBeam,
          enabled: true,
        ),
        _CoreAbilityData(
          icon: Icons.blur_on,
          name: '균열 낙인',
          state: riftMarkUnlocked ? '체력이 높은 적에게 받는 피해 증가' : '챕터 2 해금',
          descriptionLines: riftMarkUnlocked
              ? const ['10초마다 내구도 높은 적 4명에게 5초 낙인. 대상이 받는 모든 피해 증가.']
              : const ['챕터 2 해금. 내구도 높은 적에게 받는 피해 증가 낙인 부여.'],
          actionLabel: snapshot.coreCombatSkill == CoreCombatSkill.riftMark
              ? '장착중'
              : riftMarkUnlocked
              ? '장착'
              : '잠김',
          accent: const Color(0xFFCFA7FF),
          combatSkill: CoreCombatSkill.riftMark,
          equipped: snapshot.coreCombatSkill == CoreCombatSkill.riftMark,
          locked: !riftMarkUnlocked,
          enabled: riftMarkUnlocked,
        ),
      ],
      _CoreAbilityTab.passive => [
        _passiveData(
          snapshot: snapshot,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ability: CorePassiveAbility.selfRepair,
          icon: Icons.healing_outlined,
          unlockText: '기본 해금',
          accent: const Color(0xFF72E0A2),
        ),
        _passiveData(
          snapshot: snapshot,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ability: CorePassiveAbility.costSavingDesign,
          icon: Icons.construction_outlined,
          unlockText: '기본 해금',
          accent: const Color(0xFFFFC66A),
        ),
        _passiveData(
          snapshot: snapshot,
          selectedPassiveSlotIndex: selectedPassiveSlotIndex,
          ability: CorePassiveAbility.skillAcceleration,
          icon: Icons.speed_outlined,
          unlockText: '기본 해금',
          accent: const Color(0xFF8EE6FF),
        ),
      ],
    };
  }

  static _CoreAbilityData _passiveData({
    required GameSnapshot snapshot,
    required int selectedPassiveSlotIndex,
    required CorePassiveAbility ability,
    required IconData icon,
    required String unlockText,
    required Color accent,
  }) {
    final equipped = snapshot.corePassiveSlots.contains(ability);
    final unlocked = snapshot.unlockedCorePassiveAbilities.contains(ability);
    final slotUnlocked =
        selectedPassiveSlotIndex < snapshot.corePassiveSlotCount;
    final effectText = switch (ability) {
      CorePassiveAbility.selfRepair => '5라운드마다 넥서스 체력 1 회복',
      CorePassiveAbility.costSavingDesign => '포탑 건설 비용 15% 감소',
      CorePassiveAbility.skillAcceleration => '전투 스킬 재사용 대기시간 10% 감소',
    };
    return _CoreAbilityData(
      icon: icon,
      name: ability.label,
      state: unlocked ? effectText : unlockText,
      actionLabel: equipped
          ? '장착중'
          : !unlocked
          ? '잠김'
          : !slotUnlocked
          ? '슬롯 잠김'
          : '장착',
      accent: accent,
      passiveAbility: ability,
      equipped: equipped,
      locked: !unlocked || !slotUnlocked,
      enabled: unlocked && slotUnlocked,
    );
  }
}

CorePassiveAbility? _corePassiveAt(GameSnapshot snapshot, int index) {
  return index < snapshot.corePassiveSlots.length
      ? snapshot.corePassiveSlots[index]
      : null;
}
