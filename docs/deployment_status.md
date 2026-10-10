# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


## 현재 미배포 변경

확인 기준: 2026-10-11 KST(UTC 2026-10-10). 승인된 변경은 아래 **Android 0.2.18 / 6047과 서버·DB**에 공개·운영 반영했다. 챕터3 후반·다섯 번째 링크·타일/냉각 포탑 경량화를 포함한 이번 요청 범위의 미배포 변경은 없다.

미완료 검증의 범위·완료 조건은 [구현·검증 체크리스트](implementation_checklist.md)에서 관리한다. 사용자의 큰 개발 계획은 [TODO](TODO.md)와 구분한다. 추가 배포나 최소 지원 버전 변경은 사용자 승인 범위에서 수행한다.

## 2026-10-11 Android 0.2.18 / code 6047 — 공개 완료

- APK 대상 `4a94337cd0c366805a912d79efc295a15986d99d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38068681133)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6047). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6047/rune-nexus.apk). 공개 시각은 2026-10-10 17:08:25 UTC이며 **선택 업데이트·최소 지원 코드 6039**를 유지했다. 검수한 build-only 산출물 5개를 그대로 공개했다.
- 챕터3 3-6~3-10·다중 경로/포탈과 저장, 3-10 성공 클리어 및 링크 확장 I 완료 후 해금되는 **링크 확장 II(기본 45,000룬·8시간)**를 포함한다. 기존 비용/시간 효율을 적용하고, 연구 완료 뒤 실제 다섯 번째 슬롯은 Lv.5·네 번째 기본 가격의 2배 골드로 구매한다. 서버·DB는 아래 절과 같이 먼저 반영했으며 APK 대상의 추가 커밋은 회귀 검사 한 파일만 바꿔 서버 실행 코드와 일치한다.
- 챕터2·3 타일과 냉각 포탑 메시 경량화, 젬14종 128px 이미지, 보상 숫자 축약/전투 UI, 시작 우편 조회·이벤트/우편 배지, 메뉴 복귀 일시정지와 보상 ACK 이후 적 사망 연출 전달 수정을 포함한다. 실제 게임의 승인 외형·조작 근거는 관련 입력 범위에서 활용했다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/38068024942)는 연구 선택 검사에서 새 선행 연구 잠금 상태를 기대값에 포함하지 않아 실패했다. 제품 동작을 보존하고 실제 해금/선행 조건으로 검사를 보정했다. 별도 검증자가 단일 사례 통과 및 잘못된 선택 노출·차단 오류 주입의 실패를 확인했다. 최종 CI의 Python110개·Godot 회귀73개·계정/AppServices·서명 빌드·Android 패치 디코더·6044/6045/6046 Python/Kotlin 복원이 통과했다.
- 별도 검증자가 실제 APK의 패키지/버전·운영 설정·최종 build·원본 JSON·변경된 compiled 스크립트, ABI3종·네이티브6개 SHA와 기존 서명 인증서를 대조했다. 실제 PCK를 엔진에서 로드해 냉각 포탑 **11,760삼각형·1024px 압축 맵4개**, 챕터2·3 메시/맵, 젬14종 원본 픽셀 일치를 확인했다. APK에 포함된 compiled 코드의 45,000룬·8시간·ID30/I 선행 조건·세대6, 다섯 슬롯의 금액/Lv.5/서로 다른 젬 스탯·체크포인트 복원·불법 슬롯 거부·구4슬롯 보존193건이 통과했다.
- APK **410,646,370 bytes**, SHA-256 `e28851dab20b33cad0d9f04e7318ffbd51bddc3fa01355652ffcd70c9fc3c686`. 6046 대비 **12,137,476 bytes 감소(-2.8708%)**로 모두 PCK 감소다. PCK182,422,064 bytes·1177항목이며 scene -9,687,889/texture -3,733,698/content +1,253,980/script +32,159 bytes를 포함한다. 제작 원본은 포함하지 않았고 기존 챕터2 노멀맵3개의 동일 압축 결과699,208 bytes 중복만 남는다. 6046→6047 패치는129,235,621 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산5개의 크기/GitHub SHA-256과 검수본 일치, 익명 APK HTTP200을 확인했다. 외장 SSD의 일부 검증 경로 I/O 지연으로 최종 APK·패치·CI·독립 검수·추가 DB 근거는 내장 SSD의 Git 밖 `~/Library/Application Support/RuneNexus/operations/apk-6047-release-verification/`에 보관한다. API37 AVD의 기존 부팅 장애에 변화가 없고 API36 이미지·연결 기기가 없어 최종 Android 설치·본게임·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 **미검증**이다. 정상 성장으로 챕터3 후반을 연속 플레이한 난이도와 실제 Google 계정 E2E도 [기존 확인 항목](implementation_checklist.md)에 남는다.

## 2026-10-11 서버·DB — 6047 선행 반영 완료

- 서버 대상 `cfa9e6d82de422ab1e9deccadcdb3bb37df3cf9e`의 정확한 `git archive` 소스로 `rune-nexus-api:cfa9e6d8`를 빌드해 기존 운영 API에 반영했다. 실제 실행 image는 `sha256:0ec474c20437969ca2943236f48ea1d94cb2be6d88754040980fd933fac052a9`이며 revision label과 대상 SHA가 일치한다.
- 운영 DB를 **스키마 12→13**으로 올렸다. 기존 운영 tern 마이그레이터가 `013_chapter_three_routes.sql` 하나만 적용했으며 ID26–30 제약·진행 순위 함수·랭킹 인덱스를 실제 DB에서 확인했다. 기존 진행·계정 기록 삭제나 DB down은 수행하지 않았다. 적용 직전 보호된 custom-format 백업을 확보하고 별도 PostgreSQL18에 복원해 스키마12 복구 가능 여부를 확인했다.
- 기존 영속 인증키·전체 API 환경·secret mount를 보존하고 **최소 저장 호환 세대4**를 유지했다. ID26–30/경로 저장은 선택적으로 세대5, 링크 확장II 연구/5슬롯 저장은 선택적으로 세대6을 요구한다. 기존 6046의 25맵 저장 접근을 유지하며 전체 최소 호환 세대를 올리지 않았다. DB/Caddy/DuckDNS 컨테이너와 네트워크·공유기 설정은 유지했다.
- 같은 최종 image를 별도 복원 DB와 합성 검증 계정에 연결해 HTTP 계약15건을 통과했다. 기존 세대4 writer·저장 허용, ID30 저장의 세대4 차단, 링크II의 세대5 writer/PUT 426, 즉시 완료·멱등 재시도·효과 ACK, 연구 완료·5슬롯 저장/조회 왕복과 구버전 덮어쓰기 차단을 확인했다. 운영 사용자 계정·저장은 조작하지 않았다.
- 추가 P0 검증에서 확정 서버 소스의 유지 DB 통합 검사3개(skip0), 012→013 기존 기록/달성 시각 보존·26–30 랭킹·신규 기록이 있는 down의23514 거부·실패 후 스키마/함수/제약/인덱스/모든 기록 보존4건을 통과했다. 별도 검증자가 원본 Git 바이트와 전후 SQL/JSON·실제 실패 로그를 대조했다. Go1.26.5·PostgreSQL18.4의 별도 임시 DB를 사용한 뒤 삭제했으며 운영 DB·계정은 조작하지 않았다.
- 운영 API는 healthy이며 loopback·공개 HTTPS live/ready 200, 무인증 저장·writer·경제 카탈로그·링크II 완료·랭킹401을 확인했다. 상세 배포·백업 메타·복원·격리 HTTP·운영 DB/health 근거는 로컬 `build/release-verification/apk-6047/server/`에 보관한다. 백업과 영속 private compose는 Git 밖의 보호된 운영 폴더에 유지했고 검증 컨테이너·임시 볼륨·네트워크는 제거했다. 실제 Google 계정 로그인·운영 계정의 연구/저장 동기화는 미검증이다.

## 2026-10-09 Android 0.2.17 / code 6046 — 공개 완료

- APK 대상 `a63ce407374191b0e415b2d8c6e8d23c79899bd6`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37882057710)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6046). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6046/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검수한 build-only 산출물 5개를 그대로 공개했다.
- 승인 일반 골렘·최적화 탱커·UltraTex 보스 모델과 보행·사망 표시, 젬 장착 VFX, 이동 경로 선과 설치 충격 조정을 포함한다. 스테이지 자원 수명·로딩 안내·타깃 메시 준비·UI/환경 텍스처 메모리·별 배경 조회를 최적화하고, 저장 오류·타깃 처리·고정 전투 시간 간격·지속피해·앱 전환 시간 보정을 반영했다. 서버·API·DB·Android 호스트·운영 설정 변경이나 재배포는 없다.
- 독립 검토에서 최종 탱커 입력·상태 에셋과 실제 Mobile/Metal 게임의 이동·일시정지·12조각 사망·냉각 핵 보호 근거가 일치했고, 최신 전투 시계·지속피해 집중 회귀 2개를 격리 실행해 통과했다. 기존 일반·보스·기타 표현 근거는 관련 입력·공유 의존성 범위에서 활용했다. 부모도 대표 실제 게임 화면을 확인했다. 이는 데스크톱 및 헤드리스 결과이며 최종 Android 실행 검증과 구분한다.
- 최초 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37881409226)는 젬 보상창 resize 검사에서 약 0.000015px 부동소수점 오차를 완전 일치로 비교해 실패했다. 런타임·기대 좌표는 보존하고 기존 중심 검사와 같은 근사 비교로 수정했다. 별도 검증자가 원본 실패와 수정 후 45개 통과, 중심/배치 각각 1px 오류 주입 시 실패를 확인했다. 최종 CI의 Python 83개·콘텐츠·Godot 회귀 62개·계정/AppServices·서명 빌드·Android 패치 디코더·6043/6044/6045 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK의 패키지·버전·운영 설정·대상 build·콘텐츠 JSON·변경 컴파일 스크립트와 탱커 상태 자료 포함을 대조했다. 별도 검증자가 실제 APK의 PCK에서 normal/normal_death/tank/tank_death/boss 5씬을 직접 로드·생성해 삼각형·스킨·클립·공유 맵을 확인했다. 탱커 Walk 49키·Death 61키의 24Hz 원본 키 보존, 상태 자료 9개·관련 셰이더 3개의 원본 일치, 최종 compiled 고정 시계·보폭·사체 수명도 확인했다.
- APK **422,783,846 bytes**, SHA-256 `ff9fd36ae8b84d6fa18ef5c289123a22c6f78822691b54dd63e7f3e609a7bbf7`. 6045 대비 **22,408,364 bytes 감소(-5.0334%)**로 PCK 감소와 일치한다. 텍스처 payload -25,195,642 bytes가 주요 감소 원인이며 새 별 배경 자료 +2,596,638 bytes 등을 반영했다. PCK 194,559,540 bytes·1181항목, 제작 원본 포함 없음, 지원 ABI 3종과 네이티브 라이브러리 크기·CRC 유지. 챕터2 건설칸·측면·길 노멀맵 3개의 512 축소·ASTC 결과가 같아 699,208 bytes의 완전 중복이 남는다. 원본의 최대 1/255 소수 픽셀 차이가 축소 후 사라진 것으로 출처·로드 참조를 확인했으며 잘못된 맵 포함으로 보지 않는다. 6045→6046 패치는 139,948,602 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK HTTP 200을 확인했다. 로컬 산출물과 상세 검증은 외장 SSD의 `build/release-verification/apk-6046/`에 보관한다. 새 격리 Android API37 AVD는 앱 실행 전 `super` 파티션 경로 오류로 커널 재부팅을 반복했고 구성/렌더러 대체에서도 복구되지 않았다. API36 대체 이미지·연결 실기기가 없어 최종 APK 설치·본게임·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 **미검증**이다. 기존 사용자 저장·계정·AVD는 보존했다.

## 2026-10-07 Android 0.2.16 / code 6045 — 공개 완료

- APK 대상 `d859b80d944f6a9712bbf9c616ebc399381f78c5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37565375644)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6045). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6045/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검수한 build-only 산출물 5개를 그대로 공개했다.
- 포탑 모듈 코어·포신·프레임의 등급별 아이콘 12종과 유니크 전용 배경 후광, 빈 모듈 인벤토리의 슬롯 한 줄, 라이트닝 포탑 표시 크기 10% 축소, 설치 시 0.22초·최대 2px 상하 충격을 포함한다. 화상·독 지속피해는 방어구 감쇄를 무시하되 보호막→방어구→체력 순서를 유지하며, 장갑병 처치 보상은 7→8골드다. 서버·DB·운영 설정 변경이나 재배포는 없다.
- 독립 검증자가 승인 원본과 최종 모듈 화면·관련 입력·공유 의존성을 대조하고, 기존 지속피해 독립 89건의 입력 유효성을 확인했다. 실제 App 격리 실행에서 장갑병 보상 6건, 라이트닝 미리보기·설치 90% 크기와 상하 충격·HUD 고정·일시정지/4배속 64건, 빈 인벤토리 320px 12건이 통과했다. 부모도 최종 모듈·빈 인벤토리·전장 화면과 설치 시간축을 직접 확인했다. 추가 실제 실행은 Godot 4.7.2·macOS Apple M4·Metal Forward Mobile의 데스크톱 결과다.
- CI Python 77개·콘텐츠·Godot 네이티브 회귀 57개·계정/AppServices 검사, 서명 빌드·Android 패치 디코더·6042/6043/6044 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK의 버전·운영 설정·대상 build, 최종 콘텐츠 JSON과 장갑병 8골드, 모듈 텍스처 13개와 변경된 컴파일 스크립트의 포함도 확인했다.
- APK **445,192,210 bytes**, SHA-256 `6a013a85740b9c0a3f1ea4e0b99b1009d49a90b8d2ff9bc7028a4c04610e25a2`. 6044 대비 **+2,674,056 bytes(+0.6043%)**로 모두 PCK 증가이며 새 모듈 아이콘·후광이 주요 원인이다. PCK 216,967,904 bytes·1177항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종과 네이티브 라이브러리 크기·CRC를 유지한다. 6044→6045 패치는 157,161,555 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK HTTP 200을 확인했다. 다운로드 정체는 받은 바이트를 보존하고 이어받아 복구했으며 전체 아티팩트의 GitHub SHA-256을 대조했다. 로컬 산출물과 검증 자료는 외장 SSD의 `build/release-verification/apk-6045/`에 보관한다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·터치/수명주기·모바일 GPU/지속 성능은 미검증이다.

