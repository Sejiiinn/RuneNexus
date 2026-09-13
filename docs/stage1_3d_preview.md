# 스테이지 1 3D 전장

역할: Android 본게임 스테이지 1 Godot 연결과 공용 검수 경로의 실행·구조·검증 범위. 갱신: 2026-09-13. 배포는 별도다.

## 본게임 진입과 공용 런타임

Android 본게임은 기존 `lib/main.dart → RuneNexusApp → GameHud` 진입을 유지하며 **스테이지 1에서 Godot 전장을 기본 사용**한다. 카메라 버튼은 실제 전장이 준비된 뒤 기존 전투 HUD에 나타난다. 다른 스테이지와 Android 이외 플랫폼은 기존 전장을 사용한다. 로그인·스테이지 선택·웨이브·건설·보상·저장 흐름은 기존 게임이 담당한다.

본게임과 [별도 Godot 검수 앱](../design/stage1_3d/godot_preview/README.md)은 `godot/`의 카메라·지형·모델·효과와 공통 프레임 직렬화를 공유한다. 검수 앱의 대포 6문·정지 표적 3기 배치는 검수 앱에만 있다. 본게임은 실제 선택한 스테이지와 포탑·적 상태를 전달하며 시험 배치를 만들지 않는다. 검수 앱은 별도 패키지와 메모리 저장소를 유지한다.

`GameHud` 아래의 `GodotBattlefieldView`가 Flutter/Flame의 `BattlefieldFrame`을 전달한다. Godot은 모델과 함께 `labels`(내구도·상태·코어 쿨다운), `selection`(범위·선택·보상 대상), `effects`(피해/획득 수치·보조 전투 효과)를 현재 카메라로 표시한다. Flutter는 반환된 같은 투영을 건설·선택 입력과 보상 패널 위치에 사용한다. 세 묶음은 실제 적용 응답을 받은 경우에만 대응하는 Flame 그림을 생략하며, 지원되지 않거나 철회된 묶음은 기존 그림을 유지한다. 고정↔드론 버튼은 전장 중심을 바라보는 0.7초 cubic ease-out 전환이며, 연속 입력은 현재 위치에서 이어진다. 전투 정지·배속과 독립적으로 움직인다. 포탑 레벨은 기존 Flutter 배지 그림을 재사용해 Godot이 고정 받침의 하단에 화면 정면으로 그린다. 렌더 직전 카메라로 위치를 갱신하여 시점 전환 중에도 포탑과 같은 프레임에 움직인다. Godot이 레벨 표시 기능을 알린 경우에만 Flutter의 중복 배지를 숨기며, 실패·화면 종료 시 기존 표시로 복귀한다. [배지 원본·재생성](../design/stage1_3d/turret_level_labels/README.md).

표시 계약 버전 2의 `sceneEpoch`·`viewportRevision`·크기·적용 sequence로 지연 응답과 이전 화면의 투영을 거절한다. viewport 크기는 Godot JSON 소수 반올림 오차 `1e-6` 미만만 허용한다. 짧은 효과는 생성 시 등록하고 최신 age를 유지하는 최대 256개 큐로 전달한다. 종료 효과는 적용 sequence 확인 또는 최대 2초 뒤 제거하며, 전투 판정이나 보상을 다시 실행하지 않는다. 코어 파괴 흔들림은 Godot world 변환으로 이관하고 라벨·선택도 같은 변환을 따른다. Flutter HUD·화면 피격 경고·전투/저장 로직은 유지한다. [현행 책임·구현과 남은 검증](godot_presentation_migration_plan.md)을 참고한다.

엔진은 전장을 처음 붙일 때 초기화하고, 화면 이탈·백그라운드에서는 정지하며 재진입 시 재사용한다. 장면 초기화 요청은 최신 프레임에 덮이지 않고 먼저 처리된다. 렌더러 초기화·실행 오류 시 투영을 해제해 기존 2D 전장과 입력으로 복귀한다.

