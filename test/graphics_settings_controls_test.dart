import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/settings/graphics_settings.dart';
import 'package:rune_nexus/ui/settings/graphics_settings_controls.dart';
import 'package:rune_nexus/ui/settings/graphics_settings_scope.dart';

void main() {
  Future<GraphicsSettingsController> mount(
    WidgetTester tester,
    _Repository repository,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = GraphicsSettingsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    await tester.pumpWidget(
      MaterialApp(
        home: GraphicsSettingsScope(
          controller: controller,
          child: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.3)),
              child: Scaffold(
                body: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: GraphicsSettingsControls(
                    controller: GraphicsSettingsScope.maybeOf(context)!,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return controller;
  }

  List<int?> selected(WidgetTester tester) => tester
      .widgetList<RadioGroup<int>>(find.byType(RadioGroup<int>))
      .map((group) => group.groupValue)
      .toList();

  Future<void> choose(WidgetTester tester, String key) async {
    final option = find.byKey(ValueKey(key));
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
  }

  testWidgets(
    'small screen keeps independent single-choice groups and saves changes',
    (tester) async {
      final repository = _Repository();
      final controller = await mount(tester, repository);
      expect(tester.takeException(), isNull);
      expect(find.byType(RadioListTile<int>), findsNWidgets(6));
      expect(selected(tester), [2, 2048]);

      await choose(tester, 'graphics-msaa-0');
      expect(selected(tester), [0, 2048]);
      expect(controller.value, const GraphicsSettings(msaaSamples: 0));
      await choose(tester, 'graphics-shadow-512');
      expect(selected(tester), [0, 512]);
      expect(
        repository.value,
        const GraphicsSettings(msaaSamples: 0, shadowMapSize: 512),
      );
      await choose(tester, 'graphics-shadow-1024');
      expect(selected(tester), [0, 1024]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed save retains selected radio and shows retryable error', (
    tester,
  ) async {
    final repository = _Repository()..failSave = true;
    final controller = await mount(tester, repository);
    await choose(tester, 'graphics-shadow-0');
    expect(selected(tester), [2, 2048]);
    expect(find.text(controller.error!), findsOneWidget);
    expect(
      tester
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .every((tile) => tile.enabled == true),
      isTrue,
    );
    repository.failSave = false;
    await choose(tester, 'graphics-shadow-0');
    expect(selected(tester), [2, 0]);
    expect(controller.error, isNull);
    expect(find.textContaining('저장하지 못했습니다'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending save disables both groups until durable completion', (
    tester,
  ) async {
    final repository = _Repository()..pending = Completer<void>();
    await mount(tester, repository);
    await choose(tester, 'graphics-msaa-0');
    expect(selected(tester), [2, 2048]);
    expect(
      tester
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .every((tile) => tile.enabled == false),
      isTrue,
    );
    await choose(tester, 'graphics-shadow-512');
    expect(repository.saves, 1);
    repository.pending!.complete();
    await tester.pump();
    expect(selected(tester), [0, 2048]);
    expect(
      tester
          .widgetList<RadioListTile<int>>(find.byType(RadioListTile<int>))
          .every((tile) => tile.enabled == true),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

class _Repository implements GraphicsSettingsRepository {
  GraphicsSettings? value;
  bool failSave = false;
  Completer<void>? pending;
  int saves = 0;

  @override
  Future<GraphicsSettings?> load() async => value;

  @override
  Future<void> save(GraphicsSettings settings) async {
    saves++;
    if (failSave) throw StateError('unavailable');
    if (pending != null) await pending!.future;
    value = settings;
  }
}
