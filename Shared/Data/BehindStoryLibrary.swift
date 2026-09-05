import Foundation

/// 명언별 비하인드 스토리 원본 데이터.
///
/// **여기 있는 항목은 출처를 확인한 것만 넣는다.**
/// 배경 설명은 "그럴듯하게" 지어내기 쉬운 종류의 글이라, 확인되지 않은 일화를
/// 넣으면 앱이 조용히 틀린 역사를 가르치게 된다. 그래서 규칙을 둔다.
///
/// 1. `source` 를 비워 두지 않는다. 연설이면 날짜와 장소, 글이면 제목과 연도를 적는다.
/// 2. 귀속이 논쟁 중인 명언(예: 링컨의 "도끼를 갈겠다")은 배경을 달지 않는다.
/// 3. 확인하지 못했으면 그냥 비워 둔다 — UI 는 배경이 없는 명언을 정상으로 다룬다.
///
/// 지금은 검증된 3편만 들어 있다. 나머지는 출처를 확인하는 대로 채워 넣으면 되고,
/// 그때 코드는 손댈 필요가 없다.
public enum BehindStoryLibrary {
    public static let all: [BehindStory] = [
        BehindStory(
            quoteSlug: "jobs-love-what-you-do",
            occasion: "2005년 6월 12일, 스탠퍼드대 졸업식 연설",
            context: """
            스티브 잡스는 자신이 세운 애플에서 1985년에 쫓겨났다. \
            이 연설에서 그는 그 해고를 "인생에서 가장 좋은 일"이었다고 회고하며, \
            성공의 무게를 내려놓자 다시 가벼워져 가장 창의적인 시기로 들어갈 수 있었다고 말했다. \
            이 문장은 그 대목 뒤에 이어진다 — 아직 사랑할 일을 찾지 못했다면 안주하지 말고 계속 찾으라는 당부와 함께.
            """,
            takeaway: "일을 사랑하라는 말이 낭만이 아니라, 해고당한 사람이 되짚어 본 회복의 조건으로 나왔다는 점이 이 문장의 무게다.",
            source: "Stanford University 졸업식 연설문 전문 (2005-06-12)"
        ),
        BehindStory(
            quoteSlug: "mandela-education-weapon",
            occasion: "1990년 7월 23일, 미국 보스턴 매디슨파크 고등학교",
            context: """
            넬슨 만델라가 27년의 수감 생활에서 풀려난 지 다섯 달 만에 미국을 찾았을 때 한 연설이다. \
            아파르트헤이트 아래 남아공의 흑인 학생들은 백인 학생의 몇 분의 일에 불과한 교육 예산을 받았고, \
            만델라 자신도 감옥 안에서 통신 과정으로 공부를 이어 갔다. \
            무기라는 단어는 은유가 아니라, 총 대신 무엇으로 싸울 것인가에 대한 그의 답에 가깝다.
            """,
            takeaway: "교육을 개인의 성취가 아니라 구조를 바꾸는 수단으로 본 문장이다.",
            source: "Nelson Mandela Foundation 연설 기록 (1990-07-23)"
        ),
        BehindStory(
            quoteSlug: "einstein-education-what-remains",
            occasion: "1936년, 미국 고등교육 300주년 기념 강연 「On Education」",
            context: """
            아인슈타인은 이 말을 자기 생각으로 내놓지 않았다. \
            강연에서 그는 "어떤 재치 있는 사람이 말하기를"이라며 이 문장을 인용한 뒤, \
            그 농담이 사실은 정확하다고 덧붙였다. \
            시험을 위해 채워 넣은 지식은 빠져나가고 사고하는 방식만 남는다는 것이 \
            그가 학교 교육에 대해 반복해서 말한 요지였다.
            """,
            takeaway: "인용을 인용으로 밝힌 원문을 보면, 이 문장은 권위 있는 선언이 아니라 동의의 표시였다.",
            source: "Albert Einstein, 「On Education」, *Out of My Later Years* 수록 (1936)"
        )
    ]

    /// slug → 스토리 색인. 명언 상세를 열 때마다 배열을 훑지 않기 위해 미리 만든다.
    private static let index: [String: BehindStory] = Dictionary(
        all.map { ($0.quoteSlug, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// 해당 명언의 배경. 없으면 nil — 정상적인 경우다.
    public static func story(for quoteSlug: String) -> BehindStory? {
        index[quoteSlug]
    }

    public static var count: Int { all.count }
}
