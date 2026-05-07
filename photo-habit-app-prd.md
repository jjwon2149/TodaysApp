# Duo-Style Photo Habit App PRD

## 0. Document Summary

- Working title: `DayFrame` / `오늘한장`
- Product type: iOS-first personal photo journaling habit app
- Core concept: One photo a day, low-friction capture, long-term archive, habit-forming loop
- Positioning: Not real-time social verification, not public feed SNS, not photo editing app
- Product principle: "하루 한 장으로 오늘의 나를 남기고, 부담 없이 다시 돌아오게 만든다."

### Product Thesis

이 앱은 `BeReal`의 실시간 인증 구조를 모방하지 않는다. 대신 `Duolingo`의 습관 형성 구조를 사진 기록에 맞게 재해석한다.

- 핵심 행동은 "친구에게 지금 보여주기"가 아니라 "오늘을 한 장으로 남기기"다.
- 보상 구조는 `streak`, `daily quest`, `badge`, `freeze`, `calendar fill`, `monthly reflection` 중심이다.
- 기록은 혼자 써도 충분히 가치 있어야 하며, 초기 소셜 기능은 제품 핵심이 아니다.

### Product Positioning Statement

`하루 한 장, 오늘의 나를 기록하는 사진 습관 앱`

### Design Principles

1. 10초 안에 기록을 시작할 수 있어야 한다.
2. 사진 한 장만으로도 기록이 완성되어야 한다.
3. 스트릭은 동기부여 수단이지 처벌 시스템이 아니어야 한다.
4. 사용자가 쌓이는 감각을 명확히 느껴야 한다.
5. 소셜 없이도 매일 열 가치가 있어야 한다.
6. 사진 권한, 알림 권한, 로그인은 가능한 늦게 요구한다.
7. 제품의 정체성은 `archive-first`, `habit-first`, `self-first`다.

---

## 1. PRD

### 1.1 제품 개요

이 앱은 사용자가 매일 사진 한 장과 짧은 메모를 남기며 개인 아카이브를 쌓아가는 iOS 앱이다. 제품의 핵심은 기록 그 자체보다 `매일 다시 돌아오게 만드는 구조`에 있다.

사용자는 홈에서 오늘의 기록 상태와 미션을 확인하고, 사진 한 장을 촬영하거나 선택하고, 필요하면 한 줄 메모와 감정 태그를 추가한 뒤 저장한다. 저장 후에는 `streak`, `XP`, `badge progress`, `calendar fill`이 즉시 반영된다. 시간이 지나면 월간 캘린더, 회고, 대표 사진, 감정 분포 등으로 자신의 일상을 돌아볼 수 있다.

### 1.2 문제 정의

#### 사용자 문제

1. 일기는 쓰고 싶지만 매일 긴 글을 쓰는 것은 부담스럽다.
2. 사진은 많이 찍지만 나중에 다시 보거나 정리하지 않는다.
3. 습관 앱은 건조하고, SNS는 피로하다.
4. 기록을 지속할 만한 가벼운 보상 구조가 부족하다.
5. 하루가 흘러가도 "오늘을 남겼다"는 감각이 없다.

#### 시장 문제

1. 사진 앱은 보관에 강하지만 회고와 습관 형성에 약하다.
2. SNS는 기록보다 노출과 반응 설계가 중심이다.
3. BeReal 계열 앱은 실시간 사회적 맥락이 강하고, 장기 개인 아카이브 동기가 약하다.

#### 해결 가설

`하루 한 장 + 저마찰 입력 + streak/freeze/quest + calendar accumulation + reflection` 조합이 있으면 사용자는 글 일기보다 쉽게, 앨범 앱보다 더 의식적으로, 습관 앱보다 더 감성적으로 기록을 지속한다.

### 1.3 타깃 사용자

#### 1차 타깃

1. 긴 일기를 못 쓰지만 하루를 남기고 싶은 사람
2. 사진을 자주 찍지만 정리하지 않는 사람
3. 작고 꾸준한 루틴을 선호하는 사람
4. 공개 SNS에 피로감을 느끼는 사람
5. 감정 기록과 자기 회고에 관심 있는 사람

#### 핵심 페르소나

| 페르소나 | 니즈 | 현재 문제 | 제품이 주는 해결 |
| --- | --- | --- | --- |
| 민지, 27, 직장인 | 긴 글 없이 하루 기록 | 일기 앱 3일 이상 못 감 | 사진 한 장과 한 줄 메모로 기록 완료 |
| 현우, 31, 기획자 | 사진을 의미 있게 남김 | 사진첩이 산만함 | 하루 대표 사진만 선택해 기록 선명화 |
| 서연, 24, 대학원생 | 성취감 있는 루틴 | 습관 앱은 감성이 없음 | streak + visual archive로 감성적 루틴 형성 |

### 1.4 핵심 가치 제안

1. `낮은 진입장벽`: 사진 한 장만 있으면 기록 완료
2. `지속 동기`: streak, quest, badge, progress bar, freeze
3. `개인 아카이브`: 시간이 지날수록 가치가 커지는 구조
4. `회고 가능성`: 캘린더, 월간 리포트, 감정/태그 축적
5. `조용한 사용성`: 공개 피드와 비교 압박 없이 혼자 써도 충분함

### 1.5 핵심 사용자 시나리오

#### 시나리오 A: 첫 기록

1. 사용자가 앱을 처음 실행한다.
2. 온보딩에서 "하루 한 장"과 "streak" 가치를 이해한다.
3. 알림 시간을 선택하거나 건너뛴다.
4. 홈에서 오늘의 미션을 본다.
5. 사진 촬영 또는 앨범 선택 후 저장한다.
6. 완료 애니메이션과 첫 streak를 받는다.

#### 시나리오 B: 일상 루프

1. 저녁 9시에 알림을 받는다.
2. 홈에서 `오늘 아직 기록 안 함`, `현재 8일 streak`, `오늘의 미션`을 본다.
3. 카메라로 사진을 찍고 한 줄 메모를 남긴다.
4. 저장 즉시 streak가 9일로 증가한다.
5. 홈과 캘린더에 오늘 카드가 채워진다.

#### 시나리오 C: 이탈 후 복귀

1. 사용자가 하루를 놓친다.
2. 다음 날 앱을 열면 freeze 자동 사용 여부 또는 streak reset 결과를 본다.
3. 실패 메시지는 처벌형이 아니라 재시작형으로 제공된다.
4. 오늘 사진을 기록하며 다시 루프에 복귀한다.

### 1.6 MVP 범위

#### MVP 목표

`사용자가 7일 연속 기록을 유지할 수 있는가`를 검증한다.

#### MVP 포함

1. 하루 한 장 기록
2. 사진 촬영 / 앨범 선택
3. 한 줄 메모
4. streak 계산
5. streak freeze 기본 정책
6. 홈 화면
7. 월간 캘린더
8. 기록 상세 / 수정 / 삭제
9. 로컬 알림
10. 온보딩
11. 기본 미션
12. 기본 배지
13. 로컬 저장

#### MVP 제외

1. 공개 피드
2. 팔로우/추천
3. 댓글
4. 대규모 친구 네트워크
5. 랭킹
6. AI 사진 분석
7. 서버 기반 소셜 동기화
8. Android 동시 출시

### 1.7 기능 요구사항

#### 핵심 루프 요구사항

1. 사용자는 하루에 대표 사진 1장을 저장할 수 있어야 한다.
2. 사진만으로 기록이 완료되어야 한다.
3. 기록 완료 시 즉시 streak와 progress가 반영되어야 한다.
4. 사용자는 월별 누적 상태를 시각적으로 확인할 수 있어야 한다.
5. 알림 없이도 앱은 완전하게 동작해야 한다.
6. 실패 후 재시작 UX가 부드러워야 한다.

#### 핵심 정책 요구사항

1. 하루 기준은 로컬 타임존 기준 `00:00~23:59`
2. 당일 기록 교체 허용
3. 과거 날짜 신규 추가는 MVP에서 비허용
4. 과거 기록 수정은 메모/태그 수정만 허용, 이미지 교체는 비허용
5. 오늘 기록 삭제 시 streak 즉시 재계산
6. freeze는 자동 사용 기본

### 1.8 비기능 요구사항

1. 기록 진입 시간: 홈 진입 후 사진 선택 화면까지 1탭 이내
2. 저장 시간: 로컬 저장 기준 1초 내 체감 완료
3. 오프라인 지원: 핵심 기능 전부 오프라인 동작
4. 개인정보 보호: 기본값은 private-only
5. 안정성: 앱 재실행 후 데이터 손실 없어야 함
6. 접근성: Dynamic Type, VoiceOver 라벨, 명확한 색 대비 고려
7. 배터리/스토리지: 썸네일 별도 저장과 압축 전략 필요

