# 화염 포탑 추가와 렌더 스레드 후속 조사 — 2026-09-14

## 최종 판정

**화염 명중 시 남아 있는 2D 효과의 도형 재생성이 확인된 Godot 병목이다.** 포탑 본체·3D 불꽃·발사체는 그대로 두고 2D `impact/flame` 그리기만 생략하자 두 번 모두 Godot FPS가 회복됐다. 공식 심볼로도 `CanvasItem::_redraw_callback → canvas_item_add_ellipse → request_polygon → vertex_buffer_create` 경로를 확인했다. GPU 입자 계산 자체가 이 스택의 원인은 아니다.

두 번째 실행: 전체 13.72 → 2D 화염 명중만 제외 34.67 → 전체 10.47 → 피해 표시만 제외 12.69 → 전체 12.38 FPS. 첫 실행도 명중 제외 구간 25.32 FPS로 회복했다. 3D 효과만 숨긴 이전 실험에서 이 2D 효과는 그대로 남았으므로 그 비교로 원인을 배제할 수 없었다.

단, **전체 앱 문제 해결은 확인하지 않았다.** 두 번째 명중 제외 구간에서도 Flutter raster 평균은 116.07ms였다(인접 전체 구간 91.10/93.77ms). Godot FPS 회복이 Flutter 프레임 또는 전투 업데이트 빈도의 회복과 동일하지 않다. 에뮬레이터의 공통 그래픽 전달 비용은 여전히 크며 실기기는 미측정이다.

## 포탑 생성 전후 비교

화염 포탑을 처음부터 생성하지 않은 대포 전투 → 화염 포탑 전투 → 다시 대포 전투로 같은 앱 안에서 바꾸자 프레임 저하와 회복이 재현됐다. 단순히 포탑을 숨겼던 이전 실험보다 추가 시점과의 연관성을 직접 확인하는 결과다. 신규 적 화상 효과는 전 구간 껐다.

| 조건 | Godot FPS 표본 평균 | Flutter raster 평균 | 그리기 호출 평균 | primitive 평균 |
| --- | ---: | ---: | ---: | ---: |
| 화염 생성 전 대포 | 31.44 | 64.39ms | 107.0 | 186,717 |
| 화염 포탑 | 13.14 | 93.61ms | 268.1 | 422,970 |
| 화염 제거 후 대포 | 32.03 | 47.40ms | 106.0 | 186,822 |

환경: Android 17 ARM64 에뮬레이터, Godot Vulkan Mobile, Flutter Impeller OpenGLES. 포탑 6개·고정 탱커 3개·4배속, release, 녹화 없음. 각 구간 준비 3초 후 12개 고유 sequence의 일반 FPS 표본을 수집했다. 표의 FPS는 표본 산술평균이며 raw frame interval pooled FPS가 아니다. Flame 게임 update 평균은 대포 0.38ms / 화염 1.13ms / 복귀 대포 0.33ms였다. 표시된 두 엔진의 시간은 측정 범위가 달라 합산하지 않는다.

첫 실행의 함수 샘플링은 화염 측정이 끝난 별도 35초 유지 구간에서만 했다. 따라서 위 표에는 샘플링 자체의 부하를 섞지 않았다. [측정 JSON](creation-probe-analysis.json), [레코드](creation-probe-records.json), [harness](../../../../../../tool/godot_performance/turret_compare.dart).

## CPU 시간이 잡히는 위치

후속 커널 포함 simpleperf 샘플에서 `goldfish_pipe.ko → writel`이 대포와 화염 양쪽 모두 약 56%를 차지했다. 이는 Android 에뮬레이터의 guest→host pipe 명령을 MMIO로 전달하는 경로다. `goldfish_pipe_read_write`, `qemu_pipe_read/write`, Vulkan 및 OpenGL 인코더 호출이 스택에 함께 나타난다. 따라서 이전 추적의 높은 vCPU 실행 시간을 게임 로직이나 불꽃 CPU 계산량으로 해석하면 안 된다. MMIO를 처리하는 가상화·호스트 작업 시간도 guest CPU의 해당 위치에 잡힐 수 있다.

이 경로가 대포에서도 크다는 점이 중요하다. “화염만의 함수 하나가 CPU를 56% 쓴다”는 의미가 아니다. 화염에서 렌더 호출은 약 2.5배, primitive는 약 2.3배가 됐고 FPS가 31→13으로 떨어졌다. **화염 표시의 늘어난 작업과 에뮬레이터 그래픽 전달 비용이 함께 나타난다.** 개별 메시/입자/드라이버 비용의 기여율까지 이번 표로 분해할 수는 없다.

사용자 공간만 샘플링했을 때는 커널 시간이 빠졌다. 그래서 추가로 커널 포함 대포/화염 10초씩을 수집했다. 두 번째 실행의 대포 구간은 샘플링과 겹치므로 첫 실행의 성능 표와 혼합하지 않는다. [함수 스택과 세부 근거](stack/README.md).

