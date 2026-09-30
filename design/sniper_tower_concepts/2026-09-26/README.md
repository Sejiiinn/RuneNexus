# 저격 포탑 C / SWIFT 제작 기준

2026-09-26 사용자 선택 기준과 3D 제작 자료의 진입점.

## 승인 외형

현재 상부 외형 기준은 [01 SWIFT](receiver-variants/01-swept-wedge.png)다. [인게임 멀티뷰 v2](ingame-multiview-v2.png)의 오른쪽 C열을 실제 3D로 제작하고 높이·금속을 수정한 뒤, 직육면체형 약실을 개선하기 위해 선택했다. 뒤로 기울이고 포신을 줄인 [v3](c-backward-raked-v3.png)는 채택하지 않았다.

- 높이를 낮춘 수직 팔각 기둥과 넓은 하단 지지발, 회전 링, 긴 포신과 작은 각형 총구를 유지한다.
- 상부 약실은 앞쪽이 좁고 뒤쪽 어깨가 둥글게 이어지는 낮은 유선형 쐐기로 만든다. 넓은 은색 경사 테두리와 전방 상단의 작은 청록 원형 조준 렌즈, 측면 다이아 룬을 따른다.
- 두껍고 매끄러운 은색 U자 요크와 황동 축이 몸체를 실제 부피로 연결해 지지한다. 평면 이미지로 곡면이나 깊이를 대신하지 않는다.
- 청회색 금속의 큰 면, 두꺼운 은색 모서리, 절제된 청동 연결부, 약실의 다이아몬드와 기둥의 청록 룬을 유지한다. 표면의 거친 얼룩과 과한 미세 요철을 줄이고 새틴 금속 반사가 읽히게 한다.
- 디테일 밀도는 [화염 포탑 원본](../../fire_tower_concepts/runic_3d/finish/centered-final-hero.png)을 참고한다. 생성 시안의 미세 흠집을 개별 부품으로 과장하지 않는다.

이번 요청은 SWIFT 형태로 실제 3D를 수정하고 수직 정투영 탑뷰 한 장을 제공하는 것이다. 게임 모델 교체·배포와 구분하며, Blender 원본과 실제 3D 렌더를 결과로 확인한다. 타일과의 관계는 실제 모델의 크기·회전 반경으로 기록하며, v3의 기울기·단축을 다시 반영하지 않는다.

## 제작 자료

[제작 폴더](production/)에 편집 가능한 원본, 제작 스크립트, 준비 GLB와 실제 렌더를 보관한다. 기존 게임 파일과 다른 포탑의 원본은 변경하지 않는다.

- [편집 원본](production/sniper-c-editable.blend)
- [정면 사선](production/sniper-c-hero.png) · [후면](production/sniper-c-rear.png) · [상부 사선](production/sniper-c-drone.png) · [수직 정투영 탑뷰](production/sniper-c-top.png): 실제 Blender 렌더이며 인게임 캡처가 아니다.
- [준비 GLB](production/sniper-c-preview.glb) · [치수·출력 정보](production/manifest.json)
- [제작 스크립트](production/build_sniper.py) · [별도 내보내기](production/export_preview.py)

제작·재현 절차와 검증 한계는 [제작 안내](production/README.md)를 따른다. 높이·재질 피드백으로 낮춘 기둥 회전축 0.45타일과 포신을 SWIFT에서도 유지한다. 최신 전체 치수는 manifest를 따른다. 긴 포신은 한 타일 밖으로 뻗으므로 이 결과를 인접 타일 침범 검증 완료로 해석하지 않는다.

[SWIFT 독립 검수](production/independent-review-swift.md)는 최종 원본·GLB와 사선·후면·상부 사선·수직 탑뷰를 확인해 제작 범위 PASS로 판정했다. [이전 C 검수](production/independent-review.md)는 수정 전 기록이다. 게임 교체와 런타임 검증은 수행하지 않았다.

[몸체 변경 시안 5종](receiver-variants/README.md) 중 01 SWIFT를 선택했다. 나머지 4종은 비교 제안으로 보존한다.

## 발사 애니메이션

SWIFT 정적 원본의 외형을 유지한 별도 [애니메이션 원본](production/animation/sniper-fire-animated.blend)에 조준광·짧은 입체 포구 섬광·빠른 반동과 느린 복귀를 제작했다. 고정 받침과 회전 헤드는 움직이지 않고 반동 노드만 이동한다. [재생 영상](production/animation/sniper-fire-preview.mp4)과 [반복 GIF](production/animation/sniper-fire-preview.gif), [제작·재현 안내](production/animation/README.md)를 제공한다. Blender 애니메이션과 재생 영상 범위이며, 게임 전투 시간·수치·기존 모델은 변경하지 않는다. 별도 준비 GLB는 반동만 포함하며 전체 표현은 Blender 원본과 영상이 기준이다.

