# 배포 상태와 세션 간 인계

배포 요청은 이 문서와 [파이프라인 지도](deployment_pipeline.md)에서 시작한다.
서버·DB·운영 설정 또는 그 계약이 바뀌는 경우 [API 운영 절차](self_hosted_api_deployment.md)를 함께 확인한다.
이 문서는 마지막 검증 이력이며 실시간 운영 상태가 아니다. 배포 대상의 실제 공개 버전·커밋과
서버 실행 이미지·DB 버전을 확인한다.


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

이하 내용은 과거 배포 기록이며 Flutter/Web 관련 명령과 상태는 당시 기준이다.

## 2026-09-20 업데이트 단일 버튼 APK 0.1.19 / code 6028, 웹 배포

- 대상 `5a1af6627fdf2941aada9cd107251ceb3b900206`. [APK workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35462929856)·[웹 workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35462931146) 성공, [공개 release](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6028) 커밋 일치. 공개 웹 주요 파일 HTTP 200 및 빌드 SHA 확인. API·DB 추가 변경 없음.
- 서버 업데이트 요구 안내의 로그아웃을 단일 `업데이트하기`로 교체하고 기존 다운로드·설치 경로로 연결했다. 계정·저장 및 마운트된 게임 상태를 유지한다. 실패 시 같은 버튼을 `다시 시도`로 표시하고, 서버 필수 판정이면 선택 manifest에서도 건너뛰지 못한다. 웹은 페이지 새로고침으로 연결한다.
- 선택 배포 `required_update=false`, 공개 최신 코드 6028·최소 지원 코드 6027 유지. 기존 APK 화면을 원격 교체한 것은 아니며 서버 응답이 기존 안내를 표시한 것이었다. 새 버튼은 새 APK 설치 후 적용된다.
- 관련 테스트 23개·analyze·웹 빌드/Wasm dry-run 통과. CI 전체 검사·서명 및 최근 3개 APK 차등 복원 통과. 일반 `lib/main.dart` Android 검수 빌드에서 필수 안내와 다운로드 실패 상태를 직접 확인했다. 버튼 하나·재시도·잘림/겹침 없음. 계정·저장 파일은 동일하고 디버그 코드/프로파일 캐시만 바뀌었다. 검수용 versionCode 6026과 공개 manifest 6027로 재현했으며 실제 서버 차단→gate 전환은 자동 테스트로 확인했다. 근거 `build/update-action-validation/`. 공개 APK 실기기 설치·로그인 및 웹 reload 실브라우저 조작은 별도 미검증이다.
- 실제 공개 APK 431,317,704 bytes, SHA-256 `3ca0dd20219c21cab056d0ce78cc2be58ce88111d4b508b49982149c2b3319f1`. 6027 대비 +16 bytes(+0.00%), Godot PCK 105,955,332 bytes·275항목·완전 중복 0 bytes. ABI 3종 유지, design 제작 파일·Flutter 원본 GLB 없음.
- 공개 APK·6025/6026/6027 패치 4개 실제 다운로드 크기·SHA-256 통과. latest/버전별 manifest 바이트 일치와 최소 지원 6027 유지 확인. 6027 패치 114,167,117 bytes. 근거 `build/release-verification/apk-6028/`의 release·verification·web-verification·CI audit.

## 2026-09-20 성장 조정·필수 업데이트 APK 0.1.18 / code 6027, 웹·API 배포