## 화염에서 증가한 호출 경로

커널 포함 비교에서 `vkCreateBuffer` 자식 포함 비중은 대포 2.63% → 화염 14.47%였다. 샘플 이벤트 시간으로 환산하면 10초 구간당 약 0.627초 → 3.091초, 약 4.9배다. 이는 CPU 귀속 시간 비교이며 버퍼 생성 횟수가 4.9배라는 뜻은 아니다. 실제 처리 프레임 수도 서로 다르다. 반면 fence 상태 조회·대기 경로의 비중은 감소했다. **화염에서 Vulkan 버퍼 생성과 호스트 전달 경로의 비용이 늘어난 것이 구체적인 차이**다. 버퍼 생성은 게임의 명시적 메모리 생성뿐 아니라 엔진 내부 전송용 버퍼 준비 등에서도 발생할 수 있다. 호출 경로별 비용은 중첩되므로 합산하지 않는다.

## 공식 심볼로 확인한 생성 주체

Godot 공식 release arm64 심볼의 Build ID `270121fef88100c19643517c328b5868e01d345c`가 앱 라이브러리와 일치했다. 주소를 해석한 큰 호출 경로는 다음과 같다.

`SceneTree::process → CallQueue::flush → CanvasItem::_redraw_callback → GDScriptFunction::call → RendererCanvasCull::canvas_item_add_ellipse → RendererCanvasRenderRD::request_polygon → RenderingDevice::vertex_buffer_create → Vulkan buffer_create → vmaCreateBuffer`

즉 여기서 관측한 버퍼 생성은 **2D 원/타원 도형의 재그리기**다. GPUParticles compute로 단정했던 후보와 구분한다. `godot/ui/battlefield_effects.gd`는 효과별로 매 입력 프레임 `queue_redraw()`를 호출하고, 화염 명중 표현은 타원 3개와 원 5개를 그린다. 화염 공격의 기존 `_showImpact`가 이 `flame` 스타일을 생성한다. 포탑 3D 불꽃과 신규 적 화상 효과 이외에 이 2D 명중 표현이 별도로 남아 있다. 피해 숫자의 약점 강조에도 원이 있으므로 둘을 따로 끄는 추가 진단을 수행했다.

## 2D 효과별 검증

모든 구간 화염 포탑 6개·적 3개·4배속·3D 불꽃과 발사체 유지·적 화상 효과 비활성·Godot timestamp 계측 비활성이다. 효과별 생략은 그리기만 건너뛰며 명중·피해·화상 판정 및 타이밍은 변경하지 않았다. 각 구간 3초 준비 후 8개 고유 sequence를 수집했다. 첫 실행의 초기 Flutter 변동이 커 같은 APK를 한 번 재시작하여 반복했다. 샘플링과 녹화는 하지 않았다.

| 두 번째 실행 구간 | Godot FPS 표본 평균 | Flutter raster 평균 ms | draw calls 평균 |
| --- | ---: | ---: | ---: |
| 전체 1 | 13.72 | 91.10 | 229.1 |
| 2D 화염 명중 제외 | 34.67 | 116.07 | 178.2 |
| 전체 2 | 10.47 | 93.77 | 237.5 |
| 피해 표시 제외 | 12.69 | 94.74 | 218.1 |
| 전체 3 | 12.38 | 93.14 | 247.0 |

[두 번째 실행](canvas-probe-analysis.json), [첫 실행](canvas-probe-analysis-first.json), [재현 집계](analyze_canvas_probe.py).

## 수정 대상으로 좁힌 부분

`godot/ui/battlefield_effects.gd`의 `apply_frame`은 각 효과에 매번 `queue_redraw()`를 요청한다. `_impact`의 `flame`은 3개 타원과 5개 원을 매번 다시 그린다. 이때 Godot Canvas가 폴리곤 정점 버퍼를 생성하고 에뮬레이터 드라이버의 호스트 통신 비용이 발생한다. GPU 입자 방식으로 만든 포탑 불꽃과 별도로 남아 있던 경로다.

후속 수정 후보는 **승인 외형을 보존하면서 명중 효과의 도형/그리기 자원을 재사용하는 것**이다. 이번에는 원인 확인 요청에 맞춰 실제 효과 교체를 채택하지 않았다. 특정 커스텀 셰이더나 엔진 변경이 필수라는 결론도 아니다. 잔여 Flutter 지연과 실기기 성능은 따로 검증해야 한다.

진단 완료 후 일반 release APK와 빌드 출력 APK를 복원했다. 진단 Dart 분석은 통과했다. adbd root는 원래 shell 권한으로 복구했다.

최종 확인: 진단 Dart analyze 및 Godot battlefield effects 회귀검사 통과. 기본 옵션에서는 기존 표현을 유지한다.
