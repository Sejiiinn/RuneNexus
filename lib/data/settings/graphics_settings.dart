import 'package:flutter/foundation.dart';

import 'graphics_settings_repository.dart';
import 'graphics_settings_repository_stub.dart'
    if (dart.library.io) 'graphics_settings_repository_io.dart'
    if (dart.library.html) 'graphics_settings_repository_web.dart';
import 'graphics_settings_value.dart';

export 'graphics_settings_repository.dart';
export 'graphics_settings_value.dart';

/// Device preferences live outside account and game progression saves.
class GraphicsSettingsController extends ChangeNotifier {
  GraphicsSettingsController({GraphicsSettingsRepository? repository})
    : _repository = repository ?? LocalGraphicsSettingsRepository();

  final GraphicsSettingsRepository _repository;
  GraphicsSettings _value = const GraphicsSettings();
  bool _loaded = false;
  bool _loading = false;
  bool _saving = false;
  bool _disposed = false;
  String? _error;

  GraphicsSettings get value => _value;
  bool get loaded => _loaded;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> load() async {
    if (_loading || _saving || _disposed) return;
    _loading = true;
    _error = null;
    try {
      _value = await _repository.load() ?? const GraphicsSettings();
    } on Object {
      _value = const GraphicsSettings();
      _error = '그래픽 설정을 불러오지 못해 기본값을 사용합니다.';
    } finally {
      _loading = false;
      _loaded = true;
      _notify();
    }
  }

  Future<void> update(GraphicsSettings settings) async {
    if (!_loaded || _loading || _saving || _disposed) return;
    if (settings == _value && _error == null) return;
    _saving = true;
    _error = null;
    _notify();
    try {
      await _repository.save(settings);
      _value = settings;
    } on Object {
      _error = '그래픽 설정을 저장하지 못했습니다. 다시 시도해 주세요.';
    } finally {
      _saving = false;
      _notify();
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
