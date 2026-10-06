# 승인 V3 화상 효과의 GPU용 원본

역할: 승인 V3 베이크·공유 처리 계약과 2026-09 제작·검증 역사. 아래 Flutter·APK·측정은 당시 경로이며 현행 실행·성능 판정이 아니다. 현행 책임은 [Godot 전환 상태](../../../../docs/godot_unified_app_roadmap.md)를 따른다. 원시 로그·측정은 로컬 보관하며 새 체크아웃의 검증 근거로 제공하지 않는다. 제거된 캡처·영상은 현재 유효한 화면 근거가 아니다.

`enemy-burn-v3-atlas.blend`는 승인 원본 `../enemy-burn-v3.blend`를 보존하고 별도로 만든 베이크 장면이다. `bake_atlas.py`를 승인 원본이 열린 Blender MCP에서 실행하면 재생성한다.

- `assets/images/stage1_3d/effects/enemy_burn/flame_atlas.png`: 512×512, 4×4, 셀 128px. 원본 `V3 short lived turbulent fire` 체적 재질을 그대로 사용한다. 실제 불꽃 크기 0.22에서 베이크해 체적 광량을 유지한다. 검정 바탕 RGB 가산 합성용이며 알파는 불투명이다.
- 프레임 순서는 왼쪽 위부터 행 우선이다. 원본 4D Noise W를 0.033부터 0.198 간격으로 변화시킨다. Standard 색변환, 원본 노출 -0.6. 셀 여백을 포함해 런타임 쿼드 크기는 원본 불꽃 크기 ×1.25다.
- `attachments.json`: normal/tank/armored는 승인 원본과 동일한 RNG 683 순서와 실제 몸체 BVH를 재현한다. shielded/fast/boss는 원본 적 파일의 실제 몸체 BVH에 같은 규칙과 이어지는 RNG를 적용한다. 전면 핵 재질은 표면 탐색에서 제외한다. 각 52개이며 GPU 인스턴스 입력으로 사용한다.
- anchor는 Blender `(x,y,z)`를 Godot `(x,z,-y)`로 변환했다. 시간 단위는 24fps이다. 원본 수명은 `age=fract((frame-1+phase_frames)/period_frames)`, 밝기/크기 곡선은 `sin(PI*age)^0.65`다.
- Godot 이동은 anchor + `(drift*age+.024*sin(age*7+index), rise*age, -.018*sin(age*5+index))`이다. 가로 크기는 `size*life*(1-.35*age)`, 높이는 `size*life*(1+.55*age)`이며 베이크 여백 배율을 마지막에 곱한다.

검증: 원본 3종 156개의 프레임 1 위치를 비교해 최대 오차 0.0. 아틀라스 16셀을 직접 확인했으며 셀별 바깥 3px 최대 RGB는 1/255로 가장자리 잘림이 없다. 체적 원형을 평면으로 베이크하므로 시점 변화와 입자 겹침의 최종 외형은 Godot에서 별도로 확인한다.


## Godot 연결과 공유 처리

`godot/effects/enemy_burn.gd`와 `enemy_burn.gdshader`를 기존 적의 화상 상태에 연결했다. 단일 공통 재질·아틀라스·입자 초기값 텍스처를 공유하고, 같은 종류의 적은 52개 입자가 들어 있는 불변 MultiMesh를 재사용한다. `shieldBoss`는 `boss` 자료를 공유한다. 적별 노드는 MultiMesh 한 개이며 별도 광원·입자별 노드·CPU 애니메이션을 만들지 않는다.

GPU에서 외부 전투 시간에 따른 상승·흔들림·크기 변화·아틀라스 보간을 계산한다. CPU는 공통 시간 uniform을 프레임당 한 번 전달하고 화상 시작·종료 시 표시만 전환한다. 원본 몸체·핵 재질을 변경하지 않으며 냉각과 병행한다. 기존 Godot 라벨의 화상 스프라이트는 제거했다. 화상 피해·중첩·지속시간은 기존 전투 판정을 따른다.

## 확인 범위

