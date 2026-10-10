# 냉각 포탑 약 1만 삼각형 후보 독립 검증

**PASS — UV 재구성·노멀 재베이크 후 11,760삼각형 시안의 외형 복원과 대표 Godot 표시를 확인했다.** 이 문서는 게임 반영 전 시안 검증이며, 이후 승인된 게임 반영 결과는 [게임 반영 검증](integration-review.md)에 기록했다.

검증 GLB SHA256: `efb65415c4b69e9e25ecd3625b49daed7805bd78eac25a8eda01c24cefc1221f`
검증 packed Blender SHA256: `0a43ba24f0f21f43b462118b36846e54a7289ce843e10ab4a7ced9d59741d082`

| 항목 | 판정과 근거 |
| --- | --- |
| 감량 | 원본 47,912 → 11,760삼각형, 75.45% 감소. 이번 작업의 약 9~12k 목표 범위 충족. |
| 구조·치수 | 7노드·3메시·19표면·13재질, 이름·부모/자식·변환·muzzle 노드가 원본과 같다. 기존 독립 기하 검사에서 499개 부품 모두 보존, 원본 위치 부분집합, 부품별 bounds 동일, component 교차·삭제·새 비다양체 없음. 위치·인덱스가 변경되지 않은 최종판에 해당 근거를 재사용했다. |
| UV·벡터 | 최종 GLB accessor 직접 검사. 텍스처를 사용하는 4,678삼각형의 UV 범위 유효, 양의 면적 중복·퇴화 0. 노멀·탄젠트 유한, mapped 표면 최대 길이 오차 N=1.33e-7/T=7.38e-5, 최대 abs(N·T)=1.27e-4, tangent W=±1. 상수 재질의 겹치는 UV와 사용하지 않는 fallback tangent는 제외했다. |
| 전사 | 구현 중간 NPZ 대신 최종 GLB의 실제 텍스처 재질·UV·인덱스와 embedded PNG를 직접 raster 대조. 1px 내부 1,022,199픽셀에서 색상 black 0·중복 0·퇴화 노멀 0. 이전 v3의 검은 색상 504,022픽셀 문제가 해소됐다. |
| 편집 원본 | 렌더 담당 종료 후 별도 background에서 직접 read-only 재열기: 최종 3메시/11,760삼각형, 숨긴 원본 3메시/47,912삼각형, 11개 이미지 packed, dirty=false. 최종 4맵과 원본 7맵이 각각 GLB 이미지 바이트와 일치. 저장 변경 없이 정상 종료했고 기존 GUI PID10077은 보존했다. |
| Blender 외형 | 같은 카메라·조명의 before/after hero 및 opposite 4장을 직접 확인. 기둥·발 검은 줄, 찢어진 UV, 하부 링 검은 패치, 금속 포화가 해소됐다. 6곡선 셔터와 틈/두께, 72핀의 6베이·12층, 4발의 오목한 창, 렌즈 큰 균열과 깊이, 서리 코팅·청동의 구분이 유지된다. |
| Godot 외형 | `review/`에 보존한 angled/drone 기본·2.5x 확대의 원본/후보 8장을 직접 확인. 원본과 같은 배치·조명·카메라에서 핵심 형태·색·재질을 유지하고 새 검은 이음·구멍·오염이 보이지 않는다. |
| 충전·안개 | 최종판 charge 0/.5/1 및 shot-mist 원본/후보 8장을 직접 확인. 충전 높이와 발광 영역, 준비 상태, 발사 후 감소와 입체 안개가 대응한다. `cold aluminum fins`/`cold circulating core`의 원본 3표면과 이름/계층 유지. 두 재질 사이 일부 fin 면 재배분은 같은 런타임 shader 영역 안에 있으며, 대표 표시에서 영역 손실 없음. |

확대에서는 핀·볼트의 작은 각짐과 균열선 선명도 차이가 남지만, 핵심 형태·서리·청동·렌즈의 읽힘을 훼손하지 않는다. GLB 1px UV 내부의 경계 가까운 basalt 22픽셀에서 tangent-normal Z<-.02가 검출됐고 2px 내부에서는 0이었다. 유한·비퇴화이며 실제 화면의 새 이음이나 검은 면과 연결되지 않아 진단값으로 남겼다.

Godot 근거는 macOS Mobile renderer의 격리된 기존 표현 fixture에서 생성한 1440×3120 SubViewport 캡처이며 PNG 리사이즈 없이 crop했다. [capture-conditions.json](review/capture-conditions.json)의 before SHA는 원본 `7d71195e…`, after SHA는 위 최종 `efb65415…`에 대응한다. 전체 앱 HUD·전투 시간 흐름·저장·Android 실기기·FPS/GPU 메모리 실측은 검증하지 않았다. 이 결과를 해당 항목의 PASS로 확장하지 않는다. 최종 GLB는 2k BC/normal/ORM + 1k emission을 내장한다.

시안 검증 당시 원본 게임 GLB `7d71195e…`, production Blender `ef01cba2…`, optimized-game-distance Blender `d3e08940…`, 기존 33,566삼각형 시안 GLB `48d6fa91…`/Blender `b542396e…`의 해시 보존을 직접 확인했다. 이후 게임 GLB는 승인된 11,760삼각형 후보로 교체했고 47,912삼각형 원본은 고정 Git commit과 SHA로 보존했다([게임 반영 검증](integration-review.md)). 상세 독립 측정과 재열기 로그는 Git에서 제외된 `checks/independent/`에 보관했다.

남은 필수 수정: 없음. 검증은 이 시안과 명시한 대표 표시 범위에 한정한다.
