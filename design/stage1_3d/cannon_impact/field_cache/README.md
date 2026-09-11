# 포탄 3D 필드 캐시 제작 원본

`bake_field.py`는 `procedural_source.dart.txt`에 보존한 기존 GLSL의 `field(p)`를 NumPy로 계산합니다. 화면 렌더나 빌보드가 아닌 공간별 밀도·발광·열도입니다. `uAngle=0`을 기준으로 하며, 작은 기폭 섬광은 격자 해상도에서 누락되지 않도록 캐시에 포함하지 않습니다. 섬광은 런타임 수식에서 별도로 더합니다.

`noise32.bin`은 원본 Dart `math.Random(9041)`로 생성한 32³ R8 바이트입니다. Python 난수로 대체하지 않습니다. 파일의 SHA256은 `validation.json`에 기록합니다.

## 재생성

저장소 루트에서 NumPy가 설치된 Python으로 실행합니다.

```sh
python3 design/stage1_3d/cannon_impact/field_cache/bake_field.py
```

최종 파일은 `assets/images/stage1_3d/effects/cannon_field.bin`과 같은 이름의 `.json`입니다. 생성기는 필드 수식, 인코딩 범위, 양자화 오차 및 brick 경계를 검증한 뒤 산출물을 기록합니다. GPU 텍스처 업로드와 실제 화면 검증은 이 생성기의 범위에 포함하지 않습니다.

## 저장 규격

- inclusive endpoint grid: 각 축 48개. XYZ 범위 `[-2.35, 0, -2.35]`부터 `[2.35, 2.9, 2.35]`.
- 시간 표본 32개: 시작 화염 구간에 집중한 비균일 간격. 정확한 값은 JSON의 `times`.
- 4×4×2개 brick을 하나의 192×192×96 RGBA8 3D 텍스처에 저장.
- frame `i`의 brick 좌표: `[i % 4, (i // 4) % 4, i // 16]`.
- 바이트 순서: RGBA interleaved, x가 가장 빠르고 다음 y, z.
- R/G: 밀도 uint16의 high/low byte. 밀도 = `(R * 256 + G) / 65535 * 64`.
- B: 발광. 발광 = `B / 255 * 32`.
- A: 열도 = `A / 255`.
- 텍스처 정규화 채널 샘플에서 밀도 = `(R * 256 + G) * 255 / 65535 * 64`.
- 각 frame의 texel 중심 범위로 좌표를 제한해 인접 frame 혼입 방지. 로컬 grid 좌표 `(p - boundsMin) / (boundsMax - boundsMin) * 47`을 사용.
- 밀도 high/low byte 복호화는 선형식이므로 RGBA 채널의 공간·시간 선형 보간 뒤에 수행해도 같은 결과.
- mipmap 없음. 투명도나 sRGB 색상을 담은 텍스처가 아니며, 알파는 열도 데이터.

최종 바이너리는 14,155,776바이트(13.5 MiB)입니다. 모든 동시 폭발에서 하나의 GPU 텍스처를 공유하기 위한 형식입니다.

## 검증 결과 해석

`validation.json`은 전체 격자의 최대값·활성 밀도 개수·양자화 오차, 대표 시점 0.12/0.55초와 중간 시점의 원본 대비 공간·시간 보간 오차, 모든 frame 경계 및 sentinel brick 분리 결과를 기록합니다.

양자화 이전 수식의 이론상 상한은 밀도 46.98, 발광 24, 열도 1입니다. 실제 생성값은 이보다 낮으며 범위 초과를 허용하지 않습니다. 밀도는 16비트로 저장해 낮은 밀도가 8비트 양자화로 지워지는 문제를 줄입니다.

48³ 격자는 원본 수식과 픽셀 단위로 동일하지 않습니다. 특히 높은 주파수의 grain과 희박한 외곽에서 공간 보간 오차가 남습니다. 정규화된 전체 공간 평균은 빈 공간 때문에 작게 나올 수 있으므로 `activeMeanAbsoluteError`와 `thinDensityBelowRenderThresholdAfterInterpolation`도 함께 확인합니다. 실제 angled/drone 시점의 화염, 금속 파편, 회색 먼지와 가늘게 흩어지는 외곽 검증을 별도로 진행해야 합니다.

또한 원본은 난류를 계산한 후 분출 방향을 회전합니다. canonical field 전체를 회전하면 각도별 난류 배치는 원본과 완전히 일치하지 않습니다. 이 검증은 모바일 GPU의 성능 측정이나 프레임 유지 보장이 아닙니다.

## 런타임 연결

`cannon_impact_field.dart`가 manifest·바이트 길이·시간 범위·공간 경계를 확인해 단일 3D 텍스처로 로드한다. `Stage1Scene.prepareEnvironment`가 첫 착탄 전 업로드하고 전장 종료 시 한 번 해제한다. `battlefield_impact_effects.dart`는 인접 두 시간의 atlas 좌표를 갱신하며 작은 기폭 섬광과 현재 광원 방향의 차폐는 실시간으로 유지한다. 기존 절차식은 이 폴더의 제작 원본에만 남는다.

통합 검증에서 캐시 공유·정확한 시간 경계·풀 재사용, 실제 초기/후기 두 카메라 렌더, Android arm64 프로파일 APK에 포함된 캐시 해시를 확인했다. 공간 보간으로 고주파 난류가 더 부드러워지는 근사는 유지되며, 모바일 실기기 성능은 미측정이다.
