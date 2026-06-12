import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/definitions/game_stage_data.dart';
import '../../domain/map/grid_point.dart';
import '../../domain/map/map_definition.dart';
import '../../domain/map/map_tile_theme.dart';
import '../../domain/map/tile_type.dart';

enum _MapEditMode { tile, path }

const _minMapSize = 4;
const _maxMapSize = 16;
const _editorStagesPerChapter = 5;

class DebugMapEditorPanel extends StatefulWidget {
  const DebugMapEditorPanel({required this.initialStageNumber, super.key});

  final int initialStageNumber;

  @override
  State<DebugMapEditorPanel> createState() => _DebugMapEditorPanelState();
}

class _DebugMapEditorPanelState extends State<DebugMapEditorPanel> {
  late int _chapterNumber;
  late int _stageNumber;
  late List<List<TileType>> _tiles;
  late List<GridPoint> _path;
  late MapTileTheme _tileTheme;
  final Map<int, _MapDraft> _draftsByStage = {};
  TileType _selectedTile = TileType.build;
  _MapEditMode _mode = _MapEditMode.tile;
  String? _lastExportText;
  GridPoint? _lastPaintedPoint;

  @override
  void initState() {
    super.initState();
    final stageCount = gameStages.length;
    _stageNumber = widget.initialStageNumber.clamp(1, stageCount).toInt();
    _loadStage(_stageNumber);
  }

  void _loadStage(int stageNumber) {
    final draft = _draftsByStage[stageNumber] ?? _draftForStage(stageNumber);
    _chapterNumber = _chapterForStage(stageNumber);
    _stageNumber = stageNumber;
    _tiles = draft.copyTiles();
    _path = [...draft.path];
    _tileTheme = draft.tileTheme;
    _lastExportText = null;
  }

  _MapDraft _draftForStage(int stageNumber) {
    final stage = gameStages[stageNumber - 1];
    final map = stage.map;
    return _MapDraft(
      tiles: [
        for (final row in map.tiles) [...row],
      ],
      path: [...map.path],
      tileTheme: map.tileTheme,
    );
  }

  void _saveCurrentDraft() {
    _draftsByStage[_stageNumber] = _MapDraft(
      tiles: [
        for (final row in _tiles) [...row],
      ],
      path: [..._path],
      tileTheme: _tileTheme,
    );
  }

  void _switchStage(int stageNumber) {
    if (stageNumber == _stageNumber) {
      return;
    }
    _saveCurrentDraft();
    _loadStage(stageNumber);
  }

  void _switchChapter(int chapterNumber) {
    if (chapterNumber == _chapterNumber) {
      return;
    }
    _saveCurrentDraft();
    final firstStage = _firstStageForChapter(chapterNumber);
    _loadStage(firstStage.clamp(1, gameStages.length).toInt());
  }

