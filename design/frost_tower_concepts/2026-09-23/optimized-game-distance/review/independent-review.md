# 냉각 포탑 경량화 독립 검수

**PASS.** 원거리 QHD 외형과 실제 게임 충전·방출 연결을 유지한 경량본이 게임 에셋에 적용됐다. 미해결 결함 없음.

- **72,752 → 47,912삼각형(34.14% 감소)**, GLB **12,576,616 → 11,371,160바이트(9.58% 감소)**를 독립 파싱으로 확인했다. 3메시·19표면·13재질·7이미지는 유지한다.
- 모든 노드/변환·재질 정의·텍스처 바인딩이 원본과 동일하다. 7이미지의 payload 바이트도 동일하여 서리·금속·청동 표현을 위한 원본 텍스처가 보존된다. `cold aluminum fins`와 `cold circulating core` 이름/표면을 유지하여 현재 충전 shader가 연결된다. [수치 결과](asset-comparison.json).
- 실제 QHD 양 시점 native 비교를 직접 확인했다. 6장 곡선 셔터의 틈·옆면, 중앙 얼음 렌즈, 원통과 냉각 베이, 4지지발, 얇은 서리와 금속이 유지된다. 원거리에서 의미 있는 식별 정보 손실은 발견하지 못했다. 투영 외곽 범위도 원본과 같다.
- 게임 `assets/images/stage1_3d/turrets/frost.glb`는 승인 후보 SHA `7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39`와 동일하다. 격리 import 입력의 노드·메시·accessor와 정점/인덱스, 외부화 텍스처를 직접 대조해 원본 payload 보존을 확인했다. [독립 import 확인](import-identity.json).
- [실렌더러 충전 계약 검사](../integration/frost-charge.log)는 failures=[]다. 고정 비회전/무반동, 아래에서 위 충전의 재질 선택, 준비 상태 유지, 단발 방출, 안개 반경·전투 시계·정지·재사용 계약을 확인한다.
- [실제 앱 결과](../integration/report.json)는 건설·발사 fired=true·적 감속 slowed_observed=true·실패 0이다. [충전](../integration/detail-charging.png)과 [방출](../integration/detail-release.png) 최종 화면을 직접 확인했다. 하부 핀부터 청록 충전광이 차오르고 방출 후 광량이 줄며 포탑 중심의 입체 안개가 연결된다. 셔터/렌즈 고정과 금속·서리를 유지한다. 최초 앱 캡처의 비동기 초기화 대기 부족은 제작자가 정상 준비 대기로 수정했고 최종 실행은 통과했다.

## 비교 화면·조건

각 비교는 **왼쪽 원본 / 오른쪽 경량**이며 원본 픽셀을 그대로 배치했다.

- [고정 시점 1:1 비교](angled-native-pair-left-original-right-optimized.png)
- [드론 시점 1:1 비교](drone-native-pair-left-original-right-optimized.png)
- 고정 전체: [원본](original-angled-full.png), [경량](optimized-angled-full.png)
- 드론 전체: [원본](original-drone-full.png), [경량](optimized-drone-full.png)

실제 1440×3120 SubViewport·3D 배율 1.0·2× MSAA·Mobile 렌더다. 앱 기준 440×760 expand → 논리 440×953.333, HUD 전장 (8,110,424,651.333), safe=0, 줌 1.0, 동일 타일/방향/조명을 사용했다. 양쪽에 현행 `FrostTower.configure`와 충전 완료/안개 없음 상태를 동일 적용했다. HUD는 표시하지 않고 전장 맞춤 영역만 재현했다. [상세 조건](capture-conditions.json), [재현기](reproduce.py).

비교 원본은 고정 커밋 `1bb0c1365481d05183c6c4110310a35add423a25`에서 임시 추출하며 SHA `e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544`를 검사한다. 게임 교체 뒤에도 원본 비교를 재현할 수 있다.

삼각형 감소는 확인했지만 표면 수·텍스처 메모리는 그대로다. macOS Godot 결과이며 Android 실기기 FPS·GPU 시간 개선은 미검증이다. 새 APK·커밋은 수행하지 않았다.
