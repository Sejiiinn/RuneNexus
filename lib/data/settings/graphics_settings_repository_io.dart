import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'graphics_settings_repository.dart';
import 'graphics_settings_value.dart';

class LocalGraphicsSettingsRepository implements GraphicsSettingsRepository {
  LocalGraphicsSettingsRepository({
    Future<Directory> Function()? applicationSupportDirectory,
  }) : _applicationSupportDirectory =
           applicationSupportDirectory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _applicationSupportDirectory;

  Future<File> _file() async {
    final directory = await _applicationSupportDirectory();
    return File('${directory.path}/graphics_settings_v1.json');
  }

  @override
  Future<GraphicsSettings?> load() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return GraphicsSettings.fromJson(jsonDecode(await file.readAsString()));
  }

  @override
  Future<void> save(GraphicsSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
      await temporary.rename(file.path);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }
}
