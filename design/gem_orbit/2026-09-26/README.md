# 장착 젬: 위성 젬과 테이퍼 리본

승인 기준: 2026-09-26 사용자 선택 **1번 테이퍼 리본**. [컨셉 원본](concept-reference.png)의 **위쪽 01 확대 이미지**를 따른다. 아래쪽 4젬 예시는 젬 앞쪽에도 선이 남아 있는 생성 오류이므로 승인 형태로 사용하지 않는다. 컨셉의 포탑 디자인은 교체 대상이 아니다.

- 작은 입체 젬이 진행 방향의 선두이며, 긴 리본은 뒤쪽으로만 가늘고 투명해진다.
- 같은 궤도에 균등 간격으로 배치한다. 꼬리 각도는 `min(150°, 360° / 개수 × 0.8)`이며, 젬 뒤쪽 연결 간격도 둔다.
- 기존 HUD의 젬 색을 사용한다. 빈 슬롯은 표시하지 않는다. 반경 0.445 타일, 높이 0.32, 젬 길이 0.16로 이웃 타일을 침범하지 않는다.
- 외부 전투 시계로 회전하므로 정지·배속·되감기를 따른다. 고정 메시와 재질은 재사용하며 매 프레임 메시를 생성하지 않는다. 준비 단계에서는 전투 시계가 멈춰 있으므로 회전도 정지한다.
- 실제 3D 깊이 검사를 사용해 포탑 뒤쪽이 가려진다. 투명 리본이 보상 실루엣 마스크를 뚫지 않도록 궤도 효과는 마스크에서 제외한다.

## 원본과 실행

- Blender 원본: [satellite-gem.blend](satellite-gem.blend), 재생성 스크립트 [build_gem.py](build_gem.py). 기존 열린 파일을 바꾸지 않고 별도 scene과 파일로 제작한다.
- 게임 GLB: `assets/images/stage1_3d/effects/gem_orbit/gem.glb` (2,716 bytes). 기존 GLB 준비 경로가 자동 포함한다.
- 실행: `godot/effects/gem_orbit.gd`, `gem_orbit_ribbon.gdshader`. 장착 데이터는 `app_selection.gd`가 전달하고 `battlefield_units.gd`가 수명주기를 소유한다.
- 저장·전투 판정·포탑 모델은 변경하지 않는다.

## 검증

Godot 4.7.2, macOS Apple M4, Metal Mobile에서 검증한다. 자동 검사 진입점은 `verify_gem_orbit.gd`, `verify_app_selection.gd`, `verify_selection_lifecycle.gd`다. 최종 화면·독립 검수 근거는 아래에 기록한다. Android 실기기는 연결되어 있지 않아 외형·성능을 확인하지 못했다.


최종 독립 Astra 검수 PASS. 정상 앱의 1·2·3젬 장착, 동일 개수 교체, 중간/전체 해제, 판매·재건설, 기관총·대포·화염·냉각, 일시정지·4배속·고정/드론 시점·장면 초기화를 확인했다. 자동 검사는 1~6개 기하 간격·앞꼬리 금지·되감기·메시 재사용과 장착 데이터·root 수명주기를 통과했다.

- [실제 게임 크기](verification/review-three.png), [여러 포탑](verification/review-drone-types.png)
- [동일 앱의 카메라 확대 진단](verification/review-detail-final.png): 꼬리 방향과 가림 확인용이며 실제 기본 배율이 아니다.
- [독립 실행 로그](verification/independent-review.log), [검증 입력](verification/review.gd)

이 결과는 데스크톱 동작·외형 확인이며 모바일 성능 향상이나 Android 실기기 통과를 뜻하지 않는다.


## 높이·가시성 보강

사용자 후속 요청에 따라 궤도를 0.14→0.32 타일 높이로 올리고 젬 길이를 0.12→0.16, 리본 폭을 0.038→0.058로 조정했다. 리본의 불투명도·끝으로 흐려지는 정도와 젬 발광을 강화하되 파티클·광원·추가 리본은 늘리지 않았다. 후방 꼬리 연결 간격은 커진 젬에 맞춰 0.14→0.19rad로 늘렸다. 위의 기존 검증 이미지는 최초 적용 시점이며 보강 결과는 별도 `verification-raised/`에 둔다.

최종 보강 독립 Astra 검수 PASS: [확대 진단](verification-raised/detail.png), [실제 게임 크기](verification-raised/combat-paused.png), [다른 포탑·드론](verification-raised/review-drone-types.png). Godot Metal 실제 앱에서 4종 포탑과 두 시점, 장착·제거·일시정지·배속을 확인했다. Android 실기기는 미확인이다.


## 젬 색광

후속 요청으로 각 젬 위치에 색상이 같은 OmniLight3D를 추가했다. 범위는 0.7타일, 광량은 `1.1 / sqrt(장착 개수)`이며 그림자는 생성하지 않는다. 슬롯의 회전 부모를 따라 이동하고 장착 구성 변경·해제 때 함께 교체·해제된다. 파티클이나 광원 그림자 패스는 추가하지 않았지만 GPU 조명 비용은 증가하므로 저사양 실기기 성능은 미측정이다.

[색광 적용 확대](verification-lit/detail.png), [실제 게임 크기](verification-lit/combat-paused.png). 기존 젬 재질을 유지하면서 포탑과 지면에 장착 색상이 비치도록 한 변경이다. 자동 검사는 광원 위치·색·범위·그림자 비활성·개수별 광량과 기존 궤도 계약을 통과했다.

색광 변경 독립 Astra 검수: 실제 확대·기본 배율·1젬 화면과 소스 수명주기 확인 PASS. Android 및 다수 포탑 GPU 성능은 미확인.
