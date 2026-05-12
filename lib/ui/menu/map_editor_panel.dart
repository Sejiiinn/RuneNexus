import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/definitions/demo_stage_data.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/tile_type.dart';

enum _MapEditMode { tile, path }

const _minMapSize = 4;
const _maxMapSize = 16;

class DebugMapEditorPanel extends StatefulWidget {
  const DebugMapEditorPanel({required this.initialStageNumber, super.key});

  final int initialStageNumber;

  @override
  State<DebugMapEditorPanel> createState() => _DebugMapEditorPanelState();
}

class _DebugMapEditorPanelState extends State<DebugMapEditorPanel> {
  late int _stageNumber;
  late List<List<TileType>> _tiles;
  late List<GridPoint> _path;
  final Map<int, _MapDraft> _draftsByStage = {};
  TileType _selectedTile = TileType.build;
  _MapEditMode _mode = _MapEditMode.tile;
  String? _lastExportText;
  GridPoint? _lastPaintedPoint;

  @override
  void initState() {
    super.initState();
    final stageCount = demoStages.length;
    _stageNumber = widget.initialStageNumber.clamp(1, stageCount).toInt();
    _loadStage(_stageNumber);
  }

  void _loadStage(int stageNumber) {
    final draft = _draftsByStage[stageNumber] ?? _draftForStage(stageNumber);
    _stageNumber = stageNumber;
    _tiles = draft.copyTiles();
    _path = [...draft.path];
    _lastExportText = null;
  }

  _MapDraft _draftForStage(int stageNumber) {
    final stage = demoStages[stageNumber - 1];
    final map = stage.map;
    return _MapDraft(
      tiles: [
        for (final row in map.tiles) [...row],
      ],
      path: [...map.path],
    );
  }

  void _saveCurrentDraft() {
    _draftsByStage[_stageNumber] = _MapDraft(
      tiles: [
        for (final row in _tiles) [...row],
      ],
      path: [..._path],
    );
  }

  void _switchStage(int stageNumber) {
    if (stageNumber == _stageNumber) {
      return;
    }
    _saveCurrentDraft();
    final draft = _draftsByStage[stageNumber] ?? _draftForStage(stageNumber);
    _tiles = [
      for (final row in draft.tiles) [...row],
    ];
    _path = [...draft.path];
    _stageNumber = stageNumber;
    _lastExportText = null;
  }

  MapDefinition get _map => MapDefinition(
    columns: _tiles.first.length,
    rows: _tiles.length,
    tiles: _tiles,
    path: _path,
  );

  void _handlePoint(GridPoint point) {
    if (_lastPaintedPoint == point) {
      return;
    }
    _lastPaintedPoint = point;
    if (_mode == _MapEditMode.path) {
      _editPath(point);
      return;
    }
    _paintTile(point);
  }

  void _paintTile(GridPoint point) {
    setState(() {
      if (_selectedTile == TileType.spawn || _selectedTile == TileType.core) {
        _replaceSingletonTile(_selectedTile);
      }
      _tiles[point.y][point.x] = _selectedTile;
      if (!_selectedTile.canBePathNode) {
        _path.remove(point);
      }
      _lastExportText = null;
    });
  }

  void _replaceSingletonTile(TileType type) {
    for (var y = 0; y < _tiles.length; y++) {
      for (var x = 0; x < _tiles[y].length; x++) {
        if (_tiles[y][x] == type) {
          _tiles[y][x] = TileType.path;
        }
      }
    }
  }

  void _editPath(GridPoint point) {
    if (!_tiles[point.y][point.x].canBePathNode) {
      return;
    }
    setState(() {
      final existingIndex = _path.indexOf(point);
      if (existingIndex == _path.length - 1) {
        _path.removeLast();
      } else if (existingIndex >= 0) {
        _path = _path.take(existingIndex + 1).toList();
      } else {
        _path.add(point);
      }
      _lastExportText = null;
    });
  }

  void _resetStage() {
    setState(() {
      _draftsByStage.remove(_stageNumber);
      _loadStage(_stageNumber);
    });
  }