## Android 빌드와 검수

일반 Android Gradle `preBuild`에서 `scripts/build_godot_pack.py`를 실행해 `godot/`와 기존 3D 에셋으로 `build/godot/android-assets/rune_nexus.pck`를 만든다. 입력 해시가 같으면 기존 팩을 재사용한다. Godot 공식 **4.7.2** 실행 파일이 필요하며 `GODOT_EXECUTABLE` 또는 PATH의 `godot`/`godot4`를 사용한다. 기존 macOS 검수 도구 경로도 인식한다. APK 배포 workflow는 체크섬을 확인한 같은 버전의 Linux 실행 파일을 준비한다.

2026-09-13 ThreeJS·`flutter_angle` 의존성과 전용 SDK 도구 설치를 제거했다. Android SDK·NDK는 Flutter Gradle 설정을 따르며 Godot 실행 파일·AAR·PCK 준비는 유지한다.

```sh
GODOT_EXECUTABLE=/path/to/Godot python3 scripts/build_godot_pack.py
WORK_DIR="$PWD" scripts/in_app_server_macos.sh flutter build apk --release --no-tree-shake-icons
```

로그인·저장 동작이 있는 본게임 검수는 실제 앱 진입에서 수행한다. 영상·성능 검수는 Android APK로 진행하며 웹 렌더·브라우저 검수를 사용하지 않는다. 디버그 패널이 필요한 로컬 검수에만 `RUNE_NEXUS_DEBUG_PANEL=true`를 추가하며 일반 빌드·배포에서는 사용하지 않는다. 빌드 성공은 배포 승인을 의미하지 않는다.

이전 `?stage1_3d=1` 분기와 ThreeJS 검수 앱은 제거했다. 해당 URL도 일반 앱으로 진입한다. 과거 렌더러·테스트 소스는 [보관 기록](../design/legacy_threejs/README.md)의 실행되지 않는 텍스트로 보존한다. Android 스테이지 1 Godot과 다른 플랫폼·스테이지의 Flame 2D 경로는 유지한다.

## 구현과 시각 기준

재질 제작·이관은 [내장 재질 우선 설계](stage1_native_material_workflow.md)를 따른다. 2026-09-13 코어를 화면 굴절 없는 StandardMaterial3D와 공용 환경 반사로 전환했으나, **사용자가 유리 표현 불일치로 거절한 실험 결과**다. 현재 코드에 남아 있는 구현 사실이며 승인 시안이나 시각 이관 완료를 뜻하지 않는다. [당시 적용 기록](../design/stage1_3d/native_material_workflow/verification/native-reflection-20260913/README.md)과 구분한다.

현재 스테이지 1은 [표면·조명·효과 설계](stage1_surface_effects.md)를 따른다. 상면 색·노멀·형태를 보존하고 측면 UV를 복구했으며 전체맵 ORM에 cavity·실제 지형의 근거리 차폐·소재별 거칠기를 연결했다. 밝은 윗면을 유지하면서 주광 방향과 환경광·보조광을 조절해 측면과 접촉 그림자를 분리한다. 대포·기관총 체적 효과는 실제 장면 깊이와 HUD 카메라 오프셋을 반영한다. [제작·실제 검수 기록](../design/stage1_3d/surface_effects/README.md)을 따른다.


