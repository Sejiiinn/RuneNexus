# 강화 레벨업·룬 비용 프레임 재제작

2026-09-25. 사용자 요청에 따라 두 프레임 에셋 자체를 ImageGen으로 다시 만들고 강화 화면에 연결했다. 원본의 오른쪽 금색 테두리 불연속을 정상 장식으로 해석했던 이전 판정은 철회한다.

## 최종 산출물

- [레벨업 프레임](../../../../assets/images/ui/components/upgrade_levelup_frame_v2.png): 604×136 RGBA, 닫힌 청록 금속 프레임.
- [룬 비용 프레임](../../../../assets/images/ui/components/upgrade_rune_cost_frame_v2.png): 320×108 RGBA, 좌우 대칭 형태의 닫힌 금색 프레임.
- ImageGen 생성 원본: [레벨업](remade/levelup-master.png), [룬 비용](remade/rune-cost-master.png). [최종 생성 프롬프트](remade/prompts.json).
- GIMP 제작 파일: [레벨업 XCF](remade/levelup-frame.xcf), [룬 비용 XCF](remade/rune-cost-frame.xcf). 기존 열린 사용자 문서는 보존했다.
- 원본의 미세한 투명 픽셀 여백을 제외하고 GIMP MCP로 명시적 크롭·리사이즈했다. 레벨업 원본 crop=(38,187,1855,421), 비용 crop=(61,105,1743,598). 외부 알파 0, 중심 알파 253~254이며 배경 체크무늬는 없다.

## 연결·검증

`godot/ui/lobby_growth.gd`의 강화 구매 버튼에만 신규 에셋을 사용하고 `godot/ui/assets.json`에 등록했다. 기존 공용 PNG와 `lobby_frame.gd`는 변경하지 않았다. 1/4 논리 해상도에서 레벨업 nine-patch center=(12,5,127,24), 비용 center=(10,6,60,15)로 양끝을 고정한다. 비용 콘텐츠 여백은 좌우9·상하7이며 이전 우측18 보정은 제거했다. 가격 계산·구매·해금·최대 레벨 계약은 유지한다.

- 실제 Godot UI 렌더: [440 전투](remade/frames-440-전투.png), [320 다섯 자리 비용](remade/frames-320-long.png), [320 경제](remade/frames-320-경제.png), [재화 부족](remade/frames-320-disabled.png), [최대 레벨](remade/frames-440-maximum.png).
- 부모 및 별도 Astra 시각 검증 PASS. 노드 사각형만이 아니라 금색 테두리 네 변이 숫자 전체를 감싸는지 직접 확인했다. 청록 테두리·양끝 비율·문구 가독성도 확인했다.
- [배치·실제 클릭 검사](remade/frames.log) PASS: 320/440 전투·경제·65620·부족·최대 상태, 비용 위치 클릭 구매 및 비활성 차단. [기존 강화/연구 회귀](remade/regression.log) PASS. [실행 스크립트](verify.gd), [최종 입력 해시](remade/inputs-sha256.json).
- 환경: Godot 4.7.2 stable, macOS Apple M4, GL compatibility. `build/godot/upgrade-cost-review/godot` 격리 프로젝트의 실제 Lobby UI/카탈로그와 테스트 진행도를 사용했다. 사용자 플레이 저장을 읽거나 바꾸지 않았다.
- 별도 확인 창은 `COST_PREVIEW=1`로 동일 스크립트를 실행하며 제목은 `RuneNexus · 강화 프레임 확인 (테스트 저장)`이다. 기존 플레이/편집기 세션은 재시작하지 않았다. Android 빌드·설치·실기기 검증은 수행하지 않았다.

`before-*`, `after-*`, `cap-fixed-*`와 이전 로그는 재제작 전 비교 자료다. 특히 `after-*`의 초기 요청 충족 PASS는 사용자 지적을 놓친 판정이므로 철회하며, 최종 근거로 사용하지 않는다.
