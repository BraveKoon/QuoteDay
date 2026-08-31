# QuoteDay

매일의 명언과 일정을 연결하는 iOS 앱. 일정을 등록하면 그 시간에 **카테고리에 어울리는 명언**이
알림으로 오고, 알림이나 홈 화면 위젯을 누르면 명언 상세와 인물 소개로 바로 들어간다.
일정에는 **반복**(매일 / 주중 / 매주 / 격주 / 매월 / 매년)을 걸 수 있다.
전체 UI 는 Claymorphism(클레이모피즘)으로 통일했다.

- Swift 5 / SwiftUI / SwiftData / WidgetKit / AppIntents / UserNotifications / EventKit
- 최소 지원 버전: **iOS 17.0**
- 명언·인물 데이터가 번들에 내장되어 **네트워크 없이도 모든 기능이 동작**
- 오늘의 명언은 선택적으로 [ZenQuotes](https://zenquotes.io/) `/today` 에서 갱신 (끄면 완전 오프라인)

---

## 1. 열고 실행하기

```bash
open QuoteDay.xcodeproj
```

Xcode 15 이상에서 열고 다음 두 가지만 설정하면 바로 실행된다.

1. **서명 팀 선택** — `QuoteDay`, `QuoteDayWidgetExtension` 두 타겟의
   Signing & Capabilities 에서 Team 을 고른다.
2. **App Group** — 두 타겟 모두 `group.com.quoteday.app` 이 이미 entitlements 에 들어 있다.
   개인 계정에서는 이 식별자를 쓸 수 없을 수 있으므로, 그럴 때는 자신의 것으로 바꾸고
   `Shared/Services/SharedStore.swift` 의 `AppGroup.identifier` 도 같이 바꾼다.
   (App Group 이 없어도 앱은 동작한다. 위젯에 일정이 안 보일 뿐이다 — 아래 "안전한 실패" 참고)

프로젝트 파일을 다시 만들어야 한다면 둘 중 아무 방법이나 쓰면 된다.

```bash
python tools/generate_xcodeproj.py   # macOS/Windows 어디서나
xcodegen generate                    # brew install xcodegen 이 있다면
```

---

## 2. 화면

| 탭 | 내용 |
|---|---|
| 🏠 홈 | 오늘 날짜, 오늘의 명언(큰 카드), 다음 일정까지 남은 시간, 오늘의 일정 목록 |
| 📅 캘린더 | 월간 격자(일정 있는 날은 카테고리 색 점), 선택한 날짜의 일정, iOS 캘린더 일정 |
| 💬 명언 | 전체 명언 검색 + 카테고리 필터 |
| ⚙️ 설정 | 알림/매일의 명언/기본 카테고리/화면 모드/캘린더 연동/위젯 안내/앱 정보 |

명언 상세는 시트로 열리며 인물 초상·생몰년·직업·국적·생애·주요 업적과
그 인물의 다른 명언까지 이어진다.

---

## 3. 구조

```
QuoteDay/
├── Shared/              앱 + 위젯이 함께 쓰는 코드
│   ├── Models/          AppCategory, Quote, Author, DeepLink, WidgetSnapshot, StableHash
│   ├── Data/            QuoteLibrary(색인) + QuoteLibraryData(원본 130편) + AuthorLibrary(87명)
│   ├── Services/        QuoteService(선택 알고리즘), RemoteQuoteService(ZenQuotes), SharedStore
│   ├── Design/          ClayTheme(토큰) + ClayStyle(.clayCard/.clayButton/.clayBackground)
│   ├── Support/         Formatters
│   └── AppIntents/      위젯 구성 인텐트
├── App/
│   ├── Models/          ScheduleItem (SwiftData @Model) + ScheduleValidator
│   │                    RecurrenceRule(반복 규칙·회차 계산) + ScheduleOccurrence(회차)
│   ├── Services/        Persistence, ScheduleStore, NotificationService, CalendarService, AppSettings
│   ├── ViewModels/      HomeViewModel, CalendarViewModel
│   ├── Components/      QuoteCard, CategoryChip, RecurrencePicker, ScheduleRow, CalendarDayCell,
│   │                    AuthorPortrait, EmptyState
│   └── Views/           Home / Calendar / Schedule / Quote / Settings / RootTabView
├── Widget/              홈 화면(Small·Medium·Large) + 잠금화면(accessory) 위젯
├── Tests/               XCTest 98개
└── tools/               프로젝트 생성기 + 정적 검증기
```

뷰는 SwiftData 컨텍스트를 직접 만지지 않는다. 모든 쓰기는 `ScheduleStore` 를 거치며,
저장 → 알림 재예약 → 위젯 스냅샷 갱신 → (설정 시) iOS 캘린더 미러링이 한 곳에서 일어난다.

---

## 4. 핵심 동작

### 오늘의 명언은 왜 랜덤이 아닌가
앱과 위젯은 **서로 다른 프로세스**다. 랜덤을 쓰면 홈 화면 위젯과 앱이 다른 명언을 보여 준다.
그래서 `"yyyy-MM-dd"` 를 FNV-1a 로 해시해 인덱스를 만든다(`StableHash`).
Swift 의 `Hasher` 는 프로세스마다 시드가 달라 쓸 수 없다.
같은 이유로 명언의 `UUID` 도 slug 에서 결정적으로 만든다 — 재설치 후에도 알림 딥링크가 유효하다.

### 카테고리 → 명언
`QuoteService.candidatePool(for:)` 가 ① 해당 카테고리 → ② `AppCategory.related` 순서로 확장 →
③ 그래도 부족하면 전체 순으로 후보를 모은다. 후보가 6개 미만이면 같은 명언만 반복되므로
관련 카테고리를 끌어온다. 최종 선택은 `일정 ID + 시작 시각` seed 로 고정되어,
일정을 수정하기 전까지 예고된 명언이 바뀌지 않는다.

### 반복 일정
반복 회차를 행으로 복제해 저장하지 않는다. 일정 한 건에 **반복 규칙(주기 + 선택적 종료일)** 만
저장하고, 화면에 필요한 구간의 회차를 `RecurrenceRule.occurrenceStarts` 로 그때그때 계산한다
(`ScheduleOccurrence`). "매일 · 종료 없음" 도 저장 비용이 일정 한 건과 같고,
규칙을 고치면 지난 회차까지 한 번에 정리된다.

- 주기: 매일 / 주중 매일(월–금) / 매주 / 2주마다 / 매월 / 매년.
- 계산은 **항상 첫 회차 기준**이다. 31일에 시작한 매월 반복은 2월에 28일로 당겨지지만
  3월에는 다시 31일로 돌아온다(직전 회차 기준으로 계산하면 날짜가 앞으로 밀려 굳는다).
- 창(window)이 아무리 먼 미래여도 첫 후보 위치를 계산으로 건너뛰므로,
  몇 년 전에 시작한 반복 일정도 순회 비용이 창 크기에만 비례한다.
- 회차마다 seed 가 달라 **회차별로 다른 명언**이 배정된다. 편집 화면에서 명언을 고정하면
  모든 회차가 그 명언을 쓴다.
- 수정·삭제는 회차 하나가 아니라 **반복 전체**에 적용된다(회차별 예외는 두지 않았다).
- iOS 캘린더로 내보낼 때는 `EKRecurrenceRule` 로 옮겨 기기 캘린더에서도 반복으로 보인다.

### 오늘의 명언 소스 (ZenQuotes)
설정에서 켜면(기본값) 오늘의 명언을 ZenQuotes `/today` 에서 받아온다. 다만 **적용 범위를 제한했다.**

- **오늘의 명언에만** 적용된다. 일정 카테고리별 명언 알림은 계속 내장 데이터를 쓴다.
  API 응답에는 카테고리가 없어 "학업 일정 → 학업 명언" 매칭을 만들 수 없고,
  14일치를 미리 예약하는 알림은 미래 날짜의 API 응답을 알 수 없기 때문이다.
- 위젯에서 특정 카테고리를 고른 경우에도 내장 명언을 쓴다(같은 이유).
- 앱과 위젯이 각각 App Group 캐시를 갱신한다. 하루 한 번만 받아오고,
  실패하면 15분 안에는 재시도하지 않는다(무료 등급 30초 5회 제한).
- 저자 이름이 내장 인물과 일치하면 생몰년·소개·업적을 그대로 붙여 준다.
  일치하지 않으면 이름만 있는 최소 정보로 표시한다.
- 원격 명언의 UUID 는 문장 내용에서 유도하므로 날짜가 지나도 딥링크가 유효하다.
- 무료 등급 이용 조건에 따라 명언 상세와 설정 화면에 출처를 표기한다.

### 알림
- 권한은 앱 시작 시가 아니라 **사용자가 명언 알림을 켜는 순간** 요청한다.
- 일정 알림: 시작 시각에 `UNCalendarNotificationTrigger` 로 1회 예약.
- 반복 일정: 회차마다 다른 명언을 담아야 하므로 반복 트리거를 쓰지 않고
  **60일 안의 회차를 일정당 최대 8개**까지 미리 예약한다. iOS 의 앱당 64개 제한이 있어
  전체 일정 알림은 가까운 순서로 40개까지만 채우고, 앱을 열 때마다 다시 채운다.
- 매일의 명언: 반복 트리거는 본문을 바꿀 수 없으므로 **14일치를 하루 단위로 미리 예약**하고
  앱을 열 때마다 갱신한다.
- 앱을 오래 켜지 않아 예약이 소진되면 `refreshOnLaunch()` 가 전부 다시 만든다.
- 알림 탭 → `userInfo` 의 `quoteday://quote/<uuid>` → `AppRouter` → 명언 상세.

### 위젯
- 홈 화면: Small(명언) / Medium(명언+인물+카테고리) / Large(명언+인물+오늘의 일정+남은 시간)
- 잠금화면·대기 화면: Inline(다음 일정 한 줄) / Circular(일정 시각) / Rectangular(명언+인물)
  accessory 패밀리는 시스템이 색을 걷어내므로 클레이 표면 대신 대비와 정보 밀도만 남겼다.
- 명언은 위젯이 **직접 계산**하고, 일정만 App Group 스냅샷에서 읽는다.
  스냅샷이 없어도 명언은 항상 나온다.
- 타임라인은 자정까지 1시간 간격 + 자정 리로드.
- 위젯을 길게 눌러 카테고리를 고를 수 있다(`SelectQuoteCategoryIntent`).
- 탭하면 `widgetURL` 로 앱의 명언 상세가 열린다.

### 안전한 실패
| 상황 | 동작 |
|---|---|
| 알림 권한 거부 | 일정은 정상 저장, 안내 문구 표시, 예약만 생략 |
| 캘린더 권한 거부 | 앱 내부 일정 그대로 사용, 해당 섹션만 빈 상태 |
| App Group 미설정 | `UserDefaults.standard` 로 내려가고 설정 화면에 경고 표시 |
| SwiftData 스토어 손상 | 로컬 → 메모리 순으로 내려감 (크래시 없음) |
| 저장된 카테고리를 모름 | `.etc` 로 강등 |
| 저장된 반복 주기를 모름 | "반복 안 함" 으로 강등 |
| 반복 필드가 없던 이전 버전 저장소 | 기본값(`none`)으로 읽혀 마이그레이션 없이 열린다 |
| 명언 slug 가 사라짐 | 카테고리에서 다시 계산 |
| 오래된 딥링크 | "명언을 찾을 수 없어요" 빈 상태 |
| 네트워크 없음 | ZenQuotes 갱신만 건너뛰고 내장 명언으로 표시. 나머지 기능은 영향 없음 |
| ZenQuotes 사용량 초과 | 안내 문구를 명언으로 저장하지 않고 거부, 내장 명언 유지 |

---

## 5. 검증

macOS 가 아닌 환경에서도 돌릴 수 있는 정적 검증을 넣어 두었다.

```bash
python tools/check_project.py
```

- `project.pbxproj` 를 직접 파싱해 구조·상호 참조·디스크 존재 여부 확인
- 모든 Swift 파일이 정확한 타겟에 들어가 있는지
- 괄호/따옴표 균형
- **타겟 경계 위반** — 위젯이 앱 전용 타입을 참조하면 실패 (모듈이 다르므로 실제 컴파일 오류가 됨)
- `@main` 이 타겟당 정확히 하나인지
- entitlements / Info.plist / App Group 식별자 일치
- 앱 아이콘이 1024x1024 이고 알파 채널이 없는지 (알파가 있으면 App Store 가 거부한다)

macOS 에서는 여기에 더해:

```bash
xcodebuild -scheme QuoteDay -destination 'platform=iOS Simulator,name=iPhone 15' build
xcodebuild -scheme QuoteDay -destination 'platform=iOS Simulator,name=iPhone 15' test
```

---

## 6. 데이터

- 명언 **130편**, 인물 **87명**. 카테고리별 최소 12편 이상(보조 카테고리 포함 시 더 많다).
- 실존 인물이 남긴 것으로 널리 확인된 문장만 사용했고, 출처가 불분명한 인터넷 문구는 배제했다.
  가능한 경우 원문(`originalText`)을 함께 담았다.
- 명언을 추가하려면 `Shared/Data/QuoteLibraryData.swift` 의 해당 카테고리 배열에 항목을 넣고,
  새 인물이면 `AuthorLibrary.all` 에 추가한다. `slug` 는 전체에서 유일해야 하며
  한 번 출시한 뒤에는 바꾸지 않는다(딥링크 기준).
- 인물 사진을 넣으려면 `Assets.xcassets` 에 이미지를 추가하고 `portraitAssetName` 을 채운다.
  없으면 이니셜 플레이스홀더가 그려진다.

## 7. 남아 있는 제한

- 인물 초상 이미지는 포함되어 있지 않다(라이선스 문제). 현재는 이니셜 플레이스홀더.
- iOS 캘린더 연동은 **읽기 + 내보내기**만 지원한다. 기기 캘린더에서 수정한 내용이
  앱 일정으로 돌아오지는 않는다.
- 반복 일정에 "이 회차만 수정/삭제" 는 없다. 회차 하나를 건너뛰려면 반복 종료일을 조정해야 한다.
- 반복 주기는 정해진 6가지뿐이다(3일마다 같은 임의 간격, "매월 둘째 화요일" 같은 규칙은 없다).
- Live Activity(동적 섬)는 아직 없다.
- 현지화 파일은 없다. UI 문자열이 한국어로 하드코딩되어 있다.