## 2026-10-06 Android 0.2.15 / code 6044 — 공개 완료

- APK 대상 `d8f19196c5bd08fe1ef11926036c8e87840ba71d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37468968196)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6044). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6044/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검증한 build-only 산출물 5개를 그대로 공개했다.
- 이전에 미배포였던 자동 저장 중복 처리 최적화, 젬 보상 카드·모달 등장 애니메이션, 3종 강화 상한 확장 연구의 비용 10배 조정, 처치 보너스 강화 비용 하향·레벨 구간별 효과 개선, 두 번째 연구 슬롯의 초기 안내, 연구 목록의 청록 테두리·전체 명암 구분을 모두 포함한다. 목록의 시작 가능 문구·체크·룬 부족 표시는 제거했다. 2-10 클리어 전 슬롯 구매 안내는 비활성화하며 기존 600다이아 구매 계약을 유지한다.
- 독립 검증자가 신규/2-10 전후/구매 후의 320px 실제 화면·포인터 구매·재진입을 확인했다. 440px 초기 안내, 카탈로그 320/440, 슬롯 A안, 젬 연출, 자동 저장, 처치 보너스는 현재 입력·소스와 유효성을 대조한 기존 독립 근거를 활용했다. CI 전체 검사·서명 빌드·Android 패치 디코더·6041/6042/6043 서명 일치와 Kotlin 차등 복원이 통과했다. 실제 APK 내부의 3종 연구 첫 비용 1500, 처치 보너스 첫 비용 10·효과 0.03, 젬 연출 컴파일 코드도 확인했다.
- APK **442,518,154 bytes**, SHA-256 `95723e6b65d296b5146be58eea5d7e4c1bfbce4a8b2196767c639517a484a92c`. 6043 대비 **+10,140 bytes(+0.00229%)**로 모두 PCK 증가이며 새 젬 연출 코드가 주요 원인이다. PCK 214,293,848 bytes·1151항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종·네이티브 라이브러리 크기·CRC와 텍스처 용량을 유지한다. 6043→6044 패치는 168,769,507 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치, 익명 APK HTTP 200을 확인했다. DuckDNS는 실행 중 컨테이너의 `0:0`·healthy·읽기 전용·권한 제한이 이미 반영돼 있어 재시작하지 않았다. API·DB 변경이나 재배포는 없다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·지속 성능은 미검증이다. 근거는 로컬 `build/release-verification/apk-6044/`에 보관한다.

## 2026-10-06 Android 0.2.14 / code 6043 — 공개 완료

- APK 대상 `993de3fa34ecd86f6c6baff50709657fceac170a`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37448415598)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6043). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6043/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 검증한 build-only 산출물 5개를 그대로 공개했다.
- 연구 중 슬롯에 승인된 A안의 남청 금속 카드·연구 아이콘·금색 진행바와 진행률·남은 시간·청동색 중단 버튼·청록색 즉시 완료와 다이아 비용을 적용했다. 재개한 연구의 경과 시간을 보존하고 초기 진행률을 바로 표시한다. 이전 공개본 이후 main의 골렘 보스 보행·사망, 웨이브 예고와 실제 적 구성 일치, 탱커 사망 계산 정리, 텍스처 압축도 포함한다. 미승인 로컬 변경·기존 미푸시 커밋은 제외했고 서버·DB 재배포는 없다.
- 별도 검증자가 배포 후보의 연구 슬롯·중단·상세·성장 규칙·저장 관련 회귀와 1/2슬롯 각각 320/440 실제 Godot 화면을 확인했다. CI 전체 검사·서명 빌드·Android 패치 디코더·6040/6041/6042 서명 일치와 Kotlin 차등 복원이 통과했다. 첫 CI의 기존 `×` 기대 문구를 승인된 `중단`으로 고친 뒤 해당 검사와 최종 CI를 통과했다.
- APK **442,508,014 bytes**, SHA-256 `e7288a84c4a1d0a5f7aebea0202add6b867649494be07096dd401f17b888816f`. 6042 대비 **+26,888,936 bytes(+6.47%)**이며 거의 전부 PCK 증가다. ASTC 텍스처 +57,324,908 bytes, 기존 기타 텍스처 -34,271,800 bytes, 가져온 장면 +3,259,588 bytes(주로 보스)가 주요 원인이다. PCK 214,283,708 bytes·1149항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종과 네이티브 라이브러리 크기·CRC를 유지하며 6042→6043 패치는 152,849,661 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 검수본 일치, 익명 APK HTTP 200을 확인했다. 연결된 Android 기기가 없어 실기기 설치·로그인·저장 유지·지속 성능은 미검증이다. 근거는 로컬 `build/release-verification/apk-6043/`에 보관한다.

## 2026-10-04 Android 0.2.13 / code 6042 — 공개 완료

- APK 대상 `74c7d33d37055dc37ff05d5eeec6e6d24227573e`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/37169361846)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6042). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6042/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지하며 build-only 산출물 5개를 그대로 공개했다.
- 모듈 뽑기 확인창 공간, 전투 종료·계정 모달, 연구 상세 정보, 결과창 크리스탈 결집 연출, 포탑 설치 충격·3D 먼지·LOD, 설치 포탑·미리보기의 남서쪽 기본 방향, 라이트닝 포탑 모델·입체 연쇄 공격 효과를 포함한다. 미커밋 연구 카드 수정은 제외했다. 서버·DB·운영 설정 변경이나 재배포는 없다.
- 첫 CI는 Godot 준비 테스트의 임시 자산에 새 설치 먼지 파일이 없어 실패했다. 제품 동작은 유지하고 fixture에 GLB·JSON을 추가한 뒤 재실행했다. 최종 CI의 Python 71개·콘텐츠·Godot 네이티브 회귀 54개·계정/AppServices 검사, 서명 빌드·Android 패치 디코더·6039/6040/6041 서명 일치 및 차등 복원이 통과했다.
- APK **415,619,078 bytes**, SHA-256 `c004a09e7efce0c48153438fa58eb0bb02931c0ffa963d11de11be514a591748`. 이전 6041 대비 **+853,872 bytes(+0.2059%)**이며 증가 대부분은 PCK의 라이트닝 모델·공격 메시와 설치 먼지다. PCK 187,394,768 bytes·1129항목·완전 중복 0, 제작 원본 포함 없음. ABI 3종을 유지하며 네이티브 라이브러리의 크기·CRC는 이전 공개본과 같다. 6041→6042 패치는 180,404,610 bytes다.
- 공개 태그 대상·latest/버전별 manifest 바이트 일치, 자산 5개의 크기·GitHub SHA-256과 CI 산출물 일치, 익명 APK 접근 HTTP 200을 확인했다. 사용자 요청에 따라 추가 로컬 기능·화면 검증과 Android 설치·실행을 생략했다. 이번 APK의 실기기 로그인·저장 유지·지속 성능은 미검증이다. 로컬 근거는 `build/release-verification/apk-6042/`에 보관한다.

## 2026-10-02 Android 0.2.12 / code 6041 — 공개 완료

- APK 대상 `7a6065debda844fc1d0a425f87f59529cb85f57d`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36965869424)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6041). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6041/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지한다. build-only 검수본 5개를 그대로 공개했다.
- 냉각타워 감속 스탯 표시 순서, 스테이지 결과창·보상 즉시 정산, 포탑 모듈 화면·작업 버튼 배치, 일일·주간 임무 완료 집계의 출석 포함을 반영했다. 탱커의 승인 모델·걷기·사망·화상/냉각 효과·머리 위 체력바도 함께 커밋·배포했다. 제작 원본과 필요한 입력은 보존하고 중복 GLB export·임시 검증 산출물은 추적에서 제외했다.
- API는 정확한 서버 소스 `2923497c426087963ab2b20632c8833e1f8bd39b`의 `rune-nexus-api:2923497c` 이미지로 반영했다. APK 대상과 서버 소스는 동일하다. 운영 환경·secret·포트·DB/Caddy/DuckDNS를 보존하고 **DB 스키마 12·최소 저장 호환 세대 4**를 유지했다. Go 테스트 292개·vet·출석 집계의 격리 DB 13사례와 새 운영 백업의 격리 복원을 통과했다. 실제 이미지·설정 보존과 공개 live/ready 200·무인증 경제/우편함/랭킹 401을 별도 검증자가 확인했다. migration·운영 계정 조작은 없다.
- CI의 Python 71개·콘텐츠·Godot 네이티브 회귀·계정/AppServices 검사, 서명 빌드·Android 패치 디코더와 6038/6039/6040 차등 복원을 통과했다. 별도 검증자가 최종 입력에 대응하는 기존 실제 화면·독립 근거를 대조하고 결과 정산·임무·모듈 관련 회귀를 실행했다. 최종 APK의 버전·운영 설정·대상 빌드·기존 정식 인증서·필수 탱커 리소스·패치 무결성도 독립 확인했다.
- 격리 Android API 37 arm64 AVD의 host GPU에서 정식 6040→6041 덮어 설치·최초 설치 시각 유지·로비·이어하기·Home 복귀·일시정지 터치 맵 이동을 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 런·모듈·설정·진행 필드가 유지됐다. 별도 저장 복사본의 본게임에서 탱커 기본/화상/냉각 보행·체력바·포탑 피격·코어 빔과 사망 직후 HP/상태 제거·정지/재개·붕괴·잔해 소멸을 확인했다. 부모도 최종 실제 화면·시간축을 직접 대조했다. 초기화 중 입력이 무시된 로비 녹화와 일시정지 구간은 붕괴 완료 근거에서 제외하고 실제 재개 영상을 확인했다. AVD 원본은 보존했다.
- APK **414,765,206 bytes**, SHA-256 `8e47d060f265d193bff6dbf6eef8451dec78b959c6e911a805f280482006c1ff`. 이전 6040 대비 **+13,134,588 bytes(+3.2703%)**로 PCK 증가분과 같다. PCK 186,540,900 bytes·1097항목·완전 중복 0이며 탱커 atlas·skinned 모델/상태 리소스와 결과창 이미지가 주요 증가 원인이다. ABI 3종·네이티브 라이브러리 6개의 바이트는 동일하며 제작 원본·시안·중복 원본 GLB는 APK에 포함하지 않았다.
- 공개 태그의 대상 SHA, latest/버전별 manifest 바이트 일치, 공개 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK 접근 HTTP 200을 확인했다. 실제 기기 Google 로그인·실계정 동기화/보상 수령·설치 권한 흐름·실기기 지속 성능은 미검증이며 에뮬레이터 결과로 대체하지 않는다. 상세 근거는 로컬 `build/release-verification/apk-6041/`에 보관한다.

## 2026-10-02 Android 0.2.11 / code 6040 — 공개 완료

- APK 대상 `2b1f68fb57c41bbd603af42c05ae9b1ed9044c42`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36895240820)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6040). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6040/rune-nexus.apk). **선택 업데이트·최소 지원 코드 6039**를 유지한다. build-only 검수본 5개를 그대로 공개했으며 미커밋 변경은 포함하지 않았다.
- 젬 장착·교체 모달의 잠긴 슬롯 추가 선택과 골드 아이콘, 모듈 뽑기 확인창·한글 가독성, 일시정지 중 맵 조작·포탑 선택/설치, 런 전환·보상 정산·저장 읽기·보스 상태효과 수정, 반복 계산·저장/효과 비용 개선과 우편함 분리를 포함한다. 기존 최종 UI·저장·전투 검증 근거의 관련 소스 일치를 확인하고 저장 계약 회귀를 독립 실행했다.
- API는 커밋 `3c1802ef8f12541eb4c5e030a00f1c38cd125ee7`의 정확한 서버 소스로 만든 `rune-nexus-api:3c1802ef` 이미지로 반영했다. APK 대상과의 차이는 검사 파일 1개뿐이다. 운영 환경·secret mount·DB/Caddy/DuckDNS를 보존하고 **DB 스키마 12·최소 저장 호환 세대 4**를 유지했다. migration 변경·운영 계정 조작은 없다. 보호된 DB 백업을 확보했으며 Go 테스트·vet·관련 격리 DB 통합 검사와 공개 live/ready 200·무인증 경제/우편함/랭킹 401을 확인했다. 별도 검증자가 실제 이미지와 운영 설정·공개 응답을 독립 확인했다.
- CI의 Python·콘텐츠·Godot 네이티브 회귀·계정/AppServices 검사, 서명 빌드·Android 패치 디코더 및 6037/6038/6039 차등 복원을 통과했다. 첫 실행에서 모듈 뽑기 확인창의 이전 문구를 찾던 AppServices 검사가 실패해, 승인된 분리 비용 표시의 실제 값으로 검사만 수정한 뒤 재실행했다. 게임 동작은 바꾸지 않았다.
- 격리 Android API 37 arm64 AVD의 host GPU에서 정식 6039→6040 덮어 설치와 최초 설치 시각 유지, 로비·이어하기·시스템 Home 복귀·복원된 일시정지 상태의 터치 맵 이동/포탑 선택을 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 런·모듈·설정·진행 필드가 유지됐다. 초기 소프트웨어 GPU 환경의 이전 버전 로딩 지연은 host GPU 설정으로 복구했다. 실제 기기 Google 로그인·계정 동기화·설치 권한 흐름·실기기 성능은 미검증이며 에뮬레이터 결과로 대체하지 않는다.
- APK **401,630,618 bytes**, SHA-256 `4609781bad5d0a024c1b64cf9fd997fd49f2f9a2339a951e32a95b22679ed0f1`. 이전 6039 대비 **+26,036 bytes(+0.00648%)**로 PCK 증가분과 같다. PCK 173,406,312 bytes·1066항목·완전 중복0이며 새 스크립트와 분리한 UI/런 전환 helper가 증가 원인이다. ABI 3종·네이티브 라이브러리 6개의 바이트와 에셋 바이트는 동일하고 제작 원본·시안은 포함하지 않았다. 기존 정식 인증서와 동일한 서명을 확인했다.
- 공개 태그의 대상 SHA, latest/버전별 manifest 바이트 일치, 공개 자산 5개의 크기·GitHub SHA-256과 검수본 일치 및 익명 APK 다운로드 HTTP 200을 확인했다. 상세 CI·서버·APK 감사·Android 저장/화면·독립 검증 근거는 로컬 `build/release-verification/apk-6040/`에 보관한다.

## 2026-10-01 Android 0.2.10 / code 6039 — 공개 완료

- 대상 `dff8cd37ca56bc9995e7504c26b07f2c0998bd6f`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36803498647)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6039). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6039/rune-nexus.apk). **필수 업데이트·최소 지원 코드 6039**로 공개했다.
- 스테이지 룬 보상을 고정 ID 대신 전체 진행 순서로 계산해 챕터 전환에서도 증가하도록 통일했다. 긴 스테이지 목록은 터치·휠 스크롤이 가능하며 스크롤바를 숨겼다. 서버·DB 변경은 없으며 이전 배포의 DB 스키마 12·최소 저장 호환 세대 4를 유지한다.
- 사용자 요청에 따라 추가 로컬 검증·Android 설치·실행·검수를 생략했다. 커밋 전 확보한 관련 Godot 실행·룬 보상 및 목록 스크롤 독립 검증 근거를 재사용했다. CI에 포함된 자동 검사·서명 빌드·패치 디코더·6036/6037/6038 차등 복원은 통과했다. 이번 배포의 Android 동작·실기기 성능은 미검증이다.
- APK **401,604,582 bytes**, SHA-256 `53ef24b5c6446cb0e3acb26510dd9a02125cac91d7dce9fbfbdb036cec0ea052`. 이전 6038 대비 **+56 bytes**다. CI 감사의 PCK는 173,380,276 bytes·1052항목·완전 중복0으로 이전보다 48 bytes 증가했으며 새 에셋·네이티브 의존성은 없다.
- 공개 태그·대상 커밋, latest/버전별 manifest 바이트 일치, 최소 지원 코드 6039, 공개 APK·패치의 크기·GitHub SHA-256과 manifest 일치 및 익명 APK 다운로드 HTTP 200을 확인했다. 로컬 근거는 `build/release-verification/apk-6039/`에 보관한다.

## 2026-10-01 Android 0.2.9 / code 6038 — 공개 완료

- 대상 `0d9a8cc215e6e9859ba41b33671676255f7dad67`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36795400076)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6038). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6038/rune-nexus.apk). **필수 업데이트·최소 지원 코드 6038**로 공개했다.
- 모듈 뽑기 결과에 아이콘과 효과 요약을 표시하고 긴 효과·좁은 화면의 스크롤과 아이콘 모서리 배경을 개선했다. 이번 공개에는 고정 ID 1~25 확장 스테이지·성장 해금·SWIFT 저격 포탑·전투 효과·퀘스트 보상과 저장 처리 개선도 포함한다. 별도 모듈 아이콘 아트는 추가하지 않았고 기존 표시와 향후 에셋 연결 방식을 유지한다.
- API는 런타임 소스 `97daa37a8fcac64caaf574e3a56a1cda51e46e73`의 `rune-nexus-api:97daa37a` 이미지로 반영했다. DB는 `11→12`로 이관해 스테이지 1~25와 논리 진행 순서의 랭킹을 지원한다. 운영 환경·secret 읽기 권한·DB/Caddy/DuckDNS를 보존했다. 새 APK 공개를 확인한 뒤 **최소 저장 호환 세대 4**로 전환했다. 공개 HTTPS live/ready 200과 무인증 API 401을 확인했다.
- 운영 DB를 보호된 위치에 백업하고 격리 복원·012 적용·신규 스테이지 기록이 있을 때 down 거부를 확인했다. 기존 29개 데이터 테이블의 행·ID·달성 시각 지문은 이관 전후 동일하다. Go 테스트 216개·vet·관련 DB 통합 7개를 통과했으며 실계정 데이터·보상 지급은 조작하지 않았다.
- CI 자동 검사·서명 빌드·패치 디코더·6035/6036/6037 차등 복원을 통과했다. 첫 CI의 기존 모듈 제목 검사 불일치는 새 표시 기준으로 수정해 재검증했다. 승인 시안과 모서리 수정의 Godot 실제 화면·관련 회귀 근거는 최종 UI와 일치하며 독립 검증을 통과했다.
- 격리한 읽기 전용 Android API 37 에뮬레이터에서 공개 6037→6038 업데이트 설치·로비·이어하기를 확인했다. 스테이지 1·웨이브 23/40·HP 4/20·골드 2199·젬 조각 34·포탑 8개와 기존 런·모듈·설정·진행 필드가 유지됐고 새 진행 권한 필드만 정상 이관됐다. 실제 기기 Google 로그인·실계정 동기화·전체 25스테이지 플레이·모바일 성능은 이번 검증 범위에 포함하지 않았다.
- APK **401,604,526 bytes**, SHA-256 `75e2f5f6b94dce64836d5be17242308dfc69891a9cb4a800c78c7e4de4082565`. 이전 6037 대비 **+17,339,640 bytes(4.51%)**로 PCK 증가분과 같으며 확장 스테이지 에셋이 주원인이다. PCK 173,380,228 bytes·1052항목·완전 중복0. ABI 3종·네이티브 라이브러리 6개의 바이트가 동일하고 제작 원본·시안은 포함하지 않았다.
- 공개 태그 커밋, latest/버전별 manifest 바이트 일치, 공개 5개 파일의 크기·GitHub SHA-256과 검증 산출물 일치 및 익명 APK 다운로드 응답을 확인했다. 상세 로그·감사·저장 전후·화면 근거는 로컬 `build/release-verification/apk-6038/`에, DB 백업은 별도의 보호된 운영 보관 폴더에 유지한다.

## 2026-09-29 Android 0.2.8 / code 6037 — 공개 완료

- 대상 `d4955ab0f1434f5402d73db9746fc150ff0c8773`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36491118299)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6037). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6037/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 이어하기를 일시정지 상태로 열고, 누적 피해를 포탑 속성 태그 오른쪽으로 옮겨 확보한 높이를 스탯 영역에 배분했다. 공격 목표는 젬 링크 옆의 간결한 공격 아이콘으로 표시한다. 서버·DB 변경은 없다.
- 사용자 요청에 따라 최종 소스와 일치하는 기존 Godot 실행·관련 회귀·독립 검증을 재사용하고 배포 필수 검사만 수행했다. CI 자동 검사·서명 빌드·패치 디코더·6034/6035/6036 차등 복원은 통과했다. Android 설치·실행과 실기기 성능 검증은 반복하지 않았으며 이번 배포의 성능 통과로 해석하지 않는다.
- APK **384,264,886 bytes**, SHA-256 `ff231738674779a6a4b1843b7b9d5ecb9ba03764ec7bc7b06fbdb6145d6d22e3`. 이전 6036 대비 **+1,152 bytes**이며 PCK 증가분과 일치한다. PCK 156,040,588 bytes·959항목·완전 중복0. 스크립트 변경에 따른 증가이며 새 대용량 에셋·네이티브 의존성은 없다.
- 공개 태그 커밋, latest/버전별 manifest 바이트 일치, APK·패치의 공개 크기·GitHub SHA-256과 manifest 일치 및 익명 다운로드 응답을 확인했다. 로컬 근거: `build/release-verification/apk-6037/`.

## 2026-09-29 Android 0.2.7 / code 6036 — 공개 완료

- 대상 `b2ca12bc5c259ce1c2e4a82f5b8b108cca0a7083`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36448316225)와 [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6036). [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6036/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 첫 전투 효과 사전 준비, 일반 앱 복귀 시 현재 화면 유지, 연속 강화, 작은 포탑 스탯창, 특성·젬 보상 선택 시 레이아웃 안정화, 지속 고통 젬의 지속피해 증폭과 설명 수정을 포함했다. 서버·DB 변경은 없다.
- 사용자 요청으로 Android 설치·실행 검증과 추가 로컬 검사를 생략하고 직접 공개했다. 기존 변경별 데스크톱 실행·독립 검증 근거를 유지하며, 배포 CI의 자동 검사·서명 빌드·패치 디코더·6033/6034/6035 차등 복원은 통과했다. Android 수명주기·실기기 성능은 이번 배포에서 미검증이다.
- APK **384,263,734 bytes**, SHA-256 `2e6dd8a2d023b2e4f99090beeedbaa8574ef530da8e95f2cad57a336ad4dcaa4`. 이전 6035 대비 **+6,908 bytes**이며 PCK 증가분과 일치한다. PCK 156,039,436 bytes·959항목·완전 중복0. 효과 준비 등 스크립트 변경에 따른 증가이며 새 대용량 에셋·네이티브 의존성은 없다.
- 공개 태그의 커밋, latest/버전별 manifest 일치, APK·패치의 공개 크기·GitHub SHA-256과 manifest 일치를 확인했다. 로컬 근거: `build/release-verification/apk-6036/`.

## 2026-09-28 Android 0.2.6 / code 6035 — 공개 완료

- main 대상 `ee52e295a4fc412a3e27f302d0babcfa84de8160`을 푸시하고 [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36434707449)의 build-only 검사·서명·최근 3개 버전 패치 복원을 통과했다. 동일 산출물 5개를 [apk-6035 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6035)로 공개하고 최신 릴리스로 지정했다. [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6035/rune-nexus.apk). 선택 업데이트·최소 지원 코드 6027을 유지한다.
- 일반형/빠른형 몹·사망 모션, 우주 배경·드론 시점, 우편함·젬 수정, 전투 HUD·포탑 강화·저장/복원 최적화를 포함한다. 서버·DB·Android 호스트 변경은 없다. 기존 미커밋 문서·산출물 정리는 포함하지 않았다.
- 격리 API 37 arm64 AVD에서 정식 6031→6035 덮어 설치와 최초 설치 시각 유지, 스테이지1·웨이브2·골드148·HP17/20·젬1·기관총 복원을 확인했다. 가디언·피해/빔·배경·HUD와 게스트 우편함 안내를 확인했고 별도 Astra가 대표 화면·기존 변경 근거·패키징을 검토했다. 실계정 Google 로그인·우편 목록·실기기 성능은 미검증이다.
- APK **384,256,826 bytes**, SHA-256 `2565988bc8aa17f35849a18ed112a6020c42a8d083b47beab6f3677786a32577`. 6034 대비 **+17,307,228 bytes(+4.7165%)**이며 증가분은 PCK와 일치한다. PCK 156,032,528 bytes·957항목·완전중복0. 몹 텍스처·메시·상태 효과와 배경이 주원인이며 ABI 3종·네이티브 크기는 유지했다.
- 검수 에뮬레이터의 렉 증가 제보를 조사한 뒤, 사용자의 명시적인 배포 지시에 따라 공개했다. 해당 AVD는 Vulkan `llvmpipe` 소프트웨어 렌더링이며 CPU 약804%를 관측했다. 이전6034 약5.356FPS, 새6035 약4.168FPS를 SurfaceFlinger에서 관측했으나 전투 진행·카메라 상태가 달라 유효한 전후 비교가 아니다. 성능 회귀 여부는 미확인이고 에뮬레이터를 종료했다. 이를 실기기 성능 또는 성능 PASS로 해석하지 않는다.
- 근거는 로컬 `build/release-verification/apk-6035/`의 CI·APK 감사·해시 검사·Android 캡처와 `review/`, `performance/`에 있다. 공개 후 태그 SHA, latest/버전별 manifest와 검수 파일의 일치, 자산 5개 크기·SHA-256·익명 다운로드 응답을 확인했다(`public-verification.json`).

## 2026-09-26 경량화·전투 최적화 Android 0.2.5 / code 6034 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6034) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6034/rune-nexus.apk). 대상 `9d8d454d7167bbd8bdd6d5f3a80fbfb04a375800`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36229160750). build-only 서명 산출물을 검수한 뒤 같은 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 서버·DB·웹 변경은 없다.
- 화염·냉각 타워와 챕터3 파이프·배기구 경량화, 전투 충돌 후보/반복 처리와 HUD 갱신 최적화, 전장 표시 책임 분리, 젬 위성·리본·색광, 로비 버튼 및 업데이트 진행·캐시 개선을 포함했다. 제작 중인 저격 SWIFT와 요청 밖 미커밋 변경은 포함하지 않았다.
- CI의 Python·콘텐츠·Godot 네이티브·계정/AppServices 검사와 서명 APK 빌드, Android 패치 디코더, 6031/6032/6033 서명 일치·차등 복원을 통과했다. 최종 게임 모델의 동일 조건 QHD 외형과 충전·방출/벽 접합은 기존 최종 검수를 재사용했다. 별도 Astra가 변경 범위·최신 업데이트 진행 Android 근거·최종 APK 패키징·Android 대표 화면을 검수했다.
- API 37 arm64 테스트 AVD에서 정식 6033 → 6034 덮어 설치와 최초 설치 시각 유지, 스테이지1·2/40 이어하기, 기존 골드148·HP17/20·젬1·기관총 복원을 확인했다. 실제 전투의 적 이동·피해·코어 빔과 일시정지 상태를 확인했다. 실제 Google 계정 로그인과 실기기 성능은 측정하지 않았다.
- APK **366,949,598 bytes**, SHA-256 `b5f716a4b3ed143b65f9547f5f4a6e7171f39143b02a1ee9342160df4745c64c`. 6033보다 **5,389,820 bytes 감소(-1.4476%)**했다. PCK 138,725,300 bytes·910항목·완전 중복0이며 ABI3종과 네이티브 라이브러리 크기를 유지했다. 감소의 주원인은 chapter3_props·magic·frost의 런타임 메시이고, 새 스크립트·젬/UI 효과를 함께 포함한 최종 크기다. design 편집 원본은 포함하지 않았다. 패치는 6031 기준136,783,101 bytes, 6032 기준136,783,111 bytes, 6033 기준136,783,115 bytes다.
- 근거: `build/release-verification/apk-6034/`의 `ci-run.json`, `ci.log`, `artifact-verification.json`, `packaging-review.json`, `ci-audit/godot-pack-audit.json`, `review/`, `public-verification.json`. 공개 태그 커밋과 latest/버전별 manifest, 자산5개의 GitHub SHA-256·크기 및 익명 다운로드 응답을 대조했다. 공개 후 전체 파일을 다시 내려받는 대신 로컬 검수 파일과 GitHub 업로드 digest를 대조했다.

## 2026-09-26 UI 개선 Android 0.2.4 / code 6033 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6033) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6033/rune-nexus.apk). 대상 `777f24be0e56c9c15cc4ee6ff75444f06d2ee7b5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36148566717). CI의 build-only 서명 산출물을 검수한 뒤 동일 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 서버·DB·웹 변경은 없다.
- 미배포 UI 개선을 포함했다: 강화 레벨업·룬 비용 프레임, 빨강 쌍검/금색 저울 아이콘, 제목 왼쪽 정렬과 작은 로비 버튼, 연구 스크롤·결제·중단 확인, 모듈 분해·개수 표시·연결부, 리더보드와 고정 내 순위, 모달 겹침·퇴장 중 배경 입력·크기 변동 및 앱 포커스 복귀 안정화. 최종 UI 변경은 `428f19dc`와 `777f24be`에 커밋했다. 로컬 과거 캡처 삭제·임시 생성 파일은 배포 대상에서 제외했다.
- Python 40개, Godot 네이티브 31개, 콘텐츠·계정·AppServices 검사, Android 패치 디코더, 6030/6031/6032 서명 일치와 차등 복원을 CI에서 통과했다. 별도 Astra가 현재 코드·기존 데스크톱 근거·최종 Android 대표 화면을 확인했다.
- Android API 37 읽기 전용 테스트 AVD에서 기존 정식 6031 → 6033 업데이트 설치를 완료하고 최초 설치 시각과 스테이지 1·2/40 라운드 저장 표시가 유지됨을 확인했다. 강화 전투/경제·연구·모듈 및 설정 화면을 확인했다. 설정 백그라운드 복귀는 검수 입력·캡처가 불확실해 성공으로 판정하지 않았고, 사용자의 추가 검수 중단 요청에 따라 재검사와 기존 런 재개 추가 검사를 중단했다. 실계정 Google 로그인·실기기 성능은 검증하지 않았다.
- APK 372,339,418 bytes, SHA-256 `91d0715ceec019e8e22b810c8b46081d65482a5a988064bb2befc2cf83587063`. 6032 대비 +222,016 bytes(+0.0597%)이며 실질 증가는 Godot PCK의 UI 텍스처·스크립트다. PCK 144,131,504 bytes·889항목·완전 중복 0 bytes. ABI 3종과 각 네이티브 라이브러리 크기를 유지하며 design 제작 원본은 포함하지 않았다. 차등 패치는 6030 기준 141,936,628 bytes, 6031 기준 123,083,548 bytes, 6032 기준 123,083,559 bytes다.
- 근거: `build/release-verification/apk-6033/`의 `ci-run.json`, `ci.log`, `artifact-verification.json`, `packaging-review.json`, `ci-audit/godot-pack-audit.json`, `android/`, `public-verification.json`. 공개 태그의 커밋과 latest/버전별 manifest, 업로드 5개 파일의 GitHub SHA-256·크기 및 익명 다운로드 응답을 대조했다. 검수 후 공개 파일 전체를 다시 내려받지는 않았으며 서버가 계산한 업로드 digest와 로컬 검수 파일의 hash를 비교했다.