### 1.9 제외 범위

1. "지금 당장 찍어야 하는" 랜덤 인증 시스템
2. 듀얼 카메라 기반 인증 촬영
3. 실시간 친구 비교 UX
4. 공개 좋아요/인기순 피드
5. 과한 필터/편집
6. 완전한 클라우드 앨범 대체

### 1.10 성공 지표

#### Core Metrics

1. 첫 기록 완료율 `> 75%`
2. D1 retention `> 40%`
3. D7 retention `> 20%`
4. 3일 연속 기록 달성률 `> 30%`
5. 7일 연속 기록 달성률 `> 15%`
6. 알림 허용률 `> 45%`
7. 홈 진입 후 기록 완료까지 평균 소요 시간 `< 30초`

#### Leading Indicators

1. 메모 작성률
2. 미션 완료율
3. 캘린더 화면 주간 조회율
4. 삭제율
5. freeze 사용률

### 1.11 리스크

1. `BeReal copycat`으로 오인될 수 있음
2. streak 강박감이 오히려 이탈을 유발할 수 있음
3. 사진 저장이 기기 용량 문제를 만들 수 있음
4. 로컬 저장만으로는 기기 교체 시 불안이 생길 수 있음
5. 권한 허용률이 낮으면 첫 경험이 흔들릴 수 있음

### 1.12 향후 확장 방향

1. 월간/연간 회고 강화
2. 위젯 고도화
3. 선택형 친구/그룹 공유
4. CloudKit 기반 백업
5. 프리미엄 테마/통계/내보내기
6. AI 보조 회고

---

## 2. Product Strategy

### 2.1 BeReal과의 차별화 프레임

| 항목 | BeReal형 구조 | 본 제품 |
| --- | --- | --- |
| 핵심 트리거 | 랜덤 시간 푸시 | 사용자 루틴 시간 / 자발적 복귀 |
| 핵심 목적 | 실시간 인증 공유 | 개인 아카이브 습관 형성 |
| 사회적 구조 | 친구 피드 우선 | 나만 보기 우선 |
| 기록 가치 | 그날의 즉시성 | 누적, 회고, 성장 감각 |
| 촬영 방식 | 즉시 촬영 중심 | 촬영 또는 선택 모두 허용 |
| 긴장감 | 놓치면 늦음 | 놓쳐도 다시 시작 가능 |

### 2.2 Duolingo에서 차용할 구조

| Duolingo 요소 | 사진 기록 앱 적용 |
| --- | --- |
| Streak | 연속 기록 일수 |
| Daily Quest | 오늘의 사진 미션 |
| XP | 기록, 메모, 미션 완료 점수 |
| Streak Freeze | 하루 누락 보호 |
| Badge | 3일/7일/30일/100일 등 성취 |
| Progress Map | 캘린더, 월간 기록률, streak card |
| Comeback Hook | 어제 놓쳤어요 / 1년 전 오늘 / 월간 회고 |

### 2.3 핵심 제품 원칙

1. `감시`가 아니라 `회고`
2. `경쟁`이 아니라 `누적`
3. `완벽함`이 아니라 `지속`
4. `과시`가 아니라 `개인성`

---

## 3. MVP Feature Spec

### 3.1 P0

#### P0-1. 오늘의 사진 기록

- 목적: 제품의 핵심 행동 완성
- 사용자 스토리: 사용자는 오늘을 대표하는 사진 한 장을 남기고 싶다.
- 상세 동작:
  1. 홈의 CTA 탭
  2. `카메라로 찍기` 또는 `앨범에서 선택`
  3. 사진 미리보기
  4. 저장 전 메모/감정/미션 완료 여부 선택 가능
  5. 저장 시 해당 로컬 날짜 엔트리 생성 또는 당일 엔트리 교체
- 예외 케이스:
  - 권한 거부
  - 사진 로드 실패
  - 저장 도중 앱 종료
  - 오늘 이미 기록한 상태에서 재기록
- 데이터 요구사항:
  - `DailyPhotoEntry.localDate`
  - `imageLocalPath`
  - `createdAtUTC`
  - `updatedAtUTC`
- 우선순위: P0
- 구현 난이도: 중
- MVP 포함 여부: 포함

#### P0-2. 한 줄 메모

- 목적: 사진에 맥락 추가
- 사용자 스토리: 사용자는 왜 이 사진을 골랐는지 짧게 남기고 싶다.
- 상세 동작:
  1. 최대 80~120자 한 줄 메모 입력
  2. 미입력 가능
  3. 저장 후 상세와 홈 카드에 일부 노출
- 예외 케이스:
  - 빈 입력
  - 너무 긴 입력
  - 이모지/줄바꿈 처리 정책
- 데이터 요구사항:
  - `memo`
- 우선순위: P0
- 구현 난이도: 하
- MVP 포함 여부: 포함

#### P0-3. Streak

- 목적: 일일 복귀 동기 강화
- 사용자 스토리: 사용자는 연속 기록을 유지하며 성취감을 느끼고 싶다.
- 상세 동작:
  1. 오늘 기록 시 streak 반영
  2. 자정 이후 첫 앱 진입 또는 저장 시 상태 계산
  3. freeze 여부 반영
  4. 홈, 마이페이지, 완료 화면에서 표시
- 예외 케이스:
  - 앱 미실행 상태에서 날짜 경과
  - 기기 시간 변경
  - 타임존 변경
  - 삭제로 인한 재계산
- 데이터 요구사항:
  - `StreakState`
  - `StreakEvent`
- 우선순위: P0
- 구현 난이도: 중상
- MVP 포함 여부: 포함

#### P0-4. 캘린더 뷰

- 목적: 기록 누적 감각 제공
- 사용자 스토리: 사용자는 내가 얼마나 기록했는지 한눈에 보고 싶다.
- 상세 동작:
  1. 월 단위 grid
  2. 기록일은 썸네일 또는 컬러 채움
  3. 미기록일은 빈 셀
  4. 날짜 탭 시 상세 이동
- 예외 케이스:
  - 기록 0개인 월
  - 사진 파일 손상
  - 긴 달력 스크롤 시 성능
- 데이터 요구사항:
  - 월별 엔트리 조회
  - thumbnail path
- 우선순위: P0
- 구현 난이도: 중
- MVP 포함 여부: 포함

#### P0-5. 홈 화면

- 목적: 오늘 기록 행동 유도
- 사용자 스토리: 사용자는 앱을 켜자마자 지금 무엇을 해야 하는지 알고 싶다.
- 상세 동작:
  1. 오늘 날짜, streak, 기록 여부, 미션 표시
  2. 가장 큰 CTA로 기록 버튼 제공
  3. 최근 기록 3~5개 미리보기
  4. 월간 기록률 표시
- 예외 케이스:
  - 첫 사용자
  - 오늘 기록 완료 상태
  - 미션 없음
- 데이터 요구사항:
  - 오늘 entry
  - current streak
  - current mission
  - month completion rate
- 우선순위: P0
- 구현 난이도: 중
- MVP 포함 여부: 포함

#### P0-6. 로컬 알림

- 목적: 사용자의 루틴 시간에 복귀 유도
- 사용자 스토리: 사용자는 정해둔 시간에 오늘 기록을 떠올리고 싶다.
- 상세 동작:
  1. 온보딩 또는 설정에서 시간 선택
  2. 매일 1회 로컬 알림 예약
  3. 기록 완료 시 추가 알림 없음
- 예외 케이스:
  - 알림 권한 거부
  - 시간대 변경
  - 사용자가 시간 수정
- 데이터 요구사항:
  - `reminderEnabled`
  - `reminderTime`
- 우선순위: P0
- 구현 난이도: 중
- MVP 포함 여부: 포함

#### P0-7. 온보딩

- 목적: 가치 이해 및 초기 설정 완료
- 사용자 스토리: 사용자는 이 앱이 무엇을 위한 앱인지 빠르게 이해하고 싶다.
- 상세 동작:
  1. 3~4장 설명 카드
  2. 알림 시간 선택
  3. 첫 기록 CTA
  4. 권한은 실제 액션 시점 요청
- 예외 케이스:
  - 알림 스킵
  - 온보딩 도중 종료
- 데이터 요구사항:
  - `onboardingCompleted`
- 우선순위: P0
- 구현 난이도: 하
- MVP 포함 여부: 포함

#### P0-8. 기록 상세 / 수정 / 삭제

- 목적: 기록의 신뢰성과 관리성 제공
- 사용자 스토리: 사용자는 과거 기록을 다시 보고, 필요하면 메모를 수정하고 싶다.
- 상세 동작:
  1. 사진 크게 보기
  2. 날짜, 메모, 감정, 태그, 미션 표시
  3. 당일은 사진 교체 허용
  4. 과거는 메모/감정/태그 수정만 허용
  5. 삭제 시 streak 영향 경고
