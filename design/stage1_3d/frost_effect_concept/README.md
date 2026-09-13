# 적 표면 서리 효과 시안

2026-09-14. 처음 Blender 전용으로 제작한 뒤, 사용자의 “최대한 똑같은 느낌으로 게임에 이식” 요청으로 채택한 서리 상태 표현이다. 최초 시안 파일과 렌더는 보존한다.

- 편집 원본: [enemy-frost-concept.blend](enemy-frost-concept.blend)
- 실제 Blender Cycles 렌더: [재질·입체감 시점](frost-hero.png), [높은 전장 방향 시점](frost-high-angle.png). 게임 실행 화면이 아니다.
- 재생성: [build_concept.py](build_concept.py). 기존 [적 원본](../enemies/chapter-one-enemies-refined.blend)의 탱커를 별도 장면에 읽고, 이 폴더에만 저장한다.

금색 장갑과 전면 핵을 남긴 채 표면에 불규칙한 성에를 붙이고, 어깨·등에 짧은 육각 얼음 결정과 작은 성에 알갱이를 배치했다. 서리 껍질은 실제 적 메시를 따르며 전면 핵의 면을 제외한다. 결정은 적 표면에 광선을 쏘아 배치한 실제 3D 기하다. 카메라를 향하는 효과 평면이나 바닥 원형 표시를 사용하지 않는다.

Blender 컬렉션 `01 Original enemy`는 원래 적, `02 Frost coating`은 성에 껍질, `03 Attached ice crystals`는 결정, `04 Studio and cameras`는 검토용 바닥·조명·두 카메라다. 원본 메시와 서리 효과를 분리해 각각 숨기거나 편집할 수 있다. 최초 시안은 정지 상태이며 별도 생성·소멸 애니메이션을 정의하지 않는다.


## 현재 게임 연결 — 공통 효과

사용자의 공통 셰이더·재사용 결정 요청에 따라 첫 종류별 베이크 구현을 교체했다. 원본 적 텍스처를 수정하지 않는다.

- 성에는 `godot/effects/enemy_frost.gdshader` 하나를 원래 몸체 재질의 `next_pass`로 붙인다. 전면 핵 재질은 제외하며 감속이 끝나면 기존 재질로 복귀한다. 공통 Blender 마스크(64³ R8)와 미세 질감 하나를 모든 적이 공유한다. 3D 마스크는 원본 Noise/ramp를 그대로 베이크했고, 미세 질감은 공통 투영과 표면 미분으로 요철을 만든다. [제작·좌표 계약](shared_noise/README.md).
- 얼음 결정은 `crystals.glb`의 `FrostShard`·`FrostGrain` 두 공통 원형이다. 원본 40개 결정의 비틀림·면색은 공통 데이터와 vertex shader로 재현하며, 95개 작은 결정도 하나의 원형을 재사용한다. 적별 데이터는 위치·방향·크기뿐이다. [원본·재생성·오차 검증](shared_crystals/README.md).
- 각 적은 결정용 두 MultiMesh를 사용한다. 서로 다른 적 종류도 같은 원형 메시와 재질을 사용하고, 같은 종류의 부착 MultiMesh 데이터도 공유한다. 성에는 원래 몸체 메시를 다시 사용하므로 별도 서리 껍질 메시를 제작하지 않는다.
- 기존 `enemy[9]`의 감속 여부만 사용한다. 감속 전에는 코팅 패스나 결정 인스턴스를 만들지 않으며, 첫 감속 이후 재적용에 자원을 재사용한다. 전투 수치·중첩·지속시간·저장 계약은 유지한다. Android 스테이지 1~10의 6종과 `shieldBoss→boss`에 적용된다.

공통 자산 생성기는 [bake_shared_noise.py](bake_shared_noise.py), [export_shared_crystals.py](export_shared_crystals.py)다. 독립 Blender background 프로세스에서 실행한다. 편집 원본은 `shared_noise/`, `shared_crystals/`에 보관한다. 게임에는 `assets/images/stage1_3d/effects/enemy_frost/`의 공통 GLB·마스크·질감·부착 데이터만 포함한다.

## 첫 종류별 구현 기록

최초 이식은 [export_runtime.py](export_runtime.py)로 6종별 코팅 텍스처와 결정 GLB를 만들었다. 현재 이 생성기의 출력 경로는 `per_kind_archive/`이며 게임 빌드에 포함하지 않는다. `runtime-{kind}.blend`, `bakes/`, [기존 Android 캡처·감사](runtime/pack-audit.json)는 변경 전 비교 자료다. [baked-tank-preview.png](baked-tank-preview.png)는 Blender 베이크 검토 렌더다.

## 공통 효과 검증

일반 `lib/main.dart` Android ARM64 에뮬레이터 debug APK를 메모리 저장소로 실행했다. [기본 크기·고정 시점](shared_runtime/android-fixed.png), [4배속·드론 시점](shared_runtime/android-drone.png), [탱크 5배 확대](shared_runtime/android-tank-detail.png)를 이전 종류별 구현과 비교했다. 공통 shader의 실제 GPU 비틀림·면색과 부착 배치, 장갑색이 비치는 성에·노출된 핵이 유지되는 것을 확인했다. 공통 미세 질감은 원본의 3D 노이즈와 픽셀 단위로 같지 않으며, 확대 시 성에 경계는 이전 베이크보다 부드럽다. 결정의 면색·거칠기는 유지하며 Cycles 내부 다중 굴절은 이전과 마찬가지로 재현하지 않는다.

2초 감속을 4배속으로 진행해 [만료](shared_runtime/android-expired.png)와 [재적용](shared_runtime/android-reapplied.png)을 실제 앱에서 확인했다. 검수 후 메모리 전투를 종료하고 기존 저장소의 앱 진입으로 복귀했다.

- [서리 검사](shared_runtime/frost-test.log): 원래 몸체 mesh·texture·core 보존, 비감속 적 격리, 6종+shieldBoss의 공통 shader/texture/두 원형 공유, 동종 MultiMesh 재사용, 감속 on/off/reapply·종류 교체·제거·초기화 0 failures.
- [기존 런타임 검사](shared_runtime/runtime-test.log): 모델·카메라·HUD/입력·초기화 0 failures.
- [텍스처 검사](shared_runtime/textures-test.log): 35 GLB, 167 참조→37 공유 이미지, 불투명 PNG 픽셀 보존, 0 failures. 공통 성에의 별도 noise 입력 검증은 제작 기록과 서리 검사에서 확인한다.
- Flutter/Dart·전투 로직은 변경하지 않았다. 실기기 p95/p99·GPU 프레임 시간·발열은 미측정이며 에뮬레이터 확인을 성능 통과로 해석하지 않는다.

## 공통화 용량

실제 APK 내부 PCK는 86,698,680B다. 첫 종류별 구현 92,601,776B에서 5,903,096B 줄었다. 서리 추가 전 86,210,120B를 기준으로 추가 용량은 6,391,656B→488,560B(약 0.47MiB)로 92.36% 감소했다. 공통 서리 payload는 487,547B이며 마스크·부착 JSON·공통 질감·두 결정 원형·코드로 구성된다. 이전 6종 서리 씬과 12개 텍스처는 팩에 남아 있지 않다.

논리/물리 중복은 0B이고 제작 원본·검증 스크립트·raw GLB/PNG 및 Flutter GLB 중복이 없다. [실제 APK 감사](shared_runtime/pack-audit.json), [기여도 표](shared_runtime/pack-audit.md). 이 비율은 용량 감소율이며 FPS 개선율이 아니다. 공개 배포는 수행하지 않았다.
