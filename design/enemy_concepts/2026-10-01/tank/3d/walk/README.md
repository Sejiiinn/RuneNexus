# 탱커 이동 애니메이션

역할: 탱커의 편집 가능한 이동 원본·preview 거리 계약·실제 렌더와 검증 상태. 확인일: 2026-10-02.

승인한 [정적 탱커 r5](../README.md)의 넓은 가슴·단일 등/골반·짧고 굵은 다리·풍화 석재를 보존하면서 [일반형 V3](../../../../2026-09-26/medium-guardian-3d/walk/tile-speed-review/v3-upper-body/README.md)의 교대 발디딤·반대팔·몸통 무게 이동·늦은 머리 반응을 적용했다. 이 폴더가 이동 원본과 검증 상태의 원본이다. 게임 이식·능력치 변경·사망 애니메이션은 포함하지 않는다.

- [편집 원본](tank-walk.blend): `Tank_WideChest_Walk` 씬, `Tank_Walk_Rig` 리그, `Tank_Walk_WeightShift` 액션. **60fps 1~26**을 재생하며 **27은 폐쇄 키**다.
- [실제 이동 영상](tank-walk.mp4): 왼쪽 3/4·오른쪽 낮은 측면. [3/4 단독](walk-three-quarter.mp4) · [측면 단독](walk-side.mp4).
- [대표 위상 시트](walk-phase-sheet.png): 위 3/4·아래 측면, 왼쪽부터 1·8·14·21프레임.
- [전진 검수 원본](tank-walk-traversal.blend): `Tank_Walk_Traversal` 씬, 7주기 전진. 183프레임의 끝점까지 **1.990625 tile** 이동한다.
- [리그와 원본 연결](rig-map.json) · [거리/주기 계약](review-contract.json) · [수치 검증 요약](walk-metrics.json) · [실제 렌더 조건](render-conditions.json).

영상은 원본 지형의 실제 바닥 위를 이동한 **2주기 52프레임을 3회 반복**한 2.6초다. 3회 반복 시에는 같은 2주기 구간과 바닥 이동으로 돌아간다. 전진 원본의 전체 7주기를 렌더한 영상으로 표기하지 않는다. Blender Cycles 12 samples·AgX Medium High Contrast·640×560·60fps의 실제 렌더이며, 두 시점 합본은 1280×560이다.

## 보존과 동작

원본 **38메시·evaluated 21,664삼각형**의 정점·면·modifier·재질을 바꾸지 않았다. 돌은 개별 강체의 bone parenting으로 움직이며 늘어나거나 찌그러지지 않는다. REST 높이 **5.666368484**, 일반형 대비 **1.25배**와 루트 배율 **1.237734437**을 보존한다. [정적 탱커](../tank-wide-chest.blend)·기존 렌더는 그대로 남는다.

양발은 55% 지지하며, 지지 중 발바닥은 수평·월드 고정이다. 스윙 발은 부드럽게 들어 회수한다. 골반 좌우 이동은 ±0.065 raw-unit, 상하 변화는 기본 −0.14에서 ±0.040이다. 골반 좌우 기울기 ±1.8°, 흉곽 ±2.6°·좌우 회전 ±3°이며, 머리는 목 위치를 몸통과 연결한 채 **0.08주기** 늦은 회전 반응을 섞는다. 같은 쪽 팔은 전진 다리의 반대 방향으로 움직인다.

탱커는 하나의 짧고 굵은 허벅지가 주다리절이다. 그 내부 상단 `z=1.57`와 하단 `z=0.77`에 피벗을 두고 기존 발목 연결 돌을 짧은 내부 보조절에 붙였다. 실제 허벅지–골반/발의 넓은 접합을 유지한다. 일반형 다리 피벗을 그대로 축소했을 때 보였던 앞쪽 표면 틈은 이 피벗과 몸통 높이 조정으로 해결했다. 메시를 길게 늘리거나 별도 얇은 정강이를 추가하지 않았다.

## 거리 기반 재생 계약