- 기존 Flame 전투 갱신·피해 계산·웨이브·Flutter HUD를 유지한다. Godot은 기존 Blender GLB의 포탑 6종·스테이지 1 적 6종과 지형·탄환·건설 미리보기·입체 착탄을 표시한다. 아래 재질·효과 설명에는 제작 기준과 이전 ThreeJS 검수 기록이 포함된다. Godot의 방향광·환경광은 이전 ThreeJS 면광원/AgX와 픽셀 단위로 같지 않다.
- `BattlefieldFrame`은 타일 단위 위치와 조준·피격·상태를 전달하고 `BattlefieldProjection`은 Flutter 타일 입력과 보상 패널을 실제 Godot 직교 투영에 맞춘다. Godot 라벨·선택·효과는 현재 네이티브 카메라를 직접 사용한다.
- 포탑·적·탄환·건설 미리보기는 3D로 표시한다. 체력·장갑·보호막·피해 숫자와 상태 효과는 기존 의미·색·공용 원본을 보존하는 Godot 표시 모듈로 이관했다. Flame 그림은 미지원·오류 복귀용으로 유지한다.
- Godot 기관총·대포는 실제 비행 원점과 발사 순번으로 총구에 연결된 탄체·입체 예광을 표시한다. 한 프레임 안에 명중한 탄환도 종료 경로를 140ms 동안 보존해 보이도록 하며, 전투 판정과 저장 데이터는 유지한다. [투사체 가독성 기준](../design/stage1_3d/projectile_visibility/README.md)을 따른다.
- 스테이지 1 지형은 승인된 Blender 원본의 흙기단·석판·외곽 바위·이끼·풀·뿌리를 재질별 7메시로 병합한 전체 환경을 사용한다. GLB의 맵 크기·타일 배열과 실제 맵이 일치할 때만 적용하며, 다른 맵은 기존 단위 타일을 사용한다. 전체 환경의 길·건설칸은 원본 UV·월드 위치·이끼 변화를 평가한 스테이지 전용 2048² atlas를 사용하여 같은 무늬의 반복을 피한다. 기관총은 현행 2D 본체·탄창의 입체화, 대포는 채도를 낮춘 주황 무광, 냉각은 비대칭 얼음 결정이 기준이다.
- 포탈·코어는 A안의 독립 `environment/landmarks.glb`를 사용한다. 지면·식생 없이 타일 중심에 배치하고 메시·재질을 공유한다. 보라 소용돌이는 오목한 메시의 불투명 공유 셰이더, 코어는 받침을 고정한 채 길쭉한 청록 결정만 부유·회전한다. 내부의 별도 불투명 물체 없이 승인한 Blender 형태와 재질 값을 사용하는 단일 청록 크리스탈에 공용 환경 반사·광원 하이라이트를 적용한다. 화면 굴절·알파 혼합은 사용하지 않는다. 파란 테두리나 모서리 전용 발광은 사용하지 않는다. 128px 공용 하늘 반사를 사용하고 석재·금속도 같은 환경을 수신한다. 코어 전용 반사 프로브는 제거했다. 전투 정지·배속을 따른다. [원본·규격·검수](../design/stage1_3d/portal_core_concepts/README.md)를 따른다.
- 기본 전장은 비스듬한 직교 시점과 전장 전체 맞춤을 사용한다. `Stage1CameraView.drone`은 같은 3D 전장을 위에서 내려다보며, 시점 변경 때 경계·맞춤 배율과 입력 투영을 함께 갱신한다. 원본 위치·면적의 RectAreaLight 세 개로 위치별 석재 반사를 계산한다. PMREM은 낮은 하늘 반사에만 쓰며, AgX 중간 명도 대비와 지형 그림자를 함께 적용한다. 복제된 실제 인스턴스에 명암 처리와 면광원 방향 행렬 보정을 연결한다. Blender 시안과 웹 렌더러의 광원 계산은 동일하지 않다.
- Android Godot 기관총은 실제 발사 시퀀스마다 좌우 포구를 교대하며 Blender 입체 화염·짧은 체적 연기·불티·반동을 표시한다. 연기와 불티는 발사 위치에 남으며 최근 6발의 슬롯을 재사용한다. [원본·효과 기준](../design/stage1_3d/machinegun_muzzle_3d/README.md)을 따른다. 대포는 더 큰 포구 섬광과 긴 반동 복귀, 작은 포탄과 짧은 궤적을 사용한다. 대포와 기존 ThreeJS 경로의 포구 이미지는 Blender 프레임 렌더와 GIMP 패킹으로 제작한 투명 아틀라스다.
- 포탄 착탄은 제작 단계에서 생성한 시간별 3D 밀도·발광·열도장(48³×32시점, 13.5MiB)을 전장 단위로 공유한다. 초기 화염에 조밀한 시간 표본을 두고 인접 시점을 보간하며, 전장 로딩 중 GPU 업로드를 끝낸다. 카메라에 종속된 완성 이미지가 아니며 광선 적분·조명·미세 기폭 섬광·입체 파편은 현재 시점에서 계산한다.
- 대포 착탄은 캐시된 3D 밀도·발광·열도장을 GPU에서 적분하는 체적 화염과 실제 입체 불티·금속 파편으로 렌더한다. 착탄 이미지나 아틀라스는 로드하지 않는다. 최신 파편탄+부분 화염 시안의 짧은 섬광·주황 화염·방사형 금속 파편·회색 먼지 흐름을 따르며 전체 표시는 1.1초다. 이 방향은 이전의 큰 화염구를 대체한다. 고정 수의 순간 광원이 가까운 석재·적·포탑을 밝히고 화염과 함께 감쇠한다. 피해 판정·탄속·공격 주기는 기존 전투 상태를 따른다.
- 추가 환경 장식은 별도 `environment/dressing.glb`의 풀·고사리와 이끼돌·뿌리를 두 메시로 병합한다. 외곽·타일 틈과 빈 건설칸 내부에 배치하며, 설치 시 중앙 식생만 숨기고 철거 시 다시 표시한다. 가장자리·틈 식생과 이동 경로의 여유는 유지한다. 풀은 공유 정점 셰이더로 최대 0.022타일만 흔들린다. 전투 배속과 독립적이며 추가 텍스처·투명 블렌딩·스킨 애니메이션을 사용하지 않는다. 새 에셋은 Godot PCK에만 포함한다. 원본·성능·검수는 [환경 장식 제작 기록](../design/stage1_3d/environment_dressing/README.md)을 따른다.
- GLB 원본·검수 산출물은 `design/stage1_3d/`, 게임용 자산은 `assets/images/stage1_3d/`에 둔다. 사진 재질 출처는 `design/high_fidelity_battlefield/production/textures/SOURCES.md`를 따른다.
- ThreeJS WebGL2 바인딩과 라이선스는 `design/legacy_threejs/web_bindings/`에 보존하며 웹 배포에 포함하지 않는다. 3D 원본 GLB·효과는 기존 경로에 보존하고 Godot PCK로만 패키징한다.

