# 빠른 룬 하운드 게임 통합 독립 검증

판정: **PASS — 이번 Godot 데스크톱 통합 범위**. 2026-09-28, 구현 담당과 별도 Astra 검증. 수정 없이 최종 코드와 실제 게임 근거를 대조했으며 결함을 발견하지 않았다.

- 승인 v9 export의 Run 34/60초·stride 0.6445833333333333타일·표시 배율 0.48이 기존 fast 스탯과 연결된다. `guardian_preview.gd`는 네이티브 누적 이동 거리로 위상을 정하고 전투 시계로 몸 회전만 보간한다. 전투·저장 계약 변경은 없다.
- `battlefield_units.gd`의 fast 생성·갱신·소멸 경로와 종별 상태 메시/skin/skeleton 연결을 독립 대조했다. normal의 걷기·0.6초 붕괴 조건은 유지되며 fast 처치는 기존 즉시 제거를 유지한다. 공용 burn clock, 성에 원본 재질 복원, 종별 atlas·정규화 계수가 분리된다.
- [status-bake.json](status-bake.json)의 최종 GLB SHA-256 `9c81ac6b2ed60bbb534f6082e17cf5e79c4d8f231f458915effd268ece41f245`와 생성 리소스·실제 실행 기록을 확인했다. 집중 검사 소스를 별도로 읽어 거리 위상/정지·회전·상태 해제·두 종 동시 스킨/성에·fast 제거·rewind의 검증 대상을 대조했다. 실행 결과는 `SKINNED_ENEMY_PRESENTATION PASS failures=0`, prepare 검사 3개 성공이다.
- 실제 stage 1 wave 4·네이티브 전투·HUD가 포함된 [1x 영상](hound-gameplay.mp4), [4x 영상](hound-gameplay-4x.mp4)의 원본 캡처 중 `angled-status/00180,00195,00210.png`와 `drone-4x/00035,00038,00041.png`를 직접 확인했다. 두 시점의 게임 크기에서 하운드 몸체·석재/청록 표현·진행 방향 및 상태 부착에 분리/왜곡이 없고 normal 가디언과 공존한다. 연속 근거에서 4x 경로 진행과 1x 슬로우 전투/fast 제거를 확인했다. JSON의 fast 100007/100008/100009 처치는 15.433/17.067/18.8초이며 normal 붕괴도 함께 발생한다.

실행 조건은 Godot 4.7.2, macOS Metal/mobile renderer, 440×900, 격리 저장, 실제 콘텐츠와 포탑 명령을 쓰는 검수용 배치/예산이다. 승인 v9 원본 모션의 재심사는 하지 않았다. 일시정지는 집중 위상 계약으로 확인했으며 별도 정지 화면을 실검증했다고 주장하지 않는다. Android 실기기·성능은 **미검증**이고 APK를 만들지 않았다. 이번 범위의 미해결 결함은 없다.

## 효과·크기 수정 후 독립 재검토

Astra 검증자 review_hound_game_integration: PASS. 최신 냉각 00180→해제00195, fast 화상 angled-status-burn/00127 및00232 직접 확인. 일반형+15%/빠른형−10%, 보폭 및 일반형 사망 크기, 체력바 배치, 실제 emission 마스크와 종별 화염 환산을 확인했다. 전투·저장 계약 변경 및 미해결 결함 없음.
