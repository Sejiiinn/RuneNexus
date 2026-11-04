# 빠른 청회색 룬 사냥개 3D 시안

2026-09-27 제작. [승인 단일 시안](../slate-cyan-concept-v1.png)과 [승인 멀티뷰](../slate-cyan-multiview-v1.png)에 따른 정적 3D 원본이다. 게임 이식·리깅·애니메이션은 포함하지 않는다.

- [편집 가능한 Blender 원본](fast-rune-hound.blend): 102개 석판·관절·눈·룬 메시, 원본 procedural 석재 재질, 스튜디오/카메라 분리.
- [대표 3/4 렌더](hero-three-quarter.png), [정면](front.png), [측면](side.png), [후면](back.png), [상면](top.png), [수직에서 25도 기울인 드론 시점](drone-25.png). 모두 같은 최종 모델의 실제 Cycles 렌더이며 조명·시점에 따라 명도가 달라진다.
- [동반 GLB](fast-rune-hound.glb): 같은 모델을 표준 PBR로 구운 정적 뷰어용 파일. 2048px color/roughness/normal/emission atlas를 포함한다. [재수입 렌더](viewer-glb-three-quarter.png).

## 수치와 확인 범위

모델 전체 평가 메시의 실제 삼각형 수는 **20,214**개다. 내부 관절·눈·등 룬을 포함하며 스튜디오 바닥·카메라·조명은 제외한다. [객체별 실측](mesh-stats.json), [원본 재오픈 검사](source-validation.json), [GLB 수치](viewer-export-stats.json)를 기준으로 한다.

낮고 앞뒤로 긴 사족 체형, 큰 뾰족귀 2개, 짧은 쐐기형 주둥이, 청회색 겹돌판, 짙은 관절, 청록 눈과 등 중앙 사각 나선 핵, 위를 향하는 짧은 꼬리와 발마다 3개 주 발가락을 입체 메시로 제작했다. 판의 광물결은 표면 재질이며 판의 두께·단차·모서리와 관절 구조는 실제 기하다.

Blender 5.2.1 LTS / Cycles 48 samples / AgX Medium High Contrast. 원본은 별도 background 프로세스에서 재오픈하여 활성 씬·카메라·102개 모델 메시·삼각형 수를 확인하고 `Fast_Hound_Concept`이 바로 열리도록 저장했다. 기존 열린 Blender 파일과 다른 씬은 삭제하거나 덮어쓰지 않았다. [열린 세션 보존 확인](open-session-preservation.json)에서 기존 파일 경로와 Guardian 씬의 110개 객체가 유지됨을 확인했다.

제작자 시각 확인: 최종 6뷰에서 석판·눈·룬·발가락과 다리 연결을 확인했고, 앞다리/어깨의 초기 코어 관통을 수정했다. GLB 재수입 렌더에서도 색·형상·석재 표현을 확인했다. GLB의 미세 표면 요철은 2048 atlas 해상도로 원본보다 약간 부드럽다. Godot·Android·애니메이션은 이번 작업의 검증 범위가 아니다.

## 재현

기존 Blender MCP 연결에서 [build_fast_hound.py](build_fast_hound.py)를 `__file__`을 지정하여 실행한다. 생성 스크립트는 해당 Hound 씬만 재작성하고 `libraries.write`로 원본을 저장한다. [render_views.py](render_views.py)는 같은 씬에서 카메라만 바꿔 렌더한다. 렌더 결과는 [render-status.json](render-status.json)에 기록된다.

[finalize_source.py](finalize_source.py)는 저장한 파일을 독립 background Blender로 열어 기본 활성 씬을 확정한다. [export_viewer.py](export_viewer.py)는 기존 guardian PBR atlas bake 경로를 재사용하며, [verify_viewer.py](verify_viewer.py)는 GLB 재수입 후 같은 스튜디오로 렌더한다. 제작 중 열린 원본을 교체하지 않고, 이 독립 background 절차에서만 파일 재오픈과 기본 씬 저장을 수행한다.