## 범위와 제약

2026-09-13 표시 통합은 세 묶음의 구현·런타임 연결과 Android 6018의 실제 3D 전장·라벨·선택·대포 6문 표시까지 확인했다. 최종 숫자 글꼴 반영 APK의 확인 범위·자동 검사 총수·APK 크기·캡처는 [표시 이관 검증 기록](../design/stage1_3d/presentation_migration/README.md)에 남긴다. 연결된 기준 실기기가 없어 p95/p99·발열을 포함한 지속 전투 성능은 미검증이다. 아래 2026-09-11 수치는 최초 연결 당시 기록이며 이번 변경의 검사 총수가 아니다.

2026-09-11 일반 `lib/main.dart` release APK를 Android 17 ARM64 에뮬레이터에서 실행해 로비→스테이지 1 진입, 기존 HUD, 기관총·대포의 실제 비용 설치, 건설 위치·범위, 웨이브 진행, 감속 시점 전환, 메인화면에서 이어서 진행, 백그라운드 복귀를 확인했다. [본게임 영상과 검증 기록](../design/stage1_3d/main_runtime/README.md)은 별도 검수 앱의 영상과 구분한다. Flutter 분석과 전체 테스트 758개가 통과했고 11개는 기존 조건에 따라 생략했다. 공용 Godot의 카메라·모델·입력 투영·장면 초기화 검사도 통과했다.

