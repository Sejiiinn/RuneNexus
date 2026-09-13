import 'graphics_settings_repository.dart';
import 'graphics_settings_value.dart';

class LocalGraphicsSettingsRepository implements GraphicsSettingsRepository {
  @override
  Future<GraphicsSettings?> load() async => null;

  @override
  Future<void> save(GraphicsSettings settings) async {
    throw UnsupportedError('Local graphics settings storage is unavailable.');
  }
}
