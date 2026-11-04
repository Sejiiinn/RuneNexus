# 공통 그림자 · 에셋/재질 읽기 검토

2026-09-13. 이번 검토는 코드·에셋·import 설정을 변경하지 않았다. 공유 프로젝트 준비, GPU, Android 실행도 하지 않았다. 실제 proxy ON/OFF 시각 비교는 주 에이전트가 별도로 진행한다.

## 결론

지형·가시 식생·포탑·적에는 이미 같은 Godot 주광의 실시간 그림자 체계가 적용되어 있다. 이 본체군에서 수신을 끄거나 알파 혼합 때문에 그림자 생성을 잃는 설정은 발견하지 못했다. 고사리만 4군락의 별도 외피가 추가 차폐를 만드는 구조적 비대칭은 있다. 이것은 공통 그림자가 빠진 것을 복구하는 장치가 아니라, 실제 잔잎 실루엣보다 넓은 군락 음영을 보강하는 장치다.

확정된 자동 LOD 소실 결함은 낮은 `fern_shadow.glb` 외피에만 해당한다. 가시 `dressing.glb`도 자동 LOD를 사용한다는 사실만으로 같은 결함을 주장할 수 없다. 가시 식생 LOD의 그림자 영향은 필요 시 같은 카메라·빛의 ON/OFF 비교로 판정해야 한다.

## 현재 계약

| 대상 | Cast / Receive | 재질·셰이더 | 자동 LOD |
| --- | --- | --- | --- |
| 실제 지형·길·건설석판·기존 정적 풀/뿌리 | 기본 ON / 기본 수신 | GLB 전 재질 OPAQUE, unlit 없음. `_prepare_terrain_surfaces`는 필터·AO·normal만 조정 | true |
| 가시 장식 식생 | DOUBLE_SIDED 명시 / 수신 | `foliage_wind.gdshader`: cull_disabled, ALPHA/unshaded/shadows_disabled 없음 | true |
| 장식 바위 | 기본 ON / 기본 수신 | OPAQUE PBR, 코드에서 수신 해제 없음 | true |
| 고사리 보조 외피 | SHADOWS_ONLY / 본체 비표시 | Alpha Hash, 실제 25변 경계 거리 기반 coverage, 공통 주광 shadow map 사용 | **false** |
| 설치된 포탑 6종 | 기본 ON / 기본 수신 | 모든 GLB 재질 OPAQUE, unlit 없음. 생성 시 정점색 플래그만 보정 | true |
| 적 6종 | 기본 ON / 기본 수신 | 모든 GLB 재질 OPAQUE, unlit 없음. 생성 시 정점색 플래그만 보정 | true |
| 포탈·코어의 석재/금속 기단 | 기본 ON / 기본 수신 | OPAQUE PBR | true |
| 포탈 에너지 | OFF / unshaded라 수광 없음 | `portal_vortex.gdshader` | true |
| 코어 결정 | OFF 명시 / PBR 수신 | GLB transmission 원본은 있으나 런타임에서 refraction/투명도를 끈 기존 상태 | true |
| 건설 미리보기 | OFF 명시 / 본체 재질 유지 | 확정 설치와 구분된 미리보기 경로 | 포탑 원본과 동일 |
| 화염·예광·연기·폭발·불티 | OFF 명시 / 다수 unshaded | 알파/가산 효과. 깊이 교차는 실제 shadow 투사와 별개 | 일부 GLB는 true, 절차형은 해당 없음 |
| 탄체·착탄 금속 파편 | OFF 명시 / PBR 부분은 수신 가능 | 짧은 전투 효과의 기존 예외 | 절차형 |

모든 확인한 GLB import는 `meshes/create_shadow_meshes=true`; 현재 `_subresources={}`로 개별 노드 cast override가 없다. 수신 비활성화 플래그·`shadows_disabled`는 공통 본체 코드에서 발견되지 않았다. 기본 ON/수신은 Godot 기본값에 의존하며, 모든 에셋에 중복 설정하는 별도 순회는 없다.

