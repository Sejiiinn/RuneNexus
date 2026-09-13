import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/rendering/stage1_3d/battlefield_presentation_state.dart';

void main() {
  Map<String, dynamic> valid() => {
    'presentationVersion': 2,
    'sceneEpoch': 31,
    'viewportRevision': 7,
    'viewport': [390, 844],
    'sequence': 15,
    'appliedGroups': ['labels', 'unimplemented'],
    'nativeTurretLevels': true,
    'projection': {
      'origin': [.2, .3],
      'xAxis': [.1, .01],
      'yAxis': [.0, .05],
      'heightAxis': [.0, -.025],
    },
  };
  BattlefieldPresentationState? decode(Map<String, dynamic> state) =>
      BattlefieldPresentationState.tryDecode(
        state,
        sceneEpoch: 31,
        viewportRevision: 7,
        viewport: const Size(390, 844),
        lastSubmitted: 20,
        lastApplied: 12,
      );

  test('실제 적용된 알려진 묶음만 소유권을 넘기고 타일 입력 투영을 보존한다', () {
    final state = decode(valid())!;
    expect(state.sequence, 15);
    expect(state.groups, {'labels'});
    expect(state.turretLevels, isTrue);
    const point = Offset(3.5, 4.5);
    final restored = state.projection.screenToGrid(
      state.projection.gridToScreen(point),
    )!;
    expect((restored - point).distance, lessThan(1e-9));
  });

  test('오래된 장면·버전·화면 크기·역행 및 미래 응답을 거절한다', () {
    for (final patch in <Map<String, dynamic>>[
      {'sceneEpoch': 30},
      {'presentationVersion': 1},
      {'viewportRevision': 6},
      {
        'viewport': [844, 390],
      },
      {'sequence': 11},
      {'sequence': 21},
      {'sequence': null},
    ]) {
      expect(decode({...valid(), ...patch}), isNull, reason: '$patch');
    }
  });

  test('빠진/비정상 투영과 역변환 불가 투영을 적용하지 않는다', () {
    for (final projection in [
      null,
      <String, dynamic>{},
      {
        ...valid()['projection'] as Map,
        'xAxis': [double.nan, 0],
      },
      {
        ...valid()['projection'] as Map,
        'yAxis': [.1, .01],
      },
    ]) {
      expect(decode({...valid(), 'projection': projection}), isNull);
    }
  });

  test('미지원 기능은 Flame에 남기고 같은 프레임의 카메라 갱신은 허용한다', () {
    final data = valid()..remove('appliedGroups');
    expect(decode(data)!.groups, isEmpty);
    expect(decode({...data, 'sequence': 12}), isNotNull);
  });

  test('Android 소수 logical viewport의 Godot JSON 반올림을 허용한다', () {
    final data = valid()..['viewport'] = [392.727272727273, 881.454545454545];
    expect(
      BattlefieldPresentationState.tryDecode(
        data,
        sceneEpoch: 31,
        viewportRevision: 7,
        viewport: const Size(392.72727272727275, 881.4545454545455),
        lastSubmitted: 20,
        lastApplied: 12,
      ),
      isNotNull,
    );
    expect(decode(valid()..['viewport'] = [390.001, 844]), isNull);
  });
}
