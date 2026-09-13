import 'graphics_settings_value.dart';

abstract interface class GraphicsSettingsRepository {
  Future<GraphicsSettings?> load();
  Future<void> save(GraphicsSettings settings);
}
