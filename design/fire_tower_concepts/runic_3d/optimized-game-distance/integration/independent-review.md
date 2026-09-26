# 화염 경량판 게임 반영 독립 검수

**PASS.** 승인된 경량 GLB가 게임 에셋에 반영됐고, 현재 Godot import 및 실제 전투 표시 경로에서 상부 불꽃·조준·총구 발사·복귀가 유지된다. 미해결 결함 없음.

- 게임 `assets/images/stage1_3d/turrets/magic.glb`를 직접 해시 검사했다. 승인본과 동일한 SHA-256 `b46a8c2089924e73b38ed06f59039b6e85a8fea009ea4e5507144ef3a71c9a5e`, 2,856,352바이트다. 따라서 [기존 QHD 외형·계약 검수](../review/independent-review.md)를 재사용했다.
- 격리 프로젝트의 실제 import 입력을 독립 파싱했다. 텍스처 외부화 후에도 노드·메시·accessor 정의와 정점/인덱스 데이터가 동일하며, 외부 텍스처 파일이 게임 GLB 내 텍스처와 바이트 단위로 일치한다. import는 해당 `res://assets/turrets/magic.glb`를 PackedScene으로 연결한다.
- 렌더러를 사용한 [화염 검사](runic-fire.log)와 [실제 프레임 통합 검사](runic-fire-integration.log)는 PASS/0 failures다. 0.9 부착 배율, 정지 시각, 총구 발사 위치, 탄환 위치·재사용·초기화 계약을 확인한다.
- 실제 [대기](runtime-idle.png), [조준](runtime-aim.png), [발사](runtime-fire.png), [복귀](runtime-recovered.png) 화면을 직접 확인했다. 불꽃이 회전한 상부 포트에 붙고, 총구 발사 효과가 이어지며, 발사 후 기본 상태로 돌아온다. [100프레임 기록](runtime-check.json)은 조준각 -0.6→0.2→-0.6, 반동 후 복귀, 고정부 불변과 불꽃 포트 위치 일치를 검증한다. 실제 로드 메시 11,411삼각형과 내부 `turret_root` 0.9 배율을 확인했다.

첫 캡처의 배율 검사는 unit-scale PackedScene wrapper를 원본 root로 오인해 실패했다. 제작자가 내부 `turret_root` 검사로 수정한 최종 [캡처 로그](capture.log)는 PASS다. 게임 모델을 수정한 문제는 아니다.

비교 재현 경로도 확인했다. [기존 재현기](../review/reproduce.py)는 원본을 커밋 `08110e36508544efbc643f2f5e3ba515bba556a7`에서 임시 추출하고 SHA `80be26ff3b5932193746df410e513290932ec4687f9f5eb5efed3cf39addd380`를 검사해 `--original`로 전달한다. 해당 커밋의 원본 바이트와 해시를 독립 확인했다. 게임 교체 후에도 양쪽 경량판을 잘못 비교하지 않는다.

최종 대표 PNG는 같은 모델·타임라인을 macOS Godot 960×720의 고정 근접 진단 카메라로 다시 렌더한 결과다. 최종 발사 PNG를 직접 재확인하여 상부 화구 및 총구 불꽃 연결 PASS를 유지했다. [근접 영상](runtime-fire-close-preview.mp4)은 이 최종 프레임에 대응하며, [기존 원거리 영상](runtime-fire-preview.mp4)은 별도로 보존한다. 근접 영상 자체의 별도 재생 검수는 추가하지 않았고 최종 PNG와 동일한 타임라인 기록을 근거로 삼았다. S26 원거리 비교는 기존 QHD 근거를 사용한다. Android 실기기·FPS·APK 검증은 수행하지 않았다. [격리 경로](project-path.json)와 [재현 스크립트](reproduce.py)를 남겼다.
