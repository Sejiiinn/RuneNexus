# 유적 감시대장 — 정적 Blender 제작 원본

2026-10-03 `static-v6-hewn`. 승인 [무기 없는 16번](../16-relic-marshal-unarmed.png)과 [멀티뷰](../multiview/16-relic-marshal-multiview.png)를 기준으로 수정했으나, 사용자 후속 지적과 원본 재대조로 **시각 완료 판정을 철회했다. 새 Astra 독립 재감사도 시각 FAIL이며 현재 외형은 미완료다.** 이전 Astra 검증은 부위별 개선을 전체 시안 충족으로 과대 평가했다. 남은 핵심 차이는 몸통·골반의 빈틈과 팔/주먹 위치, 얼굴의 표정·면 구성, 어깨·손발의 개별 형태, 반복적인 표면 패임, 코어·룬·체결물의 상대 크기와 강조 정도다. 최종 독립 검증의 standalone 직접 열기·메시 구조·파일/렌더 해시 대응·기존 씬 보존 결과는 구조 근거로 유지하며, 외형 충족의 근거로 사용하지 않는다.

편집 원본은 [relic-marshal.blend](relic-marshal.blend)이며 직접 열면 `Relic_Marshal_Concept` 씬이 열린다. 모델은 `Relic_Marshal_MODEL`, 루트는 `Relic_Marshal_ROOT`다. 정면 `-Y`, 위 `+Z`, 단위 미터, 최저점 `Z=0`을 사용한다. 부품은 개별 편집 가능한 메시이고 스튜디오·바닥·조명은 별도 컬렉션이다. 리깅·애니메이션·게임 이식·런타임 경량화는 이번 범위에 포함하지 않는다.

## 보존한 외형과 변경

- 둥글던 흉판을 상단이 넓고 허리로 좁아지는 서로 다른 절삭 석판으로 만들고, 매립 가슴핵 주위에 맞물리게 했다.
- 어깨는 낮게 맞물리는 마루석과 바깥 장갑으로 나눴다. 전완·허벅지·정강이는 비균일한 앞/중간/뒤 단면과 넓은 파단면을 가진 주 메시로 구성했다. 관절 노출을 줄이고, 굵은 접힌 손가락·엄지와 발등부터 이어지는 쐐기형 돌발을 유지했다.
- 머리 주 메시에서 두꺼운 이마, 깊은 좁은 눈홈, 짧고 넓은 코, 돌출 턱의 층을 직접 만들었다. 붉은 룬은 한 개의 연속 홈과 매립 인레이이며, 선분 접합의 검은 점을 제거했다.
- 석재는 공간 좌표 기반의 회갈색 풍화 재질로 통일했다. 넓은 면 위 비방향성 중간 패임과 작은 입자를 사용하며, 방향성 있는 줄무늬와 전면의 잔균열을 줄였다. 청동 띠·리벳과 단일 붉은 구형 코어는 입체 부품으로 유지한다.

## 실제 렌더와 검증

[사선](preview-three-quarter.png) · [정면](preview-front.png) · [측면](preview-side.png) · [후면](preview-back.png) · [상면](preview-top.png)은 모두 최종 모델의 실제 Blender Cycles 렌더다. 사선은 정투영 24° 방위·14° 고도, 나머지는 축 정투영이다. 사선 1100×1100, 나머지 1000×1000, 32 samples이며 이미지 후처리는 없다. 수평 정면/측면/후면은 바닥만 숨긴다.

최종 원본 재개방 검사에서 **240개 메시, evaluated 34,460정점·68,208삼각형, 비매니폴드 엣지 0, 누락 참조 0**을 확인했다. 경계는 약 6.333 × 1.991 × 6.631m다. 양 정강이 균열 주변의 미세분할 중복 면은 해당 두 부품의 미세분할만 제외하여 제거했다. 주요 면·재질은 보존했고 최종 원본으로 모든 제공 미리보기를 다시 생성했다. 제작기에도 폐곡면 검사를 추가했다.

[render-conditions.json](render-conditions.json)은 최종 파일/제작·렌더 소스/참조/출력 이미지 해시와 카메라·조명 조건을, [mesh-statistics.json](mesh-statistics.json)은 별도 재개방 결과를 기록한다. 시각 판정과 구조 검사는 구분한다. 회색 형태, 얼굴/어깨 확대, 중간 후보와 상세 로그는 Git 제외 `local/`에 보관한다.

## 기존 작업 보존과 재현

수정 전에 미저장 전체 세션을 `local/before-astra-full-session.blend`에 복구본으로 저장했다. 열린 원래 파일 경로는 유지하며 그 파일을 덮어쓰지 않았다. 최종 원본은 모델 씬만 분리 저장했다. 전후 전체 **36개 씬**을 유지했고, 대상 외 **35개 씬**의 오브젝트 구성·변환·메시 전체 정점/토폴로지·재질 슬롯 연결 해시가 복구본과 일치했다. 대상과 다른 씬의 공유 메시/재질은 0이다. 제작기는 정확히 대상 씬만 교체하고 재질·메시·월드를 새로 생성한다. 상세 대응은 `local/preservation-summary.json`과 전후 목록에 있다.

기존 bpy 제작·분리 저장 경로를 사용한다. 이 폴더에서 다음 순서로 재현한다. 열린 Blender 세션에서는 [build_relic_marshal.py](build_relic_marshal.py)를 MCP로 실행하며 다른 씬을 보존한다.

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python-exit-code 1 --python build_relic_marshal.py
/Applications/Blender.app/Contents/MacOS/Blender --background relic-marshal.blend --python-exit-code 1 --python render_views.py
/Applications/Blender.app/Contents/MacOS/Blender --background relic-marshal.blend --python-exit-code 1 --python finalize_project.py
/Applications/Blender.app/Contents/MacOS/Blender --background relic-marshal.blend --python-exit-code 1 --python check_relic_marshal.py
```

관련 뷰만 필요하면 `render_views.py -- --views=three-quarter`로 선택한다. Git 커밋·푸시는 수행하지 않았다.