  void _resizeMap({int? columns, int? rows}) {
    final nextColumns = (columns ?? _tiles.first.length)
        .clamp(_minMapSize, _maxMapSize)
        .toInt();
    final nextRows = (rows ?? _tiles.length)
        .clamp(_minMapSize, _maxMapSize)
        .toInt();
    if (nextColumns == _tiles.first.length && nextRows == _tiles.length) {
      return;
    }

    setState(() {
      final nextTiles = List<List<TileType>>.generate(
        nextRows,
        (y) => List<TileType>.generate(nextColumns, (x) {
          if (y < _tiles.length && x < _tiles[y].length) {
            return _tiles[y][x];
          }
          return TileType.build;
        }),
      );
      _tiles = nextTiles;
      _path = [
        for (final point in _path)
          if (_containsInSize(point, columns: nextColumns, rows: nextRows))
            point,
      ];
      _lastExportText = null;
    });
  }

  Future<void> _copyExport() async {
    final exportText = _buildExportText();
    await Clipboard.setData(ClipboardData(text: exportText));
    final copiedText = await Clipboard.getData('text/plain');
    final copied = copiedText?.text == exportText;
    if (!mounted) {
      return;
    }
    setState(() {
      _lastExportText = exportText;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          copied
              ? 'MapDefinition 텍스트를 아래에 표시하고 클립보드 복사도 요청했습니다.'
              : 'MapDefinition 텍스트를 아래에 표시했습니다. 필요한 경우 직접 선택해 복사해 주세요.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validationMessages = _validate();
    final hasErrors = validationMessages.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final editor = _EditorGrid(
          map: _map,
          onPointStart: (point) {
            _lastPaintedPoint = null;
            _handlePoint(point);
          },
          onPointDrag: _handlePoint,
          onPointEnd: () {
            _lastPaintedPoint = null;
          },
        );
        final setupControls = _EditorSetupControls(
          stageNumber: _stageNumber,
          columns: _tiles.first.length,
          rows: _tiles.length,
          onStageSelected: (stageNumber) {
            setState(() {
              _switchStage(stageNumber);
            });
          },
          onResizeColumns: (columns) => _resizeMap(columns: columns),
          onResizeRows: (rows) => _resizeMap(rows: rows),
        );
        final controls = _EditorControls(
          selectedTile: _selectedTile,
          mode: _mode,
          validationMessages: validationMessages,
          onTileSelected: (tileType) {
            setState(() {
              _selectedTile = tileType;
              _mode = _MapEditMode.tile;
            });
          },
          onModeSelected: (mode) {
            setState(() {
              _mode = mode;
            });
          },
          onReset: _resetStage,
          onClearPath: () {
            setState(() {
              _path.clear();
              _lastExportText = null;
            });
          },
          onCopyExport: hasErrors ? null : _copyExport,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _EditorHeader(),
            const SizedBox(height: 8),
            setupControls,
            const SizedBox(height: 8),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: editor,
              ),
            ),
            const SizedBox(height: 8),
            controls,
            if (_lastExportText != null) ...[
              const SizedBox(height: 8),
              _ExportPreview(text: _lastExportText!),
            ],
          ],
        );
      },
    );
  }

  List<String> _validate() {
    final messages = <String>[];
    final spawnPoints = _pointsWithTile(TileType.spawn);
    final corePoints = _pointsWithTile(TileType.core);

    if (spawnPoints.length != 1) {
      messages.add('spawn 타일은 정확히 1개여야 합니다.');
    }
    if (corePoints.length != 1) {
      messages.add('core 타일은 정확히 1개여야 합니다.');
    }
    if (_path.isEmpty) {
      messages.add('적 이동 경로가 비어 있습니다.');
    }
    if (_path.isNotEmpty) {
      final first = _path.first;
      final last = _path.last;
      if (_tiles[first.y][first.x] != TileType.spawn) {
        messages.add('경로의 첫 타일은 spawn이어야 합니다.');
      }
      if (_tiles[last.y][last.x] != TileType.core) {
        messages.add('경로의 마지막 타일은 core이어야 합니다.');
      }
      for (var i = 0; i < _path.length; i++) {
        final point = _path[i];
        if (!_contains(point)) {
          messages.add('경로에 맵 범위를 벗어난 좌표가 있습니다.');
          break;
        }
        if (!_tiles[point.y][point.x].canBePathNode) {
          messages.add('경로에는 path, spawn, core 타일만 포함할 수 있습니다.');
          break;
        }
        if (i > 0 && !_isAdjacent(_path[i - 1], point)) {
          messages.add('경로는 상하좌우로 연속되어야 합니다.');
          break;
        }
      }
    }

    final orderedPath = _path.toSet();
    for (var y = 0; y < _tiles.length; y++) {
      for (var x = 0; x < _tiles[y].length; x++) {
        final point = GridPoint(x, y);
        if (_tiles[y][x].canBePathNode && !orderedPath.contains(point)) {
          messages.add('path, spawn, core 타일은 모두 경로 순서에 포함되어야 합니다.');
          return messages;
        }
      }
    }
    return messages;
  }

  List<GridPoint> _pointsWithTile(TileType tileType) {
    final points = <GridPoint>[];
    for (var y = 0; y < _tiles.length; y++) {
      for (var x = 0; x < _tiles[y].length; x++) {
        if (_tiles[y][x] == tileType) {
          points.add(GridPoint(x, y));
        }
      }
    }
    return points;
  }

  bool _contains(GridPoint point) {
    return point.x >= 0 &&
        point.x < _tiles.first.length &&
        point.y >= 0 &&
        point.y < _tiles.length;
  }

  bool _containsInSize(
    GridPoint point, {
    required int columns,
    required int rows,
  }) {
    return point.x >= 0 && point.x < columns && point.y >= 0 && point.y < rows;
  }

  bool _isAdjacent(GridPoint a, GridPoint b) {
    return (a.x - b.x).abs() + (a.y - b.y).abs() == 1;
  }

  String _buildExportText() {
    final buffer = StringBuffer()
      ..writeln('const stage${_stageNumber}Map = MapDefinition(')
      ..writeln('  columns: ${_tiles.first.length},')
      ..writeln('  rows: ${_tiles.length},')
      ..writeln('  tiles: [');
    for (final row in _tiles) {
      buffer.writeln('    [');
      for (final tile in row) {
        buffer.writeln('      TileType.${tile.name},');
      }
      buffer.writeln('    ],');
    }
    buffer
      ..writeln('  ],')
      ..writeln('  path: [');
    for (final point in _path) {
      buffer.writeln('    GridPoint(${point.x}, ${point.y}),');
    }
    buffer
      ..writeln('  ],')
      ..writeln(');');
    return buffer.toString();
  }
}

