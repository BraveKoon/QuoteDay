import Foundation

/// 명언별 비하인드 스토리 원본 데이터.
///
/// **여기 있는 항목은 출처를 확인한 것만 넣는다.**
/// 배경 설명은 "그럴듯하게" 지어내기 쉬운 종류의 글이라, 확인되지 않은 일화를
/// 넣으면 앱이 조용히 틀린 역사를 가르치게 된다. 그래서 규칙을 둔다.
///
/// 1. `source` 를 비워 두지 않는다. 연설이면 날짜와 장소, 글이면 제목과 연도를 적는다.
/// 2. 귀속이 논쟁 중인 명언은 배경을 달지 않는다. 그런 명언은
///    `DisputedAttribution.slugs` 에 모아 두었고, 챌린지의 "누가 말했을까"에서도 제외한다.
/// 3. 확인하지 못했으면 그냥 비워 둔다 — UI 는 배경이 없는 명언을 정상으로 다룬다.
///
/// 규칙 2 에 걸려 일부러 비워 둔 예: 처칠의 "성공은 최종적인 것이 아니다"는
/// 1938년 버드와이저 광고 문안이 가장 이른 형태로 확인되었고, 처칠이 말했다는
/// 기록은 없다. 마리 퀴리의 "두려워할 것은 없다"도 1952년 이전 출처를 찾지 못했다.
public enum BehindStoryLibrary {
    public static let all: [BehindStory] = [
        // MARK: - 검증 완료 (초기 3편)
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
        ),
        // MARK: - 직장

        BehindStory(
            quoteSlug: "covey-schedule-priorities",
            occasion: "1994년, 『소중한 것을 먼저 하라』",
            context: """
            스티븐 코비는 앞서 낸 『성공하는 사람들의 7가지 습관』이 \
            "시간 관리 책"으로 읽히는 것을 불편해했다. \
            그래서 다음 책의 1장을 아예 시계와 나침반의 비유로 열었다. \
            시계는 약속과 일정을, 나침반은 방향과 가치를 가리키는데 \
            둘이 어긋날 때 사람들은 대개 시계를 따른다는 것이다. \
            이 문장은 그 어긋남을 한 줄로 뒤집어 놓은 말이다.
            """,
            takeaway: "할 일 목록에 순서를 매기는 일과, 중요한 일에 시간을 먼저 떼어 두는 일은 전혀 다른 작업이다.",
            source: "Stephen R. Covey, *First Things First* (1994)"
        ),
        BehindStory(
            quoteSlug: "shakespeare-readiness-is-all",
            occasion: "1600년경, 『햄릿』 5막 2장",
            context: """
            결투를 앞둔 햄릿에게 호레이쇼가 "마음이 내키지 않으면 그만두라"고 권하는 장면이다. \
            햄릿은 참새 한 마리가 떨어지는 데에도 섭리가 있다고 답한 뒤 이 말을 덧붙인다. \
            앞선 4막까지 복수를 미루고 또 미루던 인물이, 마지막에 이르러 \
            때를 고르는 일을 그만두고 준비된 상태로 있는 쪽을 택하는 대목이다.
            """,
            takeaway: "\u{201C}준비\u{201D}가 계획을 더 세우는 일이 아니라, 무엇이 오든 받아들일 태도를 뜻한다는 점이 이 문장의 핵심이다.",
            source: "William Shakespeare, *Hamlet*, Act 5 Scene 2 (c. 1600)"
        ),

        // MARK: - 여가

