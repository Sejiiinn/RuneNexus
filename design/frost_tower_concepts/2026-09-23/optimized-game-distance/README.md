# 냉각 포탑 경량화·게임 반영

현행 표면 서리 원본의 형태·크기·재질·충전/방출 연결을 보존하면서 삼각형을 **72,752 → 47,912(34.1% 감소)**로 줄였다. 최종 [GLB](frost-optimized.glb)를 게임 `assets/images/stage1_3d/turrets/frost.glb`에 그대로 반영했다. 게임 코드·전투 수치·안개/VFX·HUD 아이콘은 변경하지 않았다. 커밋·APK 빌드는 하지 않았다.

| 항목 | 원본 → 최종 |
|---|---|
| 삼각형 | 72,752 → 47,912 |
| GLB 바이트 | 12,576,616 → 11,371,160(9.6% 감소) |
| 런타임 메시 / 표면 / 재질 | 3 / 19 / 13 유지 |
| 내장 이미지 | 7장, 모든 이미지 바이트 동일 |
| 크기 | 기존 폭·높이 및 노드 변환 유지 |

[편집 원본](frost-optimized.blend), [실제 Blender 근접 렌더](frost-optimized-hero.png), [부품별 감축 기록](optimization-manifest.json), [내보내기 수치](model_audit.json), [GLB 검사](export-check.json).

비코팅 원형 부품만 기존 제작 함수를 재사용해 핀/코어 원주 32→16, 링 96×8→32×6, 렌즈 96×12→48×6으로 줄였다. 셔터의 평면 내부선은 UV/재질 경계를 지키며 정리했다. 6장 곡선 셔터와 틈, 72개 핀, 6개 베이, 4발과 실제 오목한 창, 표면 서리, 청동, 렌즈를 유지한다. 전역 decimate는 사용하지 않았다. 작은 코팅 베벨을 더 줄인 후보는 서리 UV 이음 때문에 폐기하고 원형을 보존했다.

원본은 [production/frost.blend](../production/frost.blend), SHA `ef01cba269112570b380788010a0700abc5591ff57bffac95578103ecdb09aff`이다. 비교 원본 GLB는 git `0c63df5fa22c1f5b7bcfd5a3f3f9ec8b448aa047:assets/images/stage1_3d/turrets/frost.glb`, SHA `e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544`로 고정한다. 현재 게임 파일을 비교 원본으로 사용하지 않는다.

최종 게임 GLB SHA: `7d71195e972710488c6912d68b1f3d5eb54ee38adf31f9a524788a8d1d3aee39`.

## 검증

- [QHD 원거리 독립 검수](review/independent-review.md): 실제 게임 카메라 고정/드론 동일 조건에서 원본과 비교.
- [UV 검사](glb_uv_validation.json): 31개 텍스처 슬롯의 선택 UV가 유효하다.
- [충전 계약 로그](integration/frost-charge.log): `verify_frost_charge.gd`, 실패 0. 충전 재질 선택, 비회전/무반동, 대기 유지, 전투 시계, 방출 범위·공유 메시 계약 보존.
- [실제 앱 결과](integration/report.json): 실제 건설·발사·적 감속·정지·4배속 모두 실패 0. [충전](integration/detail-charging.png), [서리 안개 방출](integration/detail-release.png).
- [게임/격리 import 일치](integration/import-check.json): 표준 공유 텍스처 외부화 후 BIN·노드·메시·accessor·재질 동일. 외부화된 GLB SHA는 원본과 달라진다.

근접 통합 이미지는 데스크톱 Godot Mobile/Metal 실제 렌더 900×1288이다(요청 창 크기 900×1500은 macOS 화면 제한). QHD 1440×3120 검수는 별도 review의 실제 SubViewport 결과다. Android 실기기/FPS/GPU 시간은 측정하지 않았고, 삼각형 감소를 같은 비율의 프레임 성능 개선으로 해석하지 않는다.

## 재현

열린 미저장 Blender 작업을 먼저 보존한다. 원본을 덮어쓰지 않는 별도 Blender 프로세스에서:

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python design/frost_tower_concepts/2026-09-23/optimized-game-distance/build_optimized.py
/Applications/Blender.app/Contents/MacOS/Blender --background design/frost_tower_concepts/2026-09-23/optimized-game-distance/frost-optimized.blend --python design/frost_tower_concepts/2026-09-23/optimized-game-distance/export_optimized.py
python3 design/frost_tower_concepts/2026-09-23/optimized-game-distance/check_export.py
python3 design/frost_tower_concepts/2026-09-23/optimized-game-distance/integration/reproduce.py
```

마지막 명령은 현재 게임 GLB를 사설 임시 프로젝트에 가져와 관련 검사와 캡처를 실행한다. 기존 편집 프로젝트·사용자 저장을 보존한다. 게임 GLB 교체 자체를 재현 스크립트에서 자동 수행하지 않는다. 실제 앱 하네스는 지연된 서비스 초기화를 기다린 뒤 기존 건설·전투 경로를 진행한다.
