import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/domain/combat/native_combat_protocol.dart';

void main() {
  test(
    'bootstrap freezes Flame ownership before activation acknowledgement',
    () {
      final protocol = NativeCombatProtocol()..begin(7);
      final packet = protocol.submit({'bootstrap': <String, Object?>{}});
      expect(protocol.engaged, isTrue);
      expect(protocol.active, isFalse);
      expect(
        protocol.accept({
          'epoch': 6,
          'ackSequence': packet['sequence'],
          'accepted': true,
        }),
        isFalse,
      );
      expect(protocol.active, isFalse);
      expect(
        protocol.accept({
          'epoch': 7,
          'ackSequence': packet['sequence'],
          'accepted': true,
        }),
        isTrue,
      );
      expect(protocol.active, isTrue);
    },
  );

  test(
    'unacknowledged packet is retried verbatim and duplicate response rejected',
    () {
      final protocol = NativeCombatProtocol()..begin(3);
      final first = protocol.submit({
        'dtSteps': [0.02, 0.03],
      });
      expect(
        identical(
          first,
          protocol.submit({
            'dtSteps': [1.0],
          }),
        ),
        isTrue,
      );
      final response = {'epoch': 3, 'ackSequence': 1, 'accepted': true};
      expect(protocol.accept(response), isTrue);
      expect(protocol.accept(response), isFalse);
      expect(
        protocol.submit({
          'dtSteps': [0.01],
        })['sequence'],
        2,
      );
    },
  );

  test(
    'reward event IDs are consumed once and old responses cannot resume errors',
    () {
      final protocol = NativeCombatProtocol()..begin(3);
      protocol.submit({});
      expect(protocol.acceptEvent(1), isTrue);
      expect(protocol.acceptEvent(1), isFalse);
      expect(protocol.acceptEvent(0), isFalse);
      protocol.suspend();
      expect(protocol.engaged, isTrue);
      expect(
        protocol.accept({'epoch': 3, 'ackSequence': 1, 'accepted': true}),
        isFalse,
      );
      expect(() => protocol.begin(4), throwsStateError);
    },
  );

  test('explicit run reset invalidates previous epoch and event stream', () {
    final protocol = NativeCombatProtocol()..begin(1);
    protocol.submit({});
    protocol.acceptEvent(5);
    protocol.reset();
    protocol.begin(2);
    final next = protocol.submit({});
    expect(next['ackEvent'], 0);
    expect(
      protocol.accept({'epoch': 1, 'ackSequence': 1, 'accepted': true}),
      isFalse,
    );
    expect(
      protocol.accept({'epoch': 2, 'ackSequence': 1, 'accepted': true}),
      isTrue,
    );
    expect(protocol.acceptEvent(1), isTrue);
  });
}
