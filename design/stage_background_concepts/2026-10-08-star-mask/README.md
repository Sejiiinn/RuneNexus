# 전투 배경의 정적 주변 밝기 사전 계산

역할: 별 보호 계산 최적화의 재생성 계약과 검증 근거. 확인: 2026-10-08,
기준 소스 `76364b028242517adf38ae778768e9588c49f37a` + 이 변경.
[기존 디자인 기준](../../../DESIGNS.md)과 원본 배경 외형을 유지한다.

## 구현과 재생성 계약

- 원본 `assets/images/backgrounds/combat_space_nebula.png` 바이트와 기존 lossless import를 유지한다.
- `scripts/generate_combat_space_mask.gd`가 오프라인에서 ±3텍셀의 주변 RGB 휘도 평균을 계산하여 `combat_space_nearby.res`와 JSON 해시 기록을 만든다. Godot 4.7.2로 저장소 루트에서 `godot --headless --script scripts/generate_combat_space_mask.gd`를 실행한다.
- 원본/생성기/파생 필드 SHA-256 중 하나라도 다르면 프로젝트 준비가 실패한다. 파생 필드는 프로젝트 준비 시 복사되며, 앱 시작이나 스테이지 진입 때 다시 계산하지 않는다.
- 필드는 단일 채널 `Image.FORMAT_RH`, 1026×1538, mipmap 없음. 원본 1024×1536의 양쪽에 가상 중심 한 텍셀씩을 추가하고, 각 이동된 원본 조회를 따로 clamp한다. 미리 평균 낸 가장자리만 복제하면 경계 반 텍셀에서 원래 식과 달라진다.
- 원본과 필드 모두 linear filter / repeat disabled. 셰이더의 halo UV 변환은 필터링과 선형 평균의 교환 관계를 유지한다. 비선형 `smoothstep`과 `max`는 필터링 **뒤**에 남겨 별 가장자리가 번지는 근사를 피한다.
- 현재 2D LDR canvas의 sRGB 코드값으로 생성한다. `viewport/hdr_2d=false`를 명시하며 런타임 검사도 확인한다. 향후 HDR2D로 바꾸면 선형화된 별도 필드가 필요하다. 데이터 sampler에는 `source_color`를 지정하지 않는다.
- 현재 원본은 불투명 RGB이며 생성기는 불투명성을 검사한다. 새 필드를 원본 알파에 넣지 않으므로 원본 색/알파 및 import 계약이 그대로다.
- 기존 hash, 선택되는 별, 7~14초 주기, 위상, TIME, 22% 감광과 챕터 색상은 변경하지 않는다. 밝은 별 보호와 성운 착색도 같은 식이다.
- 별도 리소스는 스테이지 manifest와 기존 threaded 준비 경로에 포함한다. cold lobby에서 preload하지 않는다. 기존 stage-scope와 동일하게 Continue용 리소스로 유지되어 반복 진입 때 늘어나지 않는다.

## 비용

- 전투 배경 fragment당 명시적 texture 호출: **5 → 2**, 3회(60%) 감소. 네 주변 RGB의 합산/휘도 연산도 오프라인으로 이동한다.
- 나머지 비선형 보호/난수/반짝임 연산은 유지한다. 전체 프레임/FPS가 60% 향상된다는 뜻이 아니다.
- 추가 GPU 텍셀 payload: **3,155,976 bytes (3.01 MiB)**, sampler 1개. allocator/driver overhead와 decode 중 CPU peak는 별도다.
- 압축된 `.res`: **2,596,638 bytes (2.48 MiB)**. APK/PCK 실측은 하지 않았다.

## 검증 결과

환경: 공식 Godot 4.7.2 `ed1daf0bf`, Linux, Compatibility, Mesa 25.0.7 / llvmpipe LLVM19.
모바일 GPU 성능 실측 대신 소스 호출 수/메모리와 실제 셰이더 출력을 구분했다.

- 준비 Python 검사 9개 통과. 원본 보존, 파생 파일 복사, 세 해시의 stale 차단 포함.
- `verify_combat_space_mask.gd`: 6개 검사 통과. HDR2D off, RH 형식, halo 크기, lossless 원본, 양쪽 mipmap 없음, 경계/분수 UV 4096개 오차 상한 확인.
- 준비된 원본 import의 픽셀은 원본 PNG와 **완전히 동일**했다. 이 배경에는 ASTC 정책이 적용되지 않는다. 다른 모델 텍스처 정책은 변경하지 않았다.
- 실제 저장 RH 데이터와 원본을 사용한 524,588 UV CPU 비교: halo의 비양자화 수학 오차 최대 5.22e-15. RH 텍셀 오차 최대 0.00024404. 최종 RGB 최대 차이는 챕터별 0.0862/0.1047/0.1775 byte level이다.
- 실제 GPU background 비교 **27쌍**: 440×900, 880×760, 1024×1536; 세 챕터 tint; TIME=0,3,8.5초. 최대 채널 차이 3/255, 평균 절대 차이 최대 0.002292/255. bilinear sampler/산술 정밀도 때문에 비트 동일은 아니며, 밝은 별·색·경계에 눈에 띄는 변화는 없었다.
- t=0→8.5초에서 실제 candidate 별 11픽셀이 바뀌고 최대19/255 변화하여 반짝임이 살아 있음을 확인했다. 전후 시간별 효과는 같은 식과 위상이다.
- 실제 앱 440×900에서 cold lobby, 스테이지1/6/11, 고정 카메라1.0배와 드론1.75배, lobby 복귀를 캡처했다. 배경은 카메라와 독립적인 CanvasLayer다. 최대 사용자 zoom2.5배는 별도로 촬영하지 않았다.
- 실제 스테이지1의 전체 프레임 차이에는 시간 경과에 따른 식생/그림자 움직임이 포함된다. 동일 셰이더의 수치 비교는 고정 입력 background 캡처에 한정한다. 독립 확인한 스테이지1 배경 ROI 세 곳의 최대 차이는1/255였다.
- 스테이지 리소스 수명 검사 fresh149 + stored25 + parent6 통과. cold lobby 무로딩, 챕터 반복 진입, Continue/Retry 및 실패 rollback 포함.
- 스테이지 로딩 feedback 45개 검사 통과. 취소/Back, 실패/Retry, 전환 시 ownership 계약 포함.
- 별도의 독립 검토에서 수학/소스/로드 범위와 대표 전후 PNG를 직접 확인했으며 차단 결함은 없었다.

## 한계와 근거 보관

Mobile renderer 실행도 시도했으나 이 cloud의 Vulkan `VK_KHR_surface` 미지원으로 Compatibility에 fallback했다. 이를 Mobile 통과로 세지 않았다. Godot4.7.2 소스의 HDR-dependent canvas texture-view 선택은 검토했지만 Android 기기 외형/성능/발열은 미측정이다. APK 빌드·커밋·푸시는 하지 않았다.

대표 전후 비교 PNG와 원본 캡처, 수치 JSON, 검증 로그, 사용한 일회성 비교 스크립트는 별도 전달한 검증 번들에 보관한다. 일회성 덤프/로그는 저장소 source 변경에 포함하지 않는다.
