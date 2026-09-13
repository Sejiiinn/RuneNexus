# 첫 내장 재질 실험 결과

역사 기록: 아래는 첫 실험 당시의 미채택 결과다. 현행은 이후 승인된 [굴절 없는 내장 PBR·환경 반사 적용](../native-reflection-20260913/README.md)을 따른다.

2026-09-13. **실험 결과는 미채택이다. 내장 재질 전환·승인 Blender 표현의 이관을 완료하지 않았다.** 원본 데이터 전달과 후보 재질의 공유·애니메이션 계약은 통과했지만, B는 불투명 면색, C는 받침이 결정 내부의 덩어리처럼 보이는 화면 굴절과 부족한 유리 하이라이트 때문에 시각 기준을 통과하지 못했다. A도 승인 표현을 완전히 재현한 정답으로 판정하지 않았다.

Android 비교판 (`android-comparison.png`, 로컬 자료) · 데스크톱 비교판 (`desktop-comparison.png`, 로컬 자료) · [승인 Blender 기준](../../../portal_core_concepts/verification/transfer-diagnosis/approved-blender-reference.jpg) · 본게임 고정 시점 (`android-main-fixed.png`, 로컬 자료)

## 무엇을 비교했는가

| 항목 | 조건 |
| --- | --- |
| A | 현재 `core_crystal.gdshader`, 현재 원본 연결·화면 깊이 검사 |
| B | `mesh.surface_get_material(0)`의 실제 임포트 StandardMaterial3D. ShaderMaterial override를 원본으로 복사하지 않음 |
| C | B의 얕은 복제에 `refraction_enabled=true`, `refraction_scale=.05`, 엔진 Albedo alpha `.65`만 설정. 원본 Alpha 1·Transmission .80·IOR 1.46은 변경하지 않음 |
| 공통 | 동일 GLB·메시·카메라·배경·조명·FILMIC·128px 단일 UPDATE_ONCE 프로브·결정 전용 보조광. 거칠기 .055·금속성 0·면색·발광 유지 |
| 장면 | 게임 방향 확대, Blender 방향 확대, 고정 전장, 드론 전장, 앞쪽 대포/체적 폭발과 겹친 고정·드론 |
| 위상 | 각 장면에서 전투 시간 0.0 / 1.1초. 받침 고정·결정만 회전/부유. 순차 비교 중 식생 TIME은 검수 복제 shader에서 0으로 고정(배포 shader 변경 없음) |
| 플랫폼 | Mac Metal Mobile 880×760, Android 17/API37 ARM64 에뮬레이터의 실제 release 검수 APK. Android 논리 viewport 880×1171, 물리 캡처 1080×1436 |

각 플랫폼의 36장과 `report.json`을 `desktop/`, `android/`에 보존했다. `conditions-verified.json`은 12개 A/B/C 그룹 각각의 카메라·크기·offset·viewport·결정 transform·표시 입력 해시·삼각형 수 일치를 검사했다. **캡처 성공과 조건 일치는 시각 채택 판정이 아니다.**

최종 GLB SHA-256은 `4570aaed44510b91815f3728d1719bc3abb174d3608f11279b9c1ab302746318`. 크기 (.27104,.84,.27104), 정점 512, 단일 surface·내부 자식 없음이 유지된다. Android 팩에는 GLB 원본 대신 import 산출물이 들어가므로 Android report의 `glb_sha256`은 빈 값이다. 원본 해시는 원본 감사 (`source-audit.json`, 로컬 자료), 팩의 실제 import payload와 APK 내장 팩 동일성은 패키징 감사 (`packaging/after-audit.json`, 로컬 자료)로 확인했다.

## 시각 판정과 원인