        BehindStory(
            quoteSlug: "twain-laughter-weapon",
            occasion: "1916년, 유고 소설 『신비한 이방인』 10장",
            context: """
            마크 트웨인이 죽고 6년 뒤에 나온 소설이고, 말하는 이는 사탄이다. \
            원문은 훨씬 길다 — 권력도 돈도 설득도 박해도 거대한 거짓을 \
            한 세기씩 조금씩 밀어낼 뿐이지만, 웃음만은 그것을 한 번에 \
            누더기로 만들어 버린다는 문장이 앞에 놓여 있다. \
            널리 인용되는 짧은 형태는 그 대목을 줄인 것이다.
            """,
            takeaway: "웃음을 무기라고 부른 사람은 유머 작가가 아니라, 그 작가가 만들어 낸 악마였다.",
            source: "Mark Twain, *The Mysterious Stranger*, ch. 10 (1916, 사후 출간)"
        ),
        BehindStory(
            quoteSlug: "tolkien-not-all-who-wander",
            occasion: "1954년, 『반지 원정단』 중 시 「진정한 금은 반짝이지 않는다」",
            context: """
            빌보가 아라고른을 두고 쓴 시의 두 번째 행이다. \
            프로도는 브리의 여관에서 만난 이 낡은 외투 차림의 순찰자를 믿지 못했고, \
            간달프는 편지에 이 시를 적어 보내 그가 누구인지 알려 준다. \
            즉 이 구절은 방랑 자체를 예찬하는 말이 아니라, \
            겉모습으로 사람을 판단하지 말라는 신원 보증에 가깝다.
            """,
            takeaway: "떠도는 것처럼 보이는 사람이 사실은 가장 먼 목적지를 알고 있을 수 있다.",
            source: "J.R.R. Tolkien, *The Fellowship of the Ring*, Book 1 ch. 10 (1954)"
        ),
        BehindStory(
            quoteSlug: "dickinson-no-frigate-like-a-book",
            occasion: "1873년경 쓰고, 1894년 사후에 처음 출간된 시",
            context: """
            에밀리 디킨슨은 생전에 발표한 시가 열 편 남짓이고, \
            말년에는 집 밖으로 거의 나가지 않았다. \
            이 시가 말하는 배와 준마와 마차는 그가 타 본 적 없는 것들이다. \
            시의 끝은 "이 여행에는 통행료가 들지 않는다"로 맺는데, \
            가난한 사람도 갈 수 있다는 뜻이다.
            """,
            takeaway: "평생 한 마을을 벗어나지 않은 사람이 쓴 여행에 대한 문장이다.",
            source: "Emily Dickinson, \u{201C}There is no Frigate like a Book\u{201D} (Fr1286), *Poems* (1894) 수록"
        ),

        // MARK: - 식사

        BehindStory(
            quoteSlug: "brillat-tell-me-what-you-eat",
            occasion: "1825년, 『미식 예찬』 앞머리의 아포리즘 4번",
            context: """
            브리야사바랭은 법관이었다. 프랑스 혁명 때 신변이 위험해져 미국으로 달아나 \
            뉴욕에서 바이올린을 켜며 2년을 버텼고, 돌아온 뒤 30년 넘게 이 책을 다듬었다. \
            책은 죽기 두 달 전에야 익명으로 나왔다. \
            맨 앞에 붙은 스무 개의 아포리즘 중 네 번째가 이 문장이다.
            """,
            takeaway: "먹는 것으로 사람을 읽겠다는 발상은, 망명지에서 남의 식탁에 앉아 본 사람의 것이다.",
            source: "Jean Anthelme Brillat-Savarin, *Physiologie du goût*, Aphorisme IV (1825)"
        ),
        BehindStory(
            quoteSlug: "brillat-new-dish",
            occasion: "1825년, 『미식 예찬』 아포리즘 9번",
            context: """
            같은 책 같은 목록의 아홉 번째 문장이다. \
            천문학이 학문의 정점으로 대접받던 시대에, \
            요리를 그 옆에 나란히 세운 것은 도발에 가까웠다. \
            브리야사바랭은 미각을 다른 감각보다 낮게 보는 관습 자체를 이 책 전체에서 반박한다.
            """,
            takeaway: "새 별은 몇 사람이 보지만, 새 요리는 모두가 먹는다.",
            source: "Jean Anthelme Brillat-Savarin, *Physiologie du goût*, Aphorisme IX (1825)"
        ),
        BehindStory(
            quoteSlug: "pollan-eat-food",
            occasion: "2008년, 『행복한 밥상』 서문의 일곱 단어",
            context: """
            마이클 폴란은 영양학이 음식을 성분으로 쪼개면서 \
            사람들이 정작 무엇을 먹어야 할지 모르게 되었다고 봤다. \
            그래서 책 한 권 분량의 논증을 일곱 단어로 먼저 내놓고 시작한다. \
            여기서 "진짜 음식"은 증조할머니가 음식으로 알아볼 만한 것을 뜻하고, \
            "주로 식물성으로"는 채식이 아니라 비율의 문제다.
            """,
            takeaway: "규칙이 짧을수록 지킬 확률이 높다는 것을 알고 쓴 문장이다.",
            source: "Michael Pollan, *In Defense of Food* (2008)"
        ),
        BehindStory(
            quoteSlug: "woolf-dined-well",
            occasion: "1929년, 『자기만의 방』 1장",
            context: """
            버지니아 울프는 남자 대학에서 대접받은 점심과 \
            여자 대학에서 받은 저녁을 나란히 묘사한다. \
            앞쪽에는 넙치와 자고새와 포도주가, 뒤쪽에는 맹물과 자두 조림이 나온다. \
            이 문장은 그 두 식탁을 비교한 바로 뒤에 놓인다. \
            여성이 글을 쓰려면 돈과 방이 필요하다는 이 책의 논지는 여기서 시작한다.
            """,
            takeaway: "잘 먹는 문제는 취향이 아니라 자원의 문제라는 것이, 이 문장이 놓인 자리다.",
            source: "Virginia Woolf, *A Room of One's Own*, ch. 1 (1929)"
        ),

