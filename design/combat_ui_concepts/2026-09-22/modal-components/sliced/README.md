# 폐기된 개별 분할 방식

실행용 목록에서 제거했다. 개별 PNG는 `deprecated-png/`에 편집 기록으로 보관한다. 현행 방식은 [Godot 공통 테마](../native/README.md)이다. 아래는 당시 분할 기록이다.

# 실제 분할 에셋

V3 원본을 GIMP로 잘라 프레임 1종·버튼 5종을 각각 9개의 개별 PNG로 저장했다. 재생성·크기 변경 없이 동일 원본의 연속 영역을 분할했다.

- 게임 경로: `assets/images/ui/combat_components/sliced/{modal,primary,secondary,danger,selected,disabled}/`
- 각 폴더: `top_left`, `top`, `top_right`, `left`, `center`, `right`, `bottom_left`, `bottom`, `bottom_right`. 총 54 PNG.
- [프레임 분할 미리보기](modal-exploded.png), [버튼 분할 미리보기](primary-exploded.png), [전체 ZIP](components-54-png.zip).
- [좌표·조립 위치](manifest.json), [검증](verification.txt), [GIMP 재현 스크립트](split_gimp.py). 각 `*-layers.xcf`는 분리된 9개 레이어의 편집 원본이다.
- 모서리는 고정 크기로 사용하고 상하 변은 가로로, 좌우 변은 세로로, 중앙은 양축으로 확장한다. 메타데이터 치수는 원본 픽셀 단위이며 UI 배율을 동일하게 적용한다.
- 크기와 알파, 불투명 부분 RGB는 원본과 일치한다. GIMP PNG 처리로 일부 낮은 알파 픽셀의 RGB에 최대 8/255 반올림 차이가 있다.
- 생성 원본에 있던 외곽 노이즈는 보존되어 있다. 이번 범위는 실제 분할과 리소스 등록이며 인게임 UI 교체·여러 크기의 적용 검증은 포함하지 않는다.