## 2026-09-24 Google 로그인 저장소 연결 수정 Android 0.2.3 / code 6032 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6032) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6032/rune-nexus.apk). 대상 `104e191fbd47378389d3ae8962834167282bceb9`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36013367828) 검사·서명·최근 3개 버전 차등 복원·공개 완료. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- 실제 Android에서 JNI 플러그인의 호출 가능한 메서드도 `has_method()`가 false를 반환하는 것을 재현했다. 계정 서비스가 이를 저장소 부재로 잘못 판단해 Google 인증 HTTP 요청 전에 중단한 것이 이번 로그인 실패 원인이다. 등록된 정확한 네이티브 singleton에는 해당 판정을 적용하지 않도록 수정했고, 같은 판정을 사용하던 기존 저장 경로 연결도 고쳤다. 일반 객체의 메서드 검사와 저장 형식·암호화·시작 화면·업데이트 흐름은 유지한다.
- 동일 Godot 엔진·실제 네이티브 플러그인의 격리 Android 실행에서 수정 전 `SECURE_STORAGE_UNAVAILABLE` → 수정 후 시험용 잘못된 토큰의 서버 HTTP 401 `GOOGLE_AUTH_REJECTED`를 확인했다. 합성 성공 응답의 암호화 저장·새 세션 복원·시험 레코드 삭제도 통과했다. 실제 사용자 계정·저장은 건드리지 않았다. 별도 Astra가 저장소 경계 9개, 계정·AppServices 회귀, 로그인 복귀 13개 시나리오와 Android 근거를 검토했다. 실계정 Google OAuth·서버 저장 동기화는 직접 수행하지 않았으며 사용자 확인 항목으로 남긴다.
- APK 372,117,402 bytes, SHA-256 `eb5e1049026bec7ff6360aa926fe31ff4676f73f1218eeb87453a004715ef92b`. 6031 대비 +260 bytes이며 PCK는 +256 bytes(143,909,484 bytes·877항목·완전 중복 0 bytes)다. 서비스 스크립트 수정에 따른 소폭 증가이며 새 에셋·네이티브 의존성 없이 ABI 3종을 유지한다. 6029/6030/6031 기준 차등 패치는 각각 141,721,287 / 141,721,288 / 49,482,800 bytes이며 CI에서 서명 APK로 복원 검증했다.
- 공개 태그·소스 커밋·최신/버전별 manifest 일치, 업로드 5개 파일의 GitHub SHA-256·크기와 공개 APK 응답을 확인했다. 근거는 `build/login-rootcause-20260924/`의 `root-cause-verification.json`, `android-probe-reflection-logcat.txt`, `android-probe-final-logcat.txt`, `android-probe-final-source-sha256.json`, 독립 검증 로그와 `build/release-verification/apk-6032/`의 `ci-run.json`, `public-verification.json`, `ci-audit/`에 있다. 앞선 6030의 복귀 UI 수정과 별개인 네이티브 저장소 결함을 이번에 실제 Android에서 확인·수정했다.