        // MARK: - 학업

        BehindStory(
            quoteSlug: "plutarch-fire-to-be-kindled",
            occasion: "1세기 말, 『모랄리아』 중 「강의를 듣는 법에 대하여」",
            context: """
            플루타르코스가 이제 막 성인이 된 청년에게 보낸 조언문이다. \
            원문의 비유는 조금 더 구체적이다 — 마음은 병처럼 채워 넣어야 하는 것이 아니라 \
            장작처럼 불씨만 붙여 주면 스스로 타오른다는 것이다. \
            그러면서 그는 듣는 사람의 태도를 길게 다룬다. \
            잘 듣는 일은 수동적인 것이 아니라 배우는 쪽이 하는 노동이라는 이야기다.
            """,
            takeaway: "가르치는 사람의 일이 아니라 배우는 사람의 일에 대한 문장이다.",
            source: "Plutarch, *Moralia*: \u{201C}De recta ratione audiendi\u{201D} (1세기 말)"
        ),
        BehindStory(
            quoteSlug: "einstein-passionately-curious",
            occasion: "1952년 3월 11일, 전기 작가 카를 젤리히에게 보낸 편지",
            context: """
            젤리히는 아인슈타인의 전기를 쓰면서 그의 천재성이 어디서 왔는지 물었다. \
            아인슈타인은 재능을 부정하는 대신 호기심으로 답을 바꿔 놓았다. \
            그는 다른 편지에서도 비슷하게 말했다 — 자신은 특별히 똑똑한 것이 아니라 \
            문제를 더 오래 붙들고 있을 뿐이라고.
            """,
            takeaway: "겸손의 표현으로 읽히기 쉽지만, 무엇이 실제로 성과를 냈는지에 대한 그의 진단이기도 하다.",
            source: "Albert Einstein → Carl Seelig 편지 (1952-03-11)"
        ),
        BehindStory(
            quoteSlug: "socrates-know-nothing",
            occasion: "기원전 399년, 재판정에서 — 플라톤 『소크라테스의 변명』 21d",
            context: """
            소크라테스는 이 말을 겸손으로 한 것이 아니다. \
            델포이 신탁이 그보다 지혜로운 자가 없다고 하자, 그는 반박할 셈으로 \
            지혜롭다는 사람들을 찾아다니며 물었고 아무도 답하지 못하는 것을 확인했다. \
            결론은 이랬다 — 그들도 나도 모르지만, 나는 모른다는 것만은 안다. \
            이 조사가 그를 미움받게 만들었고, 결국 사형 판결로 이어졌다.
            """,
            takeaway: "\u{201C}무지의 지\u{201D}는 마음가짐이 아니라, 그가 실제로 사람들을 찾아다니며 얻은 조사 결과였다.",
            source: "Plato, *Apology* 21d (플라톤 『소크라테스의 변명』)"
        ),
        BehindStory(
            quoteSlug: "confucius-learning-without-thought",
            occasion: "『논어』 위정(爲政)편",
            context: """
            學而不思則罔, 思而不學則殆. \
            앞 구절의 罔(망)은 그물에 걸려 빠져나오지 못하는 상태, \
            뒤 구절의 殆(태)는 위태로움을 뜻한다. \
            배우기만 하면 남의 생각에 갇히고, 생각만 하면 근거 없이 위험해진다는 대구다. \
            둘 중 하나를 고르라는 말이 아니라, 둘을 반드시 함께 두라는 말이다.
            """,
            takeaway: "입력과 사고 중 어느 쪽이 빠져도 결과가 나쁘다는 것을, 서로 다른 방식의 실패로 나누어 말했다.",
            source: "『논어』 위정편 15장"
        ),
        BehindStory(
            quoteSlug: "confucius-three-people-teacher",
            occasion: "『논어』 술이(述而)편",
            context: """
            흔히 앞 구절만 인용되지만 원문에는 뒤가 붙는다 — \
            "그중 좋은 것을 가려 따르고, 좋지 않은 것은 (내게 있는지 보고) 고친다." \
            즉 세 사람 중 한 명이 스승이라는 뜻이 아니라, \
            잘하는 사람에게서도 못하는 사람에게서도 각각 배울 것이 있다는 뜻이다.
            """,
            takeaway: "배울 점을 찾는 일과 고칠 점을 찾는 일이 같은 문장 안에 들어 있다.",
            source: "『논어』 술이편 21장"
        ),
        BehindStory(
            quoteSlug: "hawking-look-up-at-the-stars",
            occasion: "2010년 6월, ABC 뉴스 다이앤 소여와의 인터뷰",
            context: """
            자녀에게 해 준 가장 중요한 조언이 무엇이냐는 질문에 \
            호킹은 세 가지를 꼽았고 이것이 그 첫 번째였다. \
            나머지 둘은 "일을 놓지 마라, 일이 삶에 의미를 준다"와 \
            "사랑을 만나는 행운이 오거든 그것이 거기 있다는 걸 기억하고 놓치지 마라"였다. \
            루게릭병 진단을 받은 지 47년째 되던 해에 한 말이다.
            """,
            takeaway: "우주를 연구한 사람의 낭만적인 조언처럼 들리지만, 몸을 거의 움직이지 못하는 사람이 자식에게 남긴 실용적인 당부다.",
            source: "ABC News, Diane Sawyer 인터뷰 (2010-06)"
        ),

