# 스테이지 상세 모달 02

승인 원본은 [4개 비교 시안의 우측 상단 02](01-four-concepts.png)이다. 중앙 제목과 상태, 우측 상단 닫기, 무박스 3열 통계, 가로 보상 행과 청록 시작 버튼을 적용한다. 실제 보상 아이콘·내용·잠금·진행 상태와 시작 동작은 기존 계약을 유지한다.

폰트 크기는 후속 요청에 따라 제목 22px, 주요 버튼 18px, 통계 값·보상명·섹션 제목 16px, 상태·분류·안내 12px로 정돈했다. 아이콘과 배치 치수는 유지했다. [실제 적용 화면](typography/user-live.png), [320/440 가독성·모달 검사](typography/check.log).

## 제작

- `production/approved-02.png`: 승인 영역 원본 크롭.
- `production/clean-surfaces.png`: 내장 ImageGen으로 글자와 아이콘만 제거한 소재. 보상 행·헤더·시작 버튼의 원본이다.
- `production/clean-background.png`: 내부 버튼·행·분리선을 제거하고 외곽과 룬 문양을 보존한 배경 소재.
- `production/extract.py`: GIMP 원본 크롭·NoHalo 축소·외곽 알파 내보내기. 편집 가능한 배경은 `production/dialog-frame.xcf`.
- 게임용 파일: `assets/images/stage_details/v2/`. 닫기 버튼과 분리선은 승인 비교 시안에서 직접 추출했다.

ImageGen 편집 지시의 핵심은 원본 02의 색·비율·석재·금색 모서리를 보존하고 텍스트/아이콘만 제거하는 것이며, 배경은 같은 소재에서 내부 UI 면을 제거했다. 재생성된 글자나 가짜 보상 아이콘을 게임에 사용하지 않는다. Godot `StyleBoxTexture`가 모서리를 보존하며, 동적 내용은 표준 Container가 배치한다.

## 검증

독립 검증 기준은 [criteria.md](verification/criteria.md)에 있다. 구현 담당의 [최종 레이아웃·실제 입력 검사](../stage-modal-v2/final-layout-test.log)와 [스테이지 계약 회귀](../stage-modal-v2/stages-regression.log)는 통과했다. 320px 긴 보상명은 [스테이지 8](../stage-modal-v2/final-320-stage8.png)에서 확인했다.

부모는 사용자 테스트 실행을 최신 소스·에셋으로 갱신해 [실제 앱 최종 화면](verification/user-live-final.png)을 직접 확인했다. Godot 4.7.2 / Metal Forward Mobile / 440×900에서 모달은 390×390이며, 기존 테스트 저장을 보존했다. [실행 로그](verification/user-live-final.log), [소스·런타임 해시 일치](verification/user-live-inputs.json). 이번 작업은 Godot 데스크톱 UI 검증 범위이며 APK를 생성하지 않는다.

독립 검증 에이전트의 [실제 AppLifecycle 검사](verification/strict-live.log)도 통과했다. 단계 1·8·11, 같은 모달의 440→320→440 변경, 애니메이션 중 세로 크기 변경, 실제 닫기·잠김 차단·전투 시작 입력을 확인했다. 최종 화면의 시안 비교 및 가독성 검사에서도 미해결 결함은 없었다.
