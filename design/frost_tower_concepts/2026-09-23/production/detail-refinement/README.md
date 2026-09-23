# 냉각 포탑 기둥·상판 디테일 보완

2026-09-23. 사용자가 지적한 상하 기둥 단절과 얇고 겹친 상판을 [승인 시안 03](../../iris-variants/03-ribbed-reactor.png)에 맞춰 수정했다. 최종 편집 원본은 [production/frost.blend](../frost.blend), 게임용 원본은 [production/frost.glb](../frost.glb)이며 이번 결과의 복사본도 이 폴더에 보관한다.

## 변경

- 상부 청동 캡부터 하부 청동 캡까지 좁은 청동 레일을 연결했다. 기둥의 넓은 짙은 금속 면은 그대로 남겼다. 낮은 기단 소켓과 발 어깨 연결부가 하중을 이어 받는다. 기존 6개 리브·6개 냉각 베이·4개 방사형 발을 유지하고, 리브와 각도가 다른 두 발은 낮은 기단 연결부로 받쳐 냉각 베이 앞을 새 기둥으로 막지 않았다.
- 상판 6장은 원주를 따르는 넓은 바깥 곡선과 같은 방향으로 휘어진 안쪽 곡선을 갖는다. 동일 반경의 판 각폭을 60도보다 작게 해 인접 판이 실제로 겹치지 않으며, 판 사이에 좁은 틈을 남긴다. 끝이 길고 날카로웠던 최초 수정은 채택하지 않았다(`iteration1-*`).
- 판의 실제 세로 두께는 0.0184에서 0.0376으로 늘렸다. 위쪽 높이와 전체 외형 크기(가로·세로 약 0.8183, 높이 0.5344), 렌즈 크기, 6×12 냉각핀의 위치·재질 이름, 청흑 금속·청동 색을 보존했다.
- 상판은 소용돌이 모양으로 **배치**했으며 실제 회전하지 않는다. 게임 충전 셰이더·전투 코드·안개 코드는 변경하지 않았다. 안개 알파 배율 0.36을 유지했다.
- 동일 최종 GLB에서 256×256 RGBA HUD 아이콘을 다시 렌더해 `assets/images/ui/hud/turrets_3d/frost.png`에 적용했다.

## 최종 근거

| 확인 항목 | 근거 |
|---|---|
| 두께·곡선·틈·상하 연결 | [Blender 사선](detail-hero.png), [Blender 상단](detail-top.png) |
| 실제 게임 크기 | [앱 선택 상태](godot/app-angled-selected.png), [드론](godot/app-drone.png) |
| 실제 게임 가까운 형태 | [사선](godot/model-hero.png), [상단](godot/model-top.png), [낮은 구조 시점](godot/structure-low-angle.png) |
| 하단부터 충전 | [실제 충전 중](godot/detail-charging.png) |
| 방전·서리 안개 0.36 | [실제 방출](godot/detail-release.png) |
| 실행·발사·적 감속 | [앱 결과](godot/report.json), [실행 로그](gui.log) |
| 기존 충전·재사용·표시 계약 | [좁은 계약 검사](contract.log), 실패 0 |
| GLB 텍스처 UV | [13개 슬롯 검사](../glb_uv_validation.json), 모두 통과 |
| 최종 원본·게임 GLB·HUD 일치 | [파일 해시와 일치 검사](artifact-verification.json), [HUD 원본 해시](../hud-direction-verification.json) |

Godot 4.7.2 / Apple M4 / Metal Forward Mobile / 660×1100의 실제 `--app`에서 확인했다. 최종 GLB SHA-256은 `18c4a4843673a1092571daa298f201c83a210c8fa5f35c4f5bdcfae178a0c964`이다. Blender 형태 및 실제 Godot 형태·충전·안개는 구현 담당과 별도 검증자가 각각 확인했다.

`verify_ingame.gd`는 기존 실제 앱 검수 흐름을 재사용했다. 별도 `build/godot/frost-detail-refinement`와 `RuneNexus-Frost-Detail-Refinement` 저장을 사용했고 기존 열린 Blender 원본, Godot 편집기·local-play 및 사용자 저장은 덮어쓰지 않았다. `--structure-only`는 게임 모델의 기둥/발 연결 확인을 위해 카메라를 가까이 두고 검수 화면에서만 레벨 배지를 숨긴다. `godot/report.json`의 `video_frames`는 기존 하네스가 센 관찰 프레임 수이며 이번에는 별도 영상 프레임을 저장하지 않았다.

## 자산 비용과 원본 관계

삼각형은 60,512→72,752(+20.2%), GLB는 6,822,540→7,365,020바이트(+542,480, 약 0.54MB)다. 상판의 곡면 경계 샘플·측면 두께·베벨과 상하 레일/소켓/발 연결부의 실제 기하 추가에 따른 증가다. 텍스처 7개, 런타임 메시 3개·재질 표면 19개는 그대로다. 이 수정의 전체 FPS/GPU 시간이나 Android 기기 성능은 측정하지 않았으며 성능 개선을 주장하지 않는다. APK는 만들지 않았다.

`charge-mist-concept/charge-mist.blend`는 이전 외형으로 충전·안개를 승인받은 역사 시안이며 덮어쓰지 않았다. **현재 정적 형상의 편집 원본은 `production/frost.blend`, 현재 동작은 기존 Godot 충전·안개 코드**다. 오래된 시안 Blender를 현재 게임 형상으로 오인하지 않는다. [충전·안개 적용 계약](../../charge-mist-concept/integration/README.md)은 그대로 적용한다.

제작은 [build_frost.py](../build_frost.py), HUD는 [render_hud_icon.py](../render_hud_icon.py)를 재사용한다. `FROST_OUTPUT_PATH`를 설정하면 중간 결과를 별도 폴더에 출력할 수 있다. 제작 전 파일은 `before/`, 변경 전 제작 코드는 `build_frost_before.py`에 보관했다. 관련 변경 범위가 통과한 뒤 전체 전투 회귀나 APK 빌드를 추가하지 않았다.