        // MARK: - 운동

        BehindStory(
            quoteSlug: "jordan-failed-over-and-over",
            occasion: "1997년, 나이키 광고 「Failure」",
            context: """
            이 문장은 경기 뒤 인터뷰가 아니라 30초짜리 광고 대본이다. \
            조던이 체육관으로 걸어 들어가는 장면에 그의 목소리가 얹힌다 — \
            9천 번 넘게 슛을 놓쳤고, 300번 가까이 졌고, \
            경기를 끝낼 결승슛을 맡았다가 26번 실패했다는 숫자가 먼저 나온 뒤 \
            마지막에 이 문장이 온다.
            """,
            takeaway: "실패를 이유로 든 문장이지만, 그 앞에 붙은 숫자를 빼면 힘이 절반으로 준다.",
            source: "Nike, \u{201C}Failure\u{201D} TV 광고 (1997)"
        ),
        BehindStory(
            quoteSlug: "nietzsche-great-thoughts-walking",
            occasion: "1889년, 『우상의 황혼』 「잠언과 화살」 34번",
            context: """
            독일어 원문은 더 짧고 단호하다 — "걸으면서 얻은 생각만이 가치가 있다." \
            바로 앞 문장에서 니체는 가능한 한 적게 앉아 있으라고, \
            바깥에서 몸을 움직이며 태어나지 않은 생각은 믿지 말라고 쓴다. \
            그는 실제로 실스마리아의 호숫가를 하루 몇 시간씩 걸었고, \
            주요 저작의 상당 부분을 그 산책 중에 구상했다.
            """,
            takeaway: "책상 앞에서 짜낸 생각과 걷다가 온 생각을 그는 다른 종류로 취급했다.",
            source: "Friedrich Nietzsche, *Götzen-Dämmerung*, 「Sprüche und Pfeile」 34 (1889)"
        ),
        BehindStory(
            quoteSlug: "einstein-riding-a-bicycle",
            occasion: "1930년 2월 5일, 아들 에두아르트에게 보낸 편지",
            context: """
            물리학 강의가 아니라 아버지가 아들에게 쓴 편지의 한 대목이다. \
            당시 아인슈타인은 아내와 헤어져 지냈고 에두아르트는 스무 살이었다. \
            이 편지를 쓴 지 이태 뒤 에두아르트는 조현병 진단을 받고 평생 요양원에서 지낸다. \
            아인슈타인이 아들을 마지막으로 본 것은 1933년이다.
            """,
            takeaway: "가장 널리 인용되는 그의 비유가, 정작 지켜 주지 못한 아들에게 쓴 편지에서 나왔다.",
            source: "Albert Einstein → Eduard Einstein 편지 (1930-02-05)"
        ),