- **B 미채택:** 청록 면은 구분되지만 불투명하고 밝은 평면색 인상이 강하다. importer의 표준 재질에는 원본 Transmission/IOR 광학 동작이 연결되지 않는다.
- **C 미채택:** 배경 굴절 자체는 보인다. 그러나 받침의 밝은 판·지지대가 결정 중앙의 흰 띠/내부 덩어리처럼 보이고 승인 렌더의 유리 반사·내부 면 변화가 부족하다. 실제 내부 메시를 추가한 결과가 아니라 화면 배경을 읽는 방식의 결과다. 고정/드론·두 위상·체적 효과 겹침 캡처에서 코어 전체가 사라지는 현상은 보지 못했지만, 그것만으로 광학 표현을 통과시키지 않았다.
- **형태와 시점:** 같은 GLB를 유지했다. Blender 방향 고도 약49.6°와 게임 약62.7°의 실루엣 차이는 기존 카메라 진단 (`../../../portal_core_concepts/verification/transfer-diagnosis/crystal-camera-geometry.json`, 로컬 자료)과 이번 두 방향 이미지로 구분한다. Blender 방향 이미지는 Godot 조명으로 촬영했으며 Blender와 동일한 렌더라는 뜻이 아니다.
- **조명 차이:** Blender는 Cycles·AgX·면광원(좁은 직사각 하이라이트 광원 포함), 게임은 Mobile·FILMIC·방향광·정적 프로브다. 광원 모양·경로 추적 다중 굴절이 GLB에 실리지 않는다. Godot의 [내장 굴절](https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html#refraction)은 화면 공간 효과이며 이를 Cycles와 동등하게 취급할 수 없다.
- **석재·금속:** 동일 캡처에서 받침 노멀, 거친 석판/길의 요철·거칠기 변화, 황동/철 지지대와 무광 주황 대포의 차이가 유지됐다. 별도 소재 변경이 필요한 데이터 누락은 발견하지 못했다.

조정 순서는 원본 연결 확인 → C 내장 설정 적용까지 진행했다. 선형 정점색·생성 tangent·텍스처 채널이 정상이라 원본을 수정하지 않았다. C의 배경 띠를 공용 조명·발광·더 낮은 알파로 숨기는 조정은 하지 않았다. 따라서 공용 조명도 변경하지 않았으며 새 광학 셰이더를 작성하지 않았다. **이 후보 한 번의 미채택은 모든 내장 설정 조합이 불가능하다는 증명이 아니다.** 다음 필요 작업은 광원/반사 환경과 화면 공간 굴절의 수용 한계를 별도로 판단하는 것이다.

## 채택·재사용·검사

공용 런타임은 A를 유지한다. 채택한 새 프리셋은 없으므로 `godot/materials/*.tres`를 만들거나 원본 수치를 이중 관리하지 않았다. 석재·금속은 기존 GLB 임포트 재질을 계속 사용한다. 포탈·식생 바람·입체 포탄 VFX, 전투·저장·카메라 코드는 변경하지 않았다.

보존한 검수 구현은 `godot/verify_scene.gd --native-materials`, `godot/verify_native_materials.gd`, `godot/verify_native_contracts.gd`다. 모두 배포 PCK의 `verify_*` 제외 대상이다. 추가로 만들던 사용자 전환용 검수 UI·빌드 스크립트·APK는 범위 확장 지적 후 제거했다. 기존 설치 검수 앱은 실험 전 v6 APK로 복원했다.

- 공용 `scripts/build_godot_pack.py` 빌드 및 `verify_runtime.gd`: 실패 0. 기존 다중 랜드마크·표시·입력·reset 계약 유지.
- 독립 디렉터리에서 `.godot`·`.import` 캐시 없이 fresh import 후 `verify_native_contracts.gd`: 6,540 checks / 실패 0. 원본 재질 storage 보존·불변, 텍스처 참조 34개 공유, 선형 정점색, 노멀 tangent, ORM 채널, 2코어의 후보 1개 공유와 정지·받침 고정 확인. 결과 (`native-contract-report.json`, 로컬 자료).
- `scripts/prepare_godot_project.py`: `.tres` 삭제 동기화만 추가. 임시 파일 시스템에서 신규·갱신·이름 변경·삭제 및 생성 리소스 보존 검사 통과. 검사 기록 (`packaging/after-audit.md`, 로컬 자료).
- 원본 GLB·기존 런타임·shader 해시와 기존 작업 트리 변경을 `before/`에 보존. 새 dependency·엔진·ABI 정책 변경 없음. Dart 코드 변경이 없어 Flutter 분석·테스트를 확대하지 않음.

재현: `python3 scripts/build_godot_pack.py` 후 공식 Godot 4.7.2로 `--path build/godot/project --script res://verify_scene.gd -- --native-materials`. 후보 계약은 같은 프로젝트에서 `--headless --script res://verify_native_contracts.gd`. Android 자동 캡처는 격리 `build/godot/native-material-experiment` 프로젝트의 진입 스크립트와 별도 PCK를 사용했으며 일반 본게임 팩을 수정하지 않았다.

## APK와 비용

설치용 본게임은 `rune-nexus-native-material-review-arm64.apk` (`../../../../../build/apk-main/rune-nexus-native-material-review-arm64.apk`, 로컬 자료), **234,772,965 B**다. 기존 커스텀 재질을 유지한 일반 `lib/main.dart` release APK이며 실제 versionCode는 6003(빌드 입력4003 + Flutter ARM64 오프셋2000)이다. 기존 앱 versionCode4002보다 높게 빌드해 데이터 삭제 없이 설치했다. 서명·16KB 정렬·내장 PCK 동일성 검사를 통과했다. 공개 배포하지 않았다.

본게임의 공용 PCK **58,453,692 B는 실험 직전과 바이트 단위 동일**하다. 미채택이므로 런타임 material/texture 추가와 shipping payload 증감은 0이다. 일반 APK는 오래된 baseline universal·별도 preview와 앱/ABI 조건이 달라 단순 차이를 재질 비용으로 해석하지 않는다. 상세 바이트·원인은 비용 감사 (`packaging/after-audit.md`, 로컬 자료)에 있다.

자동 A/B/C 캡처 APK `build/apk-preview/rune-nexus-native-material-experiment-arm64.apk`는 230,922,722 B, 같은 v6 preview보다 +82,109 B다. 격리 PCK의 검수 코드·메타데이터 +31,524 B와 재서명 차이이며 게임 에셋 증가는 없다. 이 APK는 자동 검수용이고 일반 본게임과 같은 source runtime을 사용하지만 **동일한 전체 PCK 파일은 아니다**. 격리 캡처 팩에만 들어간 관계없는 기존 verify 스크립트도 감사 목록에 기록했다. 최종 본게임에는 없다.

Android 정지 고정 장면의 A/B/C는 각각 40 draw calls·307,062 primitives, texture memory 146,655,872 B·video memory 207,019,008 B였다. 후보 세 개를 한 프로세스에서 미리 보유한 실험이므로 독립 cold-start 재질 메모리 차이 측정은 아니다. 동일 장면 60프레임 표본의 A/B/C p50은17.35/17.10/17.73ms, p95는26.50/20.33/21.74ms다. 에뮬레이터·짧은 표본·순차 측정·초반 호스트 빌드 경합이 있어 성능 우열로 판정하지 않았다. GPU timer·Android static memory의 0은 미제공 값이며 실제 비용0을 뜻하지 않는다. 실기기 성능 보장은 없다.

## 확인한 Android 범위와 남은 항목

실제 Android 검수 APK에서 고정/드론, 결정 두 위상, 앞쪽 대포·뒤쪽 지형·받침과의 겹침, 체적 화염(.13)·먼지(.52)를 캡처했다. 데스크톱 화면을 Android 결과로 대체하지 않았다. 본게임에서는 덮어설치→로비→기존 스테이지1 이어서 진입→기존 HUD와 고정 시점 화면을 확인했다. 기존 진행의 5웨이브 보상 창을 닫기 위해 일반 UI로 파편10개를 수령했고, 다음 웨이브는 시작하지 않았다. 저장 코드를 수정하거나 앱 데이터를 초기화하지 않았다.

아래는 **미검증**이며 완료로 주장하지 않는다.

- 실제 본게임 HUD에서 드론 전환·새 건설/타일 선택을 이번 APK로 끝까지 조작하는 검증.
- 후보의 연속 회전 전체 주기 영상·4배속 지속 전투(후보는 두 고정 위상과 겹침 장면만 확인).
- 실기기 접근 없음: 같은 기기 release 전후의 4배속 다중 착탄·충분한 p95/p99 표본·발열 후 저하·지원 하한 기종.
- 모든 투명체 조합·화면 밖 물체·임의 시점의 정렬/굴절, 추가 공용 조명 후보.

사용자의 범위 확장 지적 이후 추가 구현·검증을 멈추고 확보한 자료만 정리했다. 내장 전환 성공이나 모바일 시각 완료를 선언하지 않는다.
