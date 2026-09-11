// 이 파일은 자동 생성된다. 직접 고치지 말 것.
//
//     python tools/generate_release_history.py
//
// 원본은 CHANGELOG.md 다. 내용을 고치려면 그쪽을 고치고 다시 생성한다.

import Foundation

public extension ReleaseHistory {
    /// 최신 버전이 앞에 온다.
    static let all: [Release] = [
        Release(
            version: "1.8.2",
            date: "2026-09-11",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "변경",
                    items: [
                        "하트 동기화와 랭킹을 켰다. v1.5 에 만들어 두고 v1.5.1 부터 꺼 두었던 기능이다. 개인(무료) 개발자 팀은 iCloud capability 를 쓸 수 없어 entitlements 에 선언만 있어도 빌드가 막혔는데, 유료 Apple Developer Program 을 확보해 그 제약이 사라졌다. 이제 하트 아래 숫자가 모든 사용자의 합계이고, 챌린지 랭킹도 실제 순위를 낸다.",
                        "컨테이너 식별자 iCloud.com.quoteday.app 를 세 곳에 함께 넣었다 — 생성기 상수, project.yml, entitlements. 한 곳만 고치면 실기기에서만 조용히 동기화가 안 되므로 check_project.py 가 셋을 대조한다.",
                        "포크해서 쓰는 사람을 위해 끄는 방법을 README 에 남겼다. 무료 팀으로 이 저장소를 빌드하려면 컨테이너 값을 비우고 entitlements 의 iCloud 키도 함께 지워야 한다. 둘 중 하나만 하면 검사에서 걸린다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.8.1",
            date: "2026-09-09",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "변경",
                    items: [
                        "카드에서 QuoteDay 표시를 끄는 선택지를 없앴다. 카드가 어디까지 퍼지든 어디서 나온 것인지는 남아 있어야 한다. Quote Plus 의 \"워터마크 없는 공유\" 항목도 함께 지웠다 — 없는 기능을 팔 수는 없다.",
                        "인물 이름을 영문으로 크게, 한국어 표기를 그 아래 작게 보여 준다. 명언을 눌러 들어가는 상세 화면과 인물 페이지 둘 다 같은 모양이다. 두 줄은 한 덩어리라 바짝 붙였다 — 사이가 벌어지면 서로 다른 정보처럼 보인다.",
                        "공유 카드에는 영문 이름만 쓴다. 카드는 앱 밖으로 나가는 물건이라, 한국어를 읽지 않는 사람에게도 누구의 말인지 전해지는 편이 낫다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.8",
            date: "2026-09-09",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "변경 이력 화면. 설정 > 앱 정보에서 열면 1.0 부터 지금까지의 릴리스를 최신순으로 보여 준다. 지금 쓰는 버전에는 \"사용 중\" 표시가 붙고, 각 항목에서 깃허브 릴리스로 이어진다.",
                        "앱 정보에 깃허브 태그 줄. 버전 아래에 v1.8 처럼 태그를 그대로 보여 준다. 이 값은 번들의 CFBundleShortVersionString 에서 만들고, 릴리스 워크플로도 같은 값으로 태그를 달기 때문에 깃허브와 어긋날 수가 없다.",
                    ]
                ),
                ReleaseSection(
                    title: "고침",
                    items: [
                        "앱이 보여 주던 버전이 계속 1.0 이었다. Info.plist 에 1.0 이 박혀 있어 project.yml 의 MARKETING_VERSION 을 아무리 올려도 앱 정보에는 그 값이 나가지 않았다. v1.1 부터 v1.7.1 까지 전부 그랬다 — 깃허브 태그는 올라갔는데 앱은 \"1.0 (1)\" 이라고 말하고 있었다. 이제 $(MARKETING_VERSION) 과 $(CURRENT_PROJECT_VERSION) 을 받는다. 앱과 위젯 둘 다 고쳤다. 이번에 넣은 테스트가 이 문제를 잡았다.",
                        "check_project.py 가 두 Info.plist 의 버전 키가 빌드 설정을 받는지 확인한다. 값을 다시 박아 넣으면 실패한다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "버전의 출처를 하나로 묶었다. 지금까지는 앱 화면·CHANGELOG·깃허브 태그가 각자 따로였다. 이제 tools/generate_release_history.py 가 이 파일을 읽어 Swift 파일을 만들고, tools/check_project.py 가 셋(이 파일의 최신 항목 · MARKETING_VERSION · 생성된 파일)이 같은지 확인한다. 하나라도 어긋나면 CI 가 실패한다.",
                        "변경 이력 화면에는 최상위 항목만 싣는다. 한 번에 훑는 곳이라 근거까지 넣으면 아무도 끝까지 읽지 않는다. 들여쓴 하위 항목과 코드 블록은 빼고, 자세한 내용은 깃허브 릴리스 링크로 잇는다. 이 파일에 항목을 쓸 때는 첫 단락만으로 뜻이 통하게 쓴다.",
                        "테스트가 \"지금 빌드가 변경 이력의 최신 항목인지\"를 확인한다. 버전만 올리고 CHANGELOG 를 잊으면 테스트에서 걸린다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.7.1",
            date: "2026-09-09",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "고침",
                    items: [
                        "오늘의 명언의 인물 이름이 영어로 나오던 문제. 1.7 에서 문장은 한국어로 옮겼는데 이름은 그대로였다.",
                        "이름 대조 규칙. 구두점을 지우지 않고 공백으로 바꾼다. 지우기만 하면 C.S. Lewis 가 cs lewis 가 되어 앱에 든 C. S. Lewis 와 어긋난다. 발음 구별 기호도 벗겨서 Saint-Exupery 와 Saint-Exupéry 를 같게 본다. 철자가 아예 다른 별칭(Laozi, Gautama Buddha, Teddy Roosevelt 등)은 별칭 표로 잇는다.",
                    ]
                ),
                ReleaseSection(
                    title: "추가",
                    items: [
                        "명언 130편 → 201편, 인물 87명 → 116명. 아홉 카테고리에 고르게 71편을 더했다.",
                        "챌린지의 문제 풀과 오답 보기가 그만큼 넓어진다. 같은 문제가 덜 돌아온다.",
                    ]
                ),
                ReleaseSection(
                    title: "검증",
                    items: [
                        "카테고리마다 최소 12편이 있는지, 인용된 명언이 하나도 없는 인물이 남아 있지 않은지를 테스트로 고정했다. 명언이 없는 인물은 화면에는 안 나오면서 챌린지의 오답 보기로만 등장한다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.7",
            date: "2026-09-09",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "오늘의 명언 한국어 번역. ZenQuotes 는 영어만 주는데, 한국어 앱에서 영어 한 문장이 튀는 것을 없애려고 애플의 온디바이스 번역으로 옮긴다.",
                    ]
                ),
                ReleaseSection(
                    title: "고침",
                    items: [
                        "오늘의 명언이 갱신되어도 홈 화면이 그대로 남아 있던 문제. RemoteQuoteStore 는 UserDefaults 를 직접 읽는 값 타입이라 관찰되지 않는다. 갱신 신호를 하나 두어 새 명언과 번역 결과가 바로 반영되게 했다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.6",
            date: "2026-09-08",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "챌린지 랭킹 — 챌린지 탭 오른쪽 위 아이콘에서 연다. 내가 전체에서 상위 몇 %인지 보여 준다.",
                        "결과 화면과 단계 목록에 점수를 표시한다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "모서리를 더 둥글게 했다. 카드 16→22, 큰 카드 20→28, 컨트롤 12→16, 칩 8→12. v1.2 에서 줄였던 것은 그라데이션·광택과 함께여서 물렁해 보였기 때문이지 반경 자체가 문제는 아니었다. 면이 단색이 된 지금은 더 둥글어도 형태가 흐려지지 않는다.",
                        "\"카드 만들기\"를 위로 올렸다. 명언 탭에서는 카드 위 왼쪽에, 명언 상세에서는 좌측 상단 툴바에 둔다. 아래에 있으면 카드에 가려 있는 줄 모르고 지나치기 쉬웠다.",
                        "HeartSyncAvailability 를 CloudSyncAvailability 로 바꿨다. 하트와 랭킹이 같은 CloudKit 상태를 쓰므로 이름이 하트 전용이면 거짓말이 된다. 문구도 무엇이 집계되는지를 부르는 쪽이 붙이도록 바꿨다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.5.1",
            date: "2026-09-08",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "고침",
                    items: [
                        "하트 동기화를 기본으로 꺼 둔다. v1.5 는 entitlements 에 iCloud 를 선언한 채로 나갔는데, 개인(무료) 개발자 팀은 그 선언만으로 프로비저닝 프로파일이 만들어지지 않아 빌드가 통째로 막힌다.",
                        "check_project.py 가 그 상태를 잡는다 — 동기화가 꺼져 있는데 entitlements 에 iCloud 선언이 남아 있으면 실패시킨다. 반대 방향(식별자를 넣었는데 entitlements 에 없음)도 그대로 본다.",
                        "정적 검사에 안내 단계를 더했다. 동기화가 꺼진 것은 정상 기본값이라 경고가 아니다 — 매번 뜨는 경고는 사람이 경고를 무시하게 만든다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.5",
            date: "2026-09-07",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "하트 — 명언마다 하트를 누를 수 있고, 하트 아래 숫자는 모든 사용자의 합계다. QuoteDay 에 붙은 첫 쓰기 가능한 백엔드이고 CloudKit 공개 데이터베이스를 쓴다. 서버를 직접 운영하지 않고, 사용자는 회원가입 없이 iCloud 계정으로 자동 구분된다.",
                        "공유 카드에 사진·감상·배경색 — 명언 탭의 각 명언 아래에서 바로 열린다.",
                        "check_project.py 가 CloudKit 컨테이너 식별자를 빌드 설정 · Info.plist · entitlements 세 곳에서 대조한다. 한 곳만 고치면 실기기에서만 조용히 동기화가 안 되거나, 더 나쁘게는 앱이 시작하자마자 죽는다. 사진 추가 권한 문구가 있는지도 함께 본다.",
                        "컨테이너 식별자를 빌드 설정 QD_CLOUDKIT_CONTAINER 로 두고 Info.plist 가 치환해 받는다. 빈 값으로 덮어쓰면 CKContainer 를 아예 만들지 않는다. 엔타이틀먼트 없이 컨테이너를 만들면 프로세스가 죽는데, 그 엔타이틀먼트는 서명할 때 붙으므로 서명을 끈 빌드에는 없다. CI 가 그 경로로 검증하고, CloudKit 을 켤 수 없는 계정도 같은 스위치로 끈다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "명언 탭의 각 명언 아래에 하트와 \"카드 만들기\" 줄이 붙었다. 카드 안이 아니라 밖에 둔 이유는 카드 전체가 이미 버튼이라, 그 안에 버튼을 겹치면 탭이 어디로 갈지 알 수 없어서다.",
                        "공유 카드 시트 제목을 \"카드로 공유\" 에서 \"카드 만들기\" 로 바꿨다. 이제 저장도 한다.",
                    ]
                ),
                ReleaseSection(
                    title: "그 밖에",
                    items: [
                        "영어 README(README.en.md). 한국어판과 같은 내용이고, 두 문서 맨 위에서 서로 오갈 수 있다. 앱의 UI 문자열과 코드 주석은 그대로 한국어다 — 번역한 것은 저장소 설명뿐이다.",
                        "README 의 \"비하인드 스토리를 3편만 넣은 이유\" 제목이 본문(41편)과 어긋나 있었다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.4",
            date: "2026-09-06",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "챌린지 탭 — 명언 퀴즈. 유형 2가지(빈칸 채우기 / 누가 말했을까) × 난이도 5단계, 한 판 10문제, 단계별 최고 점수·최고 연속·누적 정답률을 기기에 기록한다.",
                        "비하인드 스토리 3편 → 41편. 특정 책·편지·연설·방송으로 자리를 짚을 수 있는 것만 넣었다 (베토벤이 1801년 베겔러에게 보낸 편지, 『명상록』 5권 1장, 1997년 나이키 「Failure」 광고 등).",
                        "DisputedAttribution — 널리 인용되지만 1차 출처를 찾지 못한 명언 30편의 목록. \"누가 말했을까\"에서만 제외한다. 정답을 하나로 못 박는 형식이라, 그대로 내면 앱이 확인되지 않은 귀속을 정답이라고 가르치게 되기 때문이다. 명언 자체는 지우지 않는다 — 문장이 나쁜 것이 아니라 꼬리표가 불확실할 뿐이고, 인물을 묻지 않는 문제에는 그대로 쓸 수 있다.",
                        "BlankMaker — 한국어 문장에서 어절을 빈칸으로 바꾼다. 형태소 대신 어절을 통째로 뚫는다. \"인생은\"에서 \"인생\"만 뽑으면 남은 조사가 답을 절반쯤 알려 주기 때문이다.",
                    ]
                ),
                ReleaseSection(
                    title: "고침",
                    items: [
                        "미셸 오바마 명언의 원문(originalText)이 한국어 번역과 다른 문장이었다. 둘 다 『비커밍』 에필로그에 있지만 서로 대응하지 않는 대목이라, 번역에 맞는 원문으로 바꿨다.",
                    ]
                ),
                ReleaseSection(
                    title: "참고",
                    items: [
                        "처칠의 \"성공은 최종적인 것이 아니다\"에는 배경을 달지 않았다. 처칠이 말했다는 기록이 없고, 가장 이른 형태는 1938년 버드와이저 신문 광고 문안으로 확인된다. 마리 퀴리의 \"두려워할 것은 없다\"도 1952년 이전 출처를 찾지 못해 같은 이유로 비워 두었다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.3",
            date: "2026-09-05",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "Quote Plus — 광고 없이 앱을 이어 가기 위한 유료 플랜. 광고 SDK 는 넣지 않았다.",
                        "필사 노트 — 명언마다 생각을 적어 두고 모아 볼 수 있다. 쓰기·읽기는 무료다.",
                        "이미지 카드 공유 — 명언을 1080×1080 카드로 만들어 공유한다. 무료 테마 2종 포함.",
                        "개발자 후원 — 토스 계좌(눌러서 복사)와 외부 링크 두 가지. 어떤 기능도 열지 않는다.",
                        "Author 에 era(시대적 배경)와 notableWorks(대표 저서) 필드를 더했다. 둘 다 선택 항목이다.",
                        "BehindStory / BehindStoryLibrary — 명언별 배경. 출처를 확인한 3편만 넣었다.",
                        "CI — PR 마다 정적 검증(Linux) 후 macOS 러너에서 앱·위젯을 빌드하고 테스트를 돌린다. 프로젝트 파일이 생성기 출력과 어긋나면 실패시켜, 파일을 추가하고 재생성을 잊는 실수를 막는다.",
                        "릴리스 자동화 — main 에 머지되면 project.yml 의 버전을 읽어 태그를 달고 CHANGELOG 의 해당 절로 GitHub Release 를 만든다. 버전을 올리지 않은 머지는 조용히 넘어간다.",
                    ]
                ),
                ReleaseSection(
                    title: "고침",
                    items: [
                        "App Group 이 프로비저닝되지 않은 환경에서 공유 저장소를 만지면 앱이 죽던 문제. UserDefaults(suiteName:) 는 엔타이틀먼트가 없어도 객체를 돌려주고 읽고 쓸 때 죽는데, 그 nil 여부로 판단하고 있었다. 이제 App Group 컨테이너 경로로 확인한다. README 가 \"App Group 없어도 동작한다\"고 적어 둔 대로 실제로 동작하게 됐다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "명언 상세 화면을 무료·Plus 구획으로 다시 나눴다. 무료는 본문·인물 이름·초상·노트·카드 공유, Plus 는 인물 프로필·비하인드 스토리·이어서 보기.",
                        "잠긴 구획은 내용을 흐리게 깔고 그 아래에 안내를 붙인다(PlusLockedPreview). 흐린 내용은 눌리지 않고 VoiceOver 도 읽지 않으며, 투명도 줄이기를 켠 사용자에게는 단색 면으로 대체된다.",
                        "비하인드 스토리가 없는 명언에는 \"아직 준비 중입니다\"를 보여 준다. 잠금이 아니라 준비 상태다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.2",
            date: "2026-09-04",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "고침",
                    items: [
                        "프로젝트 생성기가 project.yml 의 버전을 무시하고 1.0 을 박아 넣던 문제를 고쳤다. 이 때문에 v1.1 이 MARKETING_VERSION 1.0 으로 나갔다. 이제 project.yml 이 유일한 출처이고 생성기는 그 값을 읽기만 한다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "UI 를 평면화했다. 파스텔 팔레트와 색이 나르는 의미는 그대로 두고, 표면 표현만 단순하게 바꿨다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.1",
            date: "2026-09-01",
            summary: nil,
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "일정에 반복을 설정할 수 있다. 매일 / 주중 매일(월–금) / 매주 / 2주마다 / 매월 / 매년 중에서 고르고, 반복 종료일을 정하거나 종료 없이 둘 수 있다.",
                    ]
                ),
                ReleaseSection(
                    title: "변경",
                    items: [
                        "홈·캘린더·위젯 스냅샷·캘린더 날짜 점 표시가 모두 일정이 아니라 회차 단위로 동작한다.",
                    ]
                ),
            ]
        ),
        Release(
            version: "1.0",
            date: "2026-08-15",
            summary: "첫 버전.",
            sections: [
                ReleaseSection(
                    title: "추가",
                    items: [
                        "오늘의 명언, 일정, 명언 검색, 설정의 4개 탭. 전체 UI 는 클레이모피즘으로 통일.",
                        "일정을 등록하면 시작 시각에 카테고리에 어울리는 명언을 알림으로 보낸다. 알림을 누르면 명언 상세와 인물 소개로 이어진다.",
                        "명언 130편, 인물 87명 을 번들에 내장해 네트워크 없이도 모든 기능이 동작한다.",
                        "홈 화면 위젯 Small / Medium / Large.",
                        "잠금화면·대기 화면(accessory) 위젯 — Inline / Circular / Rectangular.",
                        "위젯을 길게 눌러 카테고리를 고를 수 있다(AppIntents).",
                        "iOS 캘린더 연동(선택) — 기기 일정 읽기 + 앱 일정 내보내기.",
                        "매일의 명언 알림 — 반복 트리거로는 본문을 바꿀 수 없어 14일치를 하루 단위로 미리 예약한다.",
                        "오늘의 명언을 ZenQuotes /today 에서 갱신(설정에서 끌 수 있다). 오늘의 명언에만 적용되고, 일정 알림과 위젯 카테고리 선택은 내장 데이터를 쓴다.",
                        "앱 아이콘.",
                    ]
                ),
            ]
        ),
    ]
}
