# 작은 스테이지 보상 아이콘

현재 적용은 **24종 모두 기존 이미지 재사용**이다. [현재 목록](selected-inventory.json). 저격·라이트닝은 기존 `ui/hud/turrets_3d/` 이미지를 쓰고, 원래 이미지가 있던 나머지 21종도 복원했다. 연구 슬롯 II는 사용자가 선택한 기존 청록 플라스크 `stage_rewards/reward_research.png`를 사용하며 오른쪽 위에 금색 `+`를 별도 Label로 겹쳐 추가 슬롯을 표시한다. 원본 PNG는 유지한다. [플라스크 + 적용 화면](flask-plus-user-live.png).

아래 24종 일괄 제작 기록은 이전 제안의 제작·검수 근거다. 미채택 24종은 `unused-game-exports/`와 `originals/`에 보관하며 게임용 에셋 목록에서 제외했다.

플라스크 선택 전의 [24종 렌더](selected-contact-sheet.png)와 [스테이지 10 모달](selected-user-live.png)은 이전 선택 기록이다. 당시 [보상 계약 회귀](selected-regression.log) 통과, [런타임 이미지 일치](selected-verification.json)를 확인했다. 이후 연구 슬롯의 이미지 경로만 기존 플라스크로 변경했다.

## 제작 기준

- 실제 표시 크기는 38px로 유지한다. 큰 실루엣과 명암 면, 제한된 청록·아이보리·금색을 사용한다.
- 주제 한 개와 의미를 보완하는 큰 기호를 중심으로 구성한다. 미세한 장식·글자·입자·불투명 배경판을 넣지 않는다.
- 내장 ImageGen으로 각 항목을 개별 투명 PNG로 병렬 생성했다. 원본은 `originals/`, 정확한 지시문은 `prompts-*.json`에 보관한다.
- `inspect_bounds.py`는 알파 경계만 읽는다. 실제 크롭과 축소는 `prepare_gimp.py`의 GIMP NoHalo 경로를 사용한다. 게임용 PNG는 152×152로 내보내고 38px 슬롯에 표시한다.
- 게임 적용은 `godot/ui/stage_reward_art.gd`의 모달 전용 경로 매핑이다. 기존 보상 식별자·다른 메뉴용 이미지와 포탑 본체 에셋은 유지한다.

## 검증

24종을 실제 38px와 2배 크기로 나란히 렌더한 [전체 비교판](contact-sheet.png)을 부모와 별도 에이전트가 검수해 통과했다([교차 검수](verification.md)). [렌더 로그](preview.log)에서 24개 텍스처 로딩을 확인했고, [스테이지 회귀](stages-regression.log)도 통과했다.

부모가 [실제 앱의 스테이지 1 모달](user-live-final.png)에서 처치 보상·긴급 매각의 작은 크기 가독성과 기존 레이아웃 보존을 직접 확인했다. Godot 4.7.2 / Metal Forward Mobile / 440×900, 아이콘 슬롯 38px. [실행 로그](user-live-final.log), [알파·런타임 해시 일치](verification-inputs.json). 24종 원본·게임용 PNG 모두 존재하고 실제 투명 배경이다. Android 실기기 검증은 이번 작업에 포함하지 않는다.
