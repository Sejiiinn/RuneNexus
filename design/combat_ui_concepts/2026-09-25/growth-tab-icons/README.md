# 강화 전투·경제 탭 아이콘

## 채택한 아이콘

2026-09-25. [두 번째 시트의 빨간색 버전](concept-sheet-v2/concepts-combat-red.png)에서 전투 1번 쌍검과 경제 5번 저울을 채택했다. 초기 방패·금화 시안은 아래의 과거 탐색 기록이다.

- [전투 PNG](../../../../assets/images/ui/icons/growth_combat_swords.png): 은색 강철 쌍검·빨간 날과 보석.
- [경제 PNG](../../../../assets/images/ui/icons/growth_economy_scales.png): 청동 저울·금화.

두 아이콘은 256×256 RGBA이며 사각 배경 없이 강화 카테고리 탭에 사용한다. 제작은 ImageGen built-in 편집 **1회로 두 객체를 한 장에 추출**한 뒤 GIMP MCP에서 분리·리사이즈·알파 정리했다. [프롬프트](production/prompt.txt), [생성 원본](production/selected-master.png), [쌍검 XCF](production/combat-swords.xcf), [저울 XCF](production/economy-scales.xcf), [최종 알파·해시 확인](production/alpha-check.json). 외곽과 검 사이·저울 체인 안쪽은 투명하며 약한 배경 잔여 알파를 제거했다.

### 적용 확인

`godot/ui/lobby_growth.gd`에서 두 PNG를 동일 28px로 표시하고 기존 64×33px 탭 버튼을 유지했다. `godot/ui/assets.json`에 등록했다. Godot 4.7.2 / Compatibility / Apple M4에서 실제 Lobby와 격리된 테스트 진행도로 확인했다. [440px 전투](production/440-combat.png), [440px 경제](production/440-economy.png), [320px 전투](production/320-combat.png), [320px 경제](production/320-economy.png). [검증 스크립트](production/verify.gd)의 실제 포인터 입력으로 양방향 탭 전환을 확인했다([로그](production/verify.log)).

별도 Astra 검증 PASS: 승인 형태·색상, 외곽 및 저울 내부의 투명 합성, 선택 상태와 기존 UI 보존을 확인했다. 실행 복사본의 두 PNG와 변경 코드 해시가 최종 원본과 일치한다. Android APK 빌드·실기기 검증은 이번 PNG 교체 범위에서 수행하지 않았다.

## 초기 탐색 기록

2026-09-25. 사용자 요청: 현재 하단 전투/경제 아이콘의 표현 차이를 줄이고 기존 게임 테마와 가까운 이미지 시안을 각각 5개씩 병렬로 제작한다. 이번 범위는 비교 시안이며 게임에 적용하지 않는다.

[확대 가능한 비교 갤러리](gallery.html). 같은 번호의 전투·경제 아이콘이 하나의 스타일 쌍이다. 큰 이미지와 24px 표시, 64×33px 탭의 배치 예시를 함께 제공한다. 배치 예시는 HTML 비교용이며 실제 게임 캡처가 아니다.

| 번호 | 표현 | 전투 | 경제 |
| --- | --- | --- | --- |
| 01 | 정돈된 베벨 금속 | [방패](combat-01.png) | [금화](economy-01.png) |
| 02 | 룬 각인 | [방패](combat-02.png) | [금화](economy-02.png) |
| 03 | 각진 크리스털·금속 | [방패](combat-03.png) | [금화](economy-03.png) |
| 04 | 고대 단조 | [방패](combat-04.png) | [금화](economy-04.png) |
| 05 | 매끈한 에나멜 | [방패](combat-05.png) | [금화](economy-05.png) |

ImageGen built-in으로 각 아이콘을 별도 생성했다. 전투는 어두운 금속·강철·청록, 경제는 같은 위계의 금속·금색을 사용한다. 원본의 의미인 방패/금화와 문자 없는 독립 실루엣을 보존한다. 생성 이미지 자체는 코드 도형으로 대체하지 않는다.

프롬프트와 생성 원본 경로: [전투](combat-prompts.json), [경제](economy-prompts.json). 제작 결과는 이 폴더에 보존하고 `godot/` 및 게임용 `assets/images/`는 이번 시안 작업에서 변경하지 않는다.

## 시안 확인

[전체 비교 이미지](comparison.png)는 위 HTML을 브라우저로 표시한 캡처다. 10개 원본 모두 1254×1254 RGBA이며 실제 투명 픽셀이 있다. 브라우저에서 10개 이미지 로딩과 확대/닫기 동작을 확인했다.

부모 및 별도 Astra 시각 검증 PASS: 10개 원본과 24px 비교에서 방패/금화 의미, 사각 배경·문자 부재, 금속·룬 테마와 각 쌍의 재질을 확인했다. 05 에나멜형의 작은 크기 대비가 가장 명확하다. 일부 후보는 같은 계열 안의 변주여서 특히 경제 02/04의 소형 차이가 작다. 실제 게임 적용·검증은 이번 범위에 포함하지 않는다.
