# 이전 대포 화염구 — Blender 제작·검수 기록

이 폴더는 최신 파편탄+부분 화염으로 교체된 이전 화염구의 제작 기록이다. `cannon_impact_cinematic.blend`는 당시 승인 원본이며, `production/cannon_export.blend`는 채택하지 않은 RGBA 내보내기용 중간 파일이다. 둘 모두 최신 게임 착탄의 편집 원본이 아니다.

현재 게임은 [Python 제작 원본](../field_cache/bake_field.py)이 생성한 3D 필드 캐시와 런타임 입체 파편·불티를 사용한다. 최신 착탄에 대응하는 Blender 원본은 없다. [현재 캐시 규격](../field_cache/README.md), [현재 실제 렌더 검수](../shell_runtime/README.md), [Blender 작업 허브](../../blender_workspace/README.md)에서 현행 상태를 확인한다.

## 당시 형태와 검수 기준

아래 제작·보정 순서는 이전 화염구를 재생성하는 절차다. `cannon_impact_v2.blend`와 `frames/`는 그보다 앞서 지속시간만 조절했던 중간본이다.

- Scene: `CannonImpactV2` (화염·불티), `CannonGroundV2` (짧은 먼지·금속 파편)
- 시간: 32프레임 / fps 320, fps_base 11 / 총 1.1초
- 좌표: 원점 (0, 0, 0)이 지면 충돌점, +Z 위쪽. 폭 약 3.2m, 높이 약 2.7m의 실제 3D 체적 영역.
- 재질: 연속 체적 밀도, 비대칭 좌표 왜곡과 높이별 회전, 다중 크기 난류. 중심 거리와 무관한 국소 난류 열도로 어두운 흡수 주름·주황 화염·좁은 황금빛 핵을 분리한다. 최대 발광 22, 난류 게이트 지수 2.7, 흡수 밀도 계수 15. 체적 경계에서 밀도 0을 보장한다. AgX 사용.
- 화염: 빠르게 팽창한 뒤 위로 말려 올라가며 소멸, 25프레임부터 밀도·발광 0.
- 먼지: 초반 바닥에만 낮게 퍼지고 12프레임부터 0.
- 잔광: 70개의 가는 불티가 개별 탄도로 소멸하고 작은 금속 파편 15개를 분리. 32프레임은 모두 사라진 상태.

`preview/`는 거친 짙은 석재 바닥, 실제 순간광원, 사선 카메라를 함께 렌더한 Blender 단독 영상이다. `runtime/`는 이전 화염구를 게임에 직접 렌더했던 과거 실행 검수이며 두 영상을 구분한다. `production/`의 중간 PNG는 게임에서 사용하지 않는다.

## 재현 순서

1. Blender에서 `build_cinematic.py`를 실행하여 두 애니메이션 Scene과 최초 원본을 만든다.
2. `refine_cinematic.py`를 실행하고 같은 `cannon_impact_cinematic.blend`에 저장한다. 이 단계가 당시 최종 승인된 재질 보정이며 생략하지 않는다. 보정 스크립트는 원본과 조명 합성 검수 파일에 공통 적용할 수 있다.
3. `preview/build_scene.py`로 단독 검수 장면을 구성하고 대표 프레임을 확인한 뒤 전체 영상을 렌더한다.

현재 저장된 `cannon_impact_cinematic.blend`에는 2단계까지 적용되어 있다. `refine_cinematic.py`는 저장이나 Scene 전환 없이 화염 재질만 재구성한다.
