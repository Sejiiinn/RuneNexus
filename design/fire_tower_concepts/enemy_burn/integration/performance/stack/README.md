# 화염 포탑 함수 스택 측정 (2026-09-14)

## 조건

- Android emulator-5554, 앱 PID 14160, release, `RN_CREATION_PROBE=true`.
- `cold_cannon` → `first_magic` 측정 뒤 `stack_capture_ready` 시점의 35초 유지 구간에서 실행.
- Godot render timestamp 프로파일은 비활성화된 상태.
- 먼저 simpleperf 10초, 종료 후 호스트 QEMU `sample` 5초. 화면 녹화 없음.
- adb shell 권한의 release 샘플링은 Permission denied. 조율 후 `adb root`로 일시 전환. 종료 시 `adb unroot` 필요.

## 명령과 산출물

`capture_ready.py`는 이벤트를 감시하여 아래 수집 및 리포트를 생성한다.

```
simpleperf record -p 14160 -e task-clock:u -f 99 --call-graph dwarf,8192 --duration 10 -o /data/local/tmp/rn-magic-stack.data
sample 47909 5 10 -file host-qemu-sample.txt
```

- `magic-stack.data`: 원본 Android CPU 샘플.
- `self.txt`: 함수 자신의 사용자 공간 CPU 샘플.
- `children.txt`: 자식 호출을 포함한 스택.
- `thread.txt`, `library.txt`: 스레드 및 라이브러리별 합계.
- `host-qemu-sample.txt`: 호스트 QEMU의 시점별 스택. 대기 중인 스레드도 포함하므로 CPU 사용 비율로 해석하지 않는다.

## 확인한 내용과 한계

- 9.99초 동안 586 samples, lost 0. 사용자 공간 task-clock은 총 5.919초.
- 그 사용자 공간 샘플 중 앱 main thread 45.39%, Godot VkThread 39.08%, ART HeapTaskDaemon 11.26%.
- 가장 큰 단일 심볼은 에뮬레이터 OpenGL 드라이버의 `gfxstream::guest::GLClientState::setFboCompletenessDirtyForTexture`, 전체 샘플 4.44%(26개).
- 이 경로는 Flutter 호출 → `glTexImage2D` → `GL2Encoder::s_glTexImage2D` → 위 함수로 나타난다. 포탑 입자 GDScript 함수 자체가 아니다.
- Godot에서는 `Java_org_godotengine_godot_GodotLib_step` 아래 엔진 호출, Vulkan buffer 생성/읽기 등이 관측되지만 다수 엔진 내부 심볼은 배포 라이브러리에서 제거되어 주소로만 나타난다.
- 이 수집은 `task-clock:u`로 **커널 시간을 제외**했다. 이전 스케줄링 추적에서 두 스레드가 각 코어에 길게 실행되는 결과를 이 샘플만으로 설명할 수 없다. 커널 포함 task-clock 샘플이 필요하다.
- 호스트 QEMU에서 gfxstream Vulkan 명령 해석 및 Metal 경로가 나타나지만, 단일 스핀 함수가 압도한다는 증거는 없다. 대기 스택이 많은 것은 다수 유휴 작업 스레드도 샘플링하기 때문이며 병목이라고 단정하지 않는다.

이 자료만으로 특정 함수가 전체 지연의 원인이라고 확정하지 않는다. 동일 앱의 화염 포탑 최초 생성 전후 프레임 비교는 상위 디렉터리의 creation probe 결과를 함께 확인한다.

## 커널 포함 후속 비교

같은 APK를 다시 실행한 PID 14301에서 `capture_kernel.py`로 `-e task-clock`(커널 포함), 99Hz, 10초씩 수집했다. 각 캡처 모두 lost 0이다. 이 실행은 샘플러 간섭이 있으므로 FPS 기준값에는 앞의 무샘플러 실행을 사용한다.

- 대포 트리거: 22:48:03.211, 9.934초 수집. 다음 화염 begin은 22:48:20.881이므로 모드가 섞이지 않았다.
- 화염 트리거: 22:48:35.394, 9.980초 수집. 35초 유지 구간 안에서 끝났다.