        // MARK: - 건강

        BehindStory(
            quoteSlug: "hippocrates-life-is-short",
            occasion: "기원전 5세기경, 『아포리즘』 제1권 첫 문장",
            context: """
            라틴어로 옮겨진 "Ars longa, vita brevis" 때문에 \
            "예술은 길고 인생은 짧다"로 잘못 알려졌지만, \
            여기서 ars(τέχνη)는 예술이 아니라 의술이다. \
            원문은 네 마디가 더 이어진다 — 기회는 순식간에 지나가고, \
            경험은 위태롭고, 판단은 어렵다. 의사가 되는 데 걸리는 시간에 대한 경고문이다.
            """,
            takeaway: "\u{201C}예술은 길다\u{201D}는 유명한 오역이다. 원문은 배움이 오래 걸린다는 이야기였다.",
            source: "Hippocrates, *Aphorismi* I.1"
        ),
        BehindStory(
            quoteSlug: "seneca-suffer-in-imagination",
            occasion: "1세기, 『루킬리우스에게 보내는 도덕 서한』 13번",
            context: """
            세네카는 이 편지에서 루킬리우스에게 겁을 주는 것이 무엇인지 따져 보라고 권한다. \
            그가 든 방법은 단순하다 — 두려운 일이 실제로 일어났는지, \
            아니면 아직 일어나지 않았는지 구분하라는 것이다. \
            앞 문장은 이렇게 이어진다. "우리를 놀라게 하는 것이 우리를 짓누르는 것보다 많다."
            """,
            takeaway: "불안을 없애라는 말이 아니라, 불안의 목록과 사실의 목록을 따로 적어 보라는 제안이다.",
            source: "Seneca, *Epistulae Morales ad Lucilium* 13.4"
        ),
        BehindStory(
            quoteSlug: "epictetus-not-events-but-judgments",
            occasion: "2세기 초, 『엥케이리디온』 5장",
            context: """
            에픽테토스는 노예로 태어나 다리를 절었고, 해방된 뒤 철학을 가르쳤다. \
            그가 든 예는 죽음이다 — 죽음 자체가 무서운 것이라면 \
            소크라테스에게도 무서웠어야 하는데 그렇지 않았으니, \
            무서운 것은 죽음이 아니라 죽음에 대한 판단이라는 것이다. \
            『엥케이리디온』은 그가 쓴 책이 아니라 제자 아리아노스가 강의를 받아 적은 요약본이다.
            """,
            takeaway: "사건과 해석을 떼어 놓는 이 구분은, 훗날 인지행동치료의 기본 전제가 되었다.",
            source: "Epictetus, *Encheiridion* 5 (제자 Arrian 기록)"
        ),

        // MARK: - 인간관계

