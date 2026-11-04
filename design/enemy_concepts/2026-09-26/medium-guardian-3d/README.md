# 중형 돌 수호자 — Blender 3D 시안

승인 원본 [08 멀티뷰](../08-medium-guardian-multiview.png)와 체형 기준 [07](../07-medium-cute-guardian.png)을 바탕으로 만든 정적 3D 시안이다. 큰 둥근 돌머리, 파인 눈구멍과 자주색 구형눈, 곡면에 실제 홈을 낸 소용돌이룬, 분리된 몸통과 원형 핵, 두꺼운 석재 팔다리, 좁은 검은 철 관절, 후면 두 석판을 구현했다.

- 편집 원본: [medium-guardian.blend](medium-guardian.blend)
- 제작: [build_medium_guardian.py](build_medium_guardian.py)
- 렌더: [render_views.py](render_views.py)
- 전체 모델: **15,351 triangles**, 7,788 vertices, 89 mesh objects. [통계](mesh-stats.json)
- 실제 Blender 렌더: [정면](preview-front.png) · [측면](preview-side.png) · [후면](preview-back.png) · [3/4](preview-three-quarter.png) · [높은 시점](preview-high-angle.png) · [수직에서 25° 드론](preview-drone-25.png)

Blender 5.2.1 LTS, Cycles 48 samples와 denoising, 1100×1100 PNG, AgX Medium High Contrast. 동일한 3개 Area light와 procedural 석재 재질을 모든 시점에 사용한다. 정면은 -Y, 위는 +Z. 정/측/후면은 바닥 접지가 보이도록 약 4° 내려다보는 정투영이다. 돌의 부피, 눈구멍, 균열과 룬 홈은 실제 mesh이며 외부 이미지 텍스처에 의존하지 않는다.

통계는 evaluated depsgraph의 loop triangles를 합산하며 관절 내부와 룬을 포함한 MODEL 컬렉션 전체를 센다. 스튜디오·카메라·조명·바닥은 제외한다. 20,000 미만 제한에 대해 4,649 triangles 여유가 있다.

Blender MCP로 기존 열린 인스턴스에서 별도 `Medium_Guardian_Concept` scene을 생성하고 `bpy.data.libraries.write({scene})`로 해당 scene과 의존성만 저장했다. 기존 frost 및 C1 guardian scene은 보존했다. 스크립트 재실행은 이 시안의 이름 붙은 scene만 갱신한다. 게임 이식·리깅·애니메이션·APK 빌드는 이번 산출물에 포함하지 않는다.

자체 확인: 6방향 실제 렌더의 형태·눈과 핵·룬·돌 등판·접지 확인 및 triangle 예산 검사. 독립 검증 결과는 부모 작업 보고를 따른다.

재생성 순서: Blender MCP에서 제작 스크립트와 렌더 스크립트를 실행한 뒤, 별도 프로세스로 `Blender --background medium-guardian.blend --python finalize_project.py`를 마지막에 실행한다. 이 단계는 열린 Blender 인스턴스를 변경하지 않고 분리된 라이브러리를 직접 열기 가능한 프로젝트로 저장한다. 최종 파일을 다시 열면 `Medium_Guardian_Concept`와 95 objects가 자동 활성화되며, 라이브러리 빈 씬 경고가 없다. 독립 검증에서 최종 파일 진입점·전체 삼각형 집계·6방향 시각 확인을 통과했다.
