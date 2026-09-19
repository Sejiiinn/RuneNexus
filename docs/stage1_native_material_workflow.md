# 스테이지 1 내장 재질 제작·이관 기준

역할: 현행 원본·엔진 설정·기존 실행 경로와 알려진 한계. 확인: 2026-09-14. [첫 실험 설계 원문](archive/stage1_native_material_first_experiment_20260913.md)과 [미채택 결과](../design/stage1_3d/native_material_workflow/verification/first-native-20260913/README.md)는 역사 기록이며 다음 작업 지시가 아니다.

## 현재 상태

코어는 사용자 승인에 따라 **화면 굴절 없는 StandardMaterial3D와 공용 환경 반사**를 사용한다. 현재 결과는 광택 있는 불투명 결정이다. Blender Cycles의 투과·내부 다중 굴절이나 모든 소재의 시각 이관을 완료한 것으로 일반화하지 않는다. [후속 적용·Android 확인·남은 범위](../design/stage1_3d/native_material_workflow/verification/native-reflection-20260913/README.md)를 참고한다.

- [main.gd](../godot/main.gd)는 GLB의 `core_crystal_facets` 원본 재질을 한 번 복제해 공유하며 굴절·투명 혼합을 끈다. 형태·면색·정점색·노멀·PBR·발광, 결정의 부유·회전과 받침 고정을 보존한다.
- [battlefield_reflection_sky.tres](../godot/materials/battlefield_reflection_sky.tres)는 내장 GradientTexture2D·PanoramaSkyMaterial로 구성한 공용 반사 환경이다. 코어 전용 ReflectionProbe는 제거됐다. [프리셋 책임과 제한](../godot/materials/README.md)을 따른다.
- Mobile 렌더러·FILMIC과 색 기반 확산 환경광을 사용한다. 조명 수치의 현행 기준은 `main.gd`이며, 후속 조정 전 수치를 기록한 실험 문서를 복사하지 않는다.

## 원본과 설정의 책임

| 항목 | 기준과 운영 |
| --- | --- |
| 형태·베벨·노멀·UV·피벗·정점색 | [Blender 현행 원본 허브](../design/stage1_3d/blender_workspace/README.md)의 에셋별 `.blend`. 초기 생성기로 최신 원본을 덮거나 게임 변형으로 승인 형태를 재해석하지 않는다. |
| Base Color·Metallic·Roughness·Normal·AO·Emission | 원본 PBR 데이터와 최종 GLB. 절차적 표면은 필요한 채널만 베이크하며 기존 atlas·UV·해상도를 재사용한다. |
| 투명·컬링·필터·렌더 우선순위 | Godot 내장 재질의 엔진 설정. 원본 값과 의미가 다른 설정만 명시적으로 분리하고 원본 수치를 이중 관리하지 않는다. |
| 주광·환경광·반사·톤매핑 | 공용 Godot 장면과 `godot/materials/`. 에셋마다 보정 광원·광학 계산을 새로 만들지 않는다. |
| 회전·정지·배속·피격·재사용 | 기존 전투 시계와 런타임 계약. 이관·최적화에서도 보존한다. |

색 데이터와 Non-Color Normal/ORM, 선형/sRGB 정점색, tangent를 구분한다. 카메라 하이라이트·동적 그림자를 Base Color에 구워 재질을 대신하지 않는다. IOR를 `refraction_scale`로, Transmission을 `1 - alpha`로 자동 대응시키지 않는다.

`build/godot/project`는 생성물이다. 원본과 재사용 설정은 저장소에 두고 [prepare_godot_project.py](../scripts/prepare_godot_project.py)로 동기화한다. `.tres` 삭제 동기화는 이미 구현됐다. 새 자산은 기존 PCK 경로에 연결하고 Flutter 자산에 중복 포함하지 않는다.

## 재사용할 제작·이관 경로