| 항목 | 대포 | 화염 |
| --- | ---: | ---: |
| 샘플 수 | 2360 | 2115 |
| 전체 task-clock 합계 | 23.838초 | 21.364초 |
| goldfish_pipe_read_write, 자식 포함 | 70.59% | 69.93% |
| goldfish_pipe.ko writel, 함수 자체 | 55.89% | 56.45% |
| vkCreateBuffer 경로, 자식 포함 | 2.63% | 14.47% |
| vkCreateBuffer 경로 환산 CPU 시간 | 약 0.627초 | 약 3.091초 |
| vkGetFenceStatus, 자식 포함 | 20.04% | 8.13% |
| vkWaitForFences, 자식 포함 | 15.72% | 5.58% |

원본은 `cannon-kernel.data`, `magic-kernel.data`; 스레드/심볼/스택 보고서도 각각 같은 접두사다. `*-symbols.txt`는 자식 포함 심볼 합계를 한 줄씩 보여준다. 위 호출경로는 서로 중첩될 수 있으므로 열을 합산하지 않는다.

**확인된 지점:** 전체 guest CPU의 약 70%가 에뮬레이터 그래픽 파이프 경로에 나타난다. 화염에서는 Vulkan buffer 생성 경로의 CPU 시간이 약 4.9배 커졌다. 이 증가는 전체 CPU 사용량 증가와 다르며, 단위 시간에 처리한 프레임 수가 줄어든 조건이다. 정확한 Godot 내부 호출부는 release 심볼이 없어 주소로만 남아 있다. `writel`을 실제 CPU가 스핀했다는 뜻으로 단정하지 않는다. 가상 MMIO 접근/호스트 처리 비용이 guest의 CPU 시간으로 귀속될 수 있다.

[Android 공식 goldfish_pipe 소스](https://android.googlesource.com/kernel/common/+/1855aaccd74c/drivers/platform/goldfish/goldfish_pipe.c#243)는 guest와 QEMU 사이 통신 드라이버이며, 공유 command buffer를 채운 뒤 `writel(pipe->id, pipe->dev->base + PIPE_REG_CMD)`로 I/O 레지스터에 명령을 전달한다. 이 소스는 역할을 확인하는 공식 참조이며 설치된 모듈의 정확한 빌드 소스와 일치한다고 검증한 것은 아니다. 스택에서 관측된 `QemuPipeStream` → read/write → `goldfish_pipe_read_write` → `writel`은 이 역할과 일치한다.

이 커널 드라이버 비용은 **에뮬레이터 경로**다. 실제 Android 기기의 GPU 드라이버 비용이나 FPS로 일반화할 수 없다.

## 공식 심볼로 호출부 확인

공식 [Android release 심볼 ZIP](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_native_debug_symbols.4.7.2.stable.template_release.android.zip) 중 arm64 항목만 HTTP Range로 내려받았다(압축 192,275,926바이트). 심볼 ELF는 `/tmp/rn-libgodot_android-symbols.so`에 두었다. 앱의 merged release ELF와 심볼 ELF Build ID가 모두 `270121fef88100c19643517c328b5868e01d345c`로 동일하다.

핵심 스택은 다음과 같이 해석되었다.

```
Main::iteration (0x125a4a4)
SceneTree::process (0x23bf064)
CallQueue::flush (0x3fa68b8)
CanvasItem::_redraw_callback (0x233beb0)
GDScriptFunction::call (0x15a6884, 0x15a71b0)
RendererCanvasCull::canvas_item_add_ellipse (0x3210cd8)
RendererCanvasRenderRD::request_polygon (0x348dd48)
RenderingDevice::vertex_buffer_create (0x324256c)
RenderingDeviceDriverVulkan::buffer_create (0x2156074)
vmaCreateBuffer (0x217f7b4)
gfxstream vkCreateBuffer → QemuPipeStream → goldfish_pipe_read_write → writel
```

따라서 관측된 큰 버퍼 생성 경로 중 하나는 **Godot CanvasItem 2D 원/타원 다시 그리기**다. 이 스택을 화염 3D 입자 compute의 버퍼 생성이라고 해석하면 안 된다. `godot-symbol-map.json`에 556개 주소의 함수/소스 위치를 보존했고, `*-children-symbolized.txt`에 전체 해석 스택을 저장했다. 원래 주소 보고서도 남겼다.

14.47%와 2.63%는 호출 횟수가 아닌 자식 포함 CPU 샘플 비중이다. 환산 약 4.9배도 해당 캡처 10초 동안의 CPU 시간 비율이며, 버퍼 생성 횟수가 4.9배라는 뜻이 아니다.
