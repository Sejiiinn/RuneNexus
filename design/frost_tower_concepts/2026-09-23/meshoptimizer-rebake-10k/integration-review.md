# 냉각 포탑 게임 반영 독립 검증

**PASS — 최종 11,760삼각형 에셋이 실제 앱에서 로드되고, 기존 생산 import 정책에서 외형·충전·방출·감속·정지·4배속 계약을 유지한다.** 커밋·푸시는 부모 담당이다.

게임 GLB SHA256: `efb65415c4b69e9e25ecd3625b49daed7805bd78eac25a8eda01c24cefc1221f`
검증 staged GLB SHA256: `c3b58fca0c1f53e922931fce37db4b2fcd2bae6dd452feac8d6c9ddea7d5f857`

| 검증 대상 | 직접 확인한 근거와 판정 |
| --- | --- |
| 게임 입력 | `assets/images/stage1_3d/turrets/frost.glb`가 승인 후보와 바이트 단위로 동일. 실제 `battlefield_units.gd`의 frost 경로는 `res://assets/turrets/frost.glb`. 앱의 실제 인스턴스 index count 집계가 3메시·11,760삼각형이며 rig markers도 유지된다. |
| externalize | staged GLB는 images의 shared URI 표현만 변경. BIN 전체와 images 이외 JSON이 후보와 동일하고 외부 4맵 바이트가 embedded 4맵과 일치. |
| 공유·편집 동기화 | `build/godot/project`와 `build/godot/editor`의 frost GLB가 검증 private staged GLB `c3b58fca…`와 byte exact. 참조 4맵도 byte exact이며 명시한 생산 import 설정 6개가 모두 일치한다. private `.import`에 추가된 Godot 기본 항목은 설정 충돌이 아니다. 현재 편집 project.godot SHA `d01ea40bd533e16eefd522ddb19e7bd2a0fa3c6d8a631c694d32202d19db47bb`가 동기화 전후 기록과 일치한다. |
| 생산 import | 실제 shared 이미지 `.import`에서 compress/mode=2, high_quality=true, normal_map=2, mipmaps=true, size_limit=1024 확인. BPTC/ASTC import 산출물이 생성됐다. 이전 2K lossless fixture만으로 판단하지 않았다. |
| 최신 앱 입력 | 병합 후 HEAD `4f53dc39434bea8c8e515d3b3e5bdc2a3760d633`의 godot source 396파일과 private project를 직접 대조해 누락·변경 0. 격리를 위한 project 이름만 제외했고 최신 `dc1bba84` 포함도 확인했다. |
| 실제 앱 시각 | `integration/`의 angled-selected, drone, release-slowed, paused-release, 4x HUD 5장과 detail-charging, detail-release, structure-low-angle 3장을 직접 열어 검수. 실제 1024 압축 맵에서 핵심 셔터·서리·청동·렌즈·핀·발의 형태와 구분 유지, 새 검은 줄·재질 포화·이음 결함 없음. 일시정지 overlay와 4x 선택 HUD도 일치한다. |
| 전투 계약 | 최종 `report.json`과 실행 코드·로그 대조. 실제 앱에서 건설한 포탑과 native runtime을 step하여 shotSequence 증가 및 적 slowInstances를 관찰했고 `fired=true/slowed_observed=true`. 정지 상태 clock 불변, 4x에서 .05초 입력→.2초 clock 증가, HUD4x=true, failures=[] 확인. 감속 상태를 검수 코드가 강제로 주입하지 않는다. |
| 관련 회귀 | 실제 격리 프로젝트의 `verify_frost_charge.gd` 결과 `FROST_CHARGE_CHECK failures=[]`. 독립 충전, 대기 유지, 발사 리셋·안개, pause/rewind, 판매·재사용·해제, 복원 snapshot, light cap 관련 check 실행을 코드와 대조했다. |
| 격리 | 프로젝트·사용자 데이터 경로가 `RuneNexus-Frost-Rebaked-Integration-…` 전용. stage unlock/tutorial 준비는 이 세션에 한정한다. 사용자 플레이 저장은 사용하지 않았다. |
| 제작 재현 | `source_input.py`가 원본 commit `d83e73f32ee59112505b7e00c9222c4b774b0ef8`과 SHA `7d71195e…`를 고정해 복원한다. 해당 Git blob 해시를 직접 확인. geometry/bake는 이 입력을 사용하며 비교 studio·conditions는 이 폴더에 있어 untracked meshoptimizer-preview 필수 의존성이 없다. |

기하·UV·packed Blender 검수는 후보 SHA가 동일한 [시안 검증](review.md)을 재사용했다. 작은 각짐·균열선 차이까지 무손실이라고 보증하지 않으며 실제 게임 크기와 근접 화면에서 요청한 외형을 유지하는 것으로 판정한다.

편집 helper state의 다른 필드·기존 asset key 보존은 구현 시 메모리에 읽은 원본과 변경 5키를 제외한 equality assert로 검사했다는 실행 근거가 있다. before JSON 덤프는 없으므로 이 state 전후 대조를 별도의 독립 PASS로 표시하지 않는다. GLB·4맵·명시 import 설정·현재 config SHA는 독립적으로 직접 대조했다.

실제 근거: [앱 실행 보고](integration/report.json), [import 입력](integration/import-check.json), [충전 근접](integration/detail-charging.png), [방출 근접](integration/detail-release.png), [4배속 HUD](integration/app-4x.png). 원시 로그·독립 asset/source/hash 측정은 ignore된 `checks/`에 보관했다. 관련 실행 로그에는 기존 다른 적 에셋의 UID 경고와 텍스트 경로 fallback이 있었으며 냉각 포탑의 로드·스크립트 오류는 없었다.

Android 실기기·APK·FPS·GPU 메모리 실측은 이번 범위에서 수행하지 않았다. 전체 전투 회귀의 PASS로 확장하지 않는다. 남은 필수 결함 없음.
