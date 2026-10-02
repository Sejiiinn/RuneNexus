# 넓은 가슴 탱커 정적 3D 원본

역할: 탱커의 편집 원본·최종 렌더·실측·검증 상태. 확인일: 2026-10-02. 최우선 승인 [16번 멀티뷰](../16-wide-chest-multiview-unified-back.png)의 형태·재질을 실제 3D로 재제작했다. [12-A 오른쪽 탱커](../12-a-wide-chest-150.png)는 연결이 불명확한 부분을 보완하는 참조다. 최종 모델은 일반형 실제 높이의 **1.25배**, **38개 메시·evaluated 21,664삼각형**이다. 6방향 렌더·일반형 비교의 독립 시각 검증과 두 저장 원본의 재개방·동일성 검증을 완료했다.

후속 요청인 일반형 방식의 이동 애니메이션은 [걷기 원본·영상·검증](walk/README.md), 기존 게임 탱커 교체는 [게임 적용 기록](game-export/README.md), 무릎과 팔로 버티다가 무너지는 사망 모션은 [사망 원본·게임 검증](death/README.md)에서 관리한다. 아래는 보존한 정적 모델의 제작 기록이다.

- 편집 원본: [tank-wide-chest.blend](tank-wide-chest.blend), `Tank_WideChest_Concept` 씬, `Tank_WideChest_MODEL` 컬렉션. 정면 `-Y`·위 `+Z`.
- 실제 렌더: [3/4](preview-three-quarter.png), [정면](preview-front.png), [측면](preview-side.png), [후면](preview-back.png), [수직 TOP](preview-top.png), [고각](preview-high-angle.png).
- [일반형·탱커 1.25배 비교](preview-normal-tank-125.png), [편집 가능한 비교 씬](tank-normal-size-comparison.blend). 왼쪽 일반형·오른쪽 탱커, 같은 정투영 카메라와 바닥 높이.
- [실측 근거](size-comparison.json), [evaluated 전체 모델 집계](mesh-stats.json), [렌더 조건](render-conditions.json).
- 범위는 편집 가능한 정적 모델·렌더다. 리깅·애니메이션·게임 이식·APK·커밋은 포함하지 않는다.

큰 모서리 둥근 머리, 깊은 작은 청록 눈과 실제 음각 이마 룬·낮은 턱 홈, 대각으로 놓인 둥근 어깨, 넓은 앞가슴과 굵은 전완·돌 손가락·허벅지·평평하게 접지하는 둥근 발을 유지한다. 등과 뒤골반은 각각 하나의 돌이며 중앙 분할이 없다. 연결은 숨겨진 자연석으로 구성한다.

블록 형태를 스무스 셰이딩으로만 덮지 않고 주요 바위의 곡면·비정형 실루엣·면 전환을 재구성했다. 머리의 좌우 폭을 11% 줄이고 눈·안와·음각 룬·입을 함께 정렬했으며 눈 자체의 구형을 보존했다. 가슴은 넓은 중앙면과 서로 다른 큰 사면·짧고 둥근 모서리로 구성한다. 등은 높이가 있는 넓은 단일 돌이며, 중앙 큰 면에서 실제 가슴 상단 윤곽을 따르는 완만한 상부 사면으로 이어진다. 앞의 별도 칼라·하단 받침띠나 뒤의 계단·수평 선반이 드러나지 않는다. 골반은 중앙이 아래로 내려오는 단일 쐐기 돌이고, 짧고 굵은 허벅지 전체가 골반과 발 상면에 실제로 겹쳐 받친다. 따뜻한 회갈색의 중간 풍화 셀, 닳은 경계·면 안의 불규칙 침식·광석층·거친 결을 분리한 3D 재질을 사용한다. 드문 분기 균열은 실제 좁은 개방 홈이며, 호박 코어는 흡수·굴절하는 구형 외피와 작은 내부 광핵으로 구성한다.

## 크기와 보관

승인 일반형 `medium-guardian-3d/medium-guardian.blend`의 실제 evaluated 머리~발바닥 높이는 `4.533094734`, 탱커는 `5.666368484`, 비율은 `1.250000015`다. `build_tank.py`의 `TARGET_HEIGHT_RATIO = 1.25`로 루트의 균일 배율을 계산한다. 일반형의 현행 표시 배율 `1.15`는 공통 표시 조건에서 상쇄되므로 다시 곱하지 않는다. 폭과 깊이는 시안의 넓은 흉곽 형태를 따른다.

