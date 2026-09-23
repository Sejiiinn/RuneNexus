# 포탑 하단 스탯 UX 시안

역할: 2026-09-24 사용자 승인에 따른 포탑 탭 UI 기준과 구현·검증 기록. 06번 시안과 후속 젬 색상별 태그 지시를 구현 기준으로 사용한다.

[승인 시안: 특성·강화 순서 변경](06-action-order.png) · [ImageGen 프롬프트](prompt-06-action-order.txt) · [변경 전 실화면](../../2026-09-22/turret-actions/native/strict-audit/fixed/base-440.png)

사용자는 강화·특성·판매 한 줄을 유지하고 그 아래 영역의 UX 개선을 요청했다. 2026-09-24 피드백에서 큰 숫자 강조 시안을 거절하고 정갈한 스탯 나열을 선호한다고 명시했다. 후속 요청에 따라 스탯 7개를 좌우 2열로 나누고 행 간격과 중앙 여백을 확보했다. 각 열 안에서 항목명은 왼쪽, 값은 오른쪽에 같은 크기로 정렬하고 얇은 구분선을 사용한다. 누적 피해는 목록 아래 별도 요약 줄로 분리했다. 공격 목표는 목록 위 테두리가 있는 선택 버튼으로 표시해 현재 값과 조작 가능성을 드러낸다.

내장 ImageGen으로 실제 화면을 참조해 제작했다. 이미지의 전장·주변 프레임에 생긴 미세 차이는 변경 제안이 아니며, 특성·강화·판매 동작·가격·외형은 보존 대상이다. 06번에서는 사용자 요청에 따라 강화와 특성의 위치만 교환해 포탑 정보 → 특성 → 강화 → 판매 순서로 표시한다. 시안 자체는 스탯 탭의 기본 상태만 보여주며, 구현에서는 젬 링크·강화 미리보기·포탑별 추가 스탯·연구 해금 조건과 실제 수치를 보존한다.

최종 후속 지시: 태그는 대응하는 젬 색깔에 맞춰 구분한다. 공용 `battle_rewards.gd`의 `GEM_COLORS`를 기준으로 물리는 은백색 `F4F7FA`, 원소는 민트색 `9FFFE8`, 경량화기는 금색 `E7C66A`, 중화기는 주황색 `FF8A2A`, 지속피해는 연두색 `9DFF4A`를 사용한다. 대응 젬이 없는 냉각은 기존 `lib/domain/turret/attack_tag.dart`의 하늘색 `7FD8FF`를 보존한다. 실제 분류는 게임 콘텐츠의 damageFamily·attackTags를 따른다. 06번 이미지의 동일한 청록 태그 색보다 이 지시가 우선한다.

사용자는 [04번](04-target-summary.png)의 배치를 긍정적으로 평가하고, 물리·경량화기를 일반 텍스트가 아닌 작은 태그로 감싸 구분해 달라고 요청했다. [05번](05-category-tags.png)은 두 분류를 각각 얇은 테두리와 은은한 배경의 태그로 표시했다. 이 태그와 하단 배치는 06번에서도 유지한다. [04번 프롬프트](prompt-04-target-summary.txt) · [05번 프롬프트](prompt-05-category-tags.txt).

[이전 시안](01-primary-metrics.png)과 [프롬프트](prompt.txt)는 탐색 기록이다. 이미지 제약에 대한 당시 독립 검수를 통과했으나, 사용자가 UX 방향을 거절했으므로 승인 기준으로 사용하지 않는다.

[단일 목록 시안](02-aligned-list.png)과 [프롬프트](prompt-02-aligned-list.txt), [2열 중간 시안](03-two-columns.png)과 [프롬프트](prompt-03-two-columns.txt)는 후속 피드백 이전 탐색 기록이다. 단일 목록 시안은 이미지 제약에 대한 독립 검수를 통과했으나 최신 시안의 기준으로 사용하지 않는다.

04번 독립 Astra 이미지 검수 PASS: 원본·02번과 직접 대조하여 액션 줄과 수치 보존, 7개 스탯의 2열 정렬·간격, 누적 피해의 별도 표시, 공격 목표 버튼 가시성, 테마 및 겹침·누락 여부를 확인했다. 사용자 승인이나 실제 구현·반응형·조작 검증을 뜻하지 않는다.

05번 독립 Astra 이미지 검수 PASS: 04번과 직접 비교해 두 분류의 개별 태그 표현, 2열 스탯·목표 버튼·누적 피해·상단 액션 줄 보존, 겹침·누락 없음을 확인했다. 이미지 시안 범위의 판정이다.

