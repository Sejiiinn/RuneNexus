# SWIFT 조준선·발사 VFX 게임 이식

현재 채택·적용 상태는 [상위 제작 기록](../../README.md#전투용-본체-게임-적용)에서 관리한다. 2026-09-30 사용자가 작고 밋밋한 섬광과 보이지 않는 조준선을 지적한 뒤, 승인 제작 원본의 입체 표현을 실제 Godot 전장에 연결했다.

## 원본과 게임 표현

- [발사 원본](../animation/README.md)의 흰청록 입체 바늘과 네 짧은 날을 56삼각형/5메시 그대로 추출했다. 포구 자식으로 연결해 기존 포신 반동을 따라간다. 게임 거리 가독성을 위해 효과만 최대 2.4배로 표시하고, 게임 시계 0.105초 동안 빠르게 줄여 숨긴다. 최대 길이는 약 0.34타일이다. 저격의 공용 atlas 섬광/연기는 생성하지 않아 중복 섬광이 없다.
- [조준선 원본](../animation/aim-line/README.md)의 20삼각형 실체 육각 원통을 사용한다. 렌즈 앞 Godot barrel-local (0, 0.420, 0.196)에서 실제 적 메시의 첫 표면까지 연결한다. 게임 거리 가독성을 위해 반지름을 0.010타일로 표시한다. 원본 입체 기하·일반 깊이 검사를 유지하며 빌보드·장거리 공격 레이저·추가 조명은 사용하지 않는다.
- native의 유효 대상·사거리·실제 조준 상태만 optional 표시 필드로 전달한다. 발사·쿨다운·죽음·무대상 시 선을 숨긴다. 정지 중에는 기존 조준선/발사 효과의 게임 시계를 유지하고, 복원된 발사 이력은 재연하지 않는다. 본체·아이콘·다른 포탑·조준 시간·쿨다운·피해·저장 데이터는 변경하지 않았다.
- 최신 조준 효과는 [승인 시안 v2](../aim-vfx-concepts/2026-09-30-energy-charge-v2.png)의 세 단계를 따른다. 초반은 희미한 청록빛과 소수 glints, 중간은 가는 중심광과 투명한 주변 광채, 완료 직전은 밝은 흰청록 중심과 작은 렌즈/표면 광점이다. 이전의 재질 색만 변하는 선은 채택하지 않는다. SWIFT 본체는 시안의 AI 포신 형태로 재설계하지 않는다.
- 표시 비율은 실제 aimProgress / 현재 stats.aimDuration의 0…1 값이며, 레벨·젬·모듈이 반영된 조준 시간을 따른다. 20삼각형 원본 중심은 반지름 0.010타일을 유지한다. 동일 원본 메시를 제한적 투명 광채 볼륨에 재사용한다: 주변 반지름 0.060타일, 양끝 광점 반지름 0.080타일. 셰이더의 Gaussian 분포로 단단한 이중 원통 외곽을 숨기며, 중심과 세 광채 볼륨은 총 80삼각형이다. 평면·빌보드·새 전장 조명·전체 bloom은 사용하지 않는다.
- [국소 셰이더](../../../../../godot/effects/sniper_aim_energy.gdshader)는 정투영의 평행 화면 광선과 원근 카메라를 구분한다. 일반 깊이 검사·뒷면 제거·깊이 쓰기 없음으로 가림을 유지한다. 실제 표시 게임 시계로 세 작은 glints와 미세한 흐름을 구동한다. 작은 빛점은 중심광에 묻히지 않도록 원통 축 옆 ±0.018타일의 실제 3D 위치에서 반지름 0.016타일 Gaussian 분포로 나타났다 사라진다. 중심광 두께와 주변 광채의 기본 분포는 그대로 유지한다. 조준 비율 p에 대해 smoothstep(p)×p, 즉 p³(3−2p)로 광채를 응축한다. 최대 밝기에 일찍 머물던 이전 smoothstep(p) 곡선보다 초·중반을 은은히 유지하고 완료 직전에 부드럽게 밝아진다. 최고 밝기·색·형태와 실제 조준/발사 시간은 그대로다. 엔진 TIME이나 실제 시간 타이머를 사용하지 않아 일시정지·배속·복원 상태를 따른다. 포탑마다 네 ShaderMaterial을 최초 한 번 만들고 매 프레임 재질이나 메시를 생성하지 않는다. 발사·무대상 시 네 조준 볼륨을 함께 숨긴다.
- 대상 표면은 실제 렌더 메시의 캐시된 TriangleMesh BVH에서 구한다. 현재 스킨은 삼각형별 단일 본 가중치 1이며, 본별 BVH는 최초 한 번 준비한다. 포즈 행렬은 같은 대상에 대해 표시 배치당 한 번 갱신한다. 실제 원거리 표면의 공유 모서리 누락을 방지하도록 최근접 ray 조회에 유한거리 상한을 적용한다. 종점 바깥 여유는 0.00025타일이다.

출력은 assets/images/stage1_3d/effects/sniper/flash.glb와 aim_line.glb이며, [manifest.json](manifest.json)에 제작 원본 해시와 삼각형 수를 기록했다. 열린 Blender와 승인 원본은 보존하고, [export_vfx.py](export_vfx.py)를 별도 백그라운드 Blender에서 실행한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/sniper_tower_concepts/2026-09-26/production/game-vfx/export_vfx.py
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import --quit
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script res://verify_sniper_model.gd
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script res://verify_sniper_vfx.gd
```

## 검사 결과

- 유지 회귀 verify_sniper_model.gd: 본체 9,816삼각형·회전·포구/반동·판매·복원 PASS. verify_sniper_vfx.gd: 승인 효과 56/20삼각형·첫 표면·정지·타깃 이동·수명·잔존 발사 이력·판매/초기화·실제 shader 진행도/시계/독립/원본 보존/재사용·국소 광채 부모/숨김 등 30조건 PASS. armored의 공유 모서리 재현 조건과 회전한 실제 GLB 원통의 양끝점 대조도 포함한다. 원통은 회전 전에 로컬 축을 늘려 렌즈/표면 끝점과 일치시킨다.
- 기존 native 전투 회귀 PASS. 독립 대조는 기존/신규 native 상태·8필드 표시·저장 동일성 등 4,825조건 PASS, 실제 스킨 정점/삼각형으로 계산한 6종×3포즈×3방향 첫 표면 54조건 및 효과 수명 16조건 PASS.
- 실제 정규 앱 1-10에서 저격 Lv1 세 개만 (2,6), (3,6), (3,7)에 설치했다. 1배속 연속 영상은 25초·720×1472·30fps·750프레임이며, 각 포탑 5발/총 15발·청색/주황 포탈 각 6회·6처치를 기록했다. 원래 전투와 HUD를 사용하고 전투 시간을 확대하거나 효과를 별도 재연하지 않았다. 440×900 고정 시점에서도 얇은 조준선과 짧은 흰청록 섬광을 확인했다.
- 선행 VFX 단계의 실제 앱 상태 검사 12조건은 조준 정지/재개·4배속·발사 후 정지·격리 체크포인트 복원·판매·1-10 재시작을 확인했다. 이번 shader 변경에서도 해당 native·기하·발사 입력은 보존했다. 최신 에너지 효과의 실제 720/440 실행 및 25초 영상 디코드 오류는 0건이다. 에너지 표현 채택 단계에서는 effect/unit/test 4개 파일(3GD와 shader)의 제작 소스·준비 프로젝트·촬영 프로젝트 정합성을 확인했다(build/sniper-aim-energy/prepared-sync.json). 후속 충전 곡선 변경은 shader 한 줄만 바꾸고 공식 준비 프로젝트·새 촬영 프로젝트를 동기화했다(build/sniper-aim-timing/prepared-sync.json).
- 최신 에너지 효과의 독립 검증은 [58개 상태·수명·시간·private 재질/자원 계약](../../../../../build/sniper-independent-review/energy-contract.log)을 통과했다. 중심광에 묻혔던 glints를 국소 보정한 뒤 실제 1배속 원본 연속 프레임 f223…235에서 작은 흰청록점의 이동·감쇠·재출현을 확인했다([최종 원본 프레임 비교](../../../../../build/sniper-independent-review/energy-glint-final/blue-glints-raw-strip.png)). 세 점의 축 옆 거리 0.018타일·Gaussian 반지름 0.016타일이 기존 광채 범위 안에 있으며, 정상 깊이 검사와 최종 네 소스의 정합성도 [최종 계약 대조](../../../../../build/sniper-independent-review/energy-glint-final/shader-contract.json)로 확인했다. [발사 시 조준광 숨김·기존 단발 섬광·소멸](../../../../../build/sniper-independent-review/energy-glint-final/fire-hide-raw-strip.png)과 440/720 가독성·승인 시안의 세 단계도 최종 PASS다. 이전 glint 가독성 실패 후보는 채택하지 않았다.

- 충전 곡선 후속 조정의 독립 검증은 [동일 진행도 원본 비교](../../../../../build/sniper-independent-review/aim-timing/same-progress-early-middle-bright.png)와 [후반 연속 프레임](../../../../../build/sniper-independent-review/aim-timing/late-continuity.png)에서 초·중반의 은은함 유지와 완료 직전의 부드러운 증가를 확인했다. 두 실제 영상의 666개 native 표시 입력·발사/전송/처치는 동일하고, glints·발사 숨김·섬광 소멸은 유지됐다. 곡선 한 줄 이외 표현 계약은 이전 근거를 재사용했으며, 440/720 시각·최종 소스/준비/촬영 프로젝트 정합성 PASS다([독립 최종 기록](../../../../../build/sniper-independent-review/aim-timing/review.json)).

최신 충전 시간 조정 영상은 로컬 제외 경로 build/sniper-aim-timing/sniper-three-portal-timing.mp4다. 실제 Mobile 정규 앱의 동일 1-10·저격 Lv1 세 개·1배속 25초 영상이며, 조준 진행도와 발사 시점은 이전 영상과 같다. timing-before-after.jpg는 동일 대상/포탑의 원본 프레임 f319/332/340/342/345/346을 이전 영상과 비교한다. shader의 시각 에너지 0.9 이상 구간은 진행도 약 80.4% 이후에서 91.8% 이후로 늦어졌고, 1초 조준 기준 약 0.196초에서 0.082초로 짧아졌다(픽셀 클리핑 임계값을 뜻하지 않는다). 실제 440×900 대표는 같은 폴더 size440/에 있다. 이전 승인 에너지 영상 build/sniper-aim-energy/sniper-three-portal-energy.mp4는 보존했다. 같은 포탑/대상의 한 조준 구간 6.7%→50%→93.3%의 실제 shader/영상 대조는 charge-sequence.json과 charge-contact-sheet.jpg에 있다. 이전 에너지 폴더에는 실제 프레임 ROI만 확대한 energy-close-comparison.jpg와 원속도 energy-close-real-time.mp4도 보존한다. 실행 입력·매 프레임 조준/시계/재질 ID는 같은 폴더의 runtime-report.json, 440×900 대표는 size440/에 있다. 이전 자료 build/sniper-aim-charge/, build/sniper-vfx-integration/, build/sniper-battle-video/는 보존했다. 사용자 저장·열린 Blender 원본·Godot 편집 프로젝트는 건드리지 않았다. Android 실기기·모바일 GPU 성능은 미검증이며 APK·배포는 수행하지 않았다.
