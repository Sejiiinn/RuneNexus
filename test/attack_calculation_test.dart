import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../tool/combat/calculation_fixture.dart';

void main() {
  final fixtures =
      jsonDecode(
            File('test/fixtures/combat_calculation.json').readAsStringSync(),
          )
          as List;
  for (final fixture in fixtures) {
    test(fixture['name'] as String, () {
      compareValues(
        evaluateFixture(fixture['input'] as Map<String, dynamic>),
        fixture['expected'],
        fixture['name'] as String,
      );
    });
  }
}
