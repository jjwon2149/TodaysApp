# Git Workflow

## 목적

이 문서는 이 프로젝트에서 사용할 Git 작업 규칙을 고정하기 위한 문서입니다.  
목표는 `작업 단위를 작게 유지하고`, `확인 가능한 상태로 남기고`, `언제든 되돌릴 수 있는 히스토리`를 만드는 것입니다.

---

## 1. 기본 원칙

1. 한 커밋은 하나의 의도를 가져야 합니다.
2. 커밋은 되돌리기 쉬워야 합니다.
3. 동작 변경과 문서 변경은 가능하면 분리합니다.
4. 확인하지 않은 코드는 커밋하지 않습니다.
5. 큰 작업도 작은 완료 단위로 나누어 커밋합니다.

---

## 2. 작업 단위 규칙

### 한 커밋으로 묶는 좋은 예

1. `홈 화면 empty state 구현`
2. `사진 저장 로직 추가`
3. `streak 계산 버그 수정`
4. `캘린더 월 이동 성능 개선`
5. `온보딩 카피 정리`

### 한 커밋으로 묶으면 안 되는 예

1. 홈 화면 수정 + 카메라 로직 수정 + 프리미엄 화면 수정
2. 문서 수정 + 기능 추가 + 리팩터링을 한 번에 섞는 것
3. 원인 다른 버그 2개를 묶어서 커밋하는 것

---

## 3. 앞으로의 기본 작업 흐름

각 작업은 아래 순서로 진행합니다.

1. 작업 목표를 한 문장으로 정의합니다.
2. 관련 파일만 수정합니다.
3. 변경 범위를 다시 확인합니다.
4. 가능한 검증을 수행합니다.
5. `git diff --staged` 기준으로 커밋 내용을 마지막 확인합니다.
6. 하나의 의도로 설명 가능한 상태일 때 커밋합니다.

---

## 4. 커밋 전 확인 규칙

제가 앞으로 각 작업마다 기본적으로 확인할 항목은 아래와 같습니다.

### 공통 확인

1. 변경 파일이 이번 작업 범위를 벗어나지 않았는지 확인
2. 임시 코드, 디버그 출력, 사용하지 않는 파일이 남지 않았는지 확인
3. 문구/정책 변경이면 관련 문서도 같이 반영됐는지 확인

### SwiftUI / iOS 작업 확인

1. 빌드가 가능한지 확인
2. 주요 화면 진입이 깨지지 않는지 확인
3. 상태 변경 전/후가 의도대로 보이는지 확인

### 로직 작업 확인

1. 기존 흐름을 깨지 않았는지 확인
2. 예외 케이스를 최소 1회 이상 점검
3. streak, 날짜, 삭제, 권한 처리처럼 상태가 꼬이기 쉬운 부분은 별도 재확인

### 문서 작업 확인

1. 문서 목적이 분명한지 확인
2. 실제 구현에 바로 쓸 수 있는 수준인지 확인
3. 기존 문서와 충돌하지 않는지 확인

---

## 5. 커밋 메시지 규칙

기본 형식은 아래를 사용합니다.

```text
type(scope): summary
```

예시:

```text
feat(home): add today mission card
fix(streak): recalculate after entry deletion
docs(plan): add mvp execution checklist
refactor(storage): split image save and thumbnail generation
chore(repo): add git workflow and gitignore
```

### type 규칙

1. `feat`: 사용자 기능 추가
2. `fix`: 버그 수정
3. `docs`: 문서 변경
4. `refactor`: 동작 유지 리팩터링
5. `chore`: 설정, 환경, 유지보수성 작업
6. `design`: UI 구조나 스타일 중심 변경
7. `test`: 테스트 추가/수정

### scope 규칙

scope는 너무 넓지 않게 작성합니다.

좋은 예:

1. `home`
2. `capture`
3. `entry-editor`
4. `calendar`
5. `streak`
6. `settings`
7. `repo`
8. `plan`

피해야 할 예:

1. `app`
2. `all`
3. `misc`
4. `stuff`

---

## 6. 커밋 빈도 규칙

앞으로는 아래 기준으로 커밋합니다.

1. 화면 하나의 의미 있는 상태가 끝났을 때 커밋합니다.
2. 로직 하나가 독립적으로 완료됐을 때 커밋합니다.
3. 문서 하나가 실제 기준 문서로 쓸 수 있을 정도가 되면 커밋합니다.
4. 큰 작업 중간이라도 되돌릴 가치가 있으면 중간 커밋합니다.

### 기본 단위

`30분~2시간 내 설명 가능한 작업 단위 1개 = 커밋 1개`

---

## 7. 제가 앞으로 따를 실전 규칙

앞으로 제가 작업할 때는 기본적으로 아래처럼 진행하겠습니다.

1. 작업 시작 전에 이번 커밋 목표를 짧게 설명합니다.
2. 작업 후 변경 파일과 영향 범위를 확인합니다.
3. 가능한 검증을 수행합니다.
4. 커밋 메시지를 작업 의도 기준으로 작성합니다.
5. 서로 다른 목적의 변경은 분리 커밋합니다.

---

## 8. 이 프로젝트에 맞는 추천 커밋 단위

### 좋은 커밋 예시

1. `chore(repo): add git workflow and xcode gitignore`
2. `docs(prd): add figma alignment summary`
3. `feat(onboarding): add first-run flow and completion state`
4. `feat(home): show streak and today entry state`
5. `feat(capture): connect camera and photo picker flow`
6. `feat(entry-editor): save daily entry with memo and mood`
7. `feat(calendar): render monthly entry grid`
8. `fix(streak): handle missed day with auto freeze`

---

## 9. 하지 않을 것

1. 검증 없이 한 번에 큰 덩어리 커밋
2. unrelated 변경을 한 커밋에 섞기
3. 사용자가 만든 변경을 임의로 되돌리기
4. 커밋 메시지를 모호하게 쓰기

---

## 10. 현재 합의로 사용할 기본 규칙

현재부터는 아래 규칙을 기본값으로 사용합니다.

1. 저장소는 `main` 브랜치로 시작합니다.
2. 초기 단계에서는 작업 브랜치 없이 진행해도 됩니다.
3. 다만 기능 규모가 커지면 `feature/...`, `fix/...`, `docs/...` 브랜치를 도입합니다.
4. 제가 작업할 때는 가능한 한 `작업 완료 -> 확인 -> 커밋` 흐름으로 관리합니다.
5. 커밋 메시지는 `type(scope): summary` 형식을 유지합니다.

---

## 11. 첫 커밋 권장 기준

첫 커밋은 아래 구성을 권장합니다.

1. `.gitignore`
2. 기획 문서들
3. Git 작업 규칙 문서
4. 현재 생성된 iOS 프로젝트 골격

권장 메시지:

```text
chore(repo): initialize project workspace and planning docs
```