- Godot 비교 이미지 (당시 자료 `godot-v3-comparison.png`, 현재 미제공)를 [승인 V3 대표 이미지](../burn-v3-preview.png)와 직접 비교했다. 어깨·옆면 주변의 짧고 분리된 불길, 위로 흩어지는 작은 불꽃, 노란 중심과 주황 가장자리, 전면 핵의 가독성을 유지한다. Godot의 일부 불꽃 중심은 더 밝고 경계가 선명하며 배경·조명도 다르므로 픽셀 단위 복제는 아니다.
- `verify_enemy_burn.gd`, `verify_enemy_frost.gd`, `verify_battlefield_labels.gd`, `verify_shared_textures.gd` headless 검사 모두 0 failures. 화상 검사는 원본 재질 보존, 7종 공유 자료, 냉각 병행, 전투 시계와 정적 입자 버퍼, 만료·재적용·제거·초기화를 포함한다. shader 컴파일 오류도 수정 후 없는 것을 확인했다. 결과 (당시 로컬 기록 `headless-verification.json`).
- macOS arm64 Godot 4.7.2 headless에서 화상 적 300개의 유지 상태 `apply`와 공통 `set_time` 1회를 측정했다. 워밍업 120회 후 1,000회 평균 **0.043834ms**, p95 **0.048ms**다. 측정값 (당시 로컬 기록 `cpu-measurement.json`), 재현 스크립트 (당시 로컬 기록 `measure_cpu.gd`).
- 위 수치는 CPU 호출 구간만 측정한다. 초기 생성·모델 변환·렌더 제출·투명 픽셀·Flutter 전달·전체 프레임 비용은 포함하지 않는다. GPU 처리에도 그리기와 투명 겹침 비용은 남으며, GPU 비용이 없다는 의미가 아니다. **실기기 Android GPU 시간과 지속 성능은 미측정**이다.
- Android 17 ARM64 에뮬레이터에서 일반 `lib/main.dart` release APK를 설치해 로비 → 이어서 진행 → 실제 9/10라운드 전투를 확인했다. 고정 시점 (당시 자료 `android-burning.png`, 현재 미제공), 드론 시점 (당시 자료 `android-drone.png`, 현재 미제공), 본게임 녹화 (당시 자료 `android-burn.mp4`, 현재 미제공). 이동 적에게 불꽃이 붙고 핵·체력바가 유지되며, 캡처 로그에 화상 shader 오류가 없다. 개발용 테스트 패널로 탱커 3개를 추가한 조건이다. 실기기 성능 검증을 뜻하지 않는다.
- 동일 ARM64 검증 APK 대비 230,196바이트(+0.103%) 증가했고 전부 Godot 팩 증가분이다. 팩 중복 데이터와 `.blend`/`design` 포함은 없다. APK 비교 (당시 로컬 기록 `android-after.json`), 팩 감사 (당시 로컬 기록 `android-pack-audit.json`). 공개 배포는 하지 않았다.
- Godot GPU 렌더 영상 (당시 자료 `godot-burn.mp4`, 현재 미제공)은 원본과 비교하기 위한 별도 스튜디오 장면이다. 실제 Android 전투 영상과 구분한다.

패키징 회귀검사 `python3 scripts/test_prepare_godot_project.py`도 통과했다. 화상 아틀라스·부착 데이터의 바이트 보존, 재준비 시 교체 및 무손실/no-mipmap import 설정을 확인한다.

## 전투 영상 끊김 후속 확인

사용자가 지적한 Android 영상은 실제 평균7.91fps였다. 녹화 없는 동일 APK·화염포탑6·고정탱커3·4배속에서 화상 표시만 on/off/off/on으로 교대했다. 실제 화상 적은2개이며 Godot 원시간격 집계는 on8.86fps / off9.10fps, Flutter raster 평균은94.24 / 94.88ms다. 구간간 변동이 커 화상의 독립 비용을 확정할 수 없지만, 화상 표시를 꺼도 심한 끊김이 남았다. 기존0.044ms CPU 호출 측정은 이 전투 프레임 비용을 대변하지 않는다. 당시 전투 전체 성능 문제가 해결됐다고 판정하지 않았다.

영상 분석 (당시 로컬 기록 `performance/video-analysis.md`), 녹화 없는 A/B 결과 (당시 로컬 기록 `performance/burn-ab-analysis.md`), 재현 진입점 (당시 자료 `../../../../../tool/godot_performance/burn_compare.dart`, 현재 미제공). 진단 옵션 `burn_effects`는 기본true이며 전투 판정이 아닌 화상 표시만 바꾼다. 검증 뒤 메모리 저장용 진단 APK를 제거하는 대신 일반 본게임 APK로 덮어 복구했으며 기존 저장 데이터는 그대로 보존했다. GPU 타이밍은 미지원이고 실기기 결과는 아니다.

## 화염 포탑 추가 후 끊김 조사

분석 보고서 (당시 로컬 기록 `performance/turret-lag-diagnosis.md`)에 적 화상·포탑 입자·효과 전체·본체 가시성 비교와 Android 스레드 추적 결과를 정리했다. 화염 포탑의 큰 원본 메시와 수동 입자 계산 비용은 확인했지만, 이를 제외해도 전체 프레임이 일관되게 회복되지 않아 단일 원인은 확정하지 않았다. 에뮬레이터 결과이며 실기기 성능을 보증하지 않는다. 진단용 옵션은 기본값에서 기존 동작을 유지한다.

후속 함수 추적 (당시 로컬 기록 `performance/render-path-followup.md`): 화염 포탑 최초 생성 전후와 제거 후를 비교해 FPS 저하·회복을 재현했다. 에뮬레이터 그래픽 pipe 및 Vulkan 버퍼 생성 경로를 확인했으며, 실기기 결과와 구분한다.

후속 최종 판정: 2D 화염 명중 효과의 원·타원 재그리기가 Vulkan 정점 버퍼 생성으로 이어지는 병목을 확인했다. 해당 표현만 생략한 반복 비교에서 Godot FPS가 회복됐다. 외형 변경은 채택하지 않았고 Flutter 잔여 지연·실기기는 별도 확인 대상이다.