class _MapDraft {
  const _MapDraft({required this.tiles, required this.path});

  final List<List<TileType>> tiles;
  final List<GridPoint> path;

  List<List<TileType>> copyTiles() {
    return [
      for (final row in tiles) [...row],
    ];
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0x2233D8FF),
            border: Border.all(color: const Color(0xAA33D8FF)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.map_outlined,
            color: Color(0xFF8EE6FF),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            '맵 에디터',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _EditorSetupControls extends StatelessWidget {
  const _EditorSetupControls({
    required this.stageNumber,
    required this.columns,
    required this.rows,
    required this.onStageSelected,
    required this.onResizeColumns,
    required this.onResizeRows,
  });

  final int stageNumber;
  final int columns;
  final int rows;
  final ValueChanged<int> onStageSelected;
  final ValueChanged<int> onResizeColumns;
  final ValueChanged<int> onResizeRows;

  @override
  Widget build(BuildContext context) {
    return _ControlSection(
      title: '스테이지 / 크기',
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (var stage = 1; stage <= demoStages.length; stage++)
                      ChoiceChip(
                        label: Text('$stage'),
                        selected: stageNumber == stage,
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        padding: EdgeInsets.zero,
                        onSelected: (_) => onStageSelected(stage),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SizeStepper(
                  icon: Icons.swap_horiz,
                  label: '가로',
                  value: columns,
                  onChanged: onResizeColumns,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SizeStepper(
                  icon: Icons.swap_vert,
                  label: '세로',
                  value: rows,
                  onChanged: onResizeRows,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EditorControls extends StatelessWidget {
  const _EditorControls({
    required this.selectedTile,
    required this.mode,
    required this.validationMessages,
    required this.onTileSelected,
    required this.onModeSelected,
    required this.onReset,
    required this.onClearPath,
    required this.onCopyExport,
  });

  final TileType selectedTile;
  final _MapEditMode mode;
  final List<String> validationMessages;
  final ValueChanged<TileType> onTileSelected;
  final ValueChanged<_MapEditMode> onModeSelected;
  final VoidCallback onReset;
  final VoidCallback onClearPath;
  final VoidCallback? onCopyExport;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ControlSection(
          title: '브러시',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.brush_outlined,
                      label: '타일',
                      selected: mode == _MapEditMode.tile,
                      onPressed: () => onModeSelected(_MapEditMode.tile),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: _ToolButton(
                      icon: Icons.route_outlined,
                      label: '경로',
                      selected: mode == _MapEditMode.path,
                      onPressed: () => onModeSelected(_MapEditMode.path),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 5,
                runSpacing: 5,
                children: [
                  for (final tileType in TileType.values)
                    _TileBrushButton(
                      tileType: tileType,
                      selected:
                          mode == _MapEditMode.tile && selectedTile == tileType,
                      onPressed: () => onTileSelected(tileType),
                    ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        _ValidationPanel(messages: validationMessages),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: onReset,
                  icon: const Icon(Icons.restart_alt, size: 14),
                  label: const Text('초기화'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 5),
            Expanded(
              child: SizedBox(
                height: 30,
                child: OutlinedButton.icon(
                  onPressed: onClearPath,
                  icon: const Icon(Icons.clear_all, size: 14),
                  label: const Text('경로 비움'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 32,
          child: FilledButton.icon(
            onPressed: onCopyExport,
            icon: const Icon(Icons.content_copy, size: 15),
            label: const Text('Export 표시'),
          ),
        ),
      ],
    );
  }
}

class _ControlSection extends StatelessWidget {
  const _ControlSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0x9907111D),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14),
        label: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF07111D) : Colors.white,
          backgroundColor: selected ? const Color(0xFF8EE6FF) : null,
          side: BorderSide(
            color: selected ? const Color(0xFF8EE6FF) : const Color(0x5533D8FF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _SizeStepper extends StatelessWidget {
  const _SizeStepper({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF8EE6FF)),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _StepButton(
          icon: Icons.remove,
          enabled: value > _minMapSize,
          onPressed: () => onChanged(value - 1),
        ),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          enabled: value < _maxMapSize,
          onPressed: () => onChanged(value + 1),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        tooltip: enabled ? null : '제한',
        onPressed: enabled ? onPressed : null,
        style: IconButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: enabled
              ? const Color(0xFFE8FBFF)
              : const Color(0xFF627384),
          backgroundColor: const Color(0x6615283A),
          side: BorderSide(
            color: enabled ? const Color(0x5533D8FF) : const Color(0x334A6172),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
        icon: Icon(icon, size: 14),
      ),
    );
  }
}

class _TileBrushButton extends StatelessWidget {
  const _TileBrushButton({
    required this.tileType,
    required this.selected,
    required this.onPressed,
  });

  final TileType tileType;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 28,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: tileType.editorColor,
            border: Border.all(color: const Color(0xFFE8FBFF)),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        label: Text(tileType.label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          foregroundColor: selected ? const Color(0xFF07111D) : Colors.white,
          backgroundColor: selected ? const Color(0xFF8EE6FF) : null,
          side: BorderSide(
            color: selected ? const Color(0xFF8EE6FF) : const Color(0x5533D8FF),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        ),
      ),
    );
  }
}

class _ValidationPanel extends StatelessWidget {
  const _ValidationPanel({required this.messages});

  final List<String> messages;

  @override
  Widget build(BuildContext context) {
    final valid = messages.isEmpty;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: valid ? const Color(0x3326C281) : const Color(0x33FF7043),
        border: Border.all(
          color: valid ? const Color(0x8826C281) : const Color(0x99FF7043),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                valid ? Icons.check_circle_outline : Icons.error_outline,
                size: 15,
                color: valid
                    ? const Color(0xFF6EF6A5)
                    : const Color(0xFFFFA082),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  valid ? '검증 통과' : '검증 필요',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          if (!valid) ...[
            const SizedBox(height: 5),
            for (final message in messages.take(3))
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFFFFC1B1),
                    fontSize: 10,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _EditorGrid extends StatelessWidget {
  const _EditorGrid({
    required this.map,
    required this.onPointStart,
    required this.onPointDrag,
    required this.onPointEnd,
  });

  final MapDefinition map;
  final ValueChanged<GridPoint> onPointStart;
  final ValueChanged<GridPoint> onPointDrag;
  final VoidCallback onPointEnd;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: map.columns / map.rows,
      child: LayoutBuilder(
        builder: (context, constraints) {
          GridPoint? pointFor(Offset localPosition) {
            final tileSize = constraints.maxWidth / map.columns;
            final x = (localPosition.dx / tileSize).floor();
            final y = (localPosition.dy / tileSize).floor();
            final point = GridPoint(x, y);
            return map.contains(point) ? point : null;
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) {
              final point = pointFor(details.localPosition);
              if (point != null) {
                onPointStart(point);
              }
            },
            onPanStart: (details) {
              final point = pointFor(details.localPosition);
              if (point != null) {
                onPointStart(point);
              }
            },
            onPanUpdate: (details) {
              final point = pointFor(details.localPosition);
              if (point != null) {
                onPointDrag(point);
              }
            },
            onPanEnd: (_) => onPointEnd(),
            onPanCancel: onPointEnd,
            child: CustomPaint(painter: _EditorGridPainter(map: map)),
          );
        },
      ),
    );
  }
}

class _EditorGridPainter extends CustomPainter {
  const _EditorGridPainter({required this.map});

  final MapDefinition map;

  @override
  void paint(Canvas canvas, Size size) {
    final tileSize = size.width / map.columns;
    final stroke = Paint()
      ..color = const Color(0x8833D8FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var y = 0; y < map.rows; y++) {
      for (var x = 0; x < map.columns; x++) {
        final point = GridPoint(x, y);
        final rect = Rect.fromLTWH(
          x * tileSize,
          y * tileSize,
          tileSize,
          tileSize,
        );
        canvas.drawRect(
          rect.deflate(1),
          Paint()..color = map.tileAt(point).editorColor,
        );
        canvas.drawRect(rect.deflate(1), stroke);
      }
    }

    final pathStroke = Paint()
      ..color = const Color(0xFFE7C66A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var i = 1; i < map.path.length; i++) {
      canvas.drawLine(
        _centerOf(map.path[i - 1], tileSize),
        _centerOf(map.path[i], tileSize),
        pathStroke,
      );
    }

    for (var i = 0; i < map.path.length; i++) {
      final point = map.path[i];
      final center = _centerOf(point, tileSize);
      final radius = tileSize * 0.23;
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = const Color(0xFFE7C66A),
      );
      _drawLabel(canvas, '${i + 1}', center, tileSize);
    }
  }

  Offset _centerOf(GridPoint point, double tileSize) {
    return Offset(
      point.x * tileSize + tileSize / 2,
      point.y * tileSize + tileSize / 2,
    );
  }

  void _drawLabel(Canvas canvas, String text, Offset center, double tileSize) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: const Color(0xFF07111D),
          fontSize: (tileSize * 0.2).clamp(8.0, 12.0),
          fontWeight: FontWeight.w900,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: tileSize * 0.7);
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _EditorGridPainter oldDelegate) {
    return oldDelegate.map != map;
  }
}

class _ExportPreview extends StatelessWidget {
  const _ExportPreview({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 170),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF07111D),
        border: Border.all(color: const Color(0x5533D8FF)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          text,
          style: const TextStyle(
            color: Color(0xFFC6D6E4),
            fontFamily: 'monospace',
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

extension on TileType {
  bool get canBePathNode {
    return this == TileType.path ||
        this == TileType.spawn ||
        this == TileType.core;
  }

  String get label {
    return switch (this) {
      TileType.path => 'path',
      TileType.build => 'build',
      TileType.blocked => 'blocked',
      TileType.spawn => 'spawn',
      TileType.core => 'core',
    };
  }

  Color get editorColor {
    return switch (this) {
      TileType.path => const Color(0xFF786C58),
      TileType.build => const Color(0xFF1C4737),
      TileType.blocked => const Color(0xFF172634),
      TileType.spawn => const Color(0xFF4B245F),
      TileType.core => const Color(0xFF0B86B8),
    };
  }
}
