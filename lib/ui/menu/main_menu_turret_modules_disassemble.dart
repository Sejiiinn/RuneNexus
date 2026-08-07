part of 'main_menu_screen.dart';

class _TurretModuleDisassembleDialog extends StatelessWidget {
  const _TurretModuleDisassembleDialog({required this.item});

  final TurretModuleInventoryItem item;

  @override
  Widget build(BuildContext context) {
    final returnDiamonds = item.key.grade.disassembleDiamondValue;
    final gradeColor = _gradeColor(item.key.grade);
    return GameModalFrame(
      key: const ValueKey('turret-module-disassemble-dialog'),
      maxWidth: 340,
      tone: GameModalTone.danger,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(child: Text('모듈 분해', style: GameTextStyles.title)),
              _ModuleInfoChip(text: item.key.grade.label),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '이 모듈 분해 시 $returnDiamonds 다이아가 반환됩니다. 진행하시겠습니까?',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: gradeColor.withValues(alpha: 0.13),
              border: Border.all(color: gradeColor.withValues(alpha: 0.44)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const DiamondCurrencyIcon(size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('반환 다이아', style: GameTextStyles.caption),
                ),
                Text(
                  '$returnDiamonds',
                  style: GameTextStyles.withColor(
                    GameTextStyles.sectionTitle,
                    _diamondCurrencyColor,
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
                  key: const ValueKey('turret-module-disassemble-cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                  label: '취소',
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-disassemble-confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  label: '분해',
                  icon: const Icon(Icons.delete_outline, size: 17),
                  variant: GameButtonVariant.danger,
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

class _TurretModuleBulkDisassembleDialog extends StatefulWidget {
  const _TurretModuleBulkDisassembleDialog({
    required this.scopeLabel,
    required this.items,
  });

  final String scopeLabel;
  final List<TurretModuleInventoryItem> items;

  @override
  State<_TurretModuleBulkDisassembleDialog> createState() =>
      _TurretModuleBulkDisassembleDialogState();
}

class _TurretModuleBulkDisassembleDialogState
    extends State<_TurretModuleBulkDisassembleDialog> {
  final Set<TurretModuleGrade> _selectedGrades = {TurretModuleGrade.normal};
  final Set<String> _selectedItemIds = {};

  @override
  void initState() {
    super.initState();
    _selectGradeItems(TurretModuleGrade.normal);
  }

  List<TurretModuleInventoryItem> get _availableItems {
    return widget.items
        .where((item) {
          return !item.equipped && item.key.grade != TurretModuleGrade.unique;
        })
        .toList(growable: false);
  }

  List<TurretModuleInventoryItem> get _visibleItems {
    return _availableItems
        .where((item) => _selectedGrades.contains(item.key.grade))
        .toList(growable: false);
  }

  List<TurretModuleInventoryItem> get _selectedItems {
    return _visibleItems
        .where((item) => _selectedItemIds.contains(item.id))
        .toList(growable: false);
  }

  void _toggleGrade(TurretModuleGrade grade) {
    setState(() {
      if (_selectedGrades.remove(grade)) {
        _selectedItemIds.removeWhere(
          (id) => widget.items.any(
            (item) => item.id == id && item.key.grade == grade,
          ),
        );
      } else {
        _selectedGrades.add(grade);
        _selectGradeItems(grade);
      }
    });
  }

  void _selectGradeItems(TurretModuleGrade grade) {
    for (final item in widget.items) {
      if (!item.equipped && item.key.grade == grade) {
        _selectedItemIds.add(item.id);
      }
    }
  }

  void _toggleItem(String id) {
    setState(() {
      if (!_selectedItemIds.remove(id)) {
        _selectedItemIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems;
    final selectedItems = _selectedItems;
    final returnDiamonds = selectedItems.fold<int>(
      0,
      (total, item) => total + item.key.grade.disassembleDiamondValue,
    );
    final previewHeight = visibleItems.isEmpty
        ? 54.0
        : math.min(230.0, visibleItems.length * 54.0);

    return GameModalFrame(
      key: const ValueKey('turret-module-bulk-disassemble-dialog'),
      maxWidth: 360,
      maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      tone: GameModalTone.danger,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      padding: const EdgeInsets.fromLTRB(16, 17, 16, 17),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.delete_sweep_outlined,
                color: GamePalette.danger,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('모듈 일괄 분해', style: GameTextStyles.title),
              ),
              _ModuleInfoChip(text: widget.scopeLabel),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            '분해할 등급을 선택하세요. 장착 모듈은 제외됩니다.',
            style: GameTextStyles.body,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (final grade in const [
                TurretModuleGrade.normal,
                TurretModuleGrade.magic,
                TurretModuleGrade.rare,
              ])
                _TurretModuleBulkGradeChip(
                  grade: grade,
                  selected: _selectedGrades.contains(grade),
                  onPressed: () => _toggleGrade(grade),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text('분해 대상 선택', style: GameTextStyles.sectionTitle),
              ),
              _ModuleInfoChip(text: '선택 ${selectedItems.length}개'),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: previewHeight,
            child: visibleItems.isEmpty
                ? const _TurretModuleEmptyInventoryHint(
                    text: '선택한 등급에 분해 가능한 모듈 없음',
                  )
                : ListView.separated(
                    itemCount: visibleItems.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 5),
                    itemBuilder: (context, index) {
                      final item = visibleItems[index];
                      return _TurretModuleBulkTargetRow(
                        key: ValueKey('turret-module-bulk-target-${item.id}'),
                        item: item,
                        selected: _selectedItemIds.contains(item.id),
                        onPressed: () => _toggleItem(item.id),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x2207111D),
              border: Border.all(color: const Color(0x55485B68)),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                const DiamondCurrencyIcon(size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('총 반환 다이아', style: GameTextStyles.caption),
                ),
                Text(
                  '$returnDiamonds',
                  key: const ValueKey('turret-module-bulk-return-diamonds'),
                  style: GameTextStyles.withColor(
                    GameTextStyles.sectionTitle,
                    _diamondCurrencyColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-bulk-disassemble-cancel'),
                  onPressed: () => Navigator.of(context).pop(),
                  label: '취소',
                  icon: const Icon(Icons.arrow_back, size: 17),
                  variant: GameButtonVariant.ghost,
                  accentColor: GamePalette.metal,
                  height: 38,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GameButton(
                  key: const ValueKey('turret-module-bulk-disassemble-confirm'),
                  onPressed: selectedItems.isEmpty
                      ? null
                      : () => Navigator.of(
                          context,
                        ).pop(selectedItems.map((item) => item.id).toList()),
                  label: '일괄 분해',
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  variant: GameButtonVariant.danger,
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

class _TurretModuleBulkGradeChip extends StatelessWidget {
  const _TurretModuleBulkGradeChip({
    required this.grade,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleGrade grade;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(grade);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('turret-module-bulk-grade-${grade.name}'),
        onTap: onPressed,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected
                ? gradeColor.withValues(alpha: 0.16)
                : const Color(0x2207111D),
            border: Border.all(
              color: selected
                  ? gradeColor.withValues(alpha: 0.88)
                  : const Color(0x55485B68),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.circle_outlined,
                size: 12,
                color: selected ? gradeColor : GamePalette.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                grade.label,
                style: GameTextStyles.withColor(
                  GameTextStyles.chip,
                  selected ? gradeColor : GamePalette.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TurretModuleBulkTargetRow extends StatelessWidget {
  const _TurretModuleBulkTargetRow({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
  });

  final TurretModuleInventoryItem item;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final gradeColor = _gradeColor(item.key.grade);
    final definition = gameTurretModuleDefinitions[item.key];
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(7),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: selected ? 1 : 0.48,
          child: Container(
            height: 49,
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: selected
                  ? gradeColor.withValues(alpha: 0.12)
                  : const Color(0x2207111D),
              border: Border.all(
                color: selected
                    ? gradeColor.withValues(alpha: 0.72)
                    : const Color(0x55485B68),
              ),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 32,
                  height: 32,
                  child: _TurretModuleItemIcon(
                    part: item.key.part,
                    color: gradeColor,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ModuleSingleLineText(
                        definition?.name ?? '${item.key.grade.label} 모듈',
                        style: const TextStyle(
                          color: GamePalette.textPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.key.grade.label} · ${item.key.part.label} · ${item.options.length}옵션',
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: GameTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                  size: 18,
                  color: selected ? gradeColor : GamePalette.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
