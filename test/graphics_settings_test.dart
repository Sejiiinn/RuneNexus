import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rune_nexus/data/settings/graphics_settings.dart';
import 'package:rune_nexus/data/settings/graphics_settings_repository_io.dart';

void main() {
  test('missing and unsupported values retain compatible defaults', () {
    for (final input in [
      null,
      [],
      'bad',
      {},
      {'msaaSamples': 8, 'shadowMapSize': -1},
    ]) {
      expect(GraphicsSettings.fromJson(input), const GraphicsSettings());
    }
    expect(
      GraphicsSettings.fromJson({'msaaSamples': 0, 'shadowMapSize': '512'}),
      const GraphicsSettings(msaaSamples: 0),
    );
    for (final msaa in [0, 2]) {
      for (final shadow in [0, 512, 1024, 2048]) {
        final value = GraphicsSettings(
          msaaSamples: msaa,
          shadowMapSize: shadow,
        );
        expect(GraphicsSettings.fromJson(value.toJson()), value);
      }
    }
  });

  test(
    'local file roundtrip survives repository recreation and replacement',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'graphics-settings-',
      );
      addTearDown(() => directory.delete(recursive: true));
      LocalGraphicsSettingsRepository repository() =>
          LocalGraphicsSettingsRepository(
            applicationSupportDirectory: () async => directory,
          );
      expect(await repository().load(), isNull);
      await repository().save(
        const GraphicsSettings(msaaSamples: 0, shadowMapSize: 512),
      );
      expect(
        await repository().load(),
        const GraphicsSettings(msaaSamples: 0, shadowMapSize: 512),
      );
      await repository().save(const GraphicsSettings(shadowMapSize: 0));
      expect(
        await repository().load(),
        const GraphicsSettings(shadowMapSize: 0),
      );
      expect(directory.listSync().map((entry) => entry.path.split('/').last), [
        'graphics_settings_v1.json',
      ]);
    },
  );

  test('failed temporary write preserves the previous settings file', () async {
    final directory = await Directory.systemTemp.createTemp(
      'graphics-settings-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final repository = LocalGraphicsSettingsRepository(
      applicationSupportDirectory: () async => directory,
    );
    const previous = GraphicsSettings(shadowMapSize: 1024);
    await repository.save(previous);
    await Directory('${directory.path}/graphics_settings_v1.json.tmp').create();
    await expectLater(
      repository.save(const GraphicsSettings(msaaSamples: 0)),
      throwsA(isA<FileSystemException>()),
    );
    expect(await repository.load(), previous);
  });

  test('invalid file reports load failure and uses defaults', () async {
    final directory = await Directory.systemTemp.createTemp(
      'graphics-settings-',
    );
    addTearDown(() => directory.delete(recursive: true));
    await File(
      '${directory.path}/graphics_settings_v1.json',
    ).writeAsString('{broken');
    final controller = GraphicsSettingsController(
      repository: LocalGraphicsSettingsRepository(
        applicationSupportDirectory: () async => directory,
      ),
    );
    addTearDown(controller.dispose);
    await controller.load();
    expect(controller.loaded, isTrue);
    expect(controller.value, const GraphicsSettings());
    expect(controller.error, isNotNull);
  });

  test('save failure preserves active value and retry succeeds', () async {
    final repository = _Repository()
      ..value = const GraphicsSettings(shadowMapSize: 1024);
    final controller = GraphicsSettingsController(repository: repository);
    addTearDown(controller.dispose);
    await controller.load();
    repository.failSave = true;
    await controller.update(const GraphicsSettings(msaaSamples: 0));
    expect(controller.value, const GraphicsSettings(shadowMapSize: 1024));
    expect(controller.error, isNotNull);
    expect(controller.saving, isFalse);
    repository.failSave = false;
    await controller.update(const GraphicsSettings(msaaSamples: 0));
    expect(controller.value, const GraphicsSettings(msaaSamples: 0));
    expect(controller.error, isNull);
  });

  test(
    'in-flight save holds old value and ignores duplicate updates',
    () async {
      final repository = _Repository()..pending = Completer<void>();
      final controller = GraphicsSettingsController(repository: repository);
      addTearDown(controller.dispose);
      await controller.load();
      final update = controller.update(
        const GraphicsSettings(shadowMapSize: 512),
      );
      expect(controller.saving, isTrue);
      expect(controller.value, const GraphicsSettings());
      await controller.update(const GraphicsSettings(shadowMapSize: 0));
      expect(repository.saves, 1);
      repository.pending!.complete();
      await update;
      expect(controller.saving, isFalse);
      expect(controller.value, const GraphicsSettings(shadowMapSize: 512));
    },
  );

  test(
    'completion after controller disposal does not notify disposed listeners',
    () async {
      final repository = _Repository()..pending = Completer<void>();
      final controller = GraphicsSettingsController(repository: repository);
      await controller.load();
      final update = controller.update(const GraphicsSettings(msaaSamples: 0));
      controller.dispose();
      repository.pending!.complete();
      await expectLater(update, completes);
    },
  );
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
    if (failSave) throw const FileSystemException('unavailable');
    if (pending != null) await pending!.future;
    value = settings;
  }
}