- 대상 `f7ca3d47897c2e3613aa5c914c0d6631c9bca522`. [APK workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35461936191)·[웹 workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35461937928) 성공, [공개 release](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6027) 대상 커밋 일치. 공개 웹의 주요 파일 HTTP 200과 빌드 SHA·운영 API 주소를 확인했다.
- 강화 상한 확장·기초 화력 비용 지수 1.06, 치명 집중/긴급 매각 연구 이관 및 토벌 보상 강화 이관. 룬 공명과 나머지 기존 연구는 유지한다. 수치는 [현행 밸런스](gameplay_balance_reference.md)를 따른다. 기존 레벨은 성장 버전 1로 자동 이전하며 비용 차액 환급은 없다.
- 이번 배포는 `required_update=true`, 공개 `minimumSupportedVersionCode=6027`. 선택 업데이트는 기존 최소 버전을 유지한다. 새 앱은 시작·복귀 시 확인하고 필수 업데이트 설치 취소 및 확인 실패 시 게임 진입을 차단한다. 이미 배포된 구앱의 오프라인 실행 자체를 소급 차단할 수는 없다.
- API는 `rune-nexus-api:f7ca3d4`, 이미지 `sha256:f1653fa27c1093be711855d635dafe9c64bafb8374a20197cacd45e1c5db7085`. 호환 하한 2로 서버 선반영 후 APK·웹 공개를 확인하고 `MINIMUM_SAVE_CLIENT_COMPATIBILITY_VERSION=3`으로 올렸다. 실행 환경값·Docker healthy·공개 HTTPS readiness 정상 확인. 구세대 writer/저장/경제 변경을 거절하며 이전된 계정의 성장 버전 회귀도 방어한다.
- DB 스키마 변경은 없다. 운영 백업 345,934 bytes의 격리 PostgreSQL 복원과 통합 검사를 완료하고 임시 DB 컨테이너·네트워크를 제거했다. 백업·이미지 override·배포 로그는 비공개 `~/Library/Application Support/RuneNexus/operations/growth-release-20260919T183021Z/`에 보관한다. 후속 API 재시작에는 해당 `api-release.override.json`을 base/production Compose에 함께 적용해야 한다. 이전 이미지·백업은 보존했다.
- 로컬 Flutter 전체 902개 통과·12개 skip, analyze 문제 없음, Python APK 검사 24개 통과. Go 전체 test/vet와 격리 PostgreSQL 통합 검사 통과. CI 분석·전체 검사·서명·최근 3개 APK 차등 복원도 통과했다.
- Android 일반 앱 debug 6027에서 강화·경제·연구 메뉴를 실제 확인했다. 기초 화력 100/체력 30/토벌 40/긴급 매각 5/치명 집중 10과 레벨당 2%p 표시 정상, 대상 메뉴 잘림·겹침 없음. 검수 전후 저장 파일 97개 SHA-256 동일. 캡처·검증 근거는 `build/growth-validation/`. 초기 로비의 기존 14px 하단 overflow는 이번 메뉴 변경 범위 밖이며, 공개 release APK의 실기기 설치·로그인을 검증한 것은 아니다.
- 공개 APK 431,317,688 bytes, SHA-256 `1ea465ad36cf9d6ae445819cdd72646922cee0f60cef7604ee7ac9ad294dcd84`. 6026 대비 +163,856 bytes (+0.04%): libapp.so arm64/x86_64 각 +65,536, armeabi-v7a +32,768, Godot PCK +16 bytes. ABI 3종 유지, design 제작 파일·Flutter 원본 GLB 포함 없음.
- Godot PCK 105,955,316 bytes·275항목·완전 중복 0 bytes. APK·6024/6025/6026 패치의 실제 다운로드 크기·SHA-256 모두 일치, latest와 버전별 update.json 바이트 일치 및 필수 하한 6027 확인. 6026 패치 97,325,997 bytes. 공개 검증·CI audit·웹 확인 근거: `build/release-verification/apk-6027/`.

## 2026-09-19 본게임 APK 0.1.17 / code 6026 배포