- 예외 케이스:
  - 삭제 후 파일 orphan cleanup
  - 삭제 후 streak 재계산
- 데이터 요구사항:
  - entry id
  - update/delete timestamps
- 우선순위: P0
- 구현 난이도: 중
- MVP 포함 여부: 포함

### 3.2 P1

#### P1-1. 오늘의 사진 미션

- 목적: 무엇을 찍을지 고민 줄이기
- 사용자 스토리: 사용자는 사진 소재가 떠오르지 않을 때 힌트를 받고 싶다.
- 상세 동작:
  1. 매일 1개 미션 제시
  2. `건너뛰기` 가능
  3. 저장 시 미션과 연결
- 예외 케이스:
  - 미션이 너무 추상적임
  - 사용자가 계속 같은 미션만 봄
- 데이터 요구사항:
  - `Mission`
  - `missionId`
  - `missionCompleted`
- 우선순위: P1
- 구현 난이도: 중
- MVP 포함 여부: 기본형은 포함, 개인화는 제외

#### P1-2. 감정 태그

- 목적: 회고 가치 강화
- 사용자 스토리: 사용자는 사진과 함께 오늘 기분도 남기고 싶다.
- 상세 동작:
  1. 1개 단일 선택 기본
  2. 건너뛰기 가능
  3. 월간 회고에 집계
- 예외 케이스:
  - 감정 정의가 사용자와 맞지 않음
- 데이터 요구사항:
  - `mood`
- 우선순위: P1
- 구현 난이도: 하
- MVP 포함 여부: 포함 가능

#### P1-3. 배지

- 목적: 장기 사용 동기 부여
- 사용자 스토리: 사용자는 기록이 성취로 보이는 보상을 원한다.
- 상세 동작:
  1. 조건 만족 시 자동 unlock
  2. 홈 또는 완료 화면에서 즉시 노출
  3. 배지 목록에서 재확인
- 예외 케이스:
  - 동시에 여러 배지 획득
- 데이터 요구사항:
  - `Badge`
  - unlock timestamp
- 우선순위: P1
- 구현 난이도: 중
- MVP 포함 여부: 기본형 포함

#### P1-4. Streak Freeze

- 목적: 실수로 인한 이탈 방지
- 사용자 스토리: 사용자는 하루를 놓쳐도 완전히 무너지지 않길 원한다.
- 상세 동작:
  1. 월별 무료 지급
  2. 자정 이후 앱 진입 시 자동 사용 판단
  3. 사용 사실을 설명하는 메시지 제공
- 예외 케이스:
  - 여러 날 연속 미기록
  - 보유 0개
- 데이터 요구사항:
  - `freezeCount`
  - `freezeUsedDates`
- 우선순위: P1
- 구현 난이도: 중
- MVP 포함 여부: 간소형 포함

#### P1-5. 월간 회고

- 목적: 장기 보관 가치 강화
- 사용자 스토리: 사용자는 한 달을 돌아보며 의미를 느끼고 싶다.
- 상세 동작:
  1. 월별 대표 사진 3~5장
  2. 기록일 수, 감정 통계, longest streak
  3. 한 줄 요약 입력 또는 자동 생성 placeholder
- 예외 케이스:
  - 기록이 3개 미만인 월
- 데이터 요구사항:
  - month aggregates
- 우선순위: P1
- 구현 난이도: 중상
- MVP 포함 여부: 제외 가능

#### P1-6. 홈 화면 위젯

- 목적: 홈스크린 복귀 유도
- 사용자 스토리: 사용자는 앱을 열지 않아도 오늘 기록 상태를 보고 싶다.
- 상세 동작:
  1. small/medium widget
  2. streak, 기록 여부, 미션 표시
  3. deep link to record flow
- 예외 케이스:
  - 권한/데이터 동기 지연
- 데이터 요구사항:
  - app group/shared storage
- 우선순위: P1
- 구현 난이도: 중상
- MVP 포함 여부: 제외

### 3.3 P2

#### P2-1. 소규모 친구 그룹

- 목적: 조용한 공유 확장
- 사용자 스토리: 사용자는 가까운 사람과만 기록을 나누고 싶다.
- 상세 동작:
  1. 초대 코드 기반 그룹
  2. 오늘 기록 여부 또는 선택적 사진 공유
  3. 가벼운 이모지 반응
- 예외 케이스:
  - 신고/차단
  - 그룹 탈퇴
- 데이터 요구사항:
  - user auth
  - group membership
  - permissions
- 우선순위: P2
- 구현 난이도: 상
- MVP 포함 여부: 제외

#### P2-2. 챌린지

- 목적: 특정 테마 기록 강화
- 사용자 스토리: 사용자는 7일/30일 테마형 기록에 참여하고 싶다.
- 상세 동작:
  1. 기간형 챌린지
  2. progress tracking
  3. 배지 연결
- 예외 케이스:
  - 챌린지 중도 이탈
- 데이터 요구사항:
  - challenge model
  - challenge progress
- 우선순위: P2
- 구현 난이도: 중상
- MVP 포함 여부: 제외

#### P2-3. AI 회고

- 목적: 감정적 회고 보조
- 사용자 스토리: 사용자는 내 기록을 요약한 문장을 받아보고 싶다.
- 상세 동작:
  1. 월간 요약 문장
  2. 제목 추천
  3. 감정 변화 정리
- 예외 케이스:
  - 프라이버시 동의
  - 부정확한 해석
- 데이터 요구사항:
  - text summary input
  - consent flag
- 우선순위: P2
- 구현 난이도: 상
- MVP 포함 여부: 제외

#### P2-4. 앨범 내보내기

- 목적: 저장 자산의 외부 활용 가치 제공
- 사용자 스토리: 사용자는 한 달 기록을 이미지나 PDF로 보관하고 싶다.
- 상세 동작:
  1. 월간 collage export
  2. PDF diary export
  3. share sheet 연결
- 예외 케이스:
  - 이미지 누락
  - 메모 비공개 처리
- 데이터 요구사항:
  - render/export metadata
- 우선순위: P2
- 구현 난이도: 상
- MVP 포함 여부: 제외

---

## 4. Screen Design Spec

### 4.1 온보딩

- 화면 목적: 제품 가치와 사용 방식을 30초 안에 이해시킨다.
- 주요 UI 컴포넌트:
  - 3~4장 pager
  - 핵심 메시지
  - `시작하기` CTA
  - `알림 설정은 나중에` secondary CTA
- 사용자 액션:
  - 넘기기
  - 시작하기
  - 건너뛰기
- 이동 경로:
  - 첫 실행 -> 온보딩 -> 알림 시간 설정 또는 홈
- 빈 상태:
  - 없음
- 에러 상태:
  - 저장 실패 시 기본값으로 진행
- 권한 거부 상태:
  - 아직 직접 요청 안 함
- 문구 예시:
  - `딱 한 장이면 충분해요`
  - `오늘의 나를 조용히 쌓아보세요`

### 4.2 알림 시간 설정

- 화면 목적: 사용자 루틴 시간 확보
- 주요 UI 컴포넌트:
  - time picker
  - 추천 시간 칩
  - `이 시간에 알려주세요`
  - `나중에 설정할게요`
- 사용자 액션:
  - 시간 선택
  - 허용/거부
  - 건너뛰기
- 이동 경로:
  - 온보딩 -> 알림 시간 설정 -> 홈
- 빈 상태:
  - 기본 추천 시간 표시
- 에러 상태:
  - 권한 요청 실패 시 설정 화면 안내
- 권한 거부 상태:
  - `알림 없이도 앱은 사용할 수 있어요`
- 문구 예시:
  - `기록하기 편한 시간을 골라주세요`

### 4.3 홈

- 화면 목적: 오늘 기록 행동을 즉시 유도
- 주요 UI 컴포넌트:
  - 상단 인사
  - streak card
  - 오늘의 미션 card
  - primary CTA
  - 오늘 기록 상태 card
  - 최근 기록 strip
  - 월간 progress bar
- 사용자 액션:
  - 기록 시작
  - 미션 보기
  - 최근 기록 탭
  - 캘린더 이동
- 이동 경로:
  - 앱 시작점
  - 홈 -> 촬영/선택
  - 홈 -> 상세
  - 홈 -> 캘린더
- 빈 상태:
  - 첫 기록 유도용 hero
- 에러 상태:
  - 데이터 로드 실패 시 CTA 유지
- 권한 거부 상태:
  - 카메라/앨범 선택 시 모달 가이드
- 문구 예시:
  - `오늘도 한 장 남겨볼까요?`
  - `현재 12일 연속 기록 중`

