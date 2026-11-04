# 스테이지 1 환경 장식

역할: 2026-09-12 승인 시안의 Blender 원본·Godot 적용·검수 진입점. [승인 시안](../environment_concepts/01-overgrown-stone-edges.png)의 외곽과 내부 타일 틈의 식생, 빈 타일 중앙의 풀 군락을 실제 타일 배열에 맞춰 구현했다. 중앙 식생은 포탑 설치 시 숨고 철거 시 다시 나타나며, 가장자리·틈 식생은 유지한다. 기존 terrain 원본과 다른 스테이지는 유지한다.

시각 목표는 모바일 성능을 고려한 스타일화된 3D 환경이다. 실제 게임 크기에서 보이는 군락의 구성·형태·색 조화와 간단한 명암을 우선하며, 과도한 사실 묘사는 요구하지 않는다. 2026-09-12 승인된 [개선 설계](improvement-design-20260912.md)를 반영해 여섯 초점을 중심으로 고사리·휘어진 넓은 잎·직립 풀·낮은 지피를 겹치고, 나머지 경계에는 드문 연결점과 빈 면을 남겼다. 초점의 제거 가능한 중앙 식생은 가로폭 약 0.91타일·안쪽 깊이 약 0.81타일의 윤곽으로 펼친다. 낮게 휜 큰 고사리 여섯 개, 세 밑동의 중층 넓은 잎, 짙은 기저 잎이 타일 중심까지 교차해 영구 가장자리와 한 덩어리로 연결된다. 주변의 선택한 일곱 건설칸에는 중간 밀도의 관목형 패치를 둔다. 돌의 뒤·옆에 중간높이 잎을 겹치고, 짙은 이끼색 아래층과 중간 올리브색 상층 사이에 선택적인 밝은 앞쪽 잎을 둬 한 덩어리 안의 깊이를 만든다. 잎 앞면의 법선, 올리브 중간색과 어두운 밑동, 회색 면이 노출된 납작한 이끼돌로 실제 게임 거리의 형태와 부피를 다듬었다.

## 독립 환경 에셋 제작 — 맵 적용 전

현재 새 식생 제작은 [독립 식물 원본](plant_library/README.md)에서 진행한다. 풀 포기·고사리·넓은 잎 식물·낮은 지피를 각각 조형하고, [정지 검수 이미지](plant_library/plant-masters-review.png)로 형태를 확인한 뒤 군락과 배치를 진행한다. 꽃·바위·돌멩이·이끼·늘어진 덩굴·뿌리는 [추가 환경 장식 7종](companion_library/README.md)에서 같은 순서로 제작·검수한다. 아래의 88개는 현재 게임에 배치된 군락 수이며, 독립 식물 종류 수가 아니다. 새 마스터는 기존 게임 장식에 아직 적용하지 않았다.

## 원본과 게임 파일

- 편집 원본: [environment-dressing.blend](environment-dressing.blend), Scene `Stage1EnvironmentDressing`. `10 Dressing` 컬렉션의 식생 88개(영구 61개·설치 시 숨기는 중앙 군락 27개), 이끼돌·뿌리 15개 군락을 개별 편집할 수 있다.
- 기존 지형: `00 Terrain` 컬렉션의 `environment/terrain-approved.blend` 연결 참조. 새 장식 GLB에 포함하지 않는다.
- 게임 에셋: `assets/images/stage1_3d/environment/dressing.glb`. 스테이지와 같은 원점·타일 단위이며, `stage1_dressing` 아래 풀·바위 두 메시만 출력한다.
- 바람: `godot/environment/foliage_wind.gdshader`. 뿌리 고정, 잎 끝 최대 0.022타일, 군락별 위상 차이, 두 사인파. 전투 정지·1/2/4배속에 연결하지 않는다.
- [Blender 미리보기](blender-preview-0001.png)는 현행 원본 제작 렌더다. 카메라 `(5, -13, 27)`은 Godot 고정 시점 `(5, 27, 13)`에 대응하며, Blender 조명·AgX를 사용하므로 실제 게임 캡처와 구분한다.
- 전체 배치 식생 88개는 [한 장 목록](foliage-catalog-20260912.png)으로 확인한다. 재현용 [capture_foliage_catalog.py](capture_foliage_catalog.py)는 원본을 읽어 개별 군락을 촬영하며 모델을 변경하지 않는다.
- 재구성 이전 편집 원본은 [environment-dressing.previous-20260912.blend](environment-dressing.previous-20260912.blend)에 별도 보존했다. 이전 생성기·manifest·제작 렌더는 `previous-20260912/`의 비교 기록이며 게임에서 로드하지 않는다. 풍성함 확대 전 19,658삼각형 원본은 `environment-dressing.before-lush-20260912.blend`, 해당 생성기·manifest는 `before-lush-20260912/`에 보존했다.

