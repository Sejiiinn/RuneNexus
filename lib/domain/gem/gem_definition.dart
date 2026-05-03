import 'package:flutter/material.dart';

import 'gem_effect_type.dart';
import 'gem_type.dart';

class GemDefinition {
  const GemDefinition({
    required this.type,
    required this.name,
    required this.shortText,
    required this.effectType,
    required this.value,
    required this.color,
    required this.icon,
  });

  final GemType type;
  final String name;
  final String shortText;
  final GemEffectType effectType;
  final double value;
  final Color color;
  final IconData icon;
}