- 대상 `af4572a1f233e66519b66f2f3b89600220fb3121`. [workflow](https://github.com/Sejiiinn/RuneNexus/actions/runs/35427499439) 성공, [공개 release](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6026) 대상 커밋 일치. Android만 배포했으며 웹·서버·DB는 변경하지 않았다.
- 탄환·선택 표시 이관, 화염 MultiMesh, 작은 고정/드론 전환 버튼과 직전 공개 이후 커밋된 변경 포함. 로컬 검사는 반복하지 않았고 CI 필수 검사·서명 빌드·패치 디코더·차등 복원 절차가 통과했다.
- 공개 APK 431,153,832 bytes, SHA-256 `54cd114d037fe37bb84e47d6760c272ce2ea034d3fc979f85889b6b4d4d4b12e`. 6025 대비 +15,138,296 bytes (+3.64%). ZIP 증가 대부분은 Godot PCK +15,089,144 bytes, armeabi-v7a libapp.so +49,152 bytes. ABI 3종 유지, design/ 제작 파일 포함 없음.
- PCK 105,955,300 bytes·275항목·완전 중복 0 bytes. 공개 APK·6023/6024/6025 패치의 실제 다운로드 크기·SHA-256 확인 PASS. latest와 버전별 update.json 바이트 일치. 6025 패치는 111,340,276 bytes.
- 근거: `build/release-verification/apk-6026/`의 release.json·verification.json·audit와 공개 파일. 배포 APK의 실기기 설치/로그인은 별도 수행하지 않았다. 기존 로컬 Android UI 검증과 에뮬레이터 FPS 측정을 실기기 성능 통과로 간주하지 않는다.

## 2026-09-15 본게임 APK 0.1.16 / code 6025 배포

- 대상 커밋: `7d29895c8c15439a5a35b96eeff0911840798779`. [APK workflow 34907234097](https://github.com/Sejiiinn/RuneNexus/actions/runs/34907234097) 전체 성공. [공개 release apk-6025](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6025)의 태그 커밋도 일치한다.
- 화염 포탑 승인 3D 모델·상부 불꽃·포구·발사체, 적 공통 GPU 화상, 6024 이후 커밋된 공통 서리·얼음 결정 및 대포 폭발 파편·불티 GPU 운동 최적화를 포함한다.
- 3D 경로의 기존 2D 화염·냉각 명중 표시와 2D 화상 중복 표시를 제거했다. 피해·지속시간·저장 계약은 유지한다.
- 사거리 원은 선택 포탑만, 설치 패널 활성 중 기존 전체 포탑을 표시한다. 설치 미리보기·업그레이드·보상 우선순위는 유지하고 Godot 투영 좌표를 캐시한다.
- 종료된 화염 입자의 GPU 요청을 중단한다. `ranchu` / `sdk_gphone64_arm64` 에뮬레이터에만 임시 Skia 호환 처리를 적용하며 실기기는 Flutter 기본 렌더러를 유지한다. Flutter 업그레이드 때 deprecated opt-out 지원을 재검증해야 한다.
- 로컬 전체 Flutter 검사 833개 통과·11개 skip, 변경된 Godot 팩 준비 Python 검사 통과. CI 분석·전체 Flutter 테스트·Python APK 검사·서명 빌드·Android 패치 디코더·기존 세 버전의 서명 일치와 차등 복원 검증도 통과했다.
- 실제 공개 APK: **416,015,536 bytes (396.74 MiB)**, SHA-256 `43f13a3cf061acb64ef745d55db15a7242004bba28b53e2752b1ea9d1847f948`. 이전 공개 6024의 411,353,104 bytes 대비 **4,662,432 bytes (4.45 MiB, 1.13%) 증가**했다. 주로 새 화염 포탑 메시·공유 텍스처 및 화상·서리 에셋이다.
- arm64-v8a·armeabi-v7a·x86_64를 유지한다. Godot PCK **90,866,156 bytes·246항목·완전 중복 0 bytes**. Flutter 원본 GLB·design 제작 파일과 미사용 코어 실험 shader가 공개 팩에 없는 것을 확인했다. 배포 전 로컬 팩에만 있던 미사용 shader는 clean checkout 빌드에서 제외됐다.
- 차등 패치: **6024 → 6025는 99,812,259 bytes (95.19 MiB)**, 6023 → 6025는 100,514,191 bytes, 2002 → 6025는 100,674,772 bytes. 공개 APK·세 패치·update.json을 직접 다운로드해 실제 크기와 SHA-256을 대조했다. latest와 버전별 update.json의 바이트 일치 및 실제 공개 6024/6025 APK 서명 인증서 일치도 확인했다.
- 검증 원본: `build/release-verification/apk-6025/`의 release·verification·signature JSON, 다운로드 자산과 CI 팩 audit. 공개 후 확인은 다운로드 무결성·서명·메타데이터이며 사용자 기기 설치·로그인 검증을 대신하지 않는다.
- 앞선 Android 일반 본게임에서 화염 발사·화상·서리·시점 전환·앱 복귀를 확인했으며 Godot 수명·정지·재사용·사거리 캐시 검사를 통과했다. 1배속 60초 에뮬레이터 재측정은 화염 전투 갱신 23.01회/초, Flutter raster 평균 24.92ms로 **60 FPS 목표 미달**이다. 실기기 지속 성능은 미검증이다.
- 이번 배포는 Android 본게임만 대상이다. 서버·DB·웹 배포, Flame 전체 제거·Godot 전투 이관은 포함하지 않는다. 제작 원본·검증용 앱·미사용 실험 파일은 이번 코드 커밋에 일괄 추가하지 않았다.

## 2026-09-14 본게임 APK 0.1.15 / code 6024 배포

- 대상 커밋: `244648bacb79593e211f5e202f4ba55ff07656cb`.
  [APK workflow 34764359633](https://github.com/Sejiiinn/RuneNexus/actions/runs/34764359633) 전체 성공.
  [공개 release apk-6024](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6024)의 태그 커밋도 일치한다.
- 스테이지 2~10 3D 전장·챕터 2 환경, 둥근 대포 포탄, 전장 로딩·시점 전환, 그래픽 설정과 렌더링 최적화를 포함한다.
  분석·전체 Flutter 테스트·Python APK 검사 23개·Android 패치 디코더·최근 세 공개 APK 서명 일치와 패치 복원을 통과했다.
- 최초 실행 34763078973은 위젯 테스트 실패로 종료되어 공개되지 않았다. 네이티브 연결을 제공하지 않는 공통/2D 테스트의 플랫폼 fixture와 그래픽 설정 로드 기대값을 수정한 뒤 전체 검사를 다시 통과했다.
- 실제 공개 APK: **411,353,104 bytes (392.30 MiB)**, SHA-256
  `b69113beeb2aba7b69d055053be0e1d769e603bca3e0f0e0094488d0393599a7`.
  이전 공개 6023의 384,821,388 bytes 대비 **26,531,716 bytes (25.30 MiB, 6.89%) 증가**했다.
  배포 전 발견한 과대 로컬 APK 479,597,500 bytes에서는 **68,244,396 bytes (65.08 MiB) 감소**했다.
- CPU 3종을 유지했다. ZIP 압축 후 네이티브 크기는 arm64-v8a 92,823,440 / armeabi-v7a 94,085,636 / x86_64 97,284,016 bytes다.
  Flutter 에셋 38,972,335 bytes, Godot PCK **86,203,724 bytes·217항목·완전 중복 0 bytes**다.
  Flutter 원본 GLB·design 제작 원본·미사용 ANGLE가 공개 APK에 없는 것도 확인했다.
- GLB 텍스처를 무손실 공유하고 이전 빌드 자산을 정리했으며, 기존 포탄 체적 데이터를 원본 바이트로 복원되는 gzip으로 압축했다.
  남은 증가는 주로 스테이지별 지형·환경과 최적화 타일 scene 리소스다. [원인·품질·실행 검증](analysis/godot_packaging_20260913/README.md)을 따른다.
- 차등 패치: **6023 → 6024는 96,210,679 bytes (91.75 MiB)**, 2002 → 6024는 96,369,800 bytes,
  13 → 6024는 172,473,082 bytes다. 공개 APK·세 패치·update.json을 직접 다운로드하여 실제 크기와 모든 SHA-256을 릴리스 및 메타데이터와 대조했다.
  latest와 버전별 update.json의 바이트가 일치하며, 공개 6023/6024 APK를 직접 검사해 서명 인증서가 같은 것도 확인했다.
- Android 에뮬레이터에서 일반 앱의 1장·2장 재질, 고정/드론 시점과 대포 설치·전투를 확인했다. 사용자 실기기의 설치·로그인·지속 성능은 별도 확인이 필요하다.
- 이번 배포는 기존 CPU 3종을 지원하는 Android 본게임 업데이트이며 웹·서버·DB 배포와 엔진 전체 이관은 포함하지 않는다.

## 2026-09-13 본게임 APK 0.1.14 / code 6023 배포

- 대상 커밋: `84e73936d83b1f3d311e3410459d3338a351bcb1`.
  [APK workflow 34739180467](https://github.com/Sejiiinn/RuneNexus/actions/runs/34739180467) 전체 성공.
  [공개 release apk-6023](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-6023)의 태그 커밋도 일치한다.
- 본게임 패키지 `com.example.rune_nexus`와 기존 서명을 유지한 업데이트다.
  분석·전체 Flutter 테스트·Python 검사·Android 패치 디코더·기존 세 공개 APK와의 서명 일치 및 패치 복원 검증을 통과했다.
- 실제 공개 APK는 384,821,388 bytes (367.00 MiB), SHA-256
  `3ceca36394f15b56dea8bc045ccc6ea3d9482e1caf0685f62505ba3e38abdff6`.
  이전 공개 2002의 414,151,176 bytes 대비 29,329,788 bytes (27.97 MiB, 7.08%) 감소했다.
- ZIP 압축 후 네이티브 크기는 arm64-v8a 92,692,368 / armeabi-v7a 93,954,564 / x86_64 97,218,480 bytes로 세 ABI를 유지한다.
  Godot PCK는 59,999,688 bytes. 신규 폰트·상태 표시·효과 모듈이 포함되며,
  제거한 ANGLE, Flutter GLB 중복, design 제작 원본은 공개 APK에 없다.
- 차등 패치: 2002 → 6023은 60,555,784 bytes, 13 → 6023은 137,370,986 bytes,
  12 → 6023은 147,377,144 bytes. 공개 APK와 세 패치를 직접 다운로드해 모든 크기·SHA-256을 확인했다.
  latest와 버전별 `update.json`의 실제 바이트도 일치한다.
- 기능·화면 검증은 [표현 이관 검증 기록](../design/stage1_3d/presentation_migration/README.md)을 따른다.
  공개 6023의 사용자 실기기 설치·로그인·장시간 성능은 아직 확인하지 않았다.
- 이번 요청은 Android 본게임 배포이며 웹·서버·DB는 배포하지 않았다.

## 2026-09-13 Godot 표현 이관 테스트 APK

- [Google Drive 테스트 APK](https://drive.google.com/file/d/1AnPBmf9zwRarabn9TWqlU6yHaKPmRUan/view?usp=drivesdk) 업로드 완료. Drive 메타데이터의 이름·크기를 확인했다. 다운로드 접근 문제 후 이 APK에 한해 링크가 있는 모든 사용자의 읽기 권한(검색 노출 없음)을 적용하고 메타데이터로 확인했다.
- 사용자 기기 테스트용 로컬 release code 6022. GitHub 공개 릴리스·자동 업데이트 메타데이터는 갱신하지 않는다.
- APK: 397,227,684 bytes (378.83 MiB), SHA-256
  `862b238d383dae40d73fe62d84991357b09780f9dde0b8db4b6541a5cfec39f1`.
- 현재 공개 `apk-2002`의 실제 릴리스 APK 414,151,176 bytes 대비
  16,923,492 bytes (16.14 MiB, 4.09%) 감소. 2026-09-13 GitHub 릴리스 자산 메타데이터로 기준 크기를 확인했다.
- 직전 로컬 6015 대비 9.20 MiB 증가는 Godot PCK에 추가한 원본 폰트·표현 에셋이 주원인이다.
  arm64-v8a·armeabi-v7a·x86_64를 유지하며, 미사용 ANGLE·Flutter 3D 자산 중복·design 원본의 APK 포함은 없다.
  ABI별 압축 크기와 남은 실기기 성능 검증은 [검증 기록](../design/stage1_3d/presentation_migration/README.md)에 남겼다.
- 테스트 APK 전달이므로 차등 패치를 생성하지 않았다.

## 마지막 확인된 운영 상태

2026-09-12, Android 0.1.13 / code 2002 및 서버 선행 반영을 완료했다.

- Android 대상: `4ee3e7bf1d26e46f028800b7c8a536de42731f9c`, versionName 0.1.13 / versionCode 2002.
  로컬 본게임 검증본이 코드 2001을 사용했으므로 기존 설치를 업데이트할 수 있는 2002를 선택했다.
  [APK workflow 34618596547](https://github.com/Sejiiinn/RuneNexus/actions/runs/34618596547) 성공.
  [공개 release apk-2002](https://github.com/Sejiiinn/RuneNexus/releases/tag/apk-2002)의 태그 대상 커밋도 일치한다.
  latest와 버전별 `update.json`이 같으며 공개 APK·apk-11/12/13용 패치의 실제 크기·SHA-256이
  매니페스트와 일치한다. APK는 414,151,176 bytes, SHA-256은
  `04f522da5db602621864e5b76083c9be5a25bbfbf9da94e79f92f63182bab081`이다.
- 운영 API: 서버 소스 `54f8d038fe74a6657dd23ba7b5e43c79f2f7ed88`의 `server/`를 빌드한
  `rune-nexus-api:54f8d03`. 실행 이미지 ID는
  `sha256:7100b1d48544fee7382e5291cf3e89c12f4bc94b17dfc817b298d432b03164a0`.
  Android 대상 커밋과 서버 소스는 같다. 운영 DB migration 011 적용, 컨테이너 healthy.
- 공개 API의 live·ready HTTP 200, economy·mailbox·mailbox/summary의 무인증 요청은
  `401 ACCESS_TOKEN_INVALID`로 확인했다.
- 웹은 이번 배포 대상에서 제외했다. 마지막 배포는 0.1.12 / `a3119b499a459fee4c24a112db5a218836492dbb`,
  [workflow 34462502175](https://github.com/Sejiiinn/RuneNexus/actions/runs/34462502175)이다.
  이번 Android 배포에서 웹 파일을 새로 배포하거나 재검증하지 않았다.

## 이번 배포 변경

- Android 본게임 스테이지 1에 Godot 3D 지형·포탑·적·발사 및 착탄 효과를 연결한다.
  일반 `lib/main.dart` 진입과 기존 로그인·웨이브·건설·보상·저장 흐름을 사용한다.
- 고정·드론 시점을 부드럽게 전환하고, 실제 투영으로 건설 입력과 기존 HUD를 연결한다.
- 기관총·대포의 총구 효과와 탄체·예광 가독성을 개선한다. 한 프레임 안에 명중한 탄환도
  짧은 종료 궤적을 표시하며 피해 계산과 저장 형식은 유지한다.
- 스테이지 2 이후와 Android 이외 플랫폼은 기존 2D 전장을 유지한다.
- 직전 APK 이후 main에 들어온 로비 우편함을 포함한다. 서버에는 우편함 조회·수령 API와
  신규 테이블 4개·인덱스를 추가하는 migration 011을 먼저 적용했다.
- Godot 4.7.2 실행 파일·AAR와 공통 PCK를 배포 빌드에서 준비한다.
  별도 검수 앱의 고정 대포 배치와 디버그 패널은 본게임 배포에서 사용하지 않는다.

## 검증 범위와 복구 참고

- 서버: Go 1.26.5 단위 테스트·vet 통과. 격리된 PostgreSQL 18의 DB 통합 테스트
  31개 통과, 실패·스킵 0건.
- 운영 DB 백업을 비공개 저장소에 보관하고 별도 PostgreSQL에서 복원 후 010→011을 검증했다.
  복원 DB의 기존 25개 테이블은 적용 전후 행 수·내용 지문이 모두 같았다.
- 운영 적용은 011 migration 후 API 컨테이너만 교체했다. PostgreSQL·Caddy·DuckDNS,
  기존 세션 암호화 키를 포함한 환경값·secret mount와 운영 DB 볼륨을 보존했다.
- 본게임의 Android 에뮬레이터 진입·건설·웨이브·이어하기·시점 전환과 1·4배속 투사체 검수는
  [본게임 연결 기록](../design/stage1_3d/main_runtime/README.md)과
  [투사체 검수 기록](../design/stage1_3d/projectile_visibility/README.md)을 따른다.
- 첫 CI 34617590541은 분석·전체 테스트·Godot 팩 생성 후 CMake 3.31.4 미설치로 빌드가 중단됐다.
  배포 환경에 패키지가 요구한 CMake·NDK·Build Tools 설치를 추가해 재실행했다. 공개 릴리스는 생성되지 않았다.
- 최종 CI의 Flutter 정적 분석·전체 테스트 766개(기존 조건에 따른 11개 생략), Python APK 검사 17개,
  Android 패치 디코더 및 최근 3개 기준 APK에서의 패치 복원 검증이 통과했다.
- 공개 APK를 직접 내려받아 ZIP 무결성, 패키지·버전·3D PCK 동봉과 기존 apk-13의 서명 일치를 확인했다.
  기존 코드 2001 설치본에 `adb install -r`로 업데이트하고 Android ARM64 에뮬레이터에서
  로비→이어서 진행→Godot 3D 전장 표시를 확인했다. 골드 330·코어 20/20·6/40 웨이브와
  5웨이브 보상 선택 상태가 동일하게 복원됐다. 실제 기기의 업데이트 설치·장시간 전투·발열과
  Google 로그인·우편 수령·계정 저장 복원 E2E는 미검증이다.
- 서버 복구용 `rune-nexus-api:de7a878` 이미지를 보존했다. 011은 추가형 forward-only이며
  이번에 down migration·계정 삭제·운영 우편 발송 또는 수령은 수행하지 않았다.
- 공개 APK 파일·태그를 덮어쓰거나 versionCode를 낮추지 않는다. 수정 또는 복구 앱은
  기존 배포·설치본보다 높은 versionCode로 배포한다.

### 현재 서버 이미지로 재생성

일반 컨테이너 재시작·Docker 자동 재시작은 현재 이미지를 유지한다. API를 재생성할 때는
이번 배포의 이미지 override를 포함한다. 기본 Compose 두 파일만 사용하면
`rune-nexus-api:latest`가 선택되므로 배포 이미지 고정이 보장되지 않는다.

저장소 루트에서 다음 명령을 사용한다. override에는 이미지 선택만 있으며 비밀값은 없다.

```bash
docker compose \
  --env-file .env.production \
  -f compose.yaml \
  -f compose.production.yaml \
  -f "/Users/sejin/Library/Application Support/RuneNexus/operations/mailbox-release-20260911T153453Z/api-release.override.json" \
  up -d --no-deps --no-build --wait --wait-timeout 45 api
```

## 미배포 항목

위 6025 항목의 Android 공개 배포는 완료했다. 로컬에 남은 제작 원본·검증 도구·문서 정리는 본게임 미배포 기능과 구분한다. 웹·서버·DB는 이번 배포 범위에 포함하지 않는다. Flame 제거·전투 전체 Godot 이관은 미구현이며 배포만 남은 상태가 아니다.

## 기록 유지 규칙

- 배포가 필요한 코드 변경에는 필요한 migration·환경 설정·선행 조건을 함께 기록한다.
- 배포 후 구성 요소별 커밋, workflow/release, 검증 결과와 한계를 갱신하고 미배포 항목을 정리한다.
- 실패·부분 완료는 구성 요소별로 기록한다. 과거 대화나 로컬 작업 기록만으로 완료를 판단하지 않는다.
- 비밀번호, 토큰, 암호화 키, DB 백업 내용은 이 문서나 커밋에 넣지 않는다.