### 4.4 사진 촬영/선택

- 화면 목적: 가장 빠르게 사진 입력 시작
- 주요 UI 컴포넌트:
  - `카메라로 찍기`
  - `앨범에서 선택`
  - 최근 선택 미리보기
- 사용자 액션:
  - 카메라 실행
  - picker 열기
  - 취소
- 이동 경로:
  - 홈 -> 사진 촬영/선택 -> 기록 작성
- 빈 상태:
  - 안내 문구만 표시
- 에러 상태:
  - 로딩 실패 / unsupported asset
- 권한 거부 상태:
  - `설정에서 카메라 접근을 허용하면 바로 찍을 수 있어요`
  - `앨범 접근 없이도 촬영은 가능해요`
- 문구 예시:
  - `오늘의 한 장을 골라주세요`

### 4.5 기록 작성

- 화면 목적: 사진 저장 전 최소한의 메타데이터 입력
- 주요 UI 컴포넌트:
  - photo preview
  - memo input
  - mood chips
  - mission status
  - save button
- 사용자 액션:
  - 메모 입력
  - 감정 선택
  - 저장
  - 다시 선택
- 이동 경로:
  - 촬영/선택 -> 기록 작성 -> 기록 완료
- 빈 상태:
  - 메모 미입력 가능
- 에러 상태:
  - 저장 실패 토스트
- 권한 거부 상태:
  - 이전 단계에서 처리
- 문구 예시:
  - `이 사진을 고른 이유는?`
  - `메모는 나중에 써도 괜찮아요`

### 4.6 기록 완료

- 화면 목적: 즉시 보상 제공, 다음 날 복귀 동기 강화
- 주요 UI 컴포넌트:
  - 완료 애니메이션
  - streak 증가 문구
  - XP
  - 다음 배지까지 남은 수치
  - 홈으로 돌아가기
- 사용자 액션:
  - 홈 복귀
  - 캘린더 보기
- 이동 경로:
  - 기록 작성 -> 완료 -> 홈/캘린더
- 빈 상태:
  - 없음
- 에러 상태:
  - 저장 성공 후 UI만 단순 fallback
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `오늘의 한 장이 저장됐어요`
  - `13일 연속 기록!`

### 4.7 캘린더

- 화면 목적: 누적 기록을 월 단위로 보여준다.
- 주요 UI 컴포넌트:
  - 월 선택 헤더
  - day grid
  - 썸네일 셀
  - 월간 기록률
- 사용자 액션:
  - 날짜 선택
  - 월 이동
- 이동 경로:
  - 홈/탭 -> 캘린더 -> 상세
- 빈 상태:
  - `아직 기록이 없어요. 오늘 첫 장을 남겨보세요`
- 에러 상태:
  - 썸네일 누락 시 placeholder
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `이번 달 18일 중 14일 기록`

### 4.8 기록 상세

- 화면 목적: 특정 날짜 기록 열람 및 관리
- 주요 UI 컴포넌트:
  - large photo
  - date
  - memo
  - mood/tag/mission
  - edit / delete
- 사용자 액션:
  - 메모 수정
  - 삭제
  - 이전/다음 날짜 이동
- 이동 경로:
  - 캘린더 -> 상세
  - 홈 최근 기록 -> 상세
- 빈 상태:
  - 직접 진입 없음
- 에러 상태:
  - 파일 누락 시 재로드 안내
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `이 기록을 삭제하면 연속 기록이 바뀔 수 있어요`

### 4.9 마이페이지

- 화면 목적: 개인 통계와 계정/설정 진입점 제공
- 주요 UI 컴포넌트:
  - profile header
  - streak summary
  - total entries
  - badge shortcut
  - premium shortcut
  - settings shortcut
- 사용자 액션:
  - 배지 보기
  - 설정 이동
  - 프리미엄 보기
- 이동 경로:
  - 탭 -> 마이페이지 -> 설정/배지/프리미엄
- 빈 상태:
  - 프로필명 기본값 제공
- 에러 상태:
  - 통계 로딩 실패 fallback
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `지금까지 42일을 남겼어요`

### 4.10 설정

- 화면 목적: 앱 동작 정책과 개인 환경 설정
- 주요 UI 컴포넌트:
  - 알림 설정
  - 기본 저장 정책
  - 데이터 백업 안내
  - 개인정보 정책
  - 계정 삭제 또는 데이터 초기화
- 사용자 액션:
  - 알림 시간 변경
  - 백업 정보 확인
  - 앱 권한 안내 열기
- 이동 경로:
  - 마이페이지 -> 설정
- 빈 상태:
  - 없음
- 에러 상태:
  - 시스템 설정 연동 실패 시 안내
- 권한 거부 상태:
  - `설정 앱에서 권한을 바꿀 수 있어요`
- 문구 예시:
  - `알림 없이도 앱은 계속 사용할 수 있어요`

### 4.11 배지 목록

- 화면 목적: 누적 성취의 시각화
- 주요 UI 컴포넌트:
  - unlocked / locked grid
  - badge detail sheet
  - progress hint
- 사용자 액션:
  - 배지 탭
- 이동 경로:
  - 마이페이지 -> 배지 목록
- 빈 상태:
  - 첫 배지 유도 문구
- 에러 상태:
  - 없음
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `첫 기록 배지가 기다리고 있어요`

### 4.12 프리미엄 안내

- 화면 목적: 유료 가치 설명
- 주요 UI 컴포넌트:
  - 가치 비교표
  - 주요 혜택
  - 가격 카드
  - 복원 버튼
- 사용자 액션:
  - 구독 / lifetime 구매
  - 닫기
- 이동 경로:
  - 마이페이지 / 제한 기능 진입 -> 프리미엄 안내
- 빈 상태:
  - 없음
- 에러 상태:
  - StoreKit 응답 실패 시 재시도
- 권한 거부 상태:
  - 없음
- 문구 예시:
  - `기록을 더 오래, 더 안전하게 보관해보세요`

---

## 5. User Flows

### 5.1 첫 실행 -> 온보딩 -> 알림 설정 -> 첫 사진 기록

1. 앱 첫 실행
2. 온보딩 1: `하루 한 장으로 기록`
3. 온보딩 2: `streak와 캘린더로 쌓이는 감각`
4. 온보딩 3: `기록은 기본적으로 나만 보기`
5. 알림 시간 설정 또는 건너뛰기
6. 홈 진입
7. `오늘 사진 남기기` 탭
8. 카메라 또는 앨범 선택
9. 실제 시점 권한 요청
10. 사진 선택
11. 메모/감정 선택
12. 저장
13. 완료 화면
14. 홈 복귀

### 5.2 일반 사용자의 오늘 기록 플로우

1. 사용자가 홈 진입
2. 오늘 기록 상태 확인
3. 미션 확인
4. CTA 탭
5. 촬영 또는 선택
6. 저장
7. streak 증가
8. 홈과 캘린더 반영

### 5.3 기록을 놓친 다음 날 복귀 플로우

1. 사용자가 어제 기록을 놓침
2. 다음 날 앱 진입
3. 시스템이 `yesterday` 기준 streak 계산
4. freeze 보유 시 자동 사용 여부 판단
5. 결과 메시지 표시
6. 오늘 기록 CTA 강조
7. 사용자가 새 기록 저장

### 5.4 Streak Freeze 사용 플로우

1. 어제 미기록
2. 앱 진입 시 `freezeCount > 0` 확인
3. 자동으로 1개 차감
4. `어제는 쉬어갔지만 streak가 유지됐어요` 메시지 노출
5. 오늘 기록 독려

### 5.5 캘린더에서 과거 기록 보기 플로우

1. 캘린더 탭 진입
2. 월간 grid 확인
3. 날짜 탭
4. 상세 화면 진입
5. 사진, 메모, 감정, 미션 확인
6. 허용 범위 내 수정 또는 삭제

### 5.6 사진 권한 거부 사용자 플로우

1. 사용자가 `앨범에서 선택` 탭
2. 권한 거부 상태 감지
3. 권한 설명 시트 표시
4. `설정으로 이동` 또는 `카메라로 찍기`
5. 사용자가 카메라 대안 선택 가능

### 5.7 알림 권한 거부 사용자 플로우

1. 온보딩 또는 설정에서 알림 요청
2. 사용자 거부
3. 앱은 정상 진입
4. 홈과 설정에서 `원하면 나중에 켤 수 있어요` 안내
5. 추가 강제 팝업 없음

### 5.8 프리미엄 전환 플로우

1. 사용자가 제한 기능 진입
2. 프리미엄 안내 화면
3. 혜택 비교 확인
4. 구매 또는 닫기
5. 구매 성공 시 상태 반영
6. 해당 기능 즉시 활성화

