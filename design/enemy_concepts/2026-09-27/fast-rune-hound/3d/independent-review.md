# 빠른 룬 사냥개 3D 시안 독립 검토

2026-09-27. 구현 담당과 별도 Astra 검증자가 승인 [단일 시안](../slate-cyan-concept-v1.png)·[멀티뷰](../slate-cyan-multiview-v1.png), 최종 실제 렌더와 저장 원본을 대조했다. 범위는 편집 가능한 정적 3D 시안과 약 2만 삼각형 예산이다. 게임 이식·리깅·애니메이션·실기기 성능은 대상이 아니다.

## 판정

**PASS.** 핵심 형태·색·석재 입체성과 요청 예산을 충족한다. 완료를 막는 미해결 결함은 없다.

| 항목 | 결과·근거 |
| --- | --- |
| 실루엣·비율 | PASS. [사선](hero-three-quarter.png)·[측면](side.png)에서 긴 몸통, 낮춘 쐐기형 머리, 큰 뾰족귀, 굽힌 사족과 상향 분절 꼬리가 유지된다. |
| 돌판·관절 | PASS. 두꺼운 청회색 석판의 베벨·측면과 어두운 내부 관절이 분리된다. [정면](front.png)·[후면](back.png)에서도 실제 부피가 확인된다. 최종 사선에서 초안의 전완 내부 기둥·어깨 관통은 해소됐다. |
| 눈·핵 | PASS. 밝은 청록 눈과 등 중앙 사각 나선 핵이 석재보다 높은 명도로 읽힌다. [탑뷰](top.png)와 [수직에서 25° 기울인 드론](drone-25.png)에서 핵 위치·부피·가독성을 확인했다. |
| 발 구조 | PASS. 네 발과 각 3개 주발가락을 실제 렌더와 원본의 12개 개별 toe 메시로 확인했다. |
| 메시 예산·재오픈 | PASS. 별도 Blender background에서 최종 원본을 직접 열고 evaluated depsgraph의 MODEL 전체 loop triangles를 독립 집계했다. 102개 메시, 10,309정점, **20,214삼각형**으로 18,000~22,000 범위다. 스튜디오 바닥·카메라·광원은 제외했다. 빈 메시·비정상 좌표·재질 누락·외부 이미지 의존성은 없다. [독립 집계](independent-source-inspection.json). |
| 동반 GLB | PASS. [재수입 렌더](viewer-glb-three-quarter.png)를 사선 원본과 직접 대조했다. 형태·색·발광이 유지된다. GLB 바이너리 독립 파싱으로 20,214삼각형과 내장 color/roughness/normal/emission PNG 4개, 외부 버퍼 의존성 없음을 확인했다. 초안 기하 잔존 우려를 추가 검증하여, 최종 원본 evaluated 정점과 GLB 재수입 정점의 양방향 최근접 좌표 차이가 모두 **0.0**임을 확인했다. [기하 대조](independent-glb-geometry.json). |
| 기존 작업 보존 | PASS. 제작 코드의 별도 씬 생성과 scene-only library 저장, 별도 background에서 신규 파일만 최종 저장하는 경로를 확인했다. 제작 담당의 종료 시 MCP 실측 [기존 세션 보존 기록](open-session-preservation.json)은 기존 frost-optimized.blend 경로·dirty=false, 원래 Guardian_WholeExit_TilePreview 씬과 110개 오브젝트 보존을 보여 준다. 기존 파일의 전후 전체 해시 비교까지 수행한 것은 아니다. |

## 입력·환경과 제한

- 검증 원본: [fast-rune-hound.blend](fast-rune-hound.blend), SHA-256 `4af29a8005bc3fa37c45927f1b7e6c28a41c75397ded726a6f877d7ad61c2b1d`. 독립 검사 전후 해시가 같고 제작자의 최종 원본 기록과 일치한다. 검증자는 활성 Blender 씬이나 원본을 수정하지 않았다.
- Blender 5.2.1 LTS. 실제 시안 렌더는 Cycles, AgX / Medium High Contrast, 정투영 카메라다. [렌더 스크립트](render_views.py)와 [완료 상태](render-status.json)의 6개 뷰를 모두 직접 확인했다.
- 원본 이미지보다 석판의 세부 분할과 발 형태가 단순하며, 측면의 어두운 몸통 노출이 조금 넓다. 핵심 사냥개 실루엣·석재 정체성·입체성을 바꾸는 차이로 보지 않는다. 생성 멀티뷰 자체의 미세한 뷰 간 모순을 정확한 3D 치수 계약으로 취급하지 않았다.
- 동반 GLB는 2048 PBR 아틀라스로 인해 확대 시 미세 표면 요철이 제작 원본보다 약간 부드럽다. 현재 판정은 Blender 재수입 결과에 한정하며 Godot/Android 이식 완료나 성능 보증을 의미하지 않는다.
