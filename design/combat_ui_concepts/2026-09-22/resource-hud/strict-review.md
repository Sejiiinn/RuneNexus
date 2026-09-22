# ResourceHUD 독립 검증

2026-09-22. **PASS — 상단 정보창 테두리 정리의 데스크톱 적용 범위.** 구현 담당자 종료 후 별도로 실제 Godot를 실행하고 최종 화면을 직접 확인했다. 구현 코드는 수정하지 않았다.

- [이전 320](before-top-320.png)·[이전 440](before-top-440.png)과 [독립 최종 320](strict-top-320.png)·[독립 최종 440](strict-top-440.png)를 직접 비교했다. 이전 바깥쪽 1px 선과 모서리 밖에 분리되어 보이던 밝은 조각이 정리됐다. 새 프레임에는 바깥으로 튀는 조각이나 9-slice 이음새가 보이지 않는다. 기존 금속의 평행 레일·비스듬한 모서리 연결·짙은 청록 내부는 유지된다. 단순히 alpha가 있다는 이유로 통과시키지 않고 실제 작은 배율의 모서리와 전체 외곽을 대조했다.
- 새 `resource_panel.png`는 376×160 RGBA다. 최외곽 네 변의 불투명 픽셀은 0개이고, 네 모서리는 alpha=0이다. 금속 레일의 (7,2)/(14,2)/(2,14)는 alpha=255로 남아 외곽 잔여 제거와 레일 보존을 확인했다. 원본 `panel_frame.png`의 다른 사용처는 이 변경의 대상이 아니다.
- 실제 `ResourceHUD`는 `PanelContainer` + 전용 Theme 변형 + `StyleBoxTexture`이며 고정 모서리 14px와 콘텐츠 여백 8px가 분리된다. 해당 프레임에 수동 9조각 draw·중복 외곽 프레임·전체 scale이 없다. 모든 하위 Control.scale=(1,1)을 검사했다.
- 크기는 320 화면에서 (8,8), 304×94, 440에서 (8,8), 424×94로 유지됐다. 모든 정보 라벨의 실제 글자 폭과 컨트롤 경계가 프레임 안에 들어온다. 골드3000·파편100·전투력0.0·HP20/20·웨이브1/40·다음 적·예상보상(+23 G/파편1), 적 아이콘·체력바·홈 아이콘 및 위치를 유지한다. 새 잘림이나 프레임 겹침은 없다.
- 두 화면 크기에서 viewport에 `InputEventMouseMotion`/`InputEventMouseButton` press/release를 주입해 홈 → 스테이지 메뉴 → 닫기를 확인했다. 액션 콜백 직접 호출로 대체하지 않았다. [독립 하네스](strict_capture.gd), [실행 로그](strict.log). 실행 오류·경고·리소스 누락은 없었다.
- 환경은 Godot 4.7.2 / macOS Metal Forward Mobile / Apple M4, 기존 격리 프로젝트 `build/godot/hud-review-v4`다. `RuneNexus-HUD-review-v4` 사용자 경로를 실행 중 assert했다. 사용자 플레이 저장은 검사하지 않았다.
- 실제 입력인 `battle_hud.gd`, 관련 4 presenter, `assets.json`, 새 PNG의 원본/격리본 SHA를 대조하고 실행 후에도 원본이 같은지 확인했다. [입력 해시](strict-inputs.json). 별도 동시 작업인 presenter 분리의 전체 완료·회귀는 이번 PASS의 대상이 아니다.

Android 실제 기기·배포는 미검증이며 APK를 빌드하지 않았다. 이전 포탑 액션 독립 PASS 범위를 다시 전체 검사하지 않았다.