`python3 scripts/asset_workflow_report.py`로 등록 경로를 찾고, 뒤에 `runic-fire` 또는 `enemy-burn`을 지정해 원본·진입 함수·출력·관련 검사를 요약한다. 이 명령은 제작이나 검증을 실행하지 않는다.

| 대상 | 기존 자동화와 적용 범위 |
| --- | --- |
| 룬 화염 포탑 | [이관 기록](../design/fire_tower_concepts/runic_3d/migration/README.md)의 `export_native.py`·`export_flame_meshes.py`. 승인 원본을 보존한 작업 사본에서 평가 메시·PBR 베이크·GLB·형상 검사 결과를 생성한다. 효과는 입체 메시·내장 재질·GPUParticles를 사용한다. |
| 적 화상 | [연결 기록](../design/fire_tower_concepts/enemy_burn/integration/README.md)의 `bake_atlas.py`·부착점 데이터·기존 검수 스크립트. 승인 V3의 체적 원본을 아틀라스로 베이크하고 공유 MultiMesh·커스텀 shader로 외부 전투 시간에 따른 운동을 계산한다. |
| 코어 | 위 원본 GLB와 공용 반사 프리셋을 사용한다. `verify_scene.gd --crystal-glass`로 반사·회전, `--crystal-camera-comparison`으로 시점 차이를 확인한다. |

내장 PBR 우선은 커스텀 효과 일괄 제거 지시가 아니다. 포탈 소용돌이·식생 바람·포구 연기·입체 포탄 VFX는 승인 표현과 필요한 고유 동작을 유지한다. 화상에 채택된 평면 베이크를 다른 입체 효과의 교체 승인으로 해석하지 않는다. 신규 커스텀은 내장 비교에서 부족한 핵심 표현과 모바일 비용을 구분한 뒤 요청 범위에서 판단한다.

## 실행과 완료 기준

게임 이관을 요청받은 새 소재는 대표 출력의 Godot 외형을 일찍 확인해 재작업 범위를 줄인다. 시안만 요청한 단계에는 이관 방식과 알려진 한계를 남긴다. 시각 실패 시의 조정·검증 확대·채택 판단은 [시안 보존 기준](../DESIGNS.md#승인-시안-보존과-채택)을 따른다.

저장소 루트의 기존 준비·검사 명령은 다음과 같다. `GODOT_EXECUTABLE`은 기존 공용 빌드와 같은 실행 파일 경로를 사용한다.

```sh
python3 scripts/build_godot_pack.py
"$GODOT_EXECUTABLE" --headless --path build/godot/project --script res://verify_runtime.gd
"$GODOT_EXECUTABLE" --path build/godot/project --script res://verify_scene.gd -- --crystal-glass
```

변경 대상의 검사만 선택한다. 룬 포탑·화상은 위 연결 기록의 기존 검수를 사용한다. Android 실행은 [공용 빌드·본게임 연결](stage1_3d_preview.md)과 [인앱 검증](../.agents/in_app_test_guide.md), 시각 판정은 [디자인 기준](../DESIGNS.md)을 따른다. APK가 필요한 범위에서는 [용량 점검](android_apk_distribution.md#용량-점검)을 적용하며 배포는 승인된 범위에서 수행한다.

비교는 GLB·투영·카메라·배율·회전 위상·배경·조명을 고정하고 한 원인씩 바꾼다. 원본 이관 비교와 실제 게임 HUD 아래 수용성 비교를 구분한다. 동일 GLB라도 Blender/게임 카메라 고도 차이로 실루엣이 달라질 수 있으며, 수치·빌드·계약 검사 통과가 시각 채택을 대신하지 않는다.

[최적화 지침](performance_optimization_guidelines.md)에 따라 CPU 호출 감소·GPU 비용·전체 프레임·APK 크기를 구분한다. 결과 기록은 에셋별 원본·실행 조건·채택 여부·화면·미검증 범위를 연결한다. 검증의 반복·완료 기준은 DESIGNS.md에 모은다.