제품 성능과 시각 검수는 모바일 네이티브를 기준으로 하며 APK로 전달한다. 기존 웹 측정과 캡처는 과거 개발 검수 기록이다. 2026-09-13 과거 ThreeJS 경로만 제거했으며 일반 웹 앱의 2D 전장은 유지한다.

모바일 성능 완료 조건은 기준 실기기의 profile/release 빌드에서 실제 전투 4배속·여러 포탑 동시 착탄·지속 전투를 측정하는 것이다. 평균 FPS 외에 프레임 시간 상위 95/99백분위, 순간 지연, 메모리와 발열 후 저하를 함께 확인한다. 목표는 60fps(프레임 예산 약 16.7ms)이며, 지원 하한 기종과 실측 결과는 아직 확정되지 않았다. 현재 밀도·발광·열도 캐시를 공유하지만 폭발별 광선 적분과 투명 중첩 비용은 남아 있으므로 다중 착탄 성능을 통과했다고 간주하지 않는다.

4배속은 생성 주기와 `ImpactEffectComponent` 수명 모두에 같은 시간 배율을 적용한다. 같은 전투 조건에서 평균 동시 개수가 단순히 네 배가 되는 구조는 아니지만, 동시 발사·다중 탄환이 집중되는 순간과 프레임당 전투 처리량은 별도 확인해야 한다.

Godot 표시 범위는 Android 스테이지 1이다. 저장 형식과 전투 수치는 변경하지 않는다. 일반 APK와 검수 APK 모두 공식 Godot AAR·공통 PCK·JNI 보존 규칙을 사용하고 Flutter가 선택한 ABI를 유지한다. 모바일 실기기의 지속 전투·메모리·발열·배포 호환성 검증은 별도로 수행한다.

현행 자동 검증은 Godot 프레임 계약·브리지, 표시 입력의 저장 불변성·타일 클릭 역변환, 기존 카메라와 보상 선택 및 적 표시를 포함한다. 표시 통합은 추가로 세 묶음의 DTO·적용 확인·소수 viewport·수명/리셋, 짧은 효과 큐·단일 tick 생성/종료, Godot 라벨·선택·효과 및 보상 dim의 실제 픽셀 클립을 검사한다. ThreeJS 카메라·발사 효과·수명 테스트는 렌더러와 함께 보관했으며 현재 테스트 대상이 아니다. 최초 연결 검수는 `design/stage1_3d/runtime/`, 그래픽 마감과 대포 발사 영상은 `design/stage1_3d/polish_runtime/`, 기관총 이펙트 가독성 수정은 `design/stage1_3d/machinegun_visibility/`에 기록한다. 원본 전체 환경과 반사광 연결 검수는 `design/stage1_3d/material_match/`, 포탄 폭발의 현재 시안은 `design/stage1_3d/cannon_impact/shell_concepts/04-fragmentation-with-fire.png`이며 두 시점의 실제 렌더 검수는 `design/stage1_3d/cannon_impact/shell_runtime/`에 기록한다. `v2/runtime/`는 교체 전 화염구의 기록이다. Blender 시안과 실제 웹 실행 캡처는 구분한다.

모바일 우선안의 구현과 후속 후보는 [모바일 포탄 폭발 조사](analysis/mobile_cannon_vfx_20260911.md)에 정리한다. 실제 전투의 URL 없는 네이티브 진입점과 1×/4× 재현은 [모바일 프로파일 실행](../design/stage1_3d/mobile_profile/README.md), 캐시 제작 원본·수치 검증은 [체적 캐시 제작](../design/stage1_3d/cannon_impact/field_cache/README.md)을 따른다. 실기기 프레임 측정은 별도로 남아 있다.
