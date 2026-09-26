# 경량 화염 본체 게임 반영 검사

게임 `assets/images/stage1_3d/turrets/magic.glb`를 승인된 11,411삼각형 경량 GLB로 교체했다. SHA256은 `b46a8c2089924e73b38ed06f59039b6e85a8fea009ea4e5507144ef3a71c9a5e`다. 90% 크기, 계층·두 부착점, 불꽃·반동·조준·탄환·전투 소스와 HUD 아이콘은 유지했다.

검사는 현재 Godot 소스와 기존 준비 에셋을 별도 임시 프로젝트에 복사하고, 새 게임 GLB에 정식 준비 경로의 공유 텍스처 처리를 적용한 뒤 실제 Godot importer로 다시 읽어서 수행했다. 기존 `build/godot/project`, 열린 편집기, 사용자 저장을 변경하지 않았다.

- `runic-fire.log`: 실제 Metal Mobile 렌더러에서 MultiMesh 버퍼·부착 0.9 배율·시계·입자·풀 검사 PASS.
- `runic-fire-integration.log`: 현재 프레임 경로의 화염 조준·발사 포즈·탄환 위치·정지·풀·초기화 검사 0 failures.
- `runtime-check.json`: 실제 로드된 본체 11,411삼각형과 0.9 내부 root 배율, 100프레임의 조준·반동·총구/상부 위치·복귀 기록. Godot 최외곽 scene wrapper 배율은 1이고 내부 `turret_root`가 0.9다.
- `runtime-fire-preview.mp4`: 독립 검수한 960×720, 30fps, 100프레임 실제 런타임 영상.
- `runtime-fire-close-preview.mp4`, `runtime-idle.png`, `runtime-aim.png`, `runtime-fire.png`, `runtime-recovered.png`: 같은 시퀀스에서 부착 위치를 보기 쉽게 고정한 별도 근접 카메라 근거. 게임 원거리 외형 판정은 기존 `../review/`의 QHD 비교를 재사용한다.

실행 환경은 Godot 4.7.2, macOS Metal Mobile/Apple M4다. APK·Android 실기기 검증이나 FPS 개선 측정은 수행하지 않았다. 변경되지 않은 전체 게임 회귀를 추가하지 않았다.

저장소 루트에서 재현:

```sh
python3 design/fire_tower_concepts/runic_3d/optimized-game-distance/integration/reproduce.py
python3 design/fire_tower_concepts/runic_3d/optimized-game-distance/integration/encode_preview.py /path/to/ffmpeg
```

실행에는 기존 `build/godot/project` 준비 에셋이 필요하다. 임시 프로젝트 경로는 `project-path.json`에 남기며 독립 검수 후 제거할 수 있다. 원본 비교 GLB는 중복 저장하지 않고 git `08110e36508544efbc643f2f5e3ba515bba556a7:assets/images/stage1_3d/turrets/magic.glb`에서 임시 추출한다. `../review/reproduce.py`는 원본 SHA `80be26ff3b5932193746df410e513290932ec4687f9f5eb5efed3cf39addd380`를 검사하며, 현재 교체된 게임 파일을 과거 원본으로 사용하지 않는다.
