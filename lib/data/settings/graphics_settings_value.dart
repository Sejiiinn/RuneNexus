import 'package:flutter/foundation.dart';

@immutable
class GraphicsSettings {
  const GraphicsSettings({int msaaSamples = 2, int shadowMapSize = 2048})
    : msaaSamples = msaaSamples == 0 ? 0 : 2,
      shadowMapSize =
          shadowMapSize == 0 || shadowMapSize == 512 || shadowMapSize == 1024
          ? shadowMapSize
          : 2048;

  final int msaaSamples;
  final int shadowMapSize;

  GraphicsSettings copyWith({int? msaaSamples, int? shadowMapSize}) =>
      GraphicsSettings(
        msaaSamples: msaaSamples ?? this.msaaSamples,
        shadowMapSize: shadowMapSize ?? this.shadowMapSize,
      );

  Map<String, dynamic> toJson() => {
    'msaaSamples': msaaSamples,
    'shadowMapSize': shadowMapSize,
  };

  factory GraphicsSettings.fromJson(Object? json) {
    if (json is! Map) return const GraphicsSettings();
    final msaa = json['msaaSamples'];
    final shadow = json['shadowMapSize'];
    return GraphicsSettings(
      msaaSamples: msaa is int ? msaa : 2,
      shadowMapSize: shadow is int ? shadow : 2048,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is GraphicsSettings &&
      msaaSamples == other.msaaSamples &&
      shadowMapSize == other.shadowMapSize;

  @override
  int get hashCode => Object.hash(msaaSamples, shadowMapSize);
}