  MapDefinition get _map => MapDefinition(
    columns: _tiles.first.length,
    rows: _tiles.length,
    tiles: _tiles,
    path: _path,
    tileTheme: _tileTheme,
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
    setState(() {
      final existingIndex = _path.indexOf(point);
      if (existingIndex >= 0) {
        if (existingIndex == _path.length - 1) {
          _path.removeLast();
        } else {
          _path = _path.take(existingIndex + 1).toList();
        }
      } else {
        if (!_tiles[point.y][point.x].canBePathNode) {
          return;
        }
        if (_path.isNotEmpty && !_isStraightSegment(_path.last, point)) {
          return;
        }
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
          return TileType.blocked;
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
    setState(() {
      _lastExportText = exportText;
    });

    var copied = false;
    try {
      await Clipboard.setData(ClipboardData(text: exportText));
      final copiedText = await Clipboard.getData('text/plain');
      copied = copiedText?.text == exportText;
    } catch (_) {
      copied = false;
    }

    if (!mounted) {
      return;
    }
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
          chapterNumber: _chapterNumber,
          stageNumber: _stageNumber,
          stageCount: gameStages.length,
          columns: _tiles.first.length,
          rows: _tiles.length,
          onChapterSelected: (chapterNumber) {
            setState(() {
              _switchChapter(chapterNumber);
            });
          },
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
          tileTheme: _tileTheme,
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
        if (i > 0 && !_isStraightSegment(_path[i - 1], point)) {
          messages.add('경로는 가로 또는 세로 직선 구간으로만 연결해야 합니다.');
          break;
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

  bool _isStraightSegment(GridPoint a, GridPoint b) {
    return a.x == b.x || a.y == b.y;
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
    buffer.writeln('  ],');
    if (_tileTheme.kind == MapTileThemeKind.chapterTwoRift) {
      buffer.writeln('  tileTheme: chapterTwoRiftTileTheme,');
    } else if (_tileTheme.kind == MapTileThemeKind.chapterThreeForge) {
      buffer.writeln('  tileTheme: chapterThreeForgeTileTheme,');
    }
    buffer.writeln(');');
    return buffer.toString();
  }

  int _chapterForStage(int stageNumber) {
    return ((stageNumber - 1) ~/ _editorStagesPerChapter) + 1;
  }

  int _firstStageForChapter(int chapterNumber) {
    return (chapterNumber - 1) * _editorStagesPerChapter + 1;
  }
}

class _MapDraft {
  const _MapDraft({
    required this.tiles,
    required this.path,
    required this.tileTheme,
  });

  final List<List<TileType>> tiles;
  final List<GridPoint> path;
  final MapTileTheme tileTheme;

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
            overflow: TextOverflow.clip,
          ),
        ),
      ],
    );
  }
}

class _EditorSetupControls extends StatelessWidget {
  const _EditorSetupControls({
    required this.chapterNumber,
    required this.stageNumber,
    required this.stageCount,
    required this.columns,
    required this.rows,
    required this.onChapterSelected,
    required this.onStageSelected,
    required this.onResizeColumns,
    required this.onResizeRows,
  });

  final int chapterNumber;
  final int stageNumber;
  final int stageCount;
  final int columns;
  final int rows;
  final ValueChanged<int> onChapterSelected;
  final ValueChanged<int> onStageSelected;
  final ValueChanged<int> onResizeColumns;
  final ValueChanged<int> onResizeRows;

