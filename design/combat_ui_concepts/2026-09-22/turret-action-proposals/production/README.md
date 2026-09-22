# 포탑 액션 제작 원본

2026-09-22. 승인 기준은 [06 수정안](../06-v2-upgrade-traits.png)과 [특성 아이콘 10번](../trait-icons-10-candidates.png)이다. 적용·실행 검증은 [포탑 액션 기록](../../turret-actions/README.md)에서 관리한다.

## 현재 채택 경로

- `extract_reference.py`: 승인 PNG(2137×736)를 표시 기준2048×705로 정규화한 뒤 원본 프레임·아이콘·구분선을 GIMP로 직접 크롭한다. 프레임의 동적 글자·아이콘 영역만 같은 원본의 빈 표면으로 채우며, 테두리의 형태·색·금속 하이라이트를 보존한다. 기준1972×418의 상대 배치를 표준 Container에서 보존한다. 전체 패널의 강제 scale은 사용하지 않는다.
- `export_native_frames.py`로 원본 추출 프레임을 기준 모바일 크기로 축소한다. 게임은 `assets/images/ui/hud/turret_actions/native/`의 완성형 PNG를 공통 Theme의 StyleBoxTexture 고정 모서리·별도 콘텐츠 여백으로 사용한다. 구분선·강화·판매 아이콘은 `ref_*.png`다. `remove_icon_backgrounds.py`가 원본 강화·판매 그림의 배경만 GIMP로 투명 처리하며, 비용의 골드는 기존 공용 `ui/hud/icons/gold.png`를 사용한다. 배경이 포함된 `ref_coin.png`는 거절된 중간 결과로 보관한다. 포탑 종류 그림은 기존 `ui/hud/turrets_3d/`의 실제 3D 렌더 PNG를 유지한다. 시안의 임시 기관총 그림은 사용하지 않는다.
- `traits-master.png`: ImageGen 내장 도구로 10번만 투명 배경에 분리. 프롬프트: 금색 테두리의 어두운 육각 판3개, 위 태양·아래 왼쪽 잎·오른쪽 소용돌이의 형태·색·재질을 보존하고 번호·배경을 제거한다. GIMP로256×256 축소한 `assets/images/ui/hud/icons/traits.png`를 사용한다.
- 재추출 순서는 `extract_reference.py` → `remove_icon_backgrounds.py` → `export_native_frames.py`다. RGBA 투명도를 유지하며 원본은 덮어쓰지 않는다. 현재 게임용 파일 크기·해시는 `manifest.json`을 따른다.
- GIMP MCP와 재연결이 시간 초과되어 기존 인스턴스를 보존한 별도 `--new-instance --no-interface` 배치로 처리했다.

## 거절된 중간 결과

`frames-master.png`, `export_assets.py`, `rejected-v2/`는 ImageGen으로 프레임을 재생성했던 중간 결과다. 사용자가 원본과100% 동일한 배치·외형을 요구하여 채택을 철회했다. 현재 게임 경로에서 사용하지 않는다. 해당 export script의 출력도 `rejected-v2/`로 한정했다.