## 2026-09-24 시작 화면 복원 Android 0.2.2 / code 6031 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6031) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6031/rune-nexus.apk). 대상 `cb9a4b18cade64d7bb9e1369dbcda1e6fa6da8a5`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36006933404)의 서명 산출물을 Android에서 확인한 뒤 동일 파일을 공개했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- Godot 기본 로고를 숨기고 기존 Flutter의 배경·로고·코어·금속 진행바를 사용하는 시작 화면을 복원했다. 경량 boot가 먼저 업데이트를 확인하고, 통과 후 본게임을 불러와 저장·계정을 복원한다. 필수/선택 업데이트, 오류 재시도, 노트 스크롤, 설치 권한 복귀 안내와 기존 로그인 복귀 처리를 유지한다.
- 관련 자동 검사·실제 데스크톱 시작 전환·독립 검토 및 최종 CI를 통과했다. 격리 Android API 37 에뮬레이터에서 기존 6029 위에 설치하고 Godot 로고 없음 → 업데이트 확인 → 게임 준비 → 로비와 기존 스테이지 1·2/40 이어하기 표시를 확인했다. SwiftShader Vulkan 환경에서 초기 준비 지연이 있었으나 정상 로비에 도달했다. 정확한 GPU 비용과 실기기 시작 성능은 미측정이며 실제 Google OAuth는 사용자 담당 미확인 항목으로 유지한다.
- APK 372,117,142 bytes, SHA-256 `538690028c9b1d7f8f7a9abf58f47fada411661782df8679b36cf2de910edb7d`. 6030 대비 +18,788 bytes이며 Godot PCK도 같은 크기만큼 증가했다(143,909,228 bytes·877항목·완전 중복 0 bytes). 시작 화면 코드 추가에 따른 증가이며 새 대용량 에셋·네이티브 의존성 없이 ABI 3종을 유지한다. 6028/6029/6030 기준 차등 패치는 각각 141,925,573 / 141,721,235 / 141,721,234 bytes이며 모두 서명 APK로 복원 검증했다.
- 공개 태그·커밋·최신/버전별 manifest 일치, 업로드 5개 파일의 SHA-256·크기와 공개 APK 응답을 확인했다. 근거는 `build/startup-restoration-20260924/independent-startup-review.json`, 같은 폴더의 로그·실제 화면과 `build/release-verification/apk-6031/`의 `ci-run.json`, `candidate-verification.json`, `public-verification.json`, `android/cold-start.mp4`, `android/lobby-final.png`, `android/result.json`에 있다.