  @override
  Widget build(BuildContext context) {
    return _ControlSection(
      title: '챕터 / 스테이지 / 크기',
      child: Column(
        children: [
          Wrap(
            spacing: 5,
            runSpacing: 5,
            children: [
              for (var chapter = 1; chapter <= _chapterCount; chapter++)
                ChoiceChip(
                  label: Text(_chapterLabel(chapter)),
                  selected: chapterNumber == chapter,
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                  padding: EdgeInsets.zero,
                  onSelected: (_) => onChapterSelected(chapter),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final stage in _stagesInChapter(chapterNumber))
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

  int get _chapterCount {
    return (stageCount / _editorStagesPerChapter).ceil();
  }

  Iterable<int> _stagesInChapter(int chapter) sync* {
    final first = (chapter - 1) * _editorStagesPerChapter + 1;
    final last = math.min(first + _editorStagesPerChapter - 1, stageCount);
    for (var stage = first; stage <= last; stage++) {
      yield stage;
    }
  }

  String _chapterLabel(int chapter) {
    final first = (chapter - 1) * _editorStagesPerChapter + 1;
    final last = math.min(first + _editorStagesPerChapter - 1, stageCount);
    return '챕터 $chapter · $first-$last';
  }
}

class _EditorControls extends StatelessWidget {
  const _EditorControls({
    required this.selectedTile,
    required this.tileTheme,
    required this.mode,
    required this.validationMessages,
    required this.onTileSelected,
    required this.onModeSelected,
    required this.onReset,
    required this.onClearPath,
    required this.onCopyExport,
  });

  final TileType selectedTile;
  final MapTileTheme tileTheme;
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
                      tileTheme: tileTheme,
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
          overflow: TextOverflow.clip,
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
            overflow: TextOverflow.clip,
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
    required this.tileTheme,
    required this.selected,
    required this.onPressed,
  });

  final TileType tileType;
  final MapTileTheme tileTheme;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: SizedBox(
          width: 20,
          height: 20,
          child: CustomPaint(
            painter: _TilePreviewPainter(
              tileType: tileType,
              tileTheme: tileTheme,
            ),
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

          return Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              final point = pointFor(event.localPosition);
              if (point != null) {
                onPointStart(point);
              }
            },
            onPointerMove: (event) {
              final point = pointFor(event.localPosition);
              if (point != null) {
                onPointDrag(point);
              }
            },
            onPointerUp: (_) => onPointEnd(),
            onPointerCancel: (_) => onPointEnd(),
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
      ..color = map.tileTheme.gridStrokeColor
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
        _EditorTileArt.drawTile(
          canvas,
          rect.deflate(1),
          point,
          map.tileAt(point),
          map.tileTheme,
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

class _TilePreviewPainter extends CustomPainter {
  const _TilePreviewPainter({required this.tileType, required this.tileTheme});

  final TileType tileType;
  final MapTileTheme tileTheme;

  @override
  void paint(Canvas canvas, Size size) {
    _EditorTileArt.drawTile(
      canvas,
      Offset.zero & size,
      const GridPoint(2, 3),
      tileType,
      tileTheme,
    );
  }

  @override
  bool shouldRepaint(covariant _TilePreviewPainter oldDelegate) {
    return oldDelegate.tileType != tileType ||
        oldDelegate.tileTheme.kind != tileTheme.kind;
  }
}

class _EditorTileArt {
  static void drawTile(
    Canvas canvas,
    Rect rect,
    GridPoint point,
    TileType tileType,
    MapTileTheme theme,
  ) {
    switch (tileType) {
      case TileType.path:
        _drawTerrainTile(
          canvas,
          rect,
          point,
          theme,
          topColor: theme.pathTopColor,
          midColor: theme.pathMidColor,
          bottomColor: theme.pathBottomColor,
          rimColor: theme.pathRimColor,
          detailColor: theme.pathChipColor,
          accentColor: theme.pathLightChipColor,
          isPath: true,
        );
      case TileType.build:
        _drawTerrainTile(
          canvas,
          rect,
          point,
          theme,
          topColor: theme.buildTopColor,
          midColor: theme.buildMidColor,
          bottomColor: theme.buildBottomColor,
          rimColor: theme.buildRimColor,
          detailColor: theme.buildDarkScuffColor,
          accentColor: theme.buildMutedLeafColor,
          isPath: false,
        );
      case TileType.blocked:
        _drawBlockedTile(canvas, rect, theme);
      case TileType.spawn:
        _drawSpecialTile(canvas, rect, point, theme, isSpawn: true);
      case TileType.core:
        _drawSpecialTile(canvas, rect, point, theme, isSpawn: false);
    }
  }

  static void _drawTerrainTile(
    Canvas canvas,
    Rect rect,
    GridPoint point,
    MapTileTheme theme, {
    required Color topColor,
    required Color midColor,
    required Color bottomColor,
    required Color rimColor,
    required Color detailColor,
    required Color accentColor,
    required bool isPath,
  }) {
    final face = rect.deflate(rect.shortestSide * 0.04);
    if (theme.usesForgeHeat) {
      if (isPath) {
        _drawForgePathPreview(canvas, rect, face, theme);
      } else {
        _drawForgeBuildPreview(canvas, rect, face, theme);
      }
      return;
    }

    final radius = Radius.circular(rect.shortestSide * 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = rimColor.withValues(alpha: 0.72),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(rect.shortestSide * 0.04)),
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          [topColor, midColor, bottomColor],
          const [0, 0.58, 1],
        ),
    );
    canvas.drawLine(
      Offset(face.left + face.width * 0.08, face.top + face.height * 0.1),
      Offset(face.right - face.width * 0.12, face.top + face.height * 0.08),
      Paint()
        ..color = const Color(0x1FFFFFFF)
        ..strokeWidth = rect.shortestSide * 0.018
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      Offset(face.left + face.width * 0.12, face.bottom - face.height * 0.1),
      Offset(face.right - face.width * 0.08, face.bottom - face.height * 0.08),
      Paint()
        ..color = const Color(0x33000000)
        ..strokeWidth = rect.shortestSide * 0.018
        ..strokeCap = StrokeCap.round,
    );

    if (isPath) {
      _drawPathChips(canvas, face, point, detailColor, accentColor);
    } else {
      _drawBuildScuffs(canvas, face, point, detailColor, accentColor);
    }
    if (theme.usesRiftEnergy) {
      _drawRiftMark(canvas, face, point, theme, isPath: isPath);
    }
  }

  static void _drawForgeTerrainFrame(
    Canvas canvas,
    Rect rect,
    Rect face, {
    required Color topColor,
    required Color midColor,
    required Color bottomColor,
    required Color rimColor,
  }) {
    final radius = Radius.circular(rect.shortestSide * 0.05);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, radius),
      Paint()..color = rimColor.withValues(alpha: 0.8),
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(rect.shortestSide * 0.04)),
      Paint()
        ..shader = ui.Gradient.linear(
          face.topLeft,
          face.bottomRight,
          [topColor, midColor, bottomColor],
          const [0, 0.58, 1],
        ),
    );

    final highlight = Paint()
      ..color = const Color(0x24FFFFFF)
      ..strokeWidth = math.max(1, face.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(face.left + face.width * 0.2, face.top + face.height * 0.08),
      Offset(face.right - face.width * 0.2, face.top + face.height * 0.08),
      highlight,
    );
    canvas.drawLine(
      Offset(face.left + face.width * 0.08, face.top + face.height * 0.2),
      Offset(face.left + face.width * 0.08, face.bottom - face.height * 0.2),
      highlight..color = const Color(0x18FFFFFF),
    );
  }

  static void _drawForgePathPreview(
    Canvas canvas,
    Rect rect,
    Rect face,
    MapTileTheme theme,
  ) {
    _drawForgeTerrainFrame(
      canvas,
      rect,
      face,
      topColor: theme.pathTopColor,
      midColor: theme.pathMidColor,
      bottomColor: theme.pathBottomColor,
      rimColor: theme.pathRimColor,
    );

    final inset = face.deflate(face.shortestSide * 0.12);
    canvas.drawRRect(
      RRect.fromRectAndRadius(inset, Radius.circular(face.shortestSide * 0.04)),
      Paint()
        ..color = theme.pathInsetStrokeColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, face.shortestSide * 0.02),
    );

    final seam = Paint()
      ..color = theme.energySoftColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1, face.shortestSide * 0.018)
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(face.left + face.width * 0.2, face.top + face.height * 0.36),
      Offset(face.right - face.width * 0.2, face.top + face.height * 0.36),
      seam,
    );
    canvas.drawLine(
      Offset(face.left + face.width * 0.2, face.bottom - face.height * 0.32),
      Offset(face.right - face.width * 0.2, face.bottom - face.height * 0.32),
      seam..color = theme.energySoftColor.withValues(alpha: 0.2),
    );