[애니메이션 독립 검수](production/animation/independent-review.md)에서 실제 인코딩 영상·타임라인·최대반동 연결과 휴지 복귀를 확인해 제작 범위 PASS로 판정했다.

조준 대상까지 이어지는 청록선은 [별도 조준선 시연](production/animation/aim-line/README.md)으로 확장했다. 기존 장갑형 적을 원래 크기로 배치하고 렌즈 전면에서 적 표면까지 가는 입체 선을 연결한다. 조준 중 추적하며 발사·대상 해제 구간에는 숨긴다. [4초 영상](production/animation/aim-line/sniper-aim-line-preview.mp4), [반복 GIF](production/animation/aim-line/sniper-aim-line-preview.gif), [편집 원본](production/animation/aim-line/sniper-aim-line.blend)을 제공한다. 이는 Blender의 대상 추적 시연이며 본게임의 모든 적·지형 조건이나 실행 성능을 검증한 결과가 아니다.

[조준선 독립 검수](production/animation/aim-line/independent-review.md)는 원본 120프레임·대표 이미지·최종 영상에서 대상 추적, 발사 시 소멸과 휴지 복귀를 확인해 제작 범위 PASS로 판정했다.

## 최종 사용 모델 — 원거리 경량본

사용자가 S26 Ultra QHD+ 비교 후 경량본 사용을 승인했다. 이후 게임 적용·발사 애니메이션·조준선 연결의 기준은 이 경량본이며, 고해상도 원본은 제작용으로 보관한다.

실제 게임의 먼 카메라에서 주요 디테일을 유지하는 [별도 경량 모델](production/optimized-game-distance/README.md)을 제작했다. 원본 43,380삼각형을 9,816개로 약 77.4% 줄였으며 긴 포신·유선형 몸체·매립 렌즈·은색 요크·금속 재질·룬과 조준/반동 계층을 유지한다. 경량본 제작 단계에서는 기존 정적·애니메이션 원본과 게임 에셋을 교체하지 않았다. 현재 게임 적용 상태는 아래 기록을 따른다. 발사·조준선 애니메이션을 합친 새 파일이 아니라 기존 동작과 연결 가능한 별도 정적 모델이다.

최신 비교는 [S26 Ultra QHD+ 기준 렌더](production/optimized-game-distance/review/s26-ultra/README.md)다. 현재 스테이지 1 지형·조명·카메라와 정식 앱의 440×760 기준 화면 배율·HUD 가용 영역 계산을 재사용하고, 줌 1.0에서 1440×3120 픽셀로 직접 렌더했다. 고정 시점 타워는 약 113×159픽셀이며 원본과 경량 후보를 같은 조건으로 비교한다. 이전 440×900 비교는 fixture의 다른 논리 배율을 사용한 초기 근거로 보존한다. 최신 결과도 실기기 캡처나 Android 성능 검증을 의미하지 않는다.


## 전투용 본체 게임 적용

2026-09-30 사용자 승인에 따라 SWIFT 9,816삼각형 경량 GLB를 assets/images/stage1_3d/turrets/sniper.glb에 적용했다. 게임 본체와 [공유 HUD 아이콘](../../hud_turret_icons_fixed/README.md)은 모두 SWIFT를 사용한다. 고해상도·경량·애니메이션 제작 원본과 다른 포탑은 보존했다.

기존 native 조준 타이밍·헤드 회전·포신 반동·즉시 타격을 유지한다. 본체를 먼저 연결한 당시의 포구 섬광/연기·설치·추적·복원 검사는 [본체 이식 기록](production/game-integration/README.md)에 있다.

이후 사용자 가독성 피드백에 따라 승인된 렌즈→실제 대상 첫 표면 조준선과 흰청록 바늘/네 날 발사 VFX를 게임에 연결했다. 최신 조준 표현은 [승인 에너지 응축 시안 v2](production/aim-vfx-concepts/2026-09-30-energy-charge-v2.png)의 얇은 중심광·부드러운 청록 광채·미세 glints·작은 렌즈/표면 광점을 따른다. 저격의 작은 공용 포구 효과를 전용 입체 효과로 교체했으며, 현재 표현·크기·수명·검사 결과는 [VFX 게임 이식](production/game-vfx/README.md)을 따른다. SWIFT 본체·공유 아이콘·전투 수치·저장 계약은 보존했다. Android 실기기 검증과 APK·배포는 수행하지 않았다.