공통 주광은 `main.gd:111` 부근에서 shadow_enabled=true, 방향/PCF/bias를 설정하고 `_apply_options`에서 전체 그림자 옵션을 적용한다. 보조 방향광·환경광은 차폐되지 않는 밝기를 더한다. 이 때문에 그림자 내부가 완전히 검지 않은 것은 공통 조명 구성의 결과이며 특정 오브젝트 수신 누락의 증거가 아니다.

## 근거 위치

- `godot/main.gd:149`: 지형·랜드마크·장식 준비. `:185` 가시 식생 DOUBLE_SIDED, `:197` 별도 고사리 재질/외피.
- `godot/main.gd:503`: 실제 지형과 장식 라이브러리 복제. 동일 셰이더/mesh 계약이 실제 장면으로 이어진다.
- `godot/main.gd:562`: `_prepare_vertex_colors`는 정점색 사용 플래그만 변경한다.
- `godot/main.gd:572`, `:714`: 포탑과 적 생성·상태 순회에서 불투명 본체 shadow를 끄지 않는다.
- `godot/main.gd:755`: 건설 미리보기만 OFF.
- `godot/effects/ballistic_projectile.gd:56`, `effects/godot_impact.gd:54,71`, `effects/machinegun_muzzle.gd:65,74,88`: 절차형/전투 효과 cast OFF 예외.
- `scripts/prepare_godot_project.py`: 보조 외피의 generate_lods=false만 고정하는 국소 계약.
- `build/godot/project/assets/{environment,turrets,enemies}/*.glb.import`: 실제 준비된 import 값을 읽어 확인했다.
- 원본 GLB JSON의 모든 material alphaMode/baseColor alpha/doubleSided/KHR_materials_unlit과 mesh primitive를 읽었다. 지형 GLB에는 실제 장면에 복제되지 않는 라이브러리 노드도 있으므로 파일 전체 삼각형 수를 실행 프레임 비용으로 취급하지 않았다.

## 누락·일관성 판단

1. **확정된 본체 공통 그림자 누락은 없음.** 공통 renderer/주광과 불투명 본체 재질이 이미 연결돼 있다. 새 전역 shadow 시스템을 추가할 근거는 없다.
2. **고사리 추가 외피는 외형상 비대칭.** 다른 풀·넓은 잎·관목은 실제 메시 그림자만 사용한다. 같은 공통 광원/PCF 안에서도 고사리만 군락 전체에 넓은 차폐가 더해진다. 과장 여부는 실제 proxy ON/OFF 결과로 판단해야 한다.
3. **가시 식생 자동 LOD는 확인할 수 있는 변수이지 확정 결함이 아님.** 얇은 잎에서 어떤 LOD가 선택되며 실제 투영 차폐가 달라지는지는 이번 읽기 검토만으로 확인되지 않았다. 전체 LOD 일괄 해제를 권하지 않는다.
4. **기존 명시 예외:** 현재 불투명 코어 결정은 cast OFF이고 포탈 에너지도 OFF다. 이는 이번 변경 이전의 별도 재질/에너지 표현 계약이며, 모든 것을 같은 cast 값으로 맞추면 기존 외형을 바꾼다. 코어의 별도 미완료 재질 문제와 함께 판단할 항목이다.
5. **검증 범위 차이:** 현재 `verify_environment.gd`는 식생 DOUBLE_SIDED·고사리 SHADOWS_ONLY/점유를 직접 검사하지만 포탑·적의 cast/receive 계약은 같은 수준의 명시 검사가 없다. 현재 누락의 증거는 아니며, 후속 공통 변경 때 회귀 확인할 범위다.

실기기 성능 측정은 하지 않았으며, 그림자 비용이나 LOD 해제 가능 범위를 단정하지 않는다.
