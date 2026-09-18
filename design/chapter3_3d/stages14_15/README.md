# 스테이지 14·15 3D 전장

승인된 챕터3 금속 타일·벽체 연결형 소품을 기존 맵에 적용한다. Stage14는 9×10/타일53/그레이팅6/매립환기구5/소품5, Stage15는 9×9/타일51/그레이팅5/매립환기구5/소품5다. 원본 GLB·배치 규칙·카메라·조명을 변경하지 않았고, 경로·건설칸·포탈·코어·웨이브·저장 계약을 유지한다.

검수 조건은 [Stage13](../stage13/README.md)과 같은 Android17 arm64 에뮬레이터1080×2424/Godot4.7.2/MSAA2x·높음그림자/공용조명/실제 RuneNexusApp·HUD다. 별도 preview 패키지와 메모리 저장만 사용한다. 기존 승인 입력을 재사용하므로 Blender 중간 렌더는 반복하지 않는다.

준비 테스트와 Godot11~15 배치·경로·재질·카메라·팬/줌·다른 장 전환 검사는 PASS(0 failures). runtime.log 및 preparation-test.log 참조.

Flutter 관련 19개 테스트 및 analyze PASS. 모든 1~15 웨이브의 적 모델 지원 검사에서 누락된 forgeBoss를 발견해 기존 공용 boss.glb 연결을 추가했다. 보스 전투 수치·상태는 변경하지 않았다.

최종 arm64 APK 239,387,713 bytes, PCK 105,945,600 bytes. 직전 로컬 Stage13 미리보기 대비 각각 -32 bytes. 원본 GLB/Blend·design 미포함, PCK 중복 payload 0 bytes. apk-after.json, apk-audit.json 참조. 공개 배포 없음.

Android 최종 시각 확인 PASS: `android-stage14.png`, `android-stage15.png`. 각 맵의 전체 타일·포탈·코어와 벽체 부착 소품이 화면 안에 들어오며 HUD·경로·건설칸을 가리지 않는다. 두 건설 타일과 주황 열원의 혼합 배치를 확인했다. 14 캡처는 동일 PCK의 앞 빌드이며 이후 검수 진입점에만 전체 스테이지 목록을 명시하여 15 전환을 확인했다. 중간 메뉴 캡처와 추가 각도 렌더는 생성하지 않았다.

실제 Stage15 Android 포탑 선택·설치 및 170→110G 차감 PASS(`build-interaction.log`). 대표 캡처는 설치 전 배치 화면이다.