        BehindStory(
            quoteSlug: "carnegie-become-interested",
            occasion: "1936년, 『인간관계론』 2부 1장",
            context: """
            데일 카네기는 이 장을 사람이 아니라 개 이야기로 연다. \
            자기 개 티피가 아무것도 하지 않고도 사람들의 사랑을 받는 이유는 \
            상대를 보면 진심으로 반가워하기 때문이라는 것이다. \
            책 전체가 세일즈맨과 직장인을 위한 실용서였고, \
            대공황 한복판에서 일자리를 구하던 사람들에게 팔렸다.
            """,
            takeaway: "관심을 끄는 일과 관심을 갖는 일의 방향이 반대라는 것이, 이 책의 처음이자 마지막 논지다.",
            source: "Dale Carnegie, *How to Win Friends and Influence People*, Part 2 ch. 1 (1936)"
        ),
        BehindStory(
            quoteSlug: "lewis-friendship-you-too",
            occasion: "1960년, 『네 가지 사랑』 중 「우정」 장",
            context: """
            루이스는 우정을 네 가지 사랑 중 가장 덜 \u{201C}필요한\u{201D} 사랑으로 분류한다. \
            종족 보존에도 생존에도 쓸모가 없어서, 오히려 가장 자유롭다는 것이다. \
            그가 말하는 우정의 시작점은 서로를 마주 보는 순간이 아니라 \
            같은 것을 보고 있었다는 사실을 발견하는 순간이다. \
            그 자신도 톨킨과 그렇게 만나 잉클링스라는 모임을 이뤘다.
            """,
            takeaway: "우정은 서로에게 관심을 갖는 데서가 아니라, 같은 제3의 것에 관심을 갖는 데서 시작한다.",
            source: "C.S. Lewis, *The Four Loves*, ch. 4 \u{201C}Friendship\u{201D} (1960)"
        ),
        BehindStory(
            quoteSlug: "saint-exupery-same-direction",
            occasion: "1939년, 『인간의 대지』",
            context: """
            생텍쥐페리는 우편 비행사였다. \
            사하라와 안데스 위를 날며 동료들이 하나씩 죽는 것을 봤고, \
            자신도 리비아 사막에 추락해 닷새를 걸어 살아남았다. \
            이 책은 그 동료들에 대한 기록이다. \
            사랑을 마주 봄이 아니라 같은 방향을 봄으로 정의한 이 문장도, \
            연인이 아니라 같은 항로를 나눠 맡은 사람들 이야기 안에 있다.
            """,
            takeaway: "연애편지에 자주 인용되지만, 원래는 함께 위험을 나눈 동료들에 대한 말이었다.",
            source: "Antoine de Saint-Exupéry, *Terre des hommes* (1939)"
        ),
        BehindStory(
            quoteSlug: "king-only-love-can-do-that",
            occasion: "1957년 설교, 1963년 설교집 『사랑의 힘』 수록",
            context: """
            몽고메리 버스 보이콧이 끝난 이듬해의 설교 「원수를 사랑하라」에 나온다. \
            보이콧 기간에 킹의 집에는 폭탄이 던져졌고, \
            그는 몰려든 흑인 군중 앞에 나가 무기를 내려놓으라고 설득해야 했다. \
            비폭력은 그에게 전략이기 이전에 신학이었고, \
            이 문장은 그 신학을 가장 짧게 압축한 형태다.
            """,
            takeaway: "폭력을 쓰지 않겠다는 선언이 아니라, 폭력으로는 목표에 도달할 수 없다는 계산에 가깝다.",
            source: "Martin Luther King Jr., \u{201C}Loving Your Enemies\u{201D}, *Strength to Love* (1963) 수록"
        ),
        BehindStory(
            quoteSlug: "wilde-lifelong-romance",
            occasion: "1895년, 희곡 『이상적인 남편』 3막",
            context: """
            로드 고링이 던지는 대사다. 늘 그렇듯 반쯤은 농담이다. \
            이 작품이 런던에서 흥행하던 바로 그 몇 달 사이에 \
            와일드는 동성애 혐의로 기소되어 2년의 중노동형을 받는다. \
            극장에서는 그의 이름이 포스터에서 지워졌다.
            """,
            takeaway: "자기 자신을 사랑하라는 이 가벼운 농담을, 정작 그 자신은 오래 지킬 수 없었다.",
            source: "Oscar Wilde, *An Ideal Husband*, Act 3 (1895)"
        ),

        // MARK: - 자기계발