검수 속도는 일반형 V3와 같은 **0.65625 tile/s**, 한 주기는 **26/60초**, 주기당 전진 거리는 **0.284375 tile**다. 이는 이 산출물의 preview 계약이며 탱커 게임 이동 수치를 변경한 결과가 아니다. 향후 게임 연결 시 실제 이동 거리에서 위상을 계산한다.

```text
phase = (distance_travelled_tiles / 0.284375) mod 1
frame = 1 + phase * 26
```

감속·배속은 실제 이동 거리와 위상을 같이 진행시킨다. 일반형과 같은 공통 표시 배율 `0.55 / 4.12951922416687 = 0.1331874173 tile/production-unit`을 사용하고, 탱커 루트의 1.237734437을 보존하여 raw 골격 기준 배율은 약 **0.1648506529 tile/raw-unit**이다. 탱커를 일반형의 폭 0.55 tile에 다시 강제 축소하지 않는다.

## 검증 상태

saved 원본의 독립 REST 대조에서 정점/면·재질·원래 외형과 1.25배 높이를 확인했다. 폐쇄 키 1↔27의 메시 행렬 차이는 약 **1.97e−17**이다. 7주기 전진을 0.25프레임 간격 **729상태**로 확인한 수치 검사에서 지지발 최대 잔여 속도 **0.000942 tile/s**, 접지 높이 최대 오차 **4.11e−6 tile**, 목 연결 최대 오차 **7.88e−8 tile**다. 최소 IK 도달 여유는 **0.03563 raw-unit**이다. 측정 원본 표본은 Git 제외 `local/`에 보관한다.

3/4·측면 대표 4위상과 최종 영상의 실제 시간축은 구현자·독립 검증자·부모가 직접 확인해 PASS했다. 독립 검증자는 두 시점의 1~52 전 프레임, 26→27과 52→1 모델 루프, 인코딩 영상의 반복 경계를 확인했다. 짧고 굵은 다리 접합·양발 회수/접지·반대팔·몸통 무게 이동·머리 반응과 승인 외형을 유지한다. 최종 MP4 전체 디코딩은 **1280×560·60fps·156프레임·2.6초**이며, 원본 52프레임의 3회 반복과 일치한다. 두 saved 프로젝트는 올바른 씬으로 직접 재개방되고 원본 액션명도 일치한다. 필수 미확인 항목과 이 작업 범위의 미해결 결함은 없다.

## 재생성

기존 Blender MCP에서 `build_walk.py` → `build_review.py`를 실행한다. 이름 붙인 이동 씬과 복사된 객체만 갱신하고 `bpy.data.libraries.write`로 분리 저장하므로 열린 frost 원본·미저장 작업·다른 씬은 보존한다. 별도 background 프로세스로 아래를 실행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background tank-walk.blend --python finalize_walk.py
/Applications/Blender.app/Contents/MacOS/Blender --background tank-walk-traversal.blend --python finalize_walk.py -- --traversal
/Applications/Blender.app/Contents/MacOS/Blender --background tank-walk-traversal.blend --python measure_walk.py
/Applications/Blender.app/Contents/MacOS/Blender --background tank-walk-traversal.blend --python render_walk.py -- final three-quarter
/Applications/Blender.app/Contents/MacOS/Blender --background tank-walk-traversal.blend --python render_walk.py -- final side
sh pack_walk.sh
```

`finalize_walk.py`는 직접 열리는 씬·액션명과 시작 UI만 정리한다. 원본 형상·모션 키는 바꾸지 않는다. `render_walk.py -- probe <view>`는 4개 대표 위상만 만든다. `--reuse`는 같은 최종 형상/모션·카메라·조명·렌더 조건임을 확인한 기존 프레임을 사용할 때만 명시한다. 소스 수정 뒤 새 검증에서는 기본 재렌더를 사용한다. 패킹은 일반형 제작에서 쓰던 ffmpeg 경로를 재사용하며 필요하면 `FFMPEG` 경로를 지정한다. 임시 프레임·중간 영상·원시 표본·실행 로그는 `local/`, 편집 가능한 원본·최종 영상/시트·재사용 제작 스크립트는 이 폴더에 둔다.