## 2026-09-24 Google 로그인 복귀 수정 Android 0.2.1 / code 6030 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6030) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6030/rune-nexus.apk). 대상 `7292d952ac8b0ba0df0fdb0165c987d50fe76ecf`, [CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/36003482740) 검사·서명·최근 3개 버전 차등 복원·공개 완료. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB 변경은 없다.
- 사용자 제보의 Google 계정 선택→앱 복귀→업데이트 창→로그인 결과가 사라지는 흐름을 실제 Godot 로비·서비스·수명주기 코드에서 재현했다. 로그인 중 실제 일시정지 후 복귀를 구분해 자동 업데이트 확인과의 충돌을 막고, 게스트 계정 화면을 다시 열어도 취소·실패 안내가 남도록 했다. 일반 복귀 확인과 서버 426 필수 업데이트는 유지한다. Android Google 인증 코드·설정·저장 형식은 변경하지 않았다.
- 콜백과 복귀의 양순서, 성공·닉네임 대기·취소·인증 실패, 일시정지 없는 콜백, 비로그인 작업 중 복귀, 필수 업데이트 등 관련 13개 시나리오와 독립 검토를 통과했다. 배포 CI도 통과했다. 사용자의 실제 Google 인증 실패 원인 및 실계정 OAuth 성공은 미확인이다. 이번 확인은 재현된 복귀 충돌·결과 누락 수정에 한정하며 실계정 성공으로 표시하지 않는다.
- APK 372,098,354 bytes, SHA-256 `8c7d835df163025b04ef6b64dc6c7e2396db9884519e97f2fc78416a42888dd4`. 6029 대비 +656 bytes이며 Godot PCK도 +656 bytes(143,890,440 bytes·871항목·완전 중복 0 bytes)다. APK 지원 ABI·네이티브 의존성·에셋 구성은 기존 배포와 같다.
- 공개 태그·커밋·latest/버전별 manifest 일치, APK와 패치 3개의 GitHub SHA-256·크기, 공개 APK 응답을 확인했다. 검증을 반복하지 않고 기존 서명·패키징·저장 근거와 최종 CI를 재사용했다. 근거는 `build/google-login-fix-20260924/`의 `login-resume-before.log`, `login-resume-after.log`, `independent-login-review.json`과 `build/release-verification/apk-6030/`의 `ci-run.json`, `public-verification.json`, `ci-audit/`에 있다.

