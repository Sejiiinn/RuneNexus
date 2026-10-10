# 최종 냉각 포탑 게임 반영 확인

게임 GLB는 최종 `efb65415…` / **11,760삼각형**이다. 현재 Godot 소스를 사설 프로젝트에 복사하고 공용 준비 에셋과 import 캐시를 APFS clone했다. 프로젝트 이름과 저장 디렉터리를 분리해 사용자 플레이·공용/편집 프로젝트를 보존했다.

Godot 4.7.2 macOS Mobile renderer에서 실제 `--app`의 앱 수명주기·건설·전투·HUD 경로를 실행했다. 준비/충전 계약 검사/앱 실행은 모두 정상 종료했고 [report.json](report.json)의 실패 목록은 비어 있다. 실제 생성된 냉각 포탑의 3메시에서 **11,760삼각형**을 계산했다. `turret_root → turret_head → turret_barrel → muzzle`, 실제 발사와 적 감속, 일시정지 시 전투 시계 고정, 4배속에서 `.05초 → .2초` 진행과 HUD 4x 활성 상태를 확인했다. 충전 fixture의 초기/부분/완충·개별 시계·방출·정지·재사용 계약은 기존 `godot/verify_frost_charge.gd`로 검사했다.

정식 `prepare_godot_project._prepare_compressed_model_textures`를 사용했다. 최종 냉각 포탑의 4맵은 **압축 mode 2·high_quality=true·normal_map=2·mipmap=true·size_limit=1024**로 import했다. [import-check.json](import-check.json)은 원본/외부화된 GLB의 BIN·노드·메시·accessor·재질 동일성과 4개 원본 맵의 바이트를 기록한다. staged SHA가 다른 이유는 표준 공유 텍스처 URI 외부화다.

대표 실제 화면은 [기본 HUD/선택](app-angled-selected.png), [드론](app-drone.png), [방출·적 감속](app-release-slowed.png), [일시정지](app-paused-release.png), [4배속 HUD](app-4x.png), [부분 충전 근접](detail-charging.png), [방출 근접](detail-release.png), [하부 구조 근접](structure-low-angle.png)이다. 요청한 창 크기는 900×1500이며 실제 캡처 크기·해시는 [summary.json](summary.json)에 기록했다. 1024 압축 조건에서도 서리·금속·청동·렌즈·셔터·핀·하부링에 앞선 UV 찢김/포화/검은 패치가 재발하지 않았다. 전체 스테이지 완주·Android·FPS 검증으로 확대하지 않는다.

공용 `prepare_godot_project.py`도 갱신했다. 편집 helper는 별도 변경된 `project.godot`를 보호하여 전체 갱신을 중단했다. 해당 설정을 보존하고 이전 helper 해시와 동일한 냉각 포탑만 확인한 뒤 GLB·새 4맵·해당 새 맵의 import 정책을 최소 갱신했다. helper 기록에서 해당 에셋 5키만 바꿨으며 다른 설정/에셋은 유지했다. 공용·편집 GLB/맵이 검증 사설 프로젝트와 동일한 결과는 [generated-projects.json](generated-projects.json)에 기록했다.

재사용 실행은 저장소 루트에서 `python3 design/frost_tower_concepts/2026-09-23/meshoptimizer-rebake-10k/scripts/integration/reproduce.py`다. 현재 게임 파일이 승인 최종 SHA인지 확인한 뒤 새 사설 프로젝트에서 검사한다. `scripts/integration/verify_ingame.gd`는 이 실행기에서 환경변수로 출력 경로를 받는다. 실제 게임 코드·전투 수치는 수정하지 않는다. 원시 로그/프로젝트 경로/여분 캡처는 Git 제외된 `checks/integration/`에 남기며 background/실행 Godot는 정상 종료했다.