---

## 6. Data Model

기준: iOS 로컬 저장, `SwiftData` 우선 설계. 추후 `CloudKit` 또는 서버 동기화 시 확장 가능하도록 `id`, `createdAtUTC`, `updatedAtUTC`, `soft delete`, `sync state` 필드를 고려한다.

### 6.1 UserProfile

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | UUID | N | 로컬 사용자 식별자 |
| nickname | String | Y | 표시 이름 |
| createdAtUTC | Date | N | 프로필 생성 시각 |
| onboardingCompleted | Bool | N | 온보딩 완료 여부 |
| preferredTone | String | Y | 감성 톤 실험용, 예: cozy/minimal |
| timezoneIdentifier | String | N | 기본 타임존 |
| premiumStatus | String | N | free/premium/lifetime |
| lastAppOpenedAtUTC | Date | Y | 최근 앱 진입 시각 |
| currentXP | Int | N | 누적 XP |

### 6.2 DailyPhotoEntry

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | UUID | N | 기록 ID |
| userId | UUID | N | UserProfile 참조 |
| localDateString | String | N | `YYYY-MM-DD` 형식 로컬 날짜 |
| createdAtUTC | Date | N | 최초 저장 시각 |
| updatedAtUTC | Date | N | 최근 수정 시각 |
| timezoneIdentifier | String | N | 저장 시점 타임존 |
| timezoneOffsetMinutes | Int | N | 저장 시점 오프셋 |
| imageLocalPath | String | N | 앱 내부 이미지 경로 |
| thumbnailLocalPath | String | Y | 썸네일 경로 |
| imageRemoteURL | String | Y | 추후 동기화용 |
| memo | String | Y | 한 줄 메모 |
| moodCode | String | Y | 감정 코드 |
| tags | [String] | Y | 선택 태그 |
| missionId | String | Y | 해당 일자 미션 ID |
| missionCompleted | Bool | N | 미션 수행 여부 |
| sourceType | String | N | camera/library |
| entryStatus | String | N | active/deleted |
| isDeleted | Bool | N | soft delete |
| deletedAtUTC | Date | Y | 삭제 시각 |
| syncState | String | N | none/pending/synced/failed |

### 6.3 Mission

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | String | N | 미션 ID |
| title | String | N | 미션 제목 |
| descriptionText | String | N | 미션 설명 |
| category | String | N | color/emotion/place/object 등 |
| difficulty | Int | N | 1~3 |
| exampleText | String | Y | 예시 문구 |
| isActive | Bool | N | 사용 여부 |
| sortOrder | Int | N | 노출 순서 |
| locale | String | Y | 현지화 코드 |

### 6.4 Badge

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | String | N | 배지 ID |
| title | String | N | 배지명 |
| descriptionText | String | N | 설명 |
| conditionType | String | N | streak/entryCount/missionCount 등 |
| conditionValue | Int | N | 조건 값 |
| iconName | String | N | 에셋 이름 |
| isUnlocked | Bool | N | 해금 여부 |
| unlockedAtUTC | Date | Y | 해금 시각 |

### 6.5 StreakState

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | UUID | N | 상태 ID |
| userId | UUID | N | UserProfile 참조 |
| currentStreak | Int | N | 현재 streak |
| longestStreak | Int | N | 최고 streak |
| lastCompletedLocalDateString | String | Y | 마지막 기록 로컬 날짜 |
| freezeCount | Int | N | 보유 freeze 수 |
| lastEvaluatedAtUTC | Date | Y | streak 계산 마지막 수행 시각 |
| lastKnownTimezoneIdentifier | String | Y | 계산 기준 타임존 |

### 6.6 StreakEvent

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | UUID | N | 이벤트 ID |
| userId | UUID | N | 사용자 참조 |
| localDateString | String | N | 기준 날짜 |
| eventType | String | N | completed/missed/freezeUsed/reset/restored |
| relatedEntryId | UUID | Y | 연결된 기록 |
| createdAtUTC | Date | N | 이벤트 생성 시각 |
| metadataJSON | String | Y | 부가 정보 |

### 6.7 AppSettings

| 필드 | 타입 | Optional | 설명 |
| --- | --- | --- | --- |
| id | UUID | N | 설정 ID |
| reminderEnabled | Bool | N | 알림 활성화 여부 |
| reminderHour | Int | Y | 알림 시 |
| reminderMinute | Int | Y | 알림 분 |
| cameraPermissionPrompted | Bool | N | 카메라 권한 요청 여부 |
| photoLibraryPermissionPrompted | Bool | N | 앨범 권한 요청 여부 |
| notificationsPermissionPrompted | Bool | N | 알림 권한 요청 여부 |
| autoApplyFreeze | Bool | N | freeze 자동 사용 여부 |
| allowSameDayReplacement | Bool | N | 당일 사진 교체 허용 |
| analyticsEnabled | Bool | N | 분석 동의 여부 |
| hapticsEnabled | Bool | N | 햅틱 여부 |

### 6.8 Recommended Local Storage Policy

1. 원본 이미지는 앱 전용 디렉터리 저장
2. 썸네일은 별도 생성 후 캐시
3. 메타데이터는 SwiftData
4. 삭제 시 soft delete 후 background cleanup
5. 추후 sync 대비해 stable ID 유지

---

## 7. iOS Implementation Plan

### 7.1 Recommended Stack

- UI: `SwiftUI`
- Architecture: `MVVM`
- Persistence: `SwiftData`
- Image picking: `PhotosPicker`
- Camera: `AVFoundation` or `UIImagePickerController` thin MVP wrapper
- Notifications: `UserNotifications`
- Widgets: `WidgetKit`
- Purchases: `StoreKit 2`
- Future sync: `CloudKit` first, server optional

### 7.2 Folder Structure

```text
App/
  DayFrameApp.swift
  AppEnvironment.swift
  Routing/
    AppRouter.swift
    DeepLinkHandler.swift
  DesignSystem/
    Colors.swift
    Typography.swift
    Components/
  Models/
    UserProfile.swift
    DailyPhotoEntry.swift
    Mission.swift
    Badge.swift
    StreakState.swift
    StreakEvent.swift
    AppSettings.swift
  Features/
    Onboarding/
      OnboardingView.swift
      OnboardingViewModel.swift
    Home/
      HomeView.swift
      HomeViewModel.swift
      Components/
    Capture/
      CaptureChoiceView.swift
      CameraView.swift
      PhotoPickerCoordinator.swift
    EntryEditor/
      EntryEditorView.swift
      EntryEditorViewModel.swift
    Completion/
      CompletionView.swift
    Calendar/
      CalendarView.swift
      CalendarViewModel.swift
    EntryDetail/
      EntryDetailView.swift
      EntryDetailViewModel.swift
    Profile/
      ProfileView.swift
      ProfileViewModel.swift
    Settings/
      SettingsView.swift
      SettingsViewModel.swift
    Badges/
      BadgeListView.swift
    Premium/
      PremiumView.swift
  Services/
    Persistence/
      EntryRepository.swift
      UserRepository.swift
      MissionRepository.swift
    Media/
      CameraService.swift
      PhotoLibraryService.swift
      ImageStorageService.swift
      ThumbnailService.swift
    Notifications/
      NotificationService.swift
    Streak/
      StreakService.swift
      StreakEvaluator.swift
    Rewards/
      XPService.swift
      BadgeService.swift
    Analytics/
      AnalyticsService.swift
  Utilities/
    DateProvider.swift
    TimezoneHelper.swift
    Logger.swift
Widgets/
  DayFrameWidget.swift
  WidgetEntryProvider.swift
```

### 7.3 MVVM Structure

#### View

- 상태 표시와 사용자 입력 처리
- business logic 최소화
- routing trigger만 수행

#### ViewModel

- 화면 상태 조합
- use case orchestration
- validation
- async task control

#### Service / Repository

- persistence
- permission handling
- image write/read
- streak calculation
- notification scheduling

### 7.4 주요 View

1. `OnboardingView`
2. `ReminderSetupView`
3. `HomeView`
4. `CaptureChoiceView`
5. `CameraView`
6. `EntryEditorView`
7. `CompletionView`
8. `CalendarView`
9. `EntryDetailView`
10. `ProfileView`
11. `SettingsView`
12. `BadgeListView`
13. `PremiumView`

### 7.5 주요 ViewModel

1. `HomeViewModel`
   - 오늘 entry 조회
   - 현재 streak 상태 조회
   - 오늘 미션 로드
   - 월간 진행률 계산
2. `EntryEditorViewModel`
   - 사진 임시 상태 관리
   - 메모, 감정, 미션 반영
   - 저장 트리거
