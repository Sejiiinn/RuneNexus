# 냉각 포탑 형상 보완 독립 검증

2026-09-23, Astra 독립 검증. **최종 PASS — 요청한 기둥 하단 연속 구조와 6개 곡선판 형상, Godot 적용.** 이전 구현의 PASS를 이번 지적의 반증으로 사용하지 않았다.

승인 `../../iris-variants/03-ribbed-reactor.png`, 이전 `../stage2f-hero.png`, 이전 게임 `../../charge-mist-concept/integration/detail-release.png`를 직접 비교했다. 이전 모델은 청동 연결이 상·하단 탭으로 분절되고, 상판이 얇고 넓은 겹침 판으로 읽혔다. 이를 실제 수정 대상으로 인정했다.

첫 후보는 기둥 연결·판 두께를 개선했으나 긴 직선 쐐기와 뾰족한 끝, 렌즈 주변의 과도한 검은 공백 때문에 **FAIL**을 반환했다. 보존한 `iteration1-hero.png`/`iteration1-top.png`가 해당 결과다. 제작자가 외곽과 폭을 곡선으로 다듬은 최종 `detail-hero.png`/`detail-top.png`를 다시 보고 아래를 확인했다.

| 항목 | 최종 판정·근거 |
| --- | --- |
| 기둥 연속 구조 | PASS. 상단 청동 캡에서 세로 청동 연결을 거쳐 하단 캡까지 이어져 한 구조로 읽힌다. 넓은 청흑색 중심 리브를 보존한다. Blender hero와 `godot/model-hero.png`에서 하단 연결이 확인된다. |
| 6개 두꺼운 곡선판 | PASS. top에서 각 판 사이 빈틈이 있고 판이 포개지지 않는다. 같은 방향으로 휜 배치가 소용돌이로 읽히며 hero에서 측면 두께가 명확하다. 첫 후보의 큰 직선 쐐기 인상과 중앙의 과한 빈 공간이 해소됐다. `godot/model-top.png`/`model-hero.png`에도 재현된다. |
| 주변 승인 외형 | PASS. 얼음 렌즈 개구, 청동 고정부, 6개 냉각 베이, 청흑 금속과 4개 지지발을 유지한다. 게임 조명 차이는 별도 외형 재설계로 확대하지 않았다. |
| 충전·안개·비회전 | PASS. `godot/detail-charging.png`는 하단부터 찬 청록 핀과 어두운 상단을, `detail-release.png`는 방전과 부드러운 3D 안개를 보여 준다. .36 알파 셰이더와 비회전 런타임은 그대로다. 계약 검사 실패 0, 실제 앱 발사·감속 결과와 검수 코드를 확인했다. |
| 실제 표시 크기 | PASS. `godot/app-angled-selected.png`에서 주변 포탑·지형·HUD와 함께 정상 표시된다. 세부 형태 판정은 동일 게임 조명의 근접 화면을 함께 사용했다. |

실제 실행은 Godot 4.7.2 / Apple M4 / Mobile 렌더러, 격리 저장 `RuneNexus-Frost-Detail-Refinement`다. [실행 결과](godot/report.json), [계약 검사](contract.log), [수량 기록](model_audit.json)을 대조했다. 현재 게임 GLB의 SHA-256 `18c4a4843673a1092571daa298f201c83a210c8fa5f35c4f5bdcfae178a0c964`가 실행 결과와 일치한다. 안개 셰이더 해시는 직전 .36 조정과 같은 `c49198d1668a5be9479456e3bb44bb4f40b7484bd16c62a151a1a3b9bfd6557c`다.

모델은 72,752삼각형으로 이전 60,512보다 12,240 증가했고 런타임 3메시·19표면을 유지한다. 이 수량 확인을 프레임 성능 측정으로 해석하지 않는다. Android와 GPU 성능은 이번 검증에 포함하지 않았다. 제품·Blender 수정과 실행은 구현 담당이 수행했고 검증자는 산출물과 코드를 읽어 판정했다. 필수 미해결 사항은 없다.

추가로 `godot/structure-low-angle.png`를 직접 확인했다. 검수용 배지를 숨긴 낮은 시점에서 세로 청동 연결의 하단 캡, 기단과 지지발 접속이 이어짐을 확인했다. 기존 PASS를 보완하며 제품 동작 변경은 없다.
