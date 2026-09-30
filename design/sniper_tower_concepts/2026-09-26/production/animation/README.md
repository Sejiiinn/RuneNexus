# SWIFT 단발 발사 애니메이션

승인된 정적 SWIFT 원본의 별도 복사본에서 제작했다. 기존 정적 `.blend`·GLB·렌더와 게임 전투 코드는 변경하지 않았다.

- `sniper-fire-animated.blend`: 완전한 편집 원본. `sniper_fire` 반동 액션, 별도 섬광·조준광 액션, 타임라인 마커 포함.
- `sniper-fire-single.mp4`: 30fps, 800×800, 정상속도 단발 2초.
- `sniper-fire-preview.mp4`: 정상속도 2회 다음 1.5배 길이의 느린 재생 1회, 약 7초.
- `sniper-fire-preview.gif`: 480×480 반복 미리보기.
- `sniper-fire-shot.png`: 발사 대표 프레임. recoil/restored PNG는 최대반동·복귀 검수 근거다.
- `sniper-fire-motion-only.glb`: 기존 구운 SWIFT 메시와 **반동 위치 애니메이션만** 포함한 준비 파일. 포구 섬광·조준광 재질 애니메이션은 포함하지 않는다. 전체 표현은 `.blend`와 영상이 기준이다.

## 동작

60프레임/30fps 단발 사이클이다. 10프레임부터 청록 조준광이 올라오고, 17프레임에 한 번 발사한다. 흰청록 섬광은 실제 입체 바늘·4개 짧은 날 형태이며 17~18프레임만 보인다. 긴 레이저·큰 화염·빌보드·연무는 사용하지 않았다.

`turret_barrel`만 Blender +Y 방향으로 0.048타일 후퇴한다(glTF -Z). 18프레임 최대반동 후 천천히 복귀하여 36프레임에 휴지 상태로 돌아온다. 고정 받침·head 요크는 움직이지 않는다. 섬광은 muzzle 하위라 반동 중에도 총구를 따른다. 처음과 마지막의 모델·섬광·발광 상태는 같다.

이 타이밍은 애니메이션 시안이며 기존 게임의 저격 반동·복귀 시간이나 전투 수치를 변경하지 않는다.

## 재현과 검증

1. 정적 `../sniper-c-editable.blend`에서 `animate_fire.py`를 실행한다. 원본이 미저장 상태이면 중단하며, 별도 파일로 복사한 뒤 그 복사본만 편집한다.
2. 애니메이션 원본에서 `render_fire.py -- stills`, `render_fire.py -- frames`로 실제 Blender Cycles 프레임을 렌더한다. 활동 구간은 각 프레임을 렌더하며 완전히 같은 휴지 구간은 동일한 렌더를 복사한다.
3. `encode_preview.py <ffmpeg 실행경로>`로 인코딩한다. 기존 화염 포탑 인코더의 H.264/yuv420p/faststart 및 GIF 경로를 재사용했다.
4. `export_motion.py`는 기존 구운 원본을 읽어 별도 반동전용 GLB를 만든다.

`verify_animation.py` / `animation-check.json`은 모든 프레임의 root/head 고정, barrel 반동 범위, 첫·마지막 휴지 일치와 승인 원본 대비 정적 메시 정점 해시 일치를 검사한다. 실제 발사·최대반동·복귀 렌더와 원본의 축 접촉은 별도 시각·구조 검수 대상이다. 게임 적용·실기기 실행 검증은 이번 작업에 포함하지 않는다.
