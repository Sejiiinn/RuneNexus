# SWIFT 최종 사용 경량 모델

기존 [승인 원본](../README.md)의 긴 포신·유선형 몸체·매립 렌즈·곡선 은색 요크·낮은 기둥·청록 룬을 유지한 별도 3D 모델이다. 제작 원본은 보존한다. 승인·게임 적용 상태는 [상위 작업 기록](../../README.md)에서 관리한다.

- [편집 원본](sniper-swift-optimized.blend), [경량 GLB](sniper-swift-optimized.glb), [확대 렌더](sniper-swift-optimized-hero.png)
- [제작 스크립트](build_optimized.py), [내보내기 스크립트](export_optimized.py), [부품별 감축 기록](optimization-manifest.json)

작은 체결 볼트의 베벨을 제거하고 주요 모서리의 베벨 폭은 유지하면서 분할을 줄였다. 렌즈·축·몸체 곡면은 부품별로 재분할했다. 일괄 Decimate는 사용하지 않았으며 금속 재질과 조준·반동 계층을 보존한다. 삼각형 수는 43,380개에서 9,816개로 약 77.4% 줄었다.

GLB는 고정 받침·회전 헤드·반동 포신의 3메시와 5재질, 1024² 컬러·노멀·거칠기 베이크를 사용한다. 파일 수치와 식별 정보는 [내보내기 기록](manifest.json), 원본 재질·계층·치수 보존 결과는 [구조 검사](source-check.json)에 있다. 발사·조준선 애니메이션을 합친 파일은 아니며 기존 동작을 연결할 계층과 좌표를 보존한 정적 모델이다.

최신 [S26 Ultra QHD+ 비교](review/s26-ultra/README.md)는 1440×3120으로 새로 렌더했으며 정식 앱의 440×760 기준 화면 배율을 적용한다. 원거리 비교는 Godot의 실제 전장 카메라와 HUD 가용 영역 계산을 사용한다. 고정 시점·드론 시점의 최원거리 줌 1.0에서 같은 위치·방향·조명으로 원본과 후보를 비교한다. Blender 확대 렌더만으로 원거리 가독성을 판정하지 않는다.

[고정 시점 비교](review/angled-native-pair-left-original-right-optimized.png)와 [드론 시점 비교](review/drone-native-pair-left-original-right-optimized.png)는 왼쪽이 원본, 오른쪽이 경량본이며 캡처 픽셀을 확대하지 않았다. [경량본 전체 전장](review/optimized-angled-full.png)은 440×900 물리 픽셀이다. 논리 viewport는 880×1800이며 HUD 영역 계산과 줌 1.0을 적용했다. 이 첫 비교는 fixture의 880×760 기준 설정을 사용했으며, 정식 앱의 440×760 기준 설정과 다르므로 실제 앱 배율의 최종 근거로 사용하지 않는다. [캡처 조건](review/capture-conditions.json)과 [파일 비교](review/asset-comparison.json)에 상세 근거가 있다. 두 시점에서 원본 대비 눈에 띄는 추가 윤곽·주요 디테일 손실은 없었다.

이 폴더의 원거리 비교는 별도 모델 제작 단계의 검증이다. 후속 본체 게임 적용 검증은 [상위 적용 상태](../../README.md#전투용-본체-게임-적용)를 따른다. 모바일 실기기 FPS·발열과 본게임 전투 연결은 검증 범위에 포함하지 않는다. 삼각형 감소율을 FPS 향상률로 해석하지 않는다.

[독립 검수](review/independent-review.md)는 원거리 시각 비교와 파일 계약 보존을 PASS로 판정했다. 원본에서도 수 픽셀 미만인 렌즈·룬의 모든 세부가 읽힌다는 뜻은 아니며, 경량화로 인한 추가적인 유의한 손실이 없다는 판정이다.

manifest.json의 not_installed_in_game은 최초 내보내기 당시 제작 범위 기록이다. 현재 적용 상태와 게임 에셋 해시는 위 상위 기록 및 연결된 게임 이식 검증을 따른다.