06번 독립 Astra 이미지 검수 PASS: 05번과 대조해 포탑 정보 → 특성 → 강화 → 판매 순서, 각 버튼의 색·아이콘·수치, 분류 태그·2열 스탯·목표·누적 피해 보존을 확인했다. 이미지 시안 범위의 판정이다.

## 실제 구현과 검증

Godot UI의 포탑 액션 순서, 태그, 스탯 목록, 목표 버튼과 누적 피해 요약을 적용했다. 각 태그는 콘텐츠의 실제 분류와 공용 젬 색을 사용한다. 스탯 수에 맞춰 영역 높이를 확보하고, 추가 항목의 스크롤과 강화 미리보기의 현재값·다음값을 유지한다. 누적 피해는 기존 전투 런타임의 직접·범위·연쇄·화상 합계를 계속 읽으며 표시 갱신 때문에 본문을 다시 만들지 않는다.

실행 환경: Godot 4.7.2, macOS Metal Forward Mobile, 격리 프로젝트 `build/godot/run-upgrades-review`, 전용 저장 `RuneNexus-TurretStats-Review`. 사용자 플레이 및 열린 에디터는 변경하지 않았다. Android APK·실기기·배포는 이번 범위에서 수행하지 않았다.

- [440px 실제 화면](implementation/base-440.png) · [320px 실제 화면](implementation/arrow-320.png) · [320px 강화 미리보기](implementation/arrow-preview-320.png)
- [실클릭·레이아웃 검사](implementation/verify.gd) · [결과](implementation/result.json) · [로그](implementation/verify.log): 기본 7항목과 조건부 항목, 태그 색·크기, 목표 연구 잠금/해금 및 변경, 강화 미리보기/확정, 젬 링크 왕복, 특성 선택, 판매 취소/환급, 골드 부족·최대 레벨 확인.
- [누적 피해 검사](implementation/live-damage.gd) · [로그](implementation/live-damage.log): 0이 아닌 직접·범위·연쇄·화상 합계 갱신 및 본문 인스턴스 유지 확인.
- [긴 가격 검사](implementation/dense.gd) · [로그](implementation/dense.log): 320/440px의 긴 포탑명·강화 미리보기·가격 표시 경계 확인.

최초 실화면 검수에서 발견한 과도한 스탯 영역 높이·320px 누적 피해 가림과 전장 비침을 수정했다. 수정 상태의 실제 캡처에서 기본 항목과 요약 표시, 남색 배경 가독성을 부모와 별도 Astra 검증자가 직접 확인했다.

최종 독립 검증 **PASS**. 실제 클릭·레이아웃 1,218 검사, 누적 피해 갱신 3 검사, 긴 가격 회귀와 기존 `verify_battle_hud.gd`가 통과했다. [독립 검수](implementation/strict-review.md) · [소스·실행 사본 해시](implementation/source-evidence.json) · [기존 HUD 회귀 로그](implementation/battle-hud.log). Android 실기기 터치·밀도는 미검증이다.

## 강화 전환 크기 후속 수정

사용자가 강화 전환 시 글꼴·공격 목표 박스 크기 변화를 지적해 같은 화면 폭의 전후 상태를 추가 측정했다. 재현된 문제는 `Lv.7 → 8`처럼 길어진 레벨 문구의 자동 글꼴 축소였다. 미리보기에서는 `7→8`로 간결하게 표시해 기본 글꼴 크기를 유지한다. 일반 상태의 `Lv.7`, 강화 미리보기·확정 동작과 버튼 구조는 유지한다. 공격 목표는 320/440px의 같은 화면 폭에서 전후 모두 102×32px·11px 글꼴로 측정돼 별도 크기 변경을 적용하지 않았다. 위 기존 검수는 각 상태의 가독성·동작 확인이며 전환 중 크기 동일성을 검증한 결과로 간주하지 않는다.

[후속 측정·수정 기록](implementation/stable-preview/README.md) · [440px 수정 후 미리보기](implementation/stable-preview/after-440-preview-settled.png) · [320px 9→10 미리보기](implementation/stable-preview/after-320-level9-preview-settled.png).

후속 독립 검증 **PASS**: 320/440px 기관총·라이트닝의 7→8 및 9→10, 미리보기·확정·닫기 후 재선택 32회 전환의 연속 256프레임에서 글꼴·목표·태그·액션·도크 크기 유지 확인. [독립 판정](implementation/stable-preview/independent-review.md) · [요약](implementation/stable-preview/independent-summary.json). Android 고유 환경은 미검증이다.
