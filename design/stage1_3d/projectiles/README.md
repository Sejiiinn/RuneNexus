# 둥근 철구 포탄

역할: Android Godot 스테이지 1~5 대포의 편집 원본·내보내기·비행 표시 계약. 작성: 2026-09-13. 실제 게임의 시각 검증과 패키지 측정은 아래 확인 기록에 별도로 남긴다.

## 형태와 원본

[승인 시안 04](../projectile_concepts/04-round-ironball.png)의 둥근 불투명 검은 철구, 얕은 단조 표면, 뒤쪽의 작은 주황 열 표현을 따른다. 구형 실루엣과 금속 몸체가 먼저 보이도록 유지한다. 큰 돌 파편 면·뾰족한 탄두·긴 예광으로 바꾸지 않는다. 시안 확대 이미지는 실제 게임 캡처와 구분한다.

| 항목 | 파일·규격 |
| --- | --- |
| 편집 원본 | [cannonball.blend](cannonball.blend), Scene `Round Iron Cannonball` |
| 생성·내보내기 | [build_cannonball.py](build_cannonball.py) |
| 단조 노멀 | [cannonball-normal.png](cannonball-normal.png), 기본 512×512, 원본에 패킹 |
| 게임 에셋 | [cannonball.glb](../../../assets/images/stage1_3d/projectiles/cannonball.glb) |
| 원본 검수 렌더 | [cannonball-source.png](cannonball-source.png), Blender 스튜디오 렌더 |
| 출력 수치 | [export_manifest.json](export_manifest.json) |

루트는 `cannonball`, 메시 이름은 `cannonball_body`와 `cannonball_heat`다. 몸체 반지름은 0.14타일이며 Godot 진행축은 +Z, 작은 열 표현은 뒤쪽 -Z에 둔다. Blender +Y가 내보낸 Godot -Z에 해당한다. 몸체는 정점색·금속·거칠기·tangent normal을 가진 불투명 native PBR 재질이다. 카메라와 조명은 편집 원본의 스튜디오 검수용이며 게임 GLB에 포함하지 않는다.

## 수동 편집 후 내보내기

원본을 Blender에서 수정하고 저장한 뒤 저장소 루트에서 실행한다. 이 명령은 저장된 원본을 열어 `cannonball` 아래 모델만 내보내며, 메시 재생성·노멀 재베이크·원본 저장·검수 렌더 재생성을 하지 않는다. GLB와 출력 수치만 갱신한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/projectiles/build_cannonball.py -- --export-only
```

생성 코드를 기준으로 원본 전체를 다시 만들 때만 옵션 없이 실행한다. **기본 재생성은 수동 편집한 `.blend`, 노멀, GLB, 원본 검수 렌더를 덮어쓴다.** 보존할 수정이 있으면 먼저 별도로 저장한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python-exit-code 1 --python design/stage1_3d/projectiles/build_cannonball.py
```

두 경로 모두 열린 Blender 작업을 보호하도록 별도 백그라운드 프로세스에서 실행한다. 원본 변경 후 [Blender 작업 허브 갱신](../blender_workspace/README.md#갱신)을 진행하면 Scene `28 Cannonball`에서 저장된 원본을 확인할 수 있다.

## 게임 표시

[ballistic_projectile.gd](../../../godot/effects/ballistic_projectile.gd)가 실제 전투의 비행 위치·발사 총구·명중점을 사용한다. 철구 GLB 메시와 native 재질은 인스턴스 간 공유하며, COLOR_0 정점색을 명시적으로 활성화해 어두운 철색을 보존한다. [cannon_flight.gd](../../../godot/effects/cannon_flight.gd)와 [체적 셰이더](../../../godot/effects/cannon_flight.gdshader)는 몸체 뒤에 최대 한 지름(0.28타일)의 짧은 화염·회색 체적 연기와 작은 불티를 표시한다. 기존 긴 대포 예광 메시는 사용하지 않는다.

명중한 몸체와 열 표현은 즉시 숨기고 잔여 효과만 140ms 동안 소멸한다. 이후 풀로 반환해 다음 발사에서 초기화하여 재사용한다. 기존 화살 비행·예광과 피해 판정·탄속·공격 주기·저장 형식은 유지한다. 착탄 폭발은 별도 [포탄 폭발 기준](../cannon_impact/shell_runtime/README.md)을 따른다.

## 확인 기록

- 자동 검사: [verify_projectiles.gd](../../../godot/verify_projectiles.gd)가 구형 규격·불투명 재질 공유·실제 비행/명중점·짧은 꼬리·종료와 재사용·기존 화살 경로를 검사한다. headless dummy 렌더러에서는 불티 MultiMesh의 GPU transform을 읽을 수 없어 해당 항목의 자동 수치 검사는 실제 렌더러 실행 시에만 수행된다. 최종 headless 결과는 0 failures다.
- 실제 게임 시각 검증: Android 에뮬레이터의 정상 `lib/main.dart` 앱, 메모리 저장소의 스테이지 2에서 실제 대포 사격으로 확인했다. [고정 시점 확대](verification/android-angled-zoom.png)·[드론 시점 확대](verification/android-drone-zoom.png)는 게임 줌 2.1배에서 비행 중 순간을 디버거로 정지한 캡처다. 둥근 어두운 금속 몸체와 뒤쪽의 짧은 주황 불꽃·회색 연기가 분리되어 보이며, 긴 예광은 없다. 초기 흰 탄체 문제는 COLOR_0 사용 플래그 누락으로 확인해 수정했고 해당 회귀 검사도 통과했다. [기본 크기 캡처](verification/android-angled-normal.png)에서도 탄체가 구분되며, [1배속 전투 영상](verification/android-gameplay-1x.mp4)의 실제 사격·명중·효과 소멸도 확인했다. 최종 실행 로그에 스크립트/셰이더 오류가 없었다. 프레임 성능 벤치마크는 수행하지 않았다. 사용자의 영구 저장 데이터는 수정하지 않았으며 검증 후 정상 앱으로 복원했다.
- 패키지 측정: 동일 환경의 직전 디버그 APK 497,014,398바이트 → 최종 497,536,194바이트(+521,796바이트, 약 0.50MiB). PCK는 74,365,128 → 74,886,924바이트. 구형 GLB 566,092바이트(내장 512 노멀 포함)와 비행 효과가 증가 원인이다. APK에 GLB의 Flutter 중복 복사나 Blender 원본·생성 Python이 들어가지 않고 `assets/rune_nexus.pck` 한 경로로 포함됨을 ZIP 목록에서 확인했다. 공개 배포는 하지 않았으며 이 비교는 공개 release APK 간 비교가 아니다.
