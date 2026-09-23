# 강화 전후 레벨 글자 크기 수정

동일 화면 폭에서 강화 미리보기를 누르면 `Lv.7`이 `Lv.7 → 8`로 늘어나며 `TurretActionPanel._fit_label()`이 레벨 글꼴을 축소했다. 440px에서 13→11px, 320px에서는 9→8px가 재현됐다. 공격 목표 버튼은 재현 계측 전체에서 102×32px / font 11로 동일했다. 강화/강화 확정 제목과 액션 버튼 크기도 동일했다.

소스 수정은 `godot/ui/hud_turret_panel.gd`의 레벨 표시 1줄이다. 일반·확정 후 `Lv.7`, 미리보기 `7→8` 형식으로 바꿔 기본 글꼴 크기를 유지한다. 액션 순서·색·태그·목표 버튼·스탯 레이아웃은 변경하지 않았다.

## 검증 근거

- Godot 4.7.2 / Metal 4.0 Forward Mobile / Apple M4, `build/godot/run-upgrades-review`, 저장 `RuneNexus-TurretStats-Review` 사용. 공용 에디터와 사용자 플레이 인스턴스는 조작하지 않았다.
- `before-measurements.json`: 수정 전 각 전환 직후 8회 샘플과 정착 상태. 초기 계측에서 내부 스크롤바의 `get_index()` 경고가 발생했으며, 이름으로 찾은 목표·액션 및 레벨 라벨 계측에는 영향이 없다. 320px 원본 계측은 8→9 전환이다. 캡처 대기로 일부 프레임을 건너뛰므로 연속 8프레임 자료로 취급하지 않는다.
- `after-measurements.json`, `after.log`: 440×900, 320×760, 7→8·9→10 미리보기/확정. 각 전환 첫 연속 8표시 프레임과 정착 상태를 기록했다. `draw_frame`의 연속성을 확인한다. 76상태, 레벨 13/9px 유지, 목표 버튼과 모든 상단 액션의 위치·크기 동일. 최종 로그 오류 없음.
- `compare.py`, `result.json`: 관련 글꼴·geometry 및 실제 프레임 연속성 176검사, 실패 0.
- `font-width.log`: 합성 두 자리 전환 `19→20`, `88→89`, `98→99`는 13px에서 폭45 / 9px에서 폭31로 실제 레벨칸48/34 안에 들어간다.
- 대표 실제 실행 캡처: `after-440-base.png`, `after-440-preview-settled.png`, `after-440-confirmed-settled.png`, `after-320-level9-preview-settled.png`. 구현 담당이 440 미리보기와 320의 9→10 미리보기 화면을 직접 확인했다. `*-frame-*.png`는 첫 자체실행의 중간 샘플이며 최종 연속프레임 근거는 JSON을 따른다.

최종 소스/격리 프로젝트 사본 `hud_turret_panel.gd` SHA-256: `08c6ae4e8896445e1cbd6bca4aea232da1b374c1a5b22f022b911070b1cb4ff7`.

공격 목표 크기 변경은 이 조건에서 미재현이다. Android 검증은 수행하지 않았다. 독립 검증 판정은 별도 검증 담당 기록을 따른다.