3. `CalendarViewModel`
   - 월별 엔트리 로딩
   - 날짜별 요약 생성
4. `EntryDetailViewModel`
   - 상세 로드
   - 수정/삭제
5. `SettingsViewModel`
   - 알림 시간 및 앱 설정 반영

### 7.6 주요 Service

#### EntryRepository

- day 단위 entry fetch
- month 단위 query
- save/update/delete

#### ImageStorageService

- 원본 저장
- 썸네일 생성 및 저장
- orphan cleanup

#### StreakService

- 오늘 기록 반영
- 자정 이후 상태 계산
- 삭제 후 재계산
- freeze 자동 적용

#### NotificationService

- 권한 상태 조회
- 시간 기반 로컬 알림 예약/갱신
- 권한 거부 상태 fallback UI 지원

#### BadgeService

- 이벤트 기반 배지 unlock
- 중복 unlock 방지

### 7.7 사진 선택 방식

#### 권장

1. 앨범 선택은 `PhotosPicker` 사용
2. 전체 라이브러리 권한 선요청 금지
3. 사용자가 탭한 시점에만 접근
4. 이미지 import 후 앱 전용 저장소로 복사

### 7.8 카메라 촬영 방식

#### MVP 권장

1. 빠른 출시가 중요하면 `UIImagePickerController` 래핑
2. UX 품질이 중요하면 추후 `AVFoundation` 커스텀 카메라
3. 초기에는 필터, 줌, 고급 편집 제외

### 7.9 로컬 저장 방식

#### 권장안

1. 이미지: `Application Support/Entries/{yyyy-mm-dd}/`
2. 썸네일: `Application Support/Thumbnails/`
3. 메타데이터: `SwiftData`
4. soft delete 후 background task로 파일 정리

#### 이미지 저장 정책

1. 원본 장축 제한 예: `2048px`
2. JPEG compression quality 예: `0.82`
3. 썸네일 별도 생성
4. 캘린더는 썸네일만 사용

### 7.10 알림 구현 방식

1. 사용자가 선택한 로컬 시각 기준으로 daily trigger 생성
2. timezone change 감지 시 재예약
3. 기록 완료 여부에 따라 알림 내용 조정은 MVP에서 생략 가능
4. 알림 카피는 5~10개 로테이션 가능

### 7.11 위젯 구현 가능성

1. `App Group`으로 streak/오늘 상태 공유
2. small widget: streak + 기록 여부
3. medium widget: 미션 + deep link
4. P1에서 충분히 가치 있음

### 7.12 Streak 계산 로직

#### 권장 정책

1. 하루 기준은 `localDateString`
2. `saveTodayEntry()` 호출 시 오늘 완료 처리
3. 앱 활성화 시 `evaluateStreakIfNeeded()` 실행
4. 평가 기준:
   - 마지막 완료일이 오늘이면 유지
   - 마지막 완료일이 어제면 유지
   - 마지막 완료일이 그저께 이상이고 어제를 비웠다면 freeze 확인
   - freeze 있으면 1개 차감 후 유지
   - 없으면 reset
5. 삭제 시 전체 재계산보다 `최근 구간 재계산`으로 최적화 가능하나 MVP는 단순 전체 재계산 허용

#### 의사 코드

```swift
func evaluateStreak(today: LocalDate, state: StreakState, completedDates: Set<LocalDate>) -> StreakOutcome {
    if completedDates.contains(today) { return .alreadyCompleted }

    let yesterday = today.minus(days: 1)

    if completedDates.contains(yesterday) {
        return .canContinueNormally
    }

    if state.freezeCount > 0 && !completedDates.contains(yesterday) {
        return .applyFreeze(date: yesterday)
    }

    return .reset
}
```

### 7.13 추후 서버 동기화 고려사항

1. 모든 모델은 stable ID 유지
2. `createdAtUTC`, `updatedAtUTC`, `isDeleted`, `syncState` 보유
3. 이미지 파일은 로컬 path와 remote URL 분리
4. 나중에 `CloudKit` 붙일 경우 개인 기록 앱과 매우 잘 맞음
5. 친구/그룹 기능이 추가되면 별도 서버가 더 자연스러움

---

## 8. Detailed Product Policies

### 8.1 로그인 필요 여부

#### 추천

초기 MVP는 `로그인 없이 시작`한다.

#### 이유

1. 첫 기록까지 마찰 최소화
2. 개인 기록 앱의 본질과 일치
3. 소셜 기능이 없으므로 계정 필요성이 낮음
4. 추후 백업/동기화 시 optional sign-in 도입 가능

### 8.2 저장 전략

#### 추천

`로컬 저장 우선`, 추후 `CloudKit` 확장

#### 이유

1. MVP 속도
2. 서버 비용 최소화
3. 개인 기록 앱에 적합
4. 오프라인 우수

### 8.3 하루 한 장 정책

#### 추천

대표 사진 1장 원칙을 `엄격하게 유지`한다.

#### 세부

1. 하루에 대표 엔트리는 1개
2. 당일에는 이미지 교체 가능
3. 다음 날 이후 이미지 교체 불가
4. 과거 기록의 메모/감정 수정은 허용

#### 이유

1. 습관 앱의 선명한 약속 유지
2. streak 조작 방지
3. 캘린더 누적 경험 단순화

### 8.4 과거 날짜 기록 추가

#### 추천

MVP에서는 `비허용`

#### 이유

1. "매일 기록"의 의미 보존
2. 복잡한 streak 예외 감소
3. 핵심 루프 집중

### 8.5 사진 교체 허용 범위

#### 추천

`당일만 허용`

#### 이유

1. 실수 수정은 필요
2. 과거 재작성은 기록의 진정성 훼손 가능

### 8.6 streak 복구 관대함

#### 추천

`자동 freeze + 재시작 친화 메시지`

#### 세부

1. 무료: 월 1개
2. 7일 streak 달성 보상: 1개
3. 최대 보유: 2개
4. 2일 이상 연속 누락 시 reset

#### 이유

1. 강박 완화
2. 무제한 복구는 streak 의미 약화

### 8.7 미션 생성 방식

#### 추천

초기에는 `큐레이션된 랜덤 풀`, 추후 개인화

#### 이유

1. 구현 단순
2. 콘텐츠 품질 통제 가능
3. 초기 데이터 부족 문제 없음

### 8.8 미션 변경 가능 여부

#### 추천

`하루 1회 reroll` 또는 `건너뛰기` 허용

#### 이유

1. 너무 억지스러운 미션 방지
2. 사용자가 통제감을 느낄 수 있음

### 8.9 친구 공유 도입 시점

#### 추천

`7일 retention과 개인 기록 가치 검증 후`

#### 이유

1. 아직 핵심 가치가 개인 루프인지 확인이 먼저
2. 소셜 기능은 운영/심사/개발 비용이 큼

### 8.10 공개 피드 여부

#### 추천

`초기 완전 배제`

#### 이유

1. 제품 정체성 흐림
2. UGC moderation 부담 급증
3. SNS와 차별성 약화

### 8.11 프리미엄 핵심 가치

#### 추천

`보관`, `회고`, `안전성`, `확장성`

#### 핵심 혜택

1. 전체 기록 무제한 조회
2. 월간/연간 회고
3. 백업/복원
4. 내보내기
5. 추가 freeze

### 8.12 사진 원본 서버 저장 여부

#### 추천

MVP에서는 `미저장`

#### 이유

1. 비용 절감
2. 프라이버시 단순화
3. 구현 속도 향상

### 8.13 감성 방향

#### 추천

`따뜻한 다이어리 감성 + 가벼운 귀여움 + 과하지 않은 미니멀`

#### 이유

1. 루틴 앱의 친화력 필요
2. 사진이 주인공이어야 함
3. 지나친 캐주얼함은 기록 자산 느낌을 약하게 함

### 8.14 시장 우선순위

#### 추천

`한국 시장 우선`, 구조는 글로벌 확장 가능하게 설계

#### 이유

1. 초기 카피/메시지/사용자 인터뷰 집중 가능
2. 로컬 정서에 맞는 톤 실험 쉬움
3. 모델/이름/로컬라이징 준비는 병행 가능

### 8.15 앱 이름 언어

#### 추천

브랜드는 `영문`, 마케팅 카피는 `한글 병행`

#### 후보 추천

1. `DayFrame`
2. `OneFrame`
3. `오늘한장`
4. `하루프레임`

#### 이유

1. iOS 글로벌 확장성
2. App Store 검색 대응
3. 한글 서브카피로 컨셉 명확화 가능

---

## 9. Functional Requirements by Priority

### 9.1 P0 Summary Table

