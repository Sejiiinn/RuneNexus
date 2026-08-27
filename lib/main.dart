import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/rune_nexus_app.dart';
import 'data/save/local_save_writer_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final localSaveWriterLock = createLocalSaveWriterLock();
  final acquired = await localSaveWriterLock.acquire();
  runApp(
    acquired ? const RuneNexusApp() : const _LocalSaveWriterUnavailableApp(),
  );
}

class _LocalSaveWriterUnavailableApp extends StatelessWidget {
  const _LocalSaveWriterUnavailableApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Color(0xFF080D19),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                '다른 탭에서 Rune Nexus를 플레이 중입니다.\n'
                '기존 탭을 닫은 뒤 이 페이지를 새로고침해 주세요.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
