part of 'main_menu_screen.dart';

class _TurretModulePanel extends StatelessWidget {
  const _TurretModulePanel({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final padding = constraints.maxWidth <= 390 ? 12.0 : 16.0;
        return GameAssetSurface(
          frame: GameAssetFrame.panel,
          padding: EdgeInsets.all(padding),
          child: child,
        );
      },
    );
  }
}

class _TurretModuleAssetButton extends StatelessWidget {
  const _TurretModuleAssetButton({
    required this.onPressed,
    required this.label,
    required this.height,
    this.icon,
    this.foregroundColor = GamePalette.textPrimary,
    this.frameColor,
    this.imageKey,
    super.key,
  });

  final VoidCallback onPressed;
  final String label;
  final double height;
  final Widget? icon;
  final Color foregroundColor;
  final Color? frameColor;
  final Key? imageKey;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            height: height,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image(
                  image: gameUiAssetImageProvider(gameButtonFrameAsset),
                  key: imageKey,
                  fit: BoxFit.fill,
                  centerSlice: gameButtonFrameCenterSlice,
                  color: frameColor,
                  colorBlendMode: frameColor == null
                      ? null
                      : BlendMode.modulate,
                  filterQuality: FilterQuality.medium,
                  excludeFromSemantics: true,
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (icon != null) ...[
                        IconTheme(
                          data: IconThemeData(color: foregroundColor),
                          child: icon!,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: TextStyle(
                          color: foregroundColor,
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
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
}

class _TurretModuleMenu extends StatefulWidget {
  const _TurretModuleMenu({
    required this.game,
    required this.snapshot,
    required this.onDrawResults,
    super.key,
  });

  final RuneNexusGame game;
  final GameSnapshot snapshot;
  final ValueChanged<List<TurretModuleInventoryItem>> onDrawResults;

  @override
  State<_TurretModuleMenu> createState() => _TurretModuleMenuState();
}

class _TurretModuleMenuState extends State<_TurretModuleMenu> {
  TurretType? _selectedTurretType;
  TurretModulePart? _selectedPartFilter;
  String? _selectedItemId;

  TurretType _activeTurretType(GameSnapshot snapshot) {
    final selected = _selectedTurretType;
    if (selected != null && snapshot.availableTurretTypes.contains(selected)) {
      return selected;
    }
    return snapshot.availableTurretTypes.first;
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = widget.snapshot;
    final selectedTurretType = _activeTurretType(snapshot);
    final selectedTurret = gameTurrets[selectedTurretType]!;
    final equipped = _equippedModulesFor(snapshot, selectedTurretType);
    final inventoryItems = _filteredModulesFor(
      snapshot,
      selectedTurretType,
      _selectedPartFilter,
    );
    final selectedItem = _selectedInventoryItem(inventoryItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ModuleDrawPanel(
          game: widget.game,
          snapshot: snapshot,
          turretType: selectedTurretType,
          onDrawResults: widget.onDrawResults,
        ),
        const SizedBox(height: 10),
        _TurretModuleSelector(
          availableTurretTypes: snapshot.availableTurretTypes,
          selectedTurretType: selectedTurretType,
          onSelect: (type) {
            setState(() {
              _selectedTurretType = type;
              _selectedPartFilter = null;
              _selectedItemId = null;
            });
          },
        ),
        const SizedBox(height: 10),
        _TurretModuleEquipmentStage(
          turretName: selectedTurret.name,
          turretType: selectedTurretType,
          turretColor: selectedTurret.color,
          equippedModules: equipped,
          onSelectEquippedModule: (item) {
            setState(() {
              _selectedPartFilter = item.key.part;
              _selectedItemId = item.id;
            });
          },
        ),
        const SizedBox(height: 8),
        _TurretModuleDetailStrip(
          game: widget.game,
          item: selectedItem,
          turretType: selectedTurretType,
          partFilter: _selectedPartFilter,
          itemCount: inventoryItems.length,
        ),
        const SizedBox(height: 8),
        _TurretModuleInventoryList(
          turretType: selectedTurretType,
          selectedPartFilter: _selectedPartFilter,
          selectedItemId: _selectedItemId,
          items: inventoryItems,
          onBulkDisassemble: () => _showBulkDisassembleDialog(
            context,
            selectedTurretType,
            _selectedPartFilter,
            inventoryItems,
          ),
          onSelectPartFilter: (part) {
            setState(() {
              _selectedPartFilter = part;
              _selectedItemId = null;
            });
          },
          onSelectItem: (item) => setState(() => _selectedItemId = item.id),
        ),
      ],
    );
  }

  void focusDrawResult(TurretModuleInventoryItem item) {
    setState(() {
      _selectedTurretType = item.key.turretType;
      _selectedPartFilter = null;
      _selectedItemId = item.id;
    });
  }

  TurretModuleInventoryItem? _selectedInventoryItem(
    List<TurretModuleInventoryItem> items,
  ) {
    final selectedId = _selectedItemId;
    if (selectedId == null) {
      return null;
    }
    for (final item in items) {
      if (item.id == selectedId) {
        return item;
      }
    }
    return null;
  }

  Map<TurretModulePart, TurretModuleInventoryItem> _equippedModulesFor(
    GameSnapshot snapshot,
    TurretType turretType,
  ) {
    final equipped = <TurretModulePart, TurretModuleInventoryItem>{};
    for (final item in snapshot.ownedTurretModules) {
      if (item.equipped && item.key.turretType == turretType) {
        equipped[item.key.part] = item;
      }
    }
    return equipped;
  }

  List<TurretModuleInventoryItem> _filteredModulesFor(
    GameSnapshot snapshot,
    TurretType turretType,
    TurretModulePart? partFilter,
  ) {
    return List.unmodifiable(
      snapshot.ownedTurretModules.where((item) {
        return item.key.turretType == turretType &&
            (partFilter == null || item.key.part == partFilter);
      }),
    );
  }

  Future<void> _showBulkDisassembleDialog(
    BuildContext context,
    TurretType turretType,
    TurretModulePart? partFilter,
    List<TurretModuleInventoryItem> items,
  ) async {
    final selectedIds = await showGameDialog<List<String>>(
      context: context,
      builder: (context) => _TurretModuleBulkDisassembleDialog(
        scopeLabel:
            '${gameTurrets[turretType]!.name} 포탑 · ${_partFilterLabel(partFilter)}',
        items: items,
      ),
    );
    if (!mounted || selectedIds == null || selectedIds.isEmpty) {
      return;
    }
    if (selectedIds.contains(_selectedItemId)) {
      setState(() => _selectedItemId = null);
    }
    try {
      await widget.game.disassembleTurretModules(selectedIds);
    } on Object {
      if (mounted && context.mounted) {
        _showEconomyRequestFailure(context);
      }
    }
  }
}
