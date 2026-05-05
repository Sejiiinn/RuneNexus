import '../map/map_definition.dart';
import '../wave/wave_definition.dart';

class StageDefinition {
  const StageDefinition({
    required this.id,
    required this.name,
    required this.map,
    required this.waves,
  }) : assert(id > 0),
       assert(waves.length > 0);

  final int id;
  final String name;
  final MapDefinition map;
  final List<WaveDefinition> waves;
}