재제작 전 원본·대표 렌더·스크립트 및 미저장 Blender 씬은 Git 제외 `local/before-reference-rebuild/`에 보존했다. 이전 `preview-normal-tank-150.png`도 이 로컬 보존 폴더로 옮겼다. 최신 머리·몸통 연결 수정 전 최종 원본·렌더·스크립트는 Git 제외 `local/before-head-torso-continuity/`에 추가 보존했다. 임시 시험 렌더·실행 로그는 `local/`에 두며 현행 최종 산출물과 구분한다.

## 재현

기존 Blender에서 아래처럼 제작 스크립트를 실행한다. 이름 붙인 탱커 씬만 재구성하고 `bpy.data.libraries.write`로 분리 저장한다. 기존 열린 파일과 다른 씬·미저장 작업은 덮어쓰지 않는다. 일반형 원본 참조를 위해 시안 폴더의 상대 위치를 유지한다.

```python
path = '/Users/sejin/Documents/Codex/RuneNexus/design/enemy_concepts/2026-10-01/tank/3d/build_tank.py'
exec(compile(open(path).read(), path, 'exec'), {'__file__': path})
```

`render_views.py`는 같은 방식으로 실행한다. `VIEWS`를 전달하면 해당 뷰만, 기본값은 전체를 렌더한다. `render-progress.log`의 `COMPLETE_RENDERED`는 **해당 실행에서 생성한 뷰만** 표시한다. `render_size_comparison.py`는 원본 일반형과 최종 탱커를 같은 정투영·바닥 높이에서 렌더하고 별도 비교 씬을 저장한다.

씬 라이브러리를 직접 열리는 프로젝트로 정리하고 저장 원본을 검사하는 과정은 열린 작업을 보존하는 별도 background에서 수행한다. 아래 명령은 이 `3d/` 폴더에서 실행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background tank-wide-chest.blend --python finalize_project.py
/Applications/Blender.app/Contents/MacOS/Blender --background tank-wide-chest.blend --python check_tank.py
/Applications/Blender.app/Contents/MacOS/Blender --background tank-normal-size-comparison.blend --python finalize_project.py -- --comparison
```

## 검증 상태

Blender `5.2.1 LTS`, Cycles 64 samples, AgX Medium High Contrast. 개별 뷰는 1200×1200이며 정면·측면·후면은 수평 정투영, TOP은 실제 수직 정투영이다. 3/4은 yaw 25°·elevation 22°로 원본의 상면 노출을 대조했다. 승인 16의 `TOP`은 고각 이미지여서 별도 고각 렌더도 제공한다.

최종 `Astra reference revision 5`의 6뷰와 일반형 비교를 구현자·독립 검증자·부모가 실제 이미지로 확인했다. 머리 폭, 가슴의 큰 불규칙 사면, 자연스럽게 이어지는 단일 등과 골반, 짧고 굵은 허벅지의 상하 접촉, 풍화 석재·실제 균열·음각 룬·눈과 코어를 최우선 16번 시안과 대조하여 PASS로 판정했다. 전체 렌더와 두 `.blend`는 같은 최종 형상이다. 관련 제작 입력과 렌더 조건은 [render-conditions.json](render-conditions.json)에 기록한다.

두 `.blend`를 별도 Blender 프로세스에서 직접 재개방하여 각각 올바른 씬으로 열리는 것을 확인했다. 독립 실측 결과 탱커는 메시 38개·evaluated 21,664삼각형·non-manifold edge 0·높이비 `1.2500000147923724`이며, 비교 씬의 탱커 기하·재질은 단독 원본과 동일하다. 비교 일반형도 실제 일반형 원본의 기하·재질을 보존한다. 머리 높이는 전체의 36.14%다.

열려 있던 `frost-optimized.blend`의 미저장 상태와 다른 씬을 보존하고 탱커 전용 씬만 수정했다. 상세 검사 로그·원시 측정·중간 시험 이미지는 Git 제외 `local/`에 로컬 보관한다. 요청 범위인 정적 3D 원본·렌더에 미해결 사항은 없다. 리깅·애니메이션·게임 이식과 인게임 검증은 이 산출물의 완료 범위가 아니다.
