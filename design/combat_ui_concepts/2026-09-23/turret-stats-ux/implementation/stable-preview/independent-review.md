# 강화 전환 안정성 독립 검증 — PASS

수정 범위는 강화 미리보기 레벨 표시를 `Lv.7 → 8`에서 `7→8`처럼 간결하게 바꾸어 기존 칸의 글꼴 자동 축소를 방지한 것이다.

320/440 동일 viewport에서 기관총·라이트닝, 7→8 및 9→10을 검사했다. 각 baseline에서 미리보기·확정·재미리보기·닫은 뒤 동일 포탑 재선택을 수행하고 전환마다 중간 캡처 없이 연속 frame_post_draw 8개를 측정했다. 실제 draw_frame 번호의 연속성을 확인했으며 총 32 전환/256 프레임에서 실패가 없었다.

공통 액션 라벨의 font_size, 목표 버튼 font_size/rect, 태그 font_size/rect, 액션 rect, 도크 rect를 baseline과 직접 대조했다. 레벨 글꼴은 440px에서 13, 320px에서 9로 유지됐으며 목표 버튼은 102×32/font11을 유지했다. 확정 시 실제 레벨 상승과 닫기·재선택 시 미확정 상태 복귀도 확인했다. 기존 각 상태별 잘림 검사만으로 안정성을 판정하지 않았다.

대표 `after-440-base.png`, `after-440-preview-settled.png`, `after-320-level9-preview-settled.png`를 직접 열어 시각적으로 대조했다. 목표 버튼 크기 변화는 이번 데스크톱 재현 조건에서 발견되지 않았다. Android 고유 환경이나 미검증 조합에서도 절대 발생하지 않는다고 확장해 판정하지 않는다.

근거: `independent.gd`, `independent-result.json`, `independent.log`, `independent-summary.json`. 최종 소스와 격리 실행 사본의 해시는 summary에 기록했다. 테스트 저장 경로는 기존 전용 RuneNexus-TurretStats-Review이다. 이전 검증·캡처를 덮어쓰지 않았다.
