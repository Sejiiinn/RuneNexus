# 기능별 젬 아이콘

2026-09-09 승인된 14종의 원석형 젬 시안과 게임 에셋 대응 기록.
각 젬은 공통 보석 안의 문양 대신 기능별 실루엣·재질·색으로 구분한다.

| 게임 에셋 이름 | 승인 원본 | 위치 |
| --- | --- | --- |
| multipleProjectiles | functional-gems-v1.png | 왼쪽 |
| explosion | functional-gems-v1.png | 오른쪽 |
| attackSpeed | functional-gems-set2-v1.png | 왼쪽 |
| armorPiercing | functional-gems-set2-v1.png | 가운데 |
| criticalChance | functional-gems-set2-v1.png | 오른쪽 |
| range | functional-gems-set3-v1.png | 왼쪽 |
| aimSpeed | functional-gems-set3-v1.png | 가운데 |
| chain | functional-gems-set3-v1.png | 오른쪽 |
| elementalDamage | functional-gems-set4-v1.png | 가운데 |
| damageAmplifier | functional-gems-set4-v1.png | 오른쪽 |
| heavyWeapon | functional-gems-set5-v1.png | 가운데 |
| damageOverTime | functional-gems-set5-v1.png | 오른쪽 |
| lightWeapon | light-physical-v2.png | 왼쪽 |
| physicalDamage | light-physical-v2.png | 오른쪽 |

최초 연쇄 시안과 set4의 물리 피해, set5의 경량화기는 대체된 역사 자료다.
시안의 제목·작은 크기 샘플·배경은 게임 에셋에 포함하지 않는다.

- 최종 게임 경로: `assets/images/gems/<이름>.png`
- 생성 프롬프트·중간 결과: `production/`
- 게임 파일 규격: 512×512 RGBA PNG, 464px 원본 축소 영역과 투명 안전 여백
- 공용 표시: `lib/ui/game/game_icons.dart`의 `GemIcon`
- 시작 로딩: `lib/ui/game/game_image_assets.dart`의 공용 이미지 목록

표시 크기는 기존 UI 기준을 유지하며 128px 디코딩 캐시를 공유한다.
이름·효과·수량·비용 표기와 젬 저장 식별자는 에셋 교체로 변경하지 않는다.

ImageGen으로 승인 시안의 개별 젬을 추출했다. 실제 알파가 없는 결과는
외부 체크무늬 영역을 분리해 투명화하며, 게임용 축소·여백·PNG 내보내기는 GIMP로 처리한다.
고해상도 투명 원본은 `production/<이름>-transparent.png`에 보존한다.

## 적용 검증

- [공용 GemIcon 14·24·40px 비교](implemented-icons-test.png): 실제 Flutter 위젯의 오프라인 테스트 렌더.
- [360px 보상 화면](../ux-previews/multiple-projectiles/reward.png): 실제 보상 위젯의 오프라인 테스트 렌더.
- `test/game_image_assets_test.dart`에서 14종 디코딩·투명 모서리·시작 로딩 확인.

Mac 잠금으로 인앱 캡처는 수행하지 못했다. 위 이미지는 실제 앱 스크린샷이 아니다.
