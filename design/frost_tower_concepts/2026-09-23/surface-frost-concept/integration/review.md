# 표면 서리 게임 적용 독립 검증

2026-09-23, Astra 독립 검증. **최종 PASS — 승인 이미지의 표면 서리 방향을 현재 3D 형태와 Godot 게임에 적용.** 기준은 [승인 시안](../frost-coated.png)이며 기존 검증 결과를 이번 외형 판정으로 재인용하지 않았다.

첫 후보 `iteration1-too-uniform.png`는 균일한 그물망과 연속 흰 테두리, 청동 과백화로 승인한 불규칙 성에와 달라 FAIL이었다. 수정된 절차 재질과 최종 베이크 `detail-hero.png`/`detail-top.png`를 직접 확인했다. 그물망이 없어지고 상판·모서리·볼트 주변·기둥·기단에 불규칙 서리가 붙으며 짙은 금속 면과 청동색이 남는다. 베이크로 미세 질감은 조금 부드러워졌지만 서리와 금속의 구분 및 원래 입체성을 유지한다.

실제 `godot/model-hero.png`, `model-top.png`, `detail-charging.png`, `detail-release.png`, `app-angled-selected.png`를 직접 승인 시안과 대조했다.

- **표면·재질 PASS:** 게임 조명에서도 성에가 불규칙한 패치로 보이고 단색 흰 도장으로 변하지 않는다. 상판과 기둥/하부 모서리의 서리, 노출 청동, 청록 냉각핀·렌즈가 공존한다. 승인 이미지의 미세 무늬와 픽셀별 동일성을 요구하지 않는다.
- **형태 보존 PASS:** 6개의 두꺼운 곡선판·분리 틈·소용돌이 배치, 상하로 이어지는 기둥, 냉각 베이와 지지발·렌즈 개구를 유지한다. 독립 GLB 파서로 변경 전후 13개 재질별 모든 삼각형의 정점 위치 집합과 노드 변환을 재계산하여 일치를 확인했다. 제작자의 `geometry_unchanged` 판정만을 근거로 삼지 않았다.
- **게임 연출 PASS:** 실제 하단 충전과 방출 프레임을 확인했다. 비회전 계약 검사 실패 0, 실제 앱 발사·감속 true/실패 0 결과와 해당 검수 조건을 확인했다. 안개 .36 셰이더 해시 `c49198d1668a5be9479456e3bb44bb4f40b7484bd16c62a151a1a3b9bfd6557c`가 이전과 동일하다.
- **비용 구분:** 독립 파싱 결과 72,752삼각형·3메시·19표면·7개 이미지로 형상/표면 수가 동일하다. 텍스처 아틀라스 2K화로 GLB가 약 7.37→12.58MB(+5.21MB) 증가했다. 드로 수를 추가하지 않는다고 텍스처 메모리·대역폭 비용까지 같다고 해석하지 않는다. GPU 시간·Android 성능은 미측정이다.

현재 게임 GLB SHA-256 `e84d5a97650056d139fd6a61868e621042955937d0584c996416dc6cc59a8544`를 독립 계산하여 [실제 실행 결과](godot/report.json)와 일치함을 확인했다. 실행은 Godot 4.7.2 / Mobile 렌더러 / 660×1100, 격리 저장 `RuneNexus-Frost-Surface-Integration`이다. 형태 보존 근거는 `before/frost.glb`와 최종 `frost.glb`, 제작 기록은 [geometry-comparison.json](geometry-comparison.json)·[surface-bake-audit.json](surface-bake-audit.json), 계약 근거는 [contract.log](contract.log)다.

필수 미해결 사항은 없다. Android/APK 검증은 수행하지 않았다. 이 검증자는 제품·Blender·GUI를 조작하지 않고 최종 근거와 바이너리를 독립 검토했다.
