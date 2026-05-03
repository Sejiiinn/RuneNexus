import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/rune_nexus_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const RuneNexusApp());
}