        BehindStory(
            quoteSlug: "nietzsche-he-who-has-a-why",
            occasion: "1889년, 『우상의 황혼』 「잠언과 화살」 12번",
            context: """
            니체가 이 문장을 쓴 것은 정신이 무너지기 불과 몇 달 전이다. \
            반세기 뒤 빅터 프랭클은 아우슈비츠에서 이 문장을 되뇌었고, \
            『죽음의 수용소에서』에 그대로 인용하며 \
            살아야 할 이유를 가진 수감자가 더 오래 버티더라는 관찰을 덧붙였다. \
            이 앱의 다음 명언이 바로 그 프랭클의 문장이다.
            """,
            takeaway: "철학자의 잠언이 수용소에서 생존 도구로 쓰인 드문 사례다.",
            source: "Friedrich Nietzsche, *Götzen-Dämmerung*, 「Sprüche und Pfeile」 12 (1889)"
        ),
        BehindStory(
            quoteSlug: "frankl-last-of-human-freedoms",
            occasion: "1946년, 『죽음의 수용소에서』 1부",
            context: """
            프랭클은 아우슈비츠를 포함한 네 곳의 수용소를 거쳤고 \
            아내와 부모와 형을 모두 잃었다. \
            그는 이 책을 9일 만에 썼고 처음에는 익명으로 낼 생각이었다. \
            같은 조건에서도 어떤 사람은 남에게 빵을 나눠 주었다는 관찰이 \
            이 문장 바로 앞에 놓여 있다.
            """,
            takeaway: "모든 것을 빼앗겼을 때 남는 것이 무엇인지, 실제로 모든 것을 빼앗겨 본 사람이 내놓은 답이다.",
            source: "Viktor E. Frankl, *…trotzdem Ja zum Leben sagen* (1946) / 영역 *Man's Search for Meaning*"
        ),
        BehindStory(
            quoteSlug: "laotzu-journey-of-a-thousand-miles",
            occasion: "『도덕경』 64장",
            context: """
            千里之行, 始於足下. \
            흔히 "한 걸음에서 시작된다"로 옮기지만 足下(족하)는 \u{201C}발 아래\u{201D}, \
            즉 지금 서 있는 그 자리를 가리킨다. \
            앞 구절도 같은 형식이다 — 아름드리나무도 터럭 같은 싹에서 자라고, \
            9층 누대도 한 삼태기의 흙에서 시작한다.
            """,
            takeaway: "\u{201C}첫걸음을 떼라\u{201D}보다 \u{201C}지금 발밑에서 시작된다\u{201D}에 가까운 문장이다.",
            source: "『도덕경』 64장"
        ),
        BehindStory(
            quoteSlug: "laotzu-knowing-yourself",
            occasion: "『도덕경』 33장",
            context: """
            知人者智, 自知者明. \
            智(지)와 明(명)을 나눠 쓴 것이 핵심이다. \
            智는 바깥을 아는 밝음, 明은 스스로 빛을 내는 밝음에 가깝다. \
            이어지는 구절도 같은 대구를 이룬다 — \
            남을 이기는 자는 힘이 있고, 자기를 이기는 자는 강하다.
            """,
            takeaway: "남을 아는 능력과 자기를 아는 능력에 서로 다른 글자를 붙였다는 점이, 이 장의 전부다.",
            source: "『도덕경』 33장"
        ),
        BehindStory(
            quoteSlug: "marcus-rise-to-do-the-work",
            occasion: "170년대, 『명상록』 5권 1장",
            context: """
            로마 황제가 남에게 보여 줄 생각 없이 자신에게 쓴 글이다. \
            게르만족과의 전쟁 중 야영지에서 그리스어로 적었고, \
            사후 1,300년이 지나서야 인쇄되었다. \
            이 대목은 이렇게 이어진다 — \
            "나는 이불 속에서 몸을 데우려고 태어났는가?" \
            제국에서 가장 큰 권력을 가진 사람이 아침에 일어나기 싫어 스스로를 설득하는 장면이다.
            """,
            takeaway: "황제의 아침도 우리와 다르지 않았다는 사실이, 이 책이 2천 년을 살아남은 이유다.",
            source: "Marcus Aurelius, *Ta eis heauton* (『명상록』) 5.1"
        ),
        BehindStory(
            quoteSlug: "edison-genius-perspiration",
            occasion: "1900년대 초, 기자들에게 반복해서 한 말",
            context: """
            에디슨은 이 비율을 여러 번 바꿔 말했다. \
            1898년 『레이디스 홈 저널』에서는 2 대 98이었고, \
            1901년 아이다호의 한 지역지에서 지금의 1 대 99가 처음 확인된다. \
            가장 널리 인용되는 형태는 그가 죽은 이듬해인 1932년 \
            『하퍼스 먼슬리』가 정리해 실은 것이다.
            """,
            takeaway: "한 번의 명언이 아니라, 30년에 걸쳐 다듬어진 홍보 문구에 가까웠다.",
            source: "Quote Investigator 조사 — *Ladies' Home Journal* (1898), 아이다호 지역지 (1901), *Harper's Monthly* (1932-09)"
        ),
        BehindStory(
            quoteSlug: "beethoven-seize-fate",
            occasion: "1801년 11월 16일, 친구 프란츠 베겔러에게 보낸 편지",
            context: """
            서른한 살의 베토벤이 귀가 멀어 가고 있다는 사실을 \
            가까운 친구에게 겨우 털어놓던 무렵의 편지다. \
            이듬해 그는 유서까지 썼다(하일리겐슈타트 유서). \
            그러나 이 시기 이후에 3번 교향곡 「영웅」부터 후기 현악사중주까지, \
            우리가 아는 베토벤의 거의 전부가 나온다.
            """,
            takeaway: "가장 잘 알려진 그의 선언이, 가장 무너져 있던 해에 나왔다.",
            source: "Ludwig van Beethoven → Franz Wegeler 편지 (1801-11-16)"
        ),
        BehindStory(
            quoteSlug: "vangogh-small-things-brought-together",
            occasion: "1882년 10월 22일, 헤이그에서 동생 테오에게 보낸 편지",
            context: """
            빈센트가 그림을 그리기 시작한 지 2년밖에 되지 않았을 때다. \
            생활비 전부를 테오에게 의지하고 있었고, \
            편지의 앞부분에서 그는 자신이 아직 얼마나 서툰지를 길게 적는다. \
            그가 남긴 편지는 900통이 넘고, 그중 650통이 테오에게 간 것이다.
            """,
            takeaway: "\u{201C}작은 일들\u{201D}이라는 말이, 아직 아무것도 이루지 못한 사람의 입에서 나왔다는 점이 다르다.",
            source: "Vincent van Gogh → Theo van Gogh 편지 274 (1882-10-22)"
        ),
        BehindStory(
            quoteSlug: "saint-exupery-nothing-left-to-take-away",
            occasion: "1939년, 『인간의 대지』 3장 「비행기」",
            context: """
            이 문장은 예술이 아니라 비행기 설계에 대한 것이다. \
            생텍쥐페리는 초기 비행기가 어떻게 군더더기를 하나씩 떨어뜨리며 \
            결국 물방울 같은 형태에 도달했는지를 설명한 뒤 이 말을 덧붙인다. \
            기계가 완성될수록 기계처럼 보이지 않게 된다는 것이 그의 관찰이었다.
            """,
            takeaway: "디자인 격언으로 널리 쓰이지만, 원래는 실제로 만들어진 물건을 두고 한 말이었다.",
            source: "Antoine de Saint-Exupéry, *Terre des hommes*, ch. 3 (1939)"
        ),