| 기능명 | 목적 | 우선순위 | 난이도 | MVP |
| --- | --- | --- | --- | --- |
| 하루 한 장 기록 | 핵심 행동 | P0 | 중 | O |
| 메모 | 맥락 추가 | P0 | 하 | O |
| streak | 습관 동기 | P0 | 중상 | O |
| 캘린더 | 누적 시각화 | P0 | 중 | O |
| 홈 화면 | 행동 유도 | P0 | 중 | O |
| 로컬 알림 | 복귀 유도 | P0 | 중 | O |
| 온보딩 | 가치 전달 | P0 | 하 | O |
| 상세/수정/삭제 | 관리 기능 | P0 | 중 | O |

### 9.2 P1 Summary Table

| 기능명 | 목적 | 우선순위 | 난이도 | MVP |
| --- | --- | --- | --- | --- |
| 미션 | 소재 제공 | P1 | 중 | 기본형 O |
| 감정 태그 | 회고 강화 | P1 | 하 | 선택 O |
| 배지 | 장기 보상 | P1 | 중 | 기본형 O |
| freeze | 이탈 완충 | P1 | 중 | 간소형 O |
| 월간 회고 | 회고 가치 | P1 | 중상 | X |
| 위젯 | 복귀 강화 | P1 | 중상 | X |

### 9.3 P2 Summary Table

| 기능명 | 목적 | 우선순위 | 난이도 | MVP |
| --- | --- | --- | --- | --- |
| 친구 그룹 | 제한적 공유 | P2 | 상 | X |
| 챌린지 | 테마 참여 | P2 | 중상 | X |
| AI 회고 | 보조 가치 | P2 | 상 | X |
| 내보내기 | 장기 보관 | P2 | 상 | X |

---

## 10. Notification Strategy

### 10.1 Reminder Principles

1. 알림은 도움이지 압박이 아니어야 한다.
2. 하루 최대 1회 기본
3. 미기록 사용자만 대상으로 고도화하는 것은 추후
4. 문구는 죄책감보다 부드러운 초대형

### 10.2 Sample Copy

- `오늘의 한 장을 아직 남기지 않았어요`
- `딱 한 장이면 충분해요`
- `지금의 하루를 한 장으로 남겨볼까요?`
- `오늘 기록하면 12일 연속이에요`
- `오늘의 미션이 도착했어요`

---

## 11. Reward Economy

### 11.1 XP Rules

#### 추천값

1. 오늘 사진 기록: `+10 XP`
2. 메모 작성: `+3 XP`
3. 감정 태그: `+2 XP`
4. 미션 완료: `+5 XP`
5. 7일 streak milestone: `+20 XP`

### 11.2 Badge Rules

1. 첫 기록
2. 3일 연속
3. 7일 연속
4. 14일 연속
5. 30일 연속
6. 100일 연속
7. 한 달 기록률 80%
8. 메모 10회
9. 미션 10회
10. 감정 태그 10회

### 11.3 Freeze Economy

1. 시작 지급: 1개
2. 무료 월 보급: 1개
3. 7일 streak 보상: 1개
4. 최대 보유: 2개
5. 프리미엄은 최대 5개

---

## 12. Premium Strategy

### 12.1 Free Tier

1. 하루 한 장 기록
2. streak
3. 기본 미션
4. 기본 알림
5. 최근 90일 조회
6. 기본 배지

### 12.2 Premium Tier

1. 전체 기록 무제한 조회
2. 월간/연간 회고
3. 고급 통계
4. 추가 freeze
5. 내보내기
6. 백업/복원
7. 잠금 기능
8. 위젯/캘린더 테마

### 12.3 Monetization Principle

핵심 습관 루프는 무료로 유지하고, `기록 자산의 장기 가치`에서 과금한다.

---

## 13. Risk Analysis and Mitigation

| 리스크 | 설명 | 완화 전략 |
| --- | --- | --- |
| BeReal 카피앱처럼 보일 위험 | 외부에서 실시간 인증 앱으로 오해 가능 | 랜덤 알림, 2분 제한, 듀얼 카메라, 친구 피드 구조를 명확히 배제하고 모든 카피를 `archive`, `streak`, `reflection` 중심으로 설계 |
| 사용자가 3일 안에 이탈할 위험 | 초기 습관이 붙기 전에 포기 가능 | 첫 기록까지 30초 이내, 3일 내 빠른 배지, 부드러운 알림, 첫 주 미션 큐레이션, freeze 1개 기본 제공 |
| 사진 저장 공간 비용 | 이미지가 누적되면 기기 저장소 부담 | 장축 제한 압축 저장, 썸네일 분리, 저장 용량 안내, 추후 백업 상품화 |
| 사진 권한 허용률 저하 | 권한 요청 순간 이탈 가능 | 선요청 금지, 실제 액션 시점 요청, 카메라/앨범 대안 분리, 권한 없이도 앱 탐색 가능 |
| 알림 피로감 | 알림이 귀찮으면 앱 삭제 가능 | 하루 1회 기본, 시간 사용자 선택, 감정적 압박 문구 금지, 끄기 쉬운 설정 |
| streak 강박감 | 놓치면 죄책감으로 이탈 가능 | freeze 자동 적용, reset 메시지를 재시작형으로 설계, streak 외에도 calendar fill/회고 가치 강조 |
| 공개 피드 도입 시 심사 리스크 | 신고/차단/운영 체계 필요 | MVP에서 공개 피드 제외, 소규모 비공개 그룹도 P2 이후 도입 |
| UGC moderation 부담 | 공유 기능 도입 시 운영 비용 증가 | 초기 private-only, 그룹 기능 도입 전 moderation scope 축소, 이모지 반응 중심으로 시작 |
| 개인정보 처리 리스크 | 사진과 감정 데이터는 민감 | 로컬 우선 저장, 기본 private, AI 분석은 추후 명시적 동의 기반 |
| 수익화가 늦어지는 문제 | 좋은 사용성은 있어도 결제 동기가 약할 수 있음 | `회고`, `내보내기`, `백업`, `무제한 아카이브`를 프리미엄 핵심 가치로 분리 |

---

## 14. Important Decision Recommendations

### 14.1 질문별 추천 답변

| 질문 | 추천 답변 | 이유 |
| --- | --- | --- |
| 처음부터 로그인이 필요한가 | 아니다 | 첫 기록 마찰 최소화, 개인 기록 앱 성격과 일치 |
| 기록은 로컬 저장만으로 시작할 것인가 | 그렇다 | MVP 속도와 비용, 프라이버시 측면에서 유리 |
| 하루 한 장 원칙을 얼마나 엄격하게 적용할 것인가 | 대표 사진 1장 원칙은 엄격하게 유지 | 제품 정체성과 습관의 선명도 확보 |
| 과거 날짜 기록 추가를 허용할 것인가 | MVP에서는 허용하지 않는다 | streak 조작과 복잡한 예외 방지 |
| 사진 교체를 허용할 것인가 | 당일에만 허용 | 실수 수정은 보장, 과거 조작은 차단 |
| streak가 끊겼을 때 얼마나 관대하게 복구할 것인가 | 자동 freeze 1회 + 재시작 친화 UX | 이탈 방지와 규칙성 균형 |
| 미션은 매일 랜덤인가, 관심사 기반인가 | 초기 랜덤, 추후 개인화 | MVP 단순화와 품질 통제 |
| 사용자가 미션을 바꿀 수 있는가 | 하루 1회 정도 허용 | 통제감 제공, 미션 거부감 감소 |
| 친구 공유는 언제 도입할 것인가 | 개인 기록 리텐션 검증 이후 | 제품 핵심을 흔들지 않기 위함 |
| 공개 피드는 아예 배제할 것인가 | 초기에는 완전 배제 | 차별화와 운영 리스크 감소 |
| 프리미엄의 핵심 가치는 무엇인가 | 보관/회고/백업/내보내기 | 장기 기록 자산에 대한 지불 의사와 맞음 |
| 사진 원본을 서버에 저장할 것인가 | MVP에서는 저장하지 않는다 | 비용, 개인정보, 구현 부담 감소 |
| 앱 감성은 무엇인가 | 따뜻한 다이어리 감성 기반 | 사진 기록 앱의 정서와 지속성에 적합 |
| 한국 시장 먼저인가 | 한국 우선, 글로벌 확장 고려 | 실행 집중도와 브랜딩 실험에 유리 |
| 앱 이름은 한국어가 좋은가, 영어가 좋은가 | 영문 브랜드 + 한글 서브카피 | 글로벌 확장성과 로컬 이해도 동시 확보 |

---

## 15. Suggested Information Architecture

### 15.1 Tab Structure

#### MVP

1. 홈
2. 캘린더
3. 마이페이지

#### Post-MVP

1. 홈
2. 캘린더
3. 회고
4. 그룹
5. 마이페이지

### 15.2 Navigation Principles

