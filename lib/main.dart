import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app/rune_nexus_app.dart';
import 'app/app_update_gate.dart';
import 'platform/update/app_update_service.dart';
import 'data/save/local_save_writer_lock.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final bool acquired;
  try {
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    final localSaveWriterLock = createLocalSaveWriterLock();
    acquired = await localSaveWriterLock.acquire();
  } on Object catch (error, stackTrace) {
    debugPrint('앱 시작 준비 실패: $error');
    debugPrintStack(stackTrace: stackTrace);
    // 재시도 실패 시 이전 화면의 진행 중 상태를 초기화.
    runApp(
      _StartupUnavailableApp(key: UniqueKey(), initializationFailed: true),
    );
    return;
  }
  runApp(
    acquired
        ? AppUpdateService.enabled
              ? const AppUpdateGate(child: RuneNexusApp())
              : const RuneNexusApp()
        : const _StartupUnavailableApp(),
  );
}

class _StartupUnavailableApp extends StatefulWidget {
  const _StartupUnavailableApp({super.key, this.initializationFailed = false});

  final bool initializationFailed;

  @override
  State<_StartupUnavailableApp> createState() => _StartupUnavailableAppState();
}

class _StartupUnavailableAppState extends State<_StartupUnavailableApp> {
  bool _retrying = false;

  Future<void> _retry() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      // 잠금 획득을 포함한 시작 준비 전체 재시도.
      await main();
    } finally {
      if (mounted) setState(() => _retrying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF080D19),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.initializationFailed
                        ? '앱을 시작하지 못했습니다.\n잠시 후 다시 시도해 주세요.'
                        : '다른 탭에서 Rune Nexus를 플레이 중입니다.\n'
                              '기존 탭을 닫은 뒤 이 페이지를 새로고침해 주세요.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  if (widget.initializationFailed) ...[
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _retrying ? null : _retry,
                      child: Text(_retrying ? '다시 시도 중…' : '다시 시도'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