## 편집·출력

허브 `10 Environment Dressing` 또는 위 원본에서 확인한다. 허브의 연결 원본은 읽기 전용이므로 수정은 `environment-dressing.blend`에서 한다. 타임라인 1~240, 30fps를 재생하면 게임과 같은 바람 수식을 Shape Key 드라이버로 확인할 수 있다. 드라이버는 간단한 sin/cos 표현식이며 별도 애드온·시뮬레이션 캐시는 필요 없다.

정점색 `Color`는 선형 RGB, 불투명 알파 1이다. UV `Wind.x`는 뿌리 0~끝 1 굽힘 가중치, `Wind.y`는 `1−군락 위상`이다. glTF의 V축 변환 뒤 Godot에는 위상값 그대로 전달된다. 두 번째 UV `Occupancy.x`는 건설 타일의 row-major 순번 0~31, `Occupancy.y`는 영구 식생 1·제거 가능한 중앙 식생 0이다. glTF V축 변환 뒤 Godot의 UV2.y는 제거 가능 플래그 0/1이 된다. 중앙 식생에는 `removableOnBuild` 속성도 둔다. 수작업 수정 시 이름·속성·UV 계약과 잎 앞면의 위쪽 법선을 보존한다. 뒤집힌 잎은 Godot에서 짙은 뒷면처럼 보이므로 원본 검사에 법선 방향도 포함한다. 영구 장식은 건설칸 중앙 0.7×0.7을 비우고 바람 여유를 둔다. 제거 가능한 중앙 풀은 빈 타일 안쪽까지 놓되 길·포털·코어는 침범하지 않는다.