## 2026-09-24 Godot 단독 Android 0.2.0 / code 6029 — 공개 완료

- [공개 릴리스](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6029) · [APK 다운로드](https://github.com/Sejiiinn/RuneNexus/releases/download/apk-6029/rune-nexus.apk). 대상 `1f2bcc27cf877c0727dadd99632db713eb3ec519`, [최종 CI](https://github.com/Sejiiinn/RuneNexus/actions/runs/35999656150) 성공. CI에서 검증한 동일 서명 산출물을 초안에 올린 뒤 공개·최신 지정했다. 선택 업데이트이며 최소 지원 코드 6027을 유지한다. 웹·API·DB는 배포하지 않았다.
- Flutter·Flame 실행 경로를 제거한 Godot 단독 앱이다. 기존 패키지·서명·저장 형식과 계정 보관 경로를 유지한다. 운영 API·Google client ID·업데이트 URL·빌드 식별자를 최종 APK에서 확인했다. 구현 상태는 [전환 상태](godot_unified_app_roadmap.md)를 따른다.
- 자동 검사·독립 검토·서명 일치·최근 3개 공개 APK의 차등 복원 검사를 통과했다. 배포 검사에서 발견한 Linux int64 변환 차이, GitHub 리다이렉트 처리, 업데이트 완료 후 대기 팝업 잔류를 수정하고 해당 조건으로 재확인했다.
- 격리 Android API 37 에뮬레이터에서 기존 공개 6028의 게스트 저장을 업데이트 설치로 인계했다. 스테이지 1·웨이브 2/40·HP 17/20·골드 148·젬 조각 1·기관총 1개가 유지됐고, 새 앱의 저장→강제 종료→재실행 복원도 통과했다. 최종 APK의 업데이트 팝업 자동 종료·로비·이어하기 화면까지 확인했다. 실기기 Google 로그인·실계정 동기화는 사용자가 직접 담당하며 통과로 간주하지 않는다.
- 최종 APK **372,097,698 bytes**, SHA-256 `5b373f12278437f1e9aa99f22905ca2e8302b6f04da189b720af9269cdbe7fe9`. 이전 공개 6028의 431,317,704 bytes보다 **59,220,006 bytes(13.73%) 감소**했다. Godot PCK는 143,889,784 bytes·871항목·완전 중복 0 bytes이며 ABI 3종을 유지한다. 앱 UI·서비스 이관으로 PCK가 늘었지만 Flutter 엔진·Dart 라이브러리·중복 에셋 제거로 전체 크기는 줄었다.
- 공개 태그의 커밋, latest/버전별 manifest 바이트 일치, 업로드된 5개 파일의 GitHub SHA-256·크기와 검증 산출물 일치, 공개 APK 다운로드 응답을 확인했다. 이미 검증한 대용량 파일의 재다운로드는 반복하지 않았다. 상세 근거는 `build/release-verification/apk-6029/`의 `ci-release-run.json`, `release-candidate-verification.json`, `final-release-review.json`, `public-verification.json`, `emulator/6029-release-after-50s.png`, `emulator/6029-release-restored-battle.png`에 있다. 이전 준비 검증은 [검증 기록](analysis/godot_android_release_20260924/README.md)을 따른다.

## 전환 전 배포 기록

2026-09-12~20의 Flutter/Web 배포, 당시 이미지 복구 명령과 미배포 판정은 [전환 전 기록](archive/deployment_before_godot_20260924.md)에 보존한다. 현행 운영 절차나 다음 작업으로 사용하지 않는다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
