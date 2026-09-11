part of 'stage1_scene.dart';

/// 모든 착탄이 공유하는 시간별 입체 밀도·발광·열도장. GPU 업로드는 전장 준비 시 수행.
class _CannonImpactField {
  _CannonImpactField({
    required this.texture,
    required this.times,
    required this.gridSize,
    required this.bricks,
    required this.boundsMin,
    required this.boundsMax,
    required this.densityScale,
    required this.emissionScale,
  });

  final three.Data3DTexture texture;
  final List<double> times;
  final int gridSize;
  final List<int> bricks;
  final three.Vector3 boundsMin;
  final three.Vector3 boundsMax;
  final double densityScale;
  final double emissionScale;

  static Future<_CannonImpactField> load() async {
    const path = 'assets/images/stage1_3d/effects/cannon_field';
    final manifest =
        jsonDecode(await rootBundle.loadString('$path.json'))
            as Map<String, dynamic>;
    final gridSize = manifest['gridSize'] as int;
    final bricks = (manifest['atlasBricks'] as List).cast<int>();
    final times = (manifest['times'] as List)
        .map((value) => (value as num).toDouble())
        .toList(growable: false);
    final minimum = (manifest['boundsMin'] as List).cast<num>();
    final maximum = (manifest['boundsMax'] as List).cast<num>();
    final densityScale = (manifest['densityScale'] as num).toDouble();
    final emissionScale = (manifest['emissionScale'] as num).toDouble();
    // 셰이더의 공간·시간 계약이 다른 캐시를 조용히 재생하지 않도록 로딩 시 검증.
    if (manifest['version'] != 1 ||
        gridSize < 2 ||
        bricks.length != 3 ||
        bricks.any((value) => value <= 0) ||
        times.length < 2 ||
        times.length != bricks[0] * bricks[1] * bricks[2] ||
        times.first != 0 ||
        times.last != BattlefieldImpact.duration ||
        times.any((value) => !value.isFinite) ||
        Iterable.generate(
          times.length - 1,
        ).any((index) => times[index] >= times[index + 1]) ||
        minimum.length != 3 ||
        maximum.length != 3 ||
        minimum[0] != -2.35 ||
        minimum[1] != 0 ||
        minimum[2] != -2.35 ||
        maximum[0] != 2.35 ||
        maximum[1] != 2.9 ||
        maximum[2] != 2.35 ||
        !densityScale.isFinite ||
        densityScale <= 0 ||
        !emissionScale.isFinite ||
        emissionScale <= 0) {
      throw const FormatException('포탄 체적 캐시의 공간·시간 형식이 맞지 않습니다.');
    }
    final bytes = await rootBundle.load('$path.bin');
    final expectedLength = gridSize * gridSize * gridSize * times.length * 4;
    if (bytes.lengthInBytes != expectedLength ||
        manifest['byteLength'] != expectedLength) {
      throw const FormatException('포탄 체적 캐시의 데이터 길이가 맞지 않습니다.');
    }
    final Uint8List data = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    final texture =
        three.Data3DTexture(
            data,
            gridSize * bricks[0],
            gridSize * bricks[1],
            gridSize * bricks[2],
          )
          ..format = three.RGBAFormat
          ..type = three.UnsignedByteType
          ..needsUpdate = true;
    return _CannonImpactField(
      texture: texture,
      times: times,
      gridSize: gridSize,
      bricks: bricks,
      boundsMin: three.Vector3(
        minimum[0].toDouble(),
        minimum[1].toDouble(),
        minimum[2].toDouble(),
      ),
      boundsMax: three.Vector3(
        maximum[0].toDouble(),
        maximum[1].toDouble(),
        maximum[2].toDouble(),
      ),
      densityScale: densityScale,
      emissionScale: emissionScale,
    );
  }
}
