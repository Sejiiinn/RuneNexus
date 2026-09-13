// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:convert';
import 'dart:html' as html;

import 'graphics_settings_repository.dart';
import 'graphics_settings_value.dart';

class LocalGraphicsSettingsRepository implements GraphicsSettingsRepository {
  static const _key = 'rune_nexus:graphics_settings:v1';

  @override
  Future<GraphicsSettings?> load() async {
    final raw = html.window.localStorage[_key];
    return raw == null ? null : GraphicsSettings.fromJson(jsonDecode(raw));
  }

  @override
  Future<void> save(GraphicsSettings settings) async {
    html.window.localStorage[_key] = jsonEncode(settings.toJson());
  }
}
