# 포탄 폭발 — 두 시점의 실제 3D 렌더

> 역사 기록: 2026-09-13 ThreeJS 실행 경로를 제거했다. `main.dart`는 `main.dart.txt`로 보존하며 아래 실행 명령은 현재 사용할 수 없다. 현행 검수는 저장소의 `docs/stage1_3d_preview.md`를 따른다.

2026-09-11. 기준은 `../shell_concepts/04-fragmentation-with-fire.png`이다. 이전 화염구를 짧은 중심 화염·방사형 먼지·어두운 금속 파편의 포탄 폭발로 교체했다.

## 이전 웹 확인 화면 — 새 검수에 사용하지 않음

현재 검수는 [별도 설치용 3D 다중 사격 APK](../barrage_runtime/README.md)로 진행한다. 아래 웹 화면·명령·캡처는 과거 기록이다.

`http://127.0.0.1:53013/`

- 2.5D 고정 시점 / 드론 시점 전환
- 재생·정지·다시 폭발, 0–1.1초 시간 탐색, 확대
- 실제 `Stage1Scene`의 전장 GLB·대포·광원·착탄 재질을 그대로 사용하는 통제된 검수 상태다. 영상이나 시안 이미지를 화면에 덧씌우지 않는다. 실제 전투 AI·피해 판정을 재생하는 영상과는 구분한다.
- 게임 시험 화면(`53000/?stage1_3d=1`)도 같은 착탄 구현을 사용한다. 기본 전투 카메라는 angled이며 드론 선택 UI는 이 검수 화면에 연결했다.

## 구현

- 하나의 3D 밀도장에서 분출 먼지와 중앙 연기를 32단계로 적분한다. 선택된 분출의 낮은 밀도 틈에서 주황 화염이 짧게 드러나고 0.3초 안에 소멸한다. 후속 피드백에 따라 화염 폭을 20% 넓히고 길이 감쇠 구간을 조금 연장했으며, 바깥 아홉 연기 분출은 길이를 15% 줄였다. 추가 피드백에서는 화염 폭·길이를 그 상태에서 다시 10% 키웠다. 연기는 주기적인 구형 마디 없이 말단 폭이 점점 가늘어지며, 끝에 노이즈 침식을 적용한다. 바깥 연기는 0.18–0.68초에 넓어진 난류 변위로 흩어진다. 명암 노이즈 계산 뒤에 바깥 밀도를 줄여 후기 덩어리가 다시 진해지지 않게 한다. 파편 탄도·수명은 유지했다. 전체 표시는 1.1초다.
- 시간별 밀도·발광·열도는 48³×32시점 RGBA8(13.5MiB) 3D 캐시를 모든 폭발·풀에서 공유한다. 밀도는 RG 16비트, 발광은 B, 열도는 A이며 CPU 생성 원본·검증은 `../field_cache/`에 둔다. 전장 준비 중 업로드하고 종료 때 해제한다. 난류와 분출 수식은 매 프레임 실행하지 않으며 자체 그림자는 캐시의 밀도를 현재 광원 방향에서 조회한다. 작은 초기 섬광은 수식으로 유지한다.
- 실제 입체 금속 파편 34개와 불티 56개가 탄도·공기 저항·회전·수명에 따라 움직인다. 착탄 Sprite·PNG·아틀라스는 없다.
- 광선은 직교/원근 카메라를 구분하고 3D 경계·지면을 따른다. 현재 실제 화면 검증은 angled/drone 직교 카메라 두 종류다.
- 밝은 연기가 화염을 가리던 밀도·그을음 명암과, 렌더러의 `emissiveIntensity=0` 적용 누락으로 파편이 살구색으로 보이던 문제를 보정했다. 파편 emissive 색을 검정으로 설정해 해당 패키지 동작에 의존하지 않는다.

## 검증 및 산출물

- `flutter analyze` 통과.
- `stage1_weapon_effects_test.dart`, `stage1_scene_projection_test.dart`, `impact_effect_component_test.dart`: 관련 7개 테스트 통과. 표시 수명·회수/반경 재사용, 드론 광선 방향, 카메라 전환 경계 갱신·투영/입력 역변환, 동시 착탄의 체적 캐시 공유와 정확한 시간 경계를 확인했다.
- 캐시 연결의 시각 검수용 빌드와 Android arm64 프로파일 APK 빌드 통과. 현재 버전은 웹 성능을 측정하지 않는다.
- Chrome 실제 GPU 렌더: 두 시점의 초기 폭발과 이후 먼지 확인, JavaScript·GPU 셰이더·HTTP 오류 없음(`browser-check.json`). 네이티브 실기기 성능 검증은 포함하지 않는다.
- `angled-0.12.png`, `drone-0.12.png`: 현재 실제 렌더 화면. `angled-0.55.png`: 화염 이후 먼지.
- `shell-field-cache-v5.mp4` (현재), `shell-two-views.mp4` (동일 내용): 동일 검수 화면을 재생하면서 버튼으로 드론 시점으로 전환한 실제 화면 녹화. 상세 프레임 수와 시간은 `playback-check.json`에 기록한다.

## 이전 구현의 성능 기록 — 모바일 수용 기준 아님

아래 수치는 시간별 field 캐시 적용 전, 난류 입력만 캐시하던 버전의 기록이다. 같은 Chrome headless·800×1000 뷰포트에서 녹화 없이 4.5초 준비 후 상태별 3초간 requestAnimationFrame 간격을 측정했다. 폭발 없는 상태는 전후 약 60fps, 초기 폭발은 약 27→46fps, 후기 연기는 약 27→47fps였다. 초기 폭발의 프레임 간격 95백분위는 50.1→33.4ms로 줄었다. 60fps 고정이나 네이티브 실기기 GPU 성능을 보장하는 값은 아니다. `performance-before-optimization.json`, `performance-check.json`, `performance.cjs`에 조건과 원자료를 남겼다.

## 이전 웹 재현 명령 — 역사 기록

```sh
scripts/in_app_server_macos.sh flutter build web --target=design/stage1_3d/cannon_impact/shell_runtime/main.dart --output=build/shell-review --pwa-strategy=none --no-tree-shake-icons
python3 scripts/no_cache_static_server.py --port 53013 --host 127.0.0.1 --directory build/shell-review
```

`capture.cjs`는 정지 상태의 두 카메라와 후기 먼지를 캡처한다. `record.cjs` → `encode.swift` → `verify_video.swift`는 재생·시점 전환 화면의 H.264 기록과 디코딩 확인에 사용한다. 브라우저 녹화 성능 수치는 네이티브 기기 벤치마크가 아니다.
