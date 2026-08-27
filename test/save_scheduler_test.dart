import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/game/systems/save_scheduler.dart';

void main() {
  const throttle = Duration(seconds: 2);

  testWidgets('delays a normal save until the throttle expires', (
    tester,
  ) async {
    var saveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () async {
        saveCount++;
      },
      throttle: throttle,
    );
    addTearDown(scheduler.dispose);

    scheduler.requestSave();
    await tester.pump(const Duration(seconds: 1));
    expect(saveCount, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(saveCount, 1);
  });

  testWidgets('coalesces repeated normal save requests', (tester) async {
    var saveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () async {
        saveCount++;
      },
      throttle: throttle,
    );
    addTearDown(scheduler.dispose);

    scheduler.requestSave();
    await tester.pump(const Duration(milliseconds: 500));
    scheduler.requestSave();
    scheduler.requestSave();

    await tester.pump(const Duration(milliseconds: 1500));
    expect(saveCount, 1);
  });

  testWidgets('runs an immediate save without waiting for the throttle', (
    tester,
  ) async {
    var saveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () async {
        saveCount++;
      },
      throttle: throttle,
    );
    addTearDown(scheduler.dispose);

    scheduler.requestSave(immediate: true);
    await tester.pump();

    expect(saveCount, 1);
  });

  testWidgets('an immediate save cancels the pending throttle timer', (
    tester,
  ) async {
    var saveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () async {
        saveCount++;
      },
      throttle: throttle,
    );
    addTearDown(scheduler.dispose);

    scheduler.requestSave();
    scheduler.requestSave(immediate: true);
    await tester.pump();
    expect(saveCount, 1);

    await tester.pump(throttle);
    expect(saveCount, 1);
  });

  testWidgets('queues a request made while a save is in flight', (
    tester,
  ) async {
    final completions = <Completer<void>>[];
    var saveCount = 0;
    var activeSaveCount = 0;
    var maxActiveSaveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () {
        saveCount++;
        activeSaveCount++;
        maxActiveSaveCount = maxActiveSaveCount < activeSaveCount
            ? activeSaveCount
            : maxActiveSaveCount;
        final completion = Completer<void>();
        completions.add(completion);
        return completion.future.whenComplete(() => activeSaveCount--);
      },
      throttle: throttle,
    );
    addTearDown(scheduler.dispose);

    final firstFlush = scheduler.flush();
    final queuedFlush = scheduler.flush();
    expect(saveCount, 1);

    completions.first.complete();
    await tester.pump();
    expect(saveCount, 2);
    expect(maxActiveSaveCount, 1);

    completions.last.complete();
    await tester.pump();
    await Future.wait([firstFlush, queuedFlush]);
    expect(activeSaveCount, 0);
  });

  testWidgets('dispose cancels a pending normal save', (tester) async {
    var saveCount = 0;
    final scheduler = SaveScheduler(
      saveNow: () async {
        saveCount++;
      },
      throttle: throttle,
    );

    scheduler.requestSave();
    scheduler.dispose();
    await tester.pump(throttle);

    expect(saveCount, 0);
  });

  testWidgets(
    'remote rebase pause cancels pending work and can resume after failure',
    (tester) async {
      var saveCount = 0;
      final scheduler = SaveScheduler(
        saveNow: () async {
          saveCount++;
        },
        throttle: throttle,
      );
      addTearDown(scheduler.dispose);

      scheduler.requestSave();
      await scheduler.quiesce();
      await tester.pump(throttle);
      expect(saveCount, 0);

      scheduler.resume();
      scheduler.requestSave(immediate: true);
      await tester.pump();
      expect(saveCount, 1);
    },
  );
}