        // MARK: - 일상

        BehindStory(
            quoteSlug: "voltaire-perfect-enemy-of-good",
            occasion: "1772년, 시 「La Bégueule」의 첫 두 행",
            context: """
            볼테르는 이 말을 자기 것으로 내놓지 않았다. \
            시의 서두에서 그는 "옛 현자가 말하기를"이라며 이탈리아 속담을 인용한다. \
            그가 이 말을 꺼낸 맥락도 도덕론이 아니라 풍자였다 — \
            지나치게 까다롭게 구는 여자를 놀리는 이야기의 도입부다. \
            『철학사전』의 「예술적 취향」 항목에도 같은 문장이 나온다.
            """,
            takeaway: "출처가 볼테르 자신이 아니라 그가 인용한 속담이라는 점은 대개 함께 인용되지 않는다.",
            source: "Voltaire, 「La Bégueule」 (1772) / *Dictionnaire philosophique* (1770)"
        ),
        BehindStory(
            quoteSlug: "cicero-gratitude-mother-of-virtues",
            occasion: "기원전 54년, 「플란키우스 변호 연설」 80절",
            context: """
            철학 저술이 아니라 법정 변론이다. \
            키케로는 자신이 망명했을 때 도와준 플란키우스가 \
            선거 부정으로 고발되자 변호를 맡았다. \
            은혜를 갚는 일에 대해 말하는 이 대목은, \
            변호인 자신이 피고에게 빚진 것이 있음을 배심원 앞에 드러내는 장면이기도 하다.
            """,
            takeaway: "감사를 미덕의 어머니라고 부른 사람은, 그 자리에서 실제로 은혜를 갚는 중이었다.",
            source: "Cicero, *Pro Plancio* 80 (기원전 54년)"
        ),
        BehindStory(
            quoteSlug: "thich-washing-the-dishes",
            occasion: "1974년, 태국의 동료들에게 보낸 편지 — 『틱낫한 명상』",
            context: """
            원래는 책으로 쓴 글이 아니라, 베트남 전쟁 중 \
            사회사업을 하던 젊은 동료들에게 보낸 긴 편지였다. \
            그들은 폭격 속에서 마을을 재건하고 있었고, \
            틱낫한이 권한 것은 명상실로 물러나는 일이 아니라 \
            설거지 같은 가장 사소한 일을 하는 동안 온전히 거기 있는 연습이었다.
            """,
            takeaway: "설거지를 빨리 끝내려고 하는 순간, 그 시간만큼의 삶이 사라진다는 이야기다.",
            source: "Thích Nhất Hạnh, *The Miracle of Mindfulness* (1975, 원래 1974년 편지)"
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
