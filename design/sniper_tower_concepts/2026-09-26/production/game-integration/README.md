# SWIFT 본체 게임 이식 검증

현재 채택·적용 상태는 [상위 제작 기록](../../README.md#전투용-본체-게임-적용)에서 관리한다. 이 기록은 2026-09-30 승인 경량본의 실제 본체 연결 검사다. 승인 GLB와 게임 GLB의 동일 해시·9,816삼각형·3메시·5재질·계층·준비 프로젝트 정합성은 [manifest.json](manifest.json)에 있다.

기존 root → head → barrel → muzzle를 사용해 조준 회전·반동·포구 섬광/연기를 연결했다. 게임 모델 스케일 1, 헤드 피벗 높이 0.45, 포구 높이 0.776/전방 거리 1.099를 유지한다. 소스 렌더 코드는 변경하지 않았다. 준비 프로젝트는 기존 텍스처 공유 처리만 적용하며 BIN·메시·accessor·노드·재질은 동일하다. 원본과 아이콘 PNG·다른 포탑은 보존했다.

저격의 기존 native instantHit은 조준 완료 후 대상에 즉시 피해와 sniperBlast를 발생시킨다. 비행체를 생성하지 않으므로 projectile 원점·전투 수치를 변경하지 않는다. 신규 렌즈→대상 표면 조준선과 Blender 전용 발사 표현은 이번 검증에 포함하지 않으며, 기존 일반 포구 효과와 반동을 유지한다.

## 검사 결과

- godot/verify_sniper_model.gd: 9,816삼각형/3메시·계층·스케일·긴 포구 좌표·2축 회전·포구 효과 부모·정확한 0.018초 최대 반동 0.045·0.14초 복귀·정지·판매·복원·초기화 PASS.
- 기존 verify_native_combat_runtime.gd, verify_native_session.gd: 저격 조준 완료 전/후 정확한 피해·기존 전투 시계/정지/배속 관련 검사 PASS.
- 실제 정규 앱 모드에서 1-1 건설칸 (2,1)에 설치하고 실제 1라운드를 시작했다. 이동 적 추적 각도 -2.655→-2.556라디안, 조준 1초 후 shotSequence 0→1, 다음 1/60초 프레임의 반동 -0.041667, 복귀 0을 확인했다. 실제 일시정지 동안 포구 위치가 고정되고, 대상 소멸 후 섬광/연기가 만료됐다. 격리 체크포인트 저장·복원, 판매와 1-1 스테이지 재시작 초기화에 잔류 효과가 없었다.
- Godot 4.7.2 stable·Metal Forward Mobile·440×900, scene._app_mode=true. 실행 프로젝트 /Users/sejin/Documents/Codex/RuneNexus/build/godot/project. 고정 시점과 선택 해제한 드론 시점에서 전체 본체·긴 포신·금속/U 요크를 확인했다.

실제 실행 입력·결과·대표 연속 프레임은 로컬 제외 경로 build/sniper-game-integration/verify_swift_runtime_local.gd, runtime-report.json, captures/01…09*.png에 보관한다. 사용자 저장·열린 Blender 원본·편집 프로젝트는 보존했다. Android 실기기·APK 성능 검증이나 배포는 수행하지 않았다.

## 재현

승인 GLB를 공식 단일 게임 경로에 복사한 뒤 기존 준비 경로를 사용한다. 준비용 design 폴더를 패키지에 추가하지 않는다.

```sh
cp design/sniper_tower_concepts/2026-09-26/production/optimized-game-distance/sniper-swift-optimized.glb assets/images/stage1_3d/turrets/sniper.glb
python3 scripts/prepare_godot_project.py
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --editor --path build/godot/project --import
build/godot-preview/tools/Godot.app/Contents/MacOS/Godot --headless --path build/godot/project --script res://verify_sniper_model.gd
python3 scripts/run_godot_native_regressions.py verify_native_combat_runtime.gd verify_native_session.gd
```