1. 홈에서 기록 시작은 항상 1탭
2. 캘린더에서 상세는 1탭
3. 설정/배지/프리미엄은 마이페이지 허브 구조

---

## 16. UX Tone and Copy Guide

### 16.1 Desired Emotional Tone

1. 따뜻함
2. 조용함
3. 가벼움
4. 성취감
5. 부담 없음

### 16.2 Avoid

1. 죄책감 유발
2. 경쟁적 카피
3. 과시형 언어
4. 시끄러운 소셜 어조

### 16.3 Copy Examples

#### 기록 전

- `오늘은 어떤 장면을 남길까요?`
- `딱 한 장이면 충분해요`
- `지나가기 전에 오늘을 붙잡아볼까요?`

#### 기록 완료

- `오늘의 한 장이 저장됐어요`
- `작은 기록이 쌓이고 있어요`
- `내일도 한 장이면 충분해요`

#### 기록 실패 후

- `어제는 쉬어갔어요. 오늘부터 다시 시작해요`
- `기록은 완벽하지 않아도 괜찮아요`

#### freeze 사용

- `기록 보호권이 사용되어 streak가 유지됐어요`

---

## 17. Analytics Plan

### 17.1 Event List

1. `app_opened`
2. `onboarding_completed`
3. `notification_prompt_shown`
4. `notification_permission_result`
5. `record_cta_tapped`
6. `camera_selected`
7. `library_selected`
8. `photo_selected`
9. `entry_saved`
10. `entry_deleted`
11. `memo_added`
12. `mood_selected`
13. `mission_completed`
14. `freeze_used`
15. `calendar_opened`
16. `badge_unlocked`
17. `premium_paywall_viewed`
18. `premium_purchased`

### 17.2 KPI Dashboard

1. first-day entry conversion
2. D1/D3/D7 retention
3. 3일/7일 streak 도달률
4. 미션 완료율
5. 메모 작성률
6. 알림 허용률
7. 삭제율

---

## 18. Final Product Direction

이 제품의 초기 정체성은 `사진 기반 개인 습관 아카이브`다. 핵심은 하루 한 장이라는 제약을 통해 사용자의 선택을 선명하게 만들고, 듀오링고식 습관 메커니즘으로 복귀 동기를 설계하는 것이다.

초기 MVP는 다음에 집중해야 한다.

1. 첫 기록까지의 마찰을 극단적으로 줄인다.
2. streak와 calendar fill로 쌓이는 재미를 만든다.
3. 실패해도 다시 시작하기 쉽게 만든다.
4. 공개 소셜 없이도 충분한 가치를 증명한다.
5. 로컬 우선 구조로 빠르게 검증한다.

### Recommended MVP Definition

`사용자가 7일 동안 하루 한 장을 남기고, 그 과정에서 홈-기록-완료-캘린더 루프를 반복하는 개인 기록 앱`

### Recommended Launch Message

`하루 한 장, 오늘의 나를 기록하는 사진 습관 앱`

### Recommended Next Step for Development

1. `SwiftUI + SwiftData`로 local-first MVP 구축
2. `Home`, `Capture`, `EntryEditor`, `Calendar`, `Detail`, `Settings` 우선 구현
3. streak/freeze 정책을 코드 레벨에서 먼저 확정
4. 7일 리텐션 검증용 내부 테스트 진행

---

## 19. Figma Alignment Summary

### 19.1 확인된 피그마 프레임

현재 피그마 파일 `kGI26ExvDpkFCNx92MaCM4`에서 확인된 주요 프레임은 다음과 같다.

1. `Onboarding`
2. `Home / Today`
3. `Capture Photo`
4. `Create Entry`
5. `Premium Plus`
6. `Your Achievements`

이 구조는 현재 PRD에서 정의한 MVP 및 P1 범위와 전반적으로 일치한다.

### 19.2 PRD와 피그마 매핑

| PRD 화면 | 피그마 프레임 | 상태 | 비고 |
| --- | --- | --- | --- |
| 온보딩 | `Onboarding` | 매칭 | 제품 가치와 시작 CTA 중심 구조 확인 |
| 홈 | `Home / Today` | 매칭 | streak, 미션, CTA, empty state 반영됨 |
| 사진 촬영/선택 | `Capture Photo` | 매칭 | 카메라 중심 구조, 최근 사진 row 포함 |
| 기록 작성 | `Create Entry` | 매칭 | 사진 preview, 메모, mood, tags, 저장 CTA 존재 |
| 프리미엄 안내 | `Premium Plus` | 매칭 | 기능 비교 + 가격 CTA 구조 확인 |
| 배지 목록 | `Your Achievements` | 매칭 | unlocked/locked badge grid 구조 확인 |

### 19.3 현재 디자인이 잘 잡힌 부분

1. `Home / Today`가 제품 핵심인 `오늘 기록하게 만들기`에 집중되어 있다.
2. `Create Entry`가 사진, 메모, 감정 입력을 분리해 기록 경험을 명확하게 만든다.
3. `Premium Plus`와 `Your Achievements`가 추후 수익화/보상 구조와 잘 맞는다.
4. 전체 구조가 공개 피드형 SNS보다 `개인 기록 루프`에 가깝다.

### 19.4 추가 보완이 필요한 화면

현재 메타데이터 기준으로는 아래 화면이 별도 프레임으로 명확히 확인되지 않았다.

1. `캘린더`
2. `기록 상세`
3. `마이페이지`
4. `설정`
5. `알림 시간 설정`
6. `기록 완료`

이 화면들은 MVP 구현에 필요하므로 피그마에서 추가되거나, 개발 단계에서 간단 버전으로 먼저 정의해야 한다.

### 19.5 개발 관점에서의 해석

현재 피그마는 `marketing polish`보다 `핵심 사용 흐름`에 먼저 초점을 둔 구조로 보인다. 이는 MVP 방향과 맞다.

특히 다음 흐름이 거의 닫혀 있다.

1. 온보딩
2. 홈
3. 촬영
4. 기록 작성
5. 저장

즉, 첫 기록 루프 구현에는 충분한 디자인 출발점이 있다.

### 19.6 구현 우선순위 제안

#### 1차 구현

1. `Home / Today`
2. `Capture Photo`
3. `Create Entry`
4. `Onboarding`

#### 2차 구현

1. `Calendar`
2. `Entry Detail`
3. `Completion`
4. `Settings`

#### 3차 구현

1. `Your Achievements`
2. `Premium Plus`
3. `Widget`

### 19.7 SwiftUI 화면 분해 기준

#### Home / Today

- `HomeView`
- `StreakCardView`
- `MissionCardView`
- `EmptyStateCardView`
- `PrimaryRecordButton`

#### Capture Photo

- `CaptureChoiceView`
- `CameraView`
- `RecentPhotosStrip`
- `ShutterControlBar`

#### Create Entry

- `EntryEditorView`
- `PhotoPreviewCard`
- `MemoInputCard`
- `MoodSelectorCard`
- `TagButtonCard`
- `SaveEntryButton`

#### Premium Plus

- `PremiumView`
- `PremiumHeroSection`
- `PremiumFeatureGrid`
- `PricingToggle`
- `PurchaseCTASection`

#### Your Achievements

- `BadgeListView`
- `BadgeGridView`
- `BadgeCardView`

### 19.8 디자인 시스템 관찰 요약

피그마 메타데이터 기준으로 다음 성향이 확인된다.

1. 카드 중심 레이아웃
2. 큰 radius와 부드러운 surface
3. 중앙 정렬 hero 영역 활용
4. icon + text 조합이 많음
5. 홈은 `미션 -> 빈 상태 -> 메인 CTA` 순으로 설계됨

이 방향은 `따뜻하고 조용한 습관 앱` 톤과 잘 맞는다.

### 19.9 바로 개발 가능한 범위 판단

현재 피그마 기준으로는 다음 범위까지 바로 개발 착수가 가능하다.

1. 온보딩
2. 홈
3. 촬영 진입
4. 기록 작성
5. 저장 CTA 구조
6. 기본 배지/프리미엄 화면 shell

반대로 아래 항목은 추가 결정이 필요하다.

1. 캘린더 셀 구조
2. 기록 완료 애니메이션 방식
3. 설정 정보 구조
4. 알림 시간 설정 UI
5. 기록 상세 수정 정책 UI

### 19.10 추천 다음 액션

1. 피그마에 `Calendar`, `Entry Detail`, `Settings`, `Completion` 프레임 추가
2. 홈과 기록 작성 화면을 기준으로 `SwiftUI MVP 화면 트리` 확정
3. 색상, 타이포, spacing token을 별도 정리
4. `streak`, `freeze`, `mission`, `entry save` 상태를 화면별로 연결
