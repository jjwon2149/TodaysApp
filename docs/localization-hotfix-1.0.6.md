# 1.0.6(8) 기록 수정 제목 번역 수정

## 원인과 변경
- `optionalSectionHeader(titleKey:)`가 `String`을 받아 `Text(titleKey)`에 넘겨, `editor.memo.title`과 `editor.mood.title`을 번역하지 않고 그대로 표시했다.
- 매개변수를 `LocalizedStringKey`로 변경했다. 기존 한국어·영어·일본어 번역을 사용하며 새 기록과 기록 수정 화면 모두에 적용된다.
- 홈 오류 제목/본문의 조건부 키 선택도 `L10n.string`으로 명시적으로 번역하도록 정리했다.
- 앱·위젯 Debug/Release 버전은 1.0.5(7)에서 **1.0.6(8)**로 올렸다. 기존 신뢰성 개선사항을 포함하며 서명/번들 ID/데이터 형식은 변경하지 않았다.

## 검증
- KO/EN/JA 각 276개 번역의 키 집합 일치, 빈 값 없음.
- 실제 앱 참조 키 262개를 각 언어 리소스와 대조: 누락 없음. SF Symbols 이름과 미션 키 접두사는 실제 번역 참조와 구분했다.
- 다른 `Text`/`Label`의 변수 인자와 공통 제목 함수를 점검했다. 기분 제목은 같은 함수 수정으로 함께 해결된다.
- iPhone 16 / iOS 18.5 전체 테스트: **65 PASS / 0 FAIL / 0 SKIP**. 결과 묶음: `/tmp/dailyframe-localization-fix.xcresult`.
- 시뮬레이터 앱 UI 제어 연결은 사용할 수 없어 이번 수정 모달의 직접 화면 조작 검증은 하지 않았다. 타입 변경과 번역 리소스 점검, 빌드/기존 회귀 테스트를 검증 근거로 사용했다.

## 배포
- 실기기 Release 아카이브 성공. 앱·위젯 아카이브의 실제 버전 **1.0.6(8)** 확인.
- **2026-09-30 22:04:08 KST TestFlight 업로드 성공**: `Upload succeeded`, `Uploaded DailyFrame`, `EXPORT SUCCEEDED` 확인. Apple 처리 시작 확인; 설치 가능 상태는 아직 확인하지 않았다.
- 보존 아카이브: `/Users/smith/Library/Developer/Xcode/Archives/2026-09-30/DailyFrame 1.0.6 (8) 22.04.xcarchive`.
- GoogleMobileAds / UserMessagingPlatform의 dSYM 누락 경고가 있었으나 업로드는 성공했다. 해당 SDK 내부 충돌 분석에는 심볼 정보가 제한될 수 있다.
- 정식 App Store 심사 제출과 외부 테스트 그룹 변경은 범위에 포함하지 않는다.
