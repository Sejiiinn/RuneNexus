# 최적화 탱커 게임 연결

역할: 승인된 탱커 Walk v2와 돌 붕괴 Death 최적화본의 게임 원본·재생 계약·검증 상태. 확인: 2026-10-09. 게임 연결과 데스크톱 인게임·독립 검증을 완료했다.

## 원본과 출력

편집 원본은 사용자 외장 SSD 보관 정책에 따라 `/Volumes/KIOXIA_MAC/AI-3D/projects/RuneNexus/tank-shoulder-03-multiview-20261008-512/rigging/death-rubble-v4-optimized/blender/tank-shoulder03-death-rubble-optimized-v4.blend`에 유지한다. SHA256은 `81a1d5008a7a909b0ca3f58c975cb3d39b8abced2693320210d02f0db8bb2ab4`다. 원본 Walk와 12개 돌 조각의 승인 붕괴·등 조각의 지면 착지를 보존하며 형상·텍스처를 다시 제작하지 않는다.

게임 출력은 `assets/images/stage1_3d/enemies/tank.glb`, `tank_death.glb`와 새 스킨에 다시 구운 `tank_status_burn.res`, `tank_status_frost_shards.res`, `tank_status_frost_grains.res`다. 제작·내보내기 중간본은 게임 패키징에 포함하지 않는다.

## 재생과 검증

생존 Walk는 기존 native 이동 거리, 사망은 전투 시계를 따른다. 전투 수치·판정·저장 계약은 유지한다. 2.5초 Death 전체를 재생한 뒤 0.10초 최종 자세와 0.35초 퇴장을 적용하며, 퇴장은 화면 표시만 정리한다.

Walk는 11,933삼각형·14뼈·2초이며 Death는 16,118삼각형·12개 rigid 조각·2.5초다. 균등 배율 `1.6920935396859471`로 이전 탱커의 rest 높이 `1.37216152`를 유지한다. 콘텐츠 `.65`와 렌더 계수 `(.55/.65)*1.15`를 유지하고, 승인 foot contact 거리에서 표시 보폭 `.2175022494278573`타일을 구한다. 새 스킨의 상태 좌표 배율과 frost 바닥 보정도 이 공용 정규화에 따른다. 출력 SHA와 팩 대응은 [출력 계약](runtime-contract.json)에 기록한다. Godot 가져오기는 Walk/Death 모두 24fps이며 AnimationPlayer optimizer를 꺼 원본 접지·정지 키를 보존한다. 일회성 캡처·로그·이전 게임 파일은 로컬 `checks/`에 보관하고 Git 추적에서 제외한다. Android 실기기·APK·배포·FPS 측정은 이 작업 범위에 포함하지 않는다.

## 확인 결과

Godot 4.7.2의 Mobile/Metal, Apple M4, 440×900 실제 앱에서 이동·일시정지·native 공격에 따른 사망·12조각 붕괴·등 조각 착지·유지·페이드·정리를 확인했다. 스테이지 1 웨이브 5의 격리된 체크포인트를 사용했으며 테스트 재화 1000과 부팅 서비스 우회를 적용했다. 집중 회귀 검사와 독립 검증은 통과했고 공용 PCK의 입력·에셋 포함도 일치한다.

냉각은 탱커 핵의 네 UV 영역만 보호해 금색 핵을 유지하고 몸의 냉각 코팅은 적용한다. 동일 native 상태의 냉각 표시 A/B 화면을 직접 대조했다. [대표 실제 게임 화면](game-preview.png)과 [출력·검증 계약](runtime-contract.json)을 유지한다. 상세 캡처·로그는 이 작업 폴더의 로컬 `checks/reviewer/`에 있다. Android 실기기·APK·성능·배포는 검증하지 않았다.