저장한 원본을 내보내고 검사한다. 저장소 루트에서 실행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background design/stage1_3d/environment_dressing/environment-dressing.blend --python-exit-code 1 --python design/stage1_3d/environment_dressing/export_dressing.py
/Applications/Blender.app/Contents/MacOS/Blender --background design/stage1_3d/environment_dressing/environment-dressing.blend --python-exit-code 1 --python design/stage1_3d/environment_dressing/verify_source.py
```

`export_dressing.py`는 Basis 좌표를 두 재질별 메시로 병합한다. Shape Key·드라이버·카메라·광원·연결 지형은 내보내지 않으며 편집 원본도 덮어쓰지 않는다. 원본 메시 수정은 반영하지만 미적용 modifier는 반영하지 않으므로 필요한 modifier는 원본에서 적용한다.

`build_dressing.py`는 현행 군락의 재현 가능한 생성 경로이며 **수작업 수정 뒤 재실행하면 생성 원본이 초기화된다**. 필요한 경우에만 별도 `--background --factory-startup --python-exit-code 1 --python design/stage1_3d/environment_dressing/build_dressing.py`로 재생성한다. 기존 지형·포탑 원본에서는 실행을 차단한다. 외곽 여섯 초점, 19개 선택 연결점, 12개 내부 틈과 세 이끼돌 모서리는 생성기의 명시적 배치 목록에서 편집한다. 모든 타일을 등간격으로 장식하지 않는다. 메시·군락 배치는 [placement_manifest.json](placement_manifest.json), 출력 수치는 [export_manifest.json](export_manifest.json)에 남긴다.

## 성능과 패키징

출력은 두 메시·두 재질, 총 22,766삼각형(식생 20,486·돌과 뿌리 2,280), GLB 1,532,092바이트다. 24,000삼각형 예산 안에서 미세 잔풀보다 큰 군락의 수평 피복에 비용을 배분한다. 실제 성능은 화면 점유 면적과 전투 부하를 함께 확인한다. 추가 텍스처·투명 블렌딩·스킨·애니메이션 클립·물리·추가 광원이 없다. 풀은 그림자를 생성하지 않고 기존 조명을 받는다. 바위는 정적으로 그림자를 만든다. 바람은 하나의 공유 셰이더에서 계산하며 풀별 CPU 갱신이나 프레임별 메모리 할당이 없다. 중앙 식생은 두 16비트 점유 마스크를 공유한다. 실제 포탑 목록을 갱신하는 기존 순회에서 마스크를 계산하고, 설치·철거 등 값이 바뀔 때만 셰이더 uniform을 갱신한다. 점유한 타일의 중앙 군락은 정점 셰이더에서 공통 지하점으로 접어 숨기므로 추가 드로콜·투명 블렌딩이 없다. 건설 미리보기는 점유로 처리하지 않는다.

Godot은 지형 원본과 실제 맵 배열이 맞을 때만 장식을 배치하고, 같은 맵의 메시·재질을 계속 공유한다. JSON 숫자를 정수로 바꿔 비교할 때 기존 지형을 매 프레임 재생성하던 문제는 입력 맵의 숫자형을 보존하여 수정했다. 초기화·재진입·다른 맵에서는 기존 지형 수명에 맞춰 제거·재사용한다.

새 장식은 Godot 전용이다. `pubspec.yaml`은 기존 `terrain.glb`와 면광원 LTC 조회표 4개만 Flutter 에셋으로 유지하며, `dressing.glb`는 공용 Godot PCK에만 포함해 원본 GLB와의 이중 패키징을 방지한다. `design/` 원본·Blender 미리보기는 게임 패키지에 넣지 않는다. 기존 다른 GLB·이전 렌더러 의존성의 패키징은 이번 범위에서 변경하지 않았다.

## 검증

[Blender 원본 검사](source-verification.json): 소속 타일과 인접 타일 모두의 영구 장식 건설 중앙 침범 0건, 제거 가능한 식생의 다른 타일 중앙 침범 0건, 바람 최대 변위를 포함한 경로·포털·코어 침범 0건, 뒤집힌 잎 앞면 0개. 7개 시점에서 최대 이동 0.02198타일, 뿌리 이동 0을 확인했다. Godot `verify_environment.gd`는 실제 GLB의 메시·삼각형·UV·정점색·패키징 예산, 공유 자원, 초기화·재진입·다른 맵 격리, 중앙 풀의 설치·이동·철거·미리보기 제외를 검사한다. `verify_runtime.gd`는 기존 6종 모델·포구·HUD 투영·맵 전환을 검사한다. 재구성 이전 두 검사의 통과 기록은 [기존 검증 기록](verification/verification.md)에 보존한다. 풍성함 확대 후 현행 에셋의 Godot·Android 적용 검수 결과는 `verification/lush-20260912/`에 따로 기록한다.

기존 회귀 검사에는 같은 Godot 장면에서 바람 시간을 고정한 GPU 픽셀 비교도 포함한다. 포탑 본체를 가려 식생 변화만 비교하며, 설치한 슬롯 0의 중앙 풀만 사라지고 슬롯 16은 동일한지, 철거 후 전체 화면이 원래 픽셀로 돌아오는지 검사한다. 실제 본게임의 건설 UI를 조작한 검증과는 구분한다.

APK는 [공용 Godot 검수 빌드](../godot_preview/README.md)를 사용한다. 실제 화면·4배속 다중 착탄·바람·변경 전후 용량과 본게임 공용 팩 확인은 [현행 Android 검증 기록](verification/lush-20260912/README.md)에 모았다. [이전 Android 검증 기록](verification/verification.md)과 구분한다. 에뮬레이터 검수는 실기기의 장시간 프레임·메모리·발열 성능 수용을 대신하지 않는다.
