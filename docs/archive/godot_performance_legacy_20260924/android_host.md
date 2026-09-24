# Android 검증 호스트

`-PruneNexusGodotPreview=true` 빌드에만 `GodotBenchmarkActivity`가 포함된다.
일반 앱 패키지·Activity·저장 경로는 변경하지 않는다. 검증용 팩에는
`res://validation/entry.tscn`을 main_scene으로 두고 `benchmark.tscn`을 포함해야 한다. Android release AAR는 CLI scene override를 허용하지 않으므로 entry가 mode 인자로 분기한다.

## Flutter 없이 실행

```sh
adb shell am force-stop com.example.rune_nexus.godotpreview
adb shell am start -W \
  -n com.example.rune_nexus.godotpreview/com.example.rune_nexus.GodotBenchmarkActivity \
  --es scenario normal --es mode standalone --es duration 30
```

이 Activity는 Godot AAR의 기본 `GodotActivity` 생명주기를 사용하고,
`:godot_benchmark` 프로세스에서 실행한다. FlutterActivity나 FlutterEngine을
만들지 않는다. 기존 `GodotBridge`를 플러그인으로 등록해 원본 씬이 요구하는
`RuneNexusPreview` singleton을 제공한다. `GodotRuntime`의 Flutter 플랫폼 뷰는
사용하지 않는다.

GDScript `OS.get_cmdline_user_args()` 계약:

```text
--scenario=normal
--mode=standalone
--duration=30.0
```

문자열은 영문·숫자·밑줄·하이픈·점으로 제한하고 64자를 넘지 않는다.
duration은 1~3600초로 제한한다. scene이나 임의 엔진 인자는 외부에서 받지 않는다.
`mode`와 `scenario`의 실제 동작은 검증 씬이 결정한다.

## Flutter 화면에서 Godot 전투로 진입

검수 앱 Dart에서 다음 채널을 호출한다.

```dart
await const MethodChannel('rune_nexus/godot_benchmark')
    .invokeMethod<void>('openBenchmark', {
  'scenario': 'normal',
  'mode': 'flutter_handoff',
  'duration': 30,
});
```

기존 Flutter Activity는 뒤로 이동하고 같은 검수 패키지의 별도 Godot Activity가
앞에 표시된다. 따라서 이 조건은 **Flutter가 상주하되 전투 화면을 직접 그리지 않는
구조**다. Flutter 안의 Godot PlatformView와 동시 합성하는 조건과 구분해서 기록한다.

Godot은 프로세스 내 재초기화 제약이 있으므로 서로 다른 독립 측정 사이에는 검수
패키지를 force-stop하고 재실행한다. 측정 결과 파일은 검증 씬이 preview 패키지의
`user://` 또는 logcat에 기록하며 production 저장 파일에 접근하지 않아야 한다.

## 확인 항목

- 단독 측정 전 force-stop으로 이전 Flutter 프로세스를 종료했는가.
- 단독 실행에서 `:godot_benchmark` 프로세스만 활성화됐는가.
- Flutter 경유 측정은 기존 Flutter 화면을 실제로 연 뒤 채널로 진입했는가.
- 두 조건에서 viewport, 렌더러, 장면, 그래픽 옵션이 같은가.
- 결과를 내장 PlatformView 비용이나 실제 기기 성능으로 잘못 해석하지 않았는가.

현재 자동 handoff는 기존 전투 기준 실행 뒤 이동하므로 이전 프로세스의 Godot도 정지·상주한다. 향후 Flutter 로비 → 단일 Godot 전투 구조의 메모리 비용과 동일하지 않으며 보수적인 전환 실험으로만 사용한다.