    _drawForgeEdgeHeat(canvas, face, theme, intensity: 0.78);

    final emberPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.32);
    canvas.drawCircle(
      Offset(face.left + face.width * 0.28, face.top + face.height * 0.68),
      face.shortestSide * 0.018,
      emberPaint,
    );
    canvas.drawCircle(
      Offset(face.right - face.width * 0.25, face.top + face.height * 0.3),
      face.shortestSide * 0.014,
      emberPaint,
    );
  }

  static void _drawForgeBuildPreview(
    Canvas canvas,
    Rect rect,
    Rect face,
    MapTileTheme theme,
  ) {
    _drawForgeTerrainFrame(
      canvas,
      rect,
      face,
      topColor: theme.buildTopColor,
      midColor: theme.buildMidColor,
      bottomColor: theme.buildBottomColor,
      rimColor: theme.buildRimColor,
    );

    final socket = Rect.fromCenter(
      center: face.center,
      width: face.width * 0.44,
      height: face.height * 0.44,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        socket,
        Radius.circular(face.shortestSide * 0.05),
      ),
      Paint()..color = const Color(0x8A061018),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        socket,
        Radius.circular(face.shortestSide * 0.05),
      ),
      Paint()
        ..color = theme.energySecondaryColor.withValues(alpha: 0.32)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, face.shortestSide * 0.02),
    );

    final inner = socket.deflate(face.shortestSide * 0.1);
    canvas.drawOval(
      inner,
      Paint()
        ..color = theme.energySoftColor.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );

    _drawForgeEdgeHeat(canvas, face, theme, intensity: 0.5);

    final rivetPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.34);
    for (final center in [
      Offset(face.left + face.width * 0.2, face.top + face.height * 0.2),
      Offset(face.right - face.width * 0.2, face.top + face.height * 0.2),
      Offset(face.left + face.width * 0.2, face.bottom - face.height * 0.2),
      Offset(face.right - face.width * 0.2, face.bottom - face.height * 0.2),
    ]) {
      canvas.drawCircle(center, face.shortestSide * 0.026, rivetPaint);
    }
  }

  static void _drawForgeEdgeHeat(
    Canvas canvas,
    Rect face,
    MapTileTheme theme, {
    required double intensity,
  }) {
    final glowPaint = Paint()
      ..color = theme.energyPrimaryColor.withValues(alpha: 0.18 * intensity)
      ..maskFilter = MaskFilter.blur(
        BlurStyle.normal,
        face.shortestSide * 0.03,
      );
    final heatPaint = Paint()
      ..shader = ui.Gradient.linear(
        face.centerLeft,
        face.centerRight,
        [
          theme.energyPrimaryColor.withValues(alpha: 0.18 * intensity),
          const Color(0xFFFFD58A).withValues(alpha: 0.55 * intensity),
          theme.energyPrimaryColor.withValues(alpha: 0.24 * intensity),
        ],
        const [0, 0.52, 1],
      );
    final vents = [
      Rect.fromLTWH(
        face.left + face.width * 0.2,
        face.bottom - face.height * 0.18,
        face.width * 0.2,
        face.shortestSide * 0.028,
      ),
      Rect.fromLTWH(
        face.right - face.width * 0.36,
        face.top + face.height * 0.17,
        face.width * 0.16,
        face.shortestSide * 0.022,
      ),
    ];

    for (final vent in vents) {
      final slit = RRect.fromRectAndRadius(
        vent,
        Radius.circular(face.shortestSide * 0.012),
      );
      canvas.drawRRect(slit.inflate(face.shortestSide * 0.016), glowPaint);
      canvas.drawRRect(slit, heatPaint);
    }
  }

  static void _drawPathChips(
    Canvas canvas,
    Rect face,
    GridPoint point,
    Color detailColor,
    Color accentColor,
  ) {
    for (var i = 0; i < 4; i++) {
      final center = Offset(
        face.left + face.width * (0.18 + _unit(point, i) * 0.64),
        face.top + face.height * (0.22 + _unit(point, i + 7) * 0.56),
      );
      final chip = Rect.fromCenter(
        center: center,
        width: face.width * (0.08 + _unit(point, i + 13) * 0.08),
        height: math.max(1, face.height * 0.035),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(chip, Radius.circular(face.width * 0.02)),
        Paint()..color = i.isEven ? detailColor : accentColor,
      );
    }
  }

  static void _drawBuildScuffs(
    Canvas canvas,
    Rect face,
    GridPoint point,
    Color detailColor,
    Color accentColor,
  ) {
    final dark = Paint()
      ..color = detailColor
      ..strokeWidth = math.max(1, face.shortestSide * 0.035)
      ..strokeCap = StrokeCap.round;
    final bright = Paint()
      ..color = accentColor
      ..strokeWidth = math.max(1, face.shortestSide * 0.03)
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 3; i++) {
      final start = Offset(
        face.left + face.width * (0.2 + _unit(point, i + 19) * 0.56),
        face.top + face.height * (0.36 + _unit(point, i + 25) * 0.42),
      );
      final end = start.translate(
        face.width * (-0.08 + _unit(point, i + 31) * 0.16),
        -face.height * (0.1 + _unit(point, i + 37) * 0.08),
      );
      canvas.drawLine(
        start.translate(face.width * 0.02, face.height * 0.02),
        end,
        dark,
      );
      canvas.drawLine(start, end, i == 1 ? bright : dark);
    }
  }

  static void _drawRiftMark(
    Canvas canvas,
    Rect face,
    GridPoint point,
    MapTileTheme theme, {
    required bool isPath,
  }) {
    final start = Offset(
      face.left + face.width * (0.16 + _unit(point, 43) * 0.12),
      face.top + face.height * (isPath ? 0.44 : 0.3),
    );
    final mid = Offset(
      face.left + face.width * (0.46 + _unit(point, 44) * 0.12),
      face.top + face.height * (0.22 + _unit(point, 45) * 0.46),
    );
    final end = Offset(
      face.right - face.width * (0.14 + _unit(point, 46) * 0.1),
      face.top + face.height * (isPath ? 0.54 : 0.62),
    );
    final path = Path()
      ..moveTo(start.dx, start.dy)
      ..quadraticBezierTo(mid.dx, mid.dy, end.dx, end.dy);
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.energyPrimaryColor.withValues(alpha: 0.24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = face.shortestSide * 0.1
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          face.shortestSide * 0.04,
        ),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = theme.energySecondaryColor.withValues(alpha: 0.72)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, face.shortestSide * 0.035)
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      mid,
      face.shortestSide * 0.055,
      Paint()..color = theme.energyPrimaryColor.withValues(alpha: 0.72),
    );
  }

  static void _drawBlockedTile(Canvas canvas, Rect rect, MapTileTheme theme) {
    final face = rect.deflate(rect.shortestSide * 0.04);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(rect.shortestSide * 0.05)),
      Paint()..color = const Color(0xFF07111D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(face, Radius.circular(rect.shortestSide * 0.04)),
      Paint()
        ..shader = ui.Gradient.linear(face.topLeft, face.bottomRight, [
          theme.buildBottomColor.withValues(alpha: 0.82),
          const Color(0xFF050A12),
        ]),
    );
    canvas.drawLine(
      Offset(face.left + face.width * 0.2, face.top + face.height * 0.2),
      Offset(face.right - face.width * 0.2, face.bottom - face.height * 0.2),
      Paint()
        ..color = theme.gridStrokeColor.withValues(alpha: 0.7)
        ..strokeWidth = math.max(1, face.shortestSide * 0.04),
    );
  }

  static void _drawSpecialTile(
    Canvas canvas,
    Rect rect,
    GridPoint point,
    MapTileTheme theme, {
    required bool isSpawn,
  }) {
    final baseColor = isSpawn ? theme.spawnTileColor : theme.coreTileColor;
    _drawTerrainTile(
      canvas,
      rect,
      point,
      theme,
      topColor: baseColor.withValues(alpha: 0.92),
      midColor: baseColor,
      bottomColor: const Color(0xFF080A18),
      rimColor: isSpawn ? theme.portalOuterColor : theme.nexusGemStrokeColor,
      detailColor: theme.stoneMortarColor,
      accentColor: theme.stoneHighlightColor,
      isPath: true,
    );
    final center = rect.center;
    final radius = rect.shortestSide * 0.24;
    if (isSpawn) {
      canvas.drawCircle(
        center,
        radius * 1.08,
        Paint()..color = theme.portalBaseColor,
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = theme.portalOuterColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(1, rect.shortestSide * 0.05),
      );
      canvas.drawCircle(
        center,
        radius * 0.55,
        Paint()..color = theme.portalGlowColor.withValues(alpha: 0.7),
      );
      return;
    }

    final gem = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.68, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.68, center.dy)
      ..close();
    canvas.drawPath(gem, Paint()..color = theme.nexusGemColor);
    canvas.drawPath(
      gem,
      Paint()
        ..color = theme.nexusGemStrokeColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1, rect.shortestSide * 0.045),
    );
  }

  static double _unit(GridPoint point, int salt) {
    final n = math.sin(point.x * 12.9898 + point.y * 78.233 + salt * 37.719);
    return (n * 43758.5453).abs() % 1;
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
}
