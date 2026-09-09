import Foundation

/// 앱에 소개 글이 준비되지 않은 인물의 한국어 표기.
///
/// ZenQuotes 는 영어 이름만 준다. 문장은 기기에서 번역해도 **이름은 번역하면 안 된다** —
/// 기계 번역은 사람 이름을 뜻으로 옮겨 버린다("Grace Hopper" 를 은혜/메뚜기로 읽는 식이다).
/// 그래서 번역기에 맡기지 않고 손으로 확인한 표기만 표에 넣는다.
///
/// 찾는 순서는 셋이다.
/// 1. `AuthorLibrary` — 소개·생몰년까지 준비된 인물. 가장 좋은 결과다.
/// 2. 이 표 — 한국어 표기와 직업·국적만 있는 인물.
/// 3. 어느 쪽에도 없으면 **영어 이름을 그대로 둔다.** 짐작해서 옮기지 않는다.
///
/// 표에 없는 이름이 나오는 것은 실패가 아니다. ZenQuotes 의 인물 목록은 수천 명이고
/// 여기에 다 넣을 수는 없다. 자주 나오는 인물부터 채워 나간다.
public struct ForeignName: Hashable, Sendable {
    public let english: String
    public let korean: String
    /// 직업. 확실하지 않으면 nil 로 두고 기본 문구를 쓴다.
    public let occupation: String?
    /// 국적. 확실하지 않으면 nil.
    public let nationality: String?

    public init(_ english: String, _ korean: String, _ occupation: String? = nil, _ nationality: String? = nil) {
        self.english = english
        self.korean = korean
        self.occupation = occupation
        self.nationality = nationality
    }
}

public enum ForeignNameLibrary {
    /// 이름이 일치하는 항목. 표기 차이는 `NameKey` 가 지운다.
    public static func entry(matchingName name: String) -> ForeignName? {
        byNormalizedName[NameKey.normalize(name)]
    }

    private static let byNormalizedName: [String: ForeignName] = Dictionary(
        all.map { (NameKey.normalize($0.english), $0) },
        uniquingKeysWith: { first, _ in first }
    )

    public static let all: [ForeignName] = philosophers + writers + poets
        + scientists + leaders + business + athletes + artists + spiritual + sayings

    // MARK: - 철학 · 사상

    static let philosophers: [ForeignName] = [
        ForeignName("Rene Descartes", "르네 데카르트", "철학자 · 수학자", "프랑스"),
        ForeignName("Baruch Spinoza", "바뤼흐 스피노자", "철학자", "네덜란드"),
        ForeignName("Jean-Paul Sartre", "장폴 사르트르", "철학자 · 작가", "프랑스"),
        ForeignName("Simone de Beauvoir", "시몬 드 보부아르", "철학자 · 작가", "프랑스"),
        ForeignName("Simone Weil", "시몬 베유", "철학자", "프랑스"),
        ForeignName("Hannah Arendt", "한나 아렌트", "정치철학자", "독일 · 미국"),
        ForeignName("Ludwig Wittgenstein", "루트비히 비트겐슈타인", "철학자", "오스트리아"),
        ForeignName("Francis Bacon", "프랜시스 베이컨", "철학자 · 정치인", "영국"),
        ForeignName("John Locke", "존 로크", "철학자", "영국"),
        ForeignName("David Hume", "데이비드 흄", "철학자", "스코틀랜드"),
        ForeignName("Jean-Jacques Rousseau", "장자크 루소", "철학자 · 작가", "제네바 · 프랑스"),
        ForeignName("Georg Wilhelm Friedrich Hegel", "게오르크 빌헬름 프리드리히 헤겔", "철학자", "독일"),
        ForeignName("Karl Marx", "카를 마르크스", "사상가 · 경제학자", "독일"),
        ForeignName("John Stuart Mill", "존 스튜어트 밀", "철학자 · 경제학자", "영국"),
        ForeignName("Blaise Pascal", "블레즈 파스칼", "수학자 · 철학자", "프랑스"),
        ForeignName("Thomas Aquinas", "토마스 아퀴나스", "신학자 · 철학자", "이탈리아"),
        ForeignName("Saint Augustine", "아우구스티누스", "신학자 · 철학자", "로마(북아프리카)"),
        ForeignName("Erasmus", "에라스뮈스", "인문학자 · 신학자", "네덜란드"),
        ForeignName("Niccolo Machiavelli", "니콜로 마키아벨리", "정치사상가", "이탈리아"),
        ForeignName("Diogenes", "디오게네스", "철학자", "그리스"),
        ForeignName("Heraclitus", "헤라클레이토스", "철학자", "그리스"),
        ForeignName("Pythagoras", "피타고라스", "수학자 · 철학자", "그리스"),
        ForeignName("Epicurus", "에피쿠로스", "철학자", "그리스"),
        ForeignName("Democritus", "데모크리토스", "철학자", "그리스"),
        ForeignName("Thales", "탈레스", "철학자", "그리스"),
        ForeignName("Zeno of Citium", "키티온의 제논", "철학자", "그리스"),
        ForeignName("Mencius", "맹자", "사상가", "중국"),
        ForeignName("Zhuangzi", "장자", "사상가", "중국"),
        ForeignName("Chuang Tzu", "장자", "사상가", "중국"),
        ForeignName("Jiddu Krishnamurti", "지두 크리슈나무르티", "사상가", "인도"),
        ForeignName("Eckhart Tolle", "에크하르트 톨레", "명상 지도자 · 작가", "독일 · 캐나다"),
        ForeignName("Alan Watts", "앨런 와츠", "철학자 · 저술가", "영국 · 미국"),
        ForeignName("Joseph Campbell", "조지프 캠벨", "신화학자", "미국"),
        ForeignName("Erich Fromm", "에리히 프롬", "정신분석학자 · 사회심리학자", "독일 · 미국"),
        ForeignName("Marshall McLuhan", "마셜 매클루언", "미디어 이론가", "캐나다"),
        ForeignName("Noam Chomsky", "노엄 촘스키", "언어학자 · 사회비평가", "미국")
    ]

    // MARK: - 문학 · 저술

    static let writers: [ForeignName] = [
        ForeignName("F. Scott Fitzgerald", "F. 스콧 피츠제럴드", "소설가", "미국"),
        ForeignName("George Orwell", "조지 오웰", "소설가 · 언론인", "영국"),
        ForeignName("Aldous Huxley", "올더스 헉슬리", "소설가", "영국"),
        ForeignName("Franz Kafka", "프란츠 카프카", "소설가", "체코(독일어권)"),
        ForeignName("Herman Melville", "허먼 멜빌", "소설가", "미국"),
        ForeignName("Marcel Proust", "마르셀 프루스트", "소설가", "프랑스"),
        ForeignName("Anton Chekhov", "안톤 체호프", "극작가 · 소설가", "러시아"),
        ForeignName("Ivan Turgenev", "이반 투르게네프", "소설가", "러시아"),
        ForeignName("Maxim Gorky", "막심 고리키", "소설가", "러시아"),
        ForeignName("Alexandre Dumas", "알렉상드르 뒤마", "소설가", "프랑스"),
        ForeignName("Jules Verne", "쥘 베른", "소설가", "프랑스"),
        ForeignName("Gustave Flaubert", "귀스타브 플로베르", "소설가", "프랑스"),
        ForeignName("Honore de Balzac", "오노레 드 발자크", "소설가", "프랑스"),
        ForeignName("Charlotte Bronte", "샬럿 브론테", "소설가", "영국"),
        ForeignName("Emily Bronte", "에밀리 브론테", "소설가 · 시인", "영국"),
        ForeignName("Mary Shelley", "메리 셸리", "소설가", "영국"),
        ForeignName("Louisa May Alcott", "루이자 메이 올컷", "소설가", "미국"),
        ForeignName("Lewis Carroll", "루이스 캐럴", "작가 · 수학자", "영국"),
        ForeignName("Robert Louis Stevenson", "로버트 루이스 스티븐슨", "소설가", "스코틀랜드"),
        ForeignName("Rudyard Kipling", "러디어드 키플링", "작가 · 시인", "영국"),
        ForeignName("H. G. Wells", "H. G. 웰스", "소설가", "영국"),
        ForeignName("Arthur Conan Doyle", "아서 코난 도일", "소설가", "영국"),
        ForeignName("Agatha Christie", "애거사 크리스티", "추리소설가", "영국"),
        ForeignName("John Steinbeck", "존 스타인벡", "소설가", "미국"),
        ForeignName("William Faulkner", "윌리엄 포크너", "소설가", "미국"),
        ForeignName("James Baldwin", "제임스 볼드윈", "작가 · 사회비평가", "미국"),
        ForeignName("Toni Morrison", "토니 모리슨", "소설가", "미국"),
        ForeignName("Harper Lee", "하퍼 리", "소설가", "미국"),
        ForeignName("Zora Neale Hurston", "조라 닐 허스턴", "소설가 · 인류학자", "미국"),
        ForeignName("Ray Bradbury", "레이 브래드버리", "소설가", "미국"),
        ForeignName("Isaac Asimov", "아이작 아시모프", "소설가 · 생화학자", "미국"),
        ForeignName("Kurt Vonnegut", "커트 보니것", "소설가", "미국"),
        ForeignName("Douglas Adams", "더글러스 애덤스", "소설가", "영국"),
        ForeignName("Terry Pratchett", "테리 프래쳇", "소설가", "영국"),
        ForeignName("Neil Gaiman", "닐 게이먼", "소설가", "영국"),
        ForeignName("Ursula K. Le Guin", "어슐러 K. 르 귄", "소설가", "미국"),
        ForeignName("Stephen King", "스티븐 킹", "소설가", "미국"),
        ForeignName("Gabriel Garcia Marquez", "가브리엘 가르시아 마르케스", "소설가", "콜롬비아"),
        ForeignName("Jorge Luis Borges", "호르헤 루이스 보르헤스", "소설가 · 시인", "아르헨티나"),
        ForeignName("Thomas Mann", "토마스 만", "소설가", "독일"),
        ForeignName("Milan Kundera", "밀란 쿤데라", "소설가", "체코 · 프랑스"),
        ForeignName("Umberto Eco", "움베르토 에코", "소설가 · 기호학자", "이탈리아"),
        ForeignName("Haruki Murakami", "무라카미 하루키", "소설가", "일본"),
        ForeignName("Nikos Kazantzakis", "니코스 카잔차키스", "소설가", "그리스"),
        ForeignName("Miguel de Cervantes", "미겔 데 세르반테스", "소설가", "스페인"),
        ForeignName("Samuel Beckett", "사뮈엘 베케트", "극작가 · 소설가", "아일랜드"),
        ForeignName("James Joyce", "제임스 조이스", "소설가", "아일랜드"),
        ForeignName("Somerset Maugham", "서머싯 몸", "소설가", "영국"),
        ForeignName("Graham Greene", "그레이엄 그린", "소설가", "영국"),
        ForeignName("George Eliot", "조지 엘리엇", "소설가", "영국"),
        ForeignName("Henry James", "헨리 제임스", "소설가", "미국 · 영국"),
        ForeignName("Edith Wharton", "이디스 워튼", "소설가", "미국"),
        ForeignName("Willa Cather", "윌라 캐더", "소설가", "미국"),
        ForeignName("Thomas Hardy", "토머스 하디", "소설가 · 시인", "영국"),
        ForeignName("D. H. Lawrence", "D. H. 로렌스", "소설가", "영국"),
        ForeignName("E. M. Forster", "E. M. 포스터", "소설가", "영국"),
        ForeignName("Samuel Johnson", "새뮤얼 존슨", "문인 · 사전 편찬자", "영국"),
        ForeignName("Jonathan Swift", "조너선 스위프트", "작가 · 성직자", "아일랜드"),
        ForeignName("Daniel Defoe", "대니얼 디포", "소설가", "영국"),
        ForeignName("Anais Nin", "아나이스 닌", "작가", "프랑스 · 미국"),
        ForeignName("Henry Miller", "헨리 밀러", "소설가", "미국"),
        ForeignName("Charles Bukowski", "찰스 부코스키", "시인 · 소설가", "미국"),
        ForeignName("Jack Kerouac", "잭 케루악", "소설가", "미국"),
        ForeignName("Hunter S. Thompson", "헌터 S. 톰슨", "작가 · 언론인", "미국"),
        ForeignName("Aesop", "이솝", "우화 작가", "그리스"),
        ForeignName("Malcolm Gladwell", "말콤 글래드웰", "작가 · 언론인", "캐나다"),
        ForeignName("Brene Brown", "브레네 브라운", "사회복지학자 · 작가", "미국"),
        ForeignName("Elizabeth Gilbert", "엘리자베스 길버트", "작가", "미국"),
        ForeignName("Anne Lamott", "앤 라모트", "작가", "미국"),
        ForeignName("Annie Dillard", "애니 딜러드", "작가", "미국"),
        ForeignName("Wendell Berry", "웬델 베리", "작가 · 농부", "미국"),
        ForeignName("Barbara Kingsolver", "바버라 킹솔버", "소설가", "미국")
    ]

    // MARK: - 시 · 극

    static let poets: [ForeignName] = [
        ForeignName("Edgar Allan Poe", "에드거 앨런 포", "시인 · 소설가", "미국"),
        ForeignName("T. S. Eliot", "T. S. 엘리엇", "시인", "미국 · 영국"),
        ForeignName("W. B. Yeats", "W. B. 예이츠", "시인", "아일랜드"),
        ForeignName("Rainer Maria Rilke", "라이너 마리아 릴케", "시인", "오스트리아"),
        ForeignName("Pablo Neruda", "파블로 네루다", "시인", "칠레"),
        ForeignName("Langston Hughes", "랭스턴 휴스", "시인", "미국"),
        ForeignName("Sylvia Plath", "실비아 플라스", "시인 · 소설가", "미국"),
        ForeignName("E. E. Cummings", "E. E. 커밍스", "시인", "미국"),
        ForeignName("William Blake", "윌리엄 블레이크", "시인 · 화가", "영국"),
        ForeignName("John Keats", "존 키츠", "시인", "영국"),
        ForeignName("Percy Bysshe Shelley", "퍼시 비시 셸리", "시인", "영국"),
        ForeignName("Lord Byron", "바이런 경", "시인", "영국"),
        ForeignName("William Wordsworth", "윌리엄 워즈워스", "시인", "영국"),
        ForeignName("Samuel Taylor Coleridge", "새뮤얼 테일러 콜리지", "시인 · 비평가", "영국"),
        ForeignName("Elizabeth Barrett Browning", "엘리자베스 배럿 브라우닝", "시인", "영국"),
        ForeignName("Robert Browning", "로버트 브라우닝", "시인", "영국"),
        ForeignName("Alfred Lord Tennyson", "알프레드 테니슨", "시인", "영국"),
        ForeignName("John Milton", "존 밀턴", "시인", "영국"),
        ForeignName("Geoffrey Chaucer", "제프리 초서", "시인", "영국"),
        ForeignName("Alexander Pope", "알렉산더 포프", "시인", "영국"),
        ForeignName("Dante Alighieri", "단테 알리기에리", "시인", "이탈리아"),
        ForeignName("Homer", "호메로스", "서사시인", "그리스"),
        ForeignName("Sophocles", "소포클레스", "비극 작가", "그리스"),
        ForeignName("Euripides", "에우리피데스", "비극 작가", "그리스"),
        ForeignName("Aeschylus", "아이스킬로스", "비극 작가", "그리스"),
        ForeignName("Virgil", "베르길리우스", "서사시인", "로마"),
        ForeignName("Ovid", "오비디우스", "시인", "로마"),
        ForeignName("Horace", "호라티우스", "시인", "로마"),
        ForeignName("Publilius Syrus", "푸블릴리우스 시루스", "격언 작가", "로마"),
        ForeignName("Omar Khayyam", "오마르 하이얌", "시인 · 수학자", "페르시아"),
        ForeignName("Hafiz", "하피즈", "시인", "페르시아"),
        ForeignName("Matsuo Basho", "마쓰오 바쇼", "하이쿠 시인", "일본")
    ]

    // MARK: - 과학 · 의학 · 심리

    static let scientists: [ForeignName] = [
        ForeignName("Galileo Galilei", "갈릴레오 갈릴레이", "천문학자 · 물리학자", "이탈리아"),
        ForeignName("Gregor Mendel", "그레고어 멘델", "유전학자 · 수도사", "오스트리아"),
        ForeignName("Niels Bohr", "닐스 보어", "물리학자", "덴마크"),
        ForeignName("Werner Heisenberg", "베르너 하이젠베르크", "물리학자", "독일"),
        ForeignName("Max Planck", "막스 플랑크", "물리학자", "독일"),
        ForeignName("Erwin Schrodinger", "에르빈 슈뢰딩거", "물리학자", "오스트리아"),
        ForeignName("Alan Turing", "앨런 튜링", "수학자 · 컴퓨터과학자", "영국"),
        ForeignName("Ada Lovelace", "에이다 러브레이스", "수학자", "영국"),
        ForeignName("Grace Hopper", "그레이스 호퍼", "컴퓨터과학자 · 해군 제독", "미국"),
        ForeignName("Rosalind Franklin", "로절린드 프랭클린", "화학자 · 결정학자", "영국"),
        ForeignName("Neil deGrasse Tyson", "닐 디그래스 타이슨", "천체물리학자", "미국"),
        ForeignName("Buckminster Fuller", "버크민스터 풀러", "건축가 · 발명가", "미국"),
        ForeignName("George Washington Carver", "조지 워싱턴 카버", "농학자 · 발명가", "미국"),
        ForeignName("Alexander Graham Bell", "알렉산더 그레이엄 벨", "발명가", "스코틀랜드 · 미국"),
        ForeignName("Archimedes", "아르키메데스", "수학자 · 발명가", "그리스"),
        ForeignName("Euclid", "에우클레이데스(유클리드)", "수학자", "그리스"),
        ForeignName("Carl Friedrich Gauss", "카를 프리드리히 가우스", "수학자", "독일"),
        ForeignName("Henri Poincare", "앙리 푸앵카레", "수학자 · 물리학자", "프랑스"),
        ForeignName("Sigmund Freud", "지크문트 프로이트", "정신분석학자", "오스트리아"),
        ForeignName("Alfred Adler", "알프레트 아들러", "정신의학자", "오스트리아"),
        ForeignName("Abraham Maslow", "에이브러햄 매슬로", "심리학자", "미국"),
        ForeignName("Carl Rogers", "칼 로저스", "심리학자", "미국"),
        ForeignName("B. F. Skinner", "B. F. 스키너", "심리학자", "미국"),
        ForeignName("Jean Piaget", "장 피아제", "발달심리학자", "스위스"),
        ForeignName("Daniel Kahneman", "대니얼 카너먼", "심리학자 · 경제학자", "이스라엘 · 미국"),
        ForeignName("Oliver Sacks", "올리버 색스", "신경과 의사 · 작가", "영국 · 미국"),
        ForeignName("Mihaly Csikszentmihalyi", "미하이 칙센트미하이", "심리학자", "헝가리 · 미국"),
        ForeignName("Carol Dweck", "캐럴 드웩", "심리학자", "미국"),
        ForeignName("Angela Duckworth", "앤절라 더크워스", "심리학자", "미국"),
        ForeignName("Elisabeth Kubler-Ross", "엘리자베스 퀴블러로스", "정신의학자", "스위스 · 미국"),
        ForeignName("Jonas Salk", "조너스 소크", "의학자", "미국"),
        ForeignName("William Osler", "윌리엄 오슬러", "의사 · 의학 교육자", "캐나다")
    ]

    // MARK: - 정치 · 사회

    static let leaders: [ForeignName] = [
        ForeignName("George Washington", "조지 워싱턴", "정치인 · 초대 미국 대통령", "미국"),
        ForeignName("Thomas Jefferson", "토머스 제퍼슨", "정치인 · 미국 대통령", "미국"),
        ForeignName("John Adams", "존 애덤스", "정치인 · 미국 대통령", "미국"),
        ForeignName("James Madison", "제임스 매디슨", "정치인 · 미국 대통령", "미국"),
        ForeignName("Harry S. Truman", "해리 S. 트루먼", "정치인 · 미국 대통령", "미국"),
        ForeignName("Dwight D. Eisenhower", "드와이트 D. 아이젠하워", "군인 · 미국 대통령", "미국"),
        ForeignName("Ronald Reagan", "로널드 레이건", "정치인 · 미국 대통령", "미국"),
        ForeignName("Barack Obama", "버락 오바마", "정치인 · 미국 대통령", "미국"),
        ForeignName("Jimmy Carter", "지미 카터", "정치인 · 미국 대통령", "미국"),
        ForeignName("Napoleon Bonaparte", "나폴레옹 보나파르트", "군인 · 프랑스 황제", "프랑스"),
        ForeignName("Julius Caesar", "율리우스 카이사르", "군인 · 정치인", "로마"),
        ForeignName("Alexander the Great", "알렉산드로스 대왕", "마케도니아 왕", "그리스"),
        ForeignName("Queen Elizabeth II", "엘리자베스 2세", "영국 국왕", "영국"),
        ForeignName("Margaret Thatcher", "마거릿 대처", "정치인 · 영국 총리", "영국"),
        ForeignName("Golda Meir", "골다 메이어", "정치인 · 이스라엘 총리", "이스라엘"),
        ForeignName("Malala Yousafzai", "말랄라 유사프자이", "교육 운동가", "파키스탄"),
        ForeignName("Frederick Douglass", "프레더릭 더글러스", "노예제 폐지 운동가 · 저술가", "미국"),
        ForeignName("Harriet Tubman", "해리엇 터브먼", "노예 해방 운동가", "미국"),
        ForeignName("Susan B. Anthony", "수전 B. 앤서니", "여성 참정권 운동가", "미국"),
        ForeignName("Booker T. Washington", "부커 T. 워싱턴", "교육자 · 저술가", "미국"),
        ForeignName("W. E. B. Du Bois", "W. E. B. 듀보이스", "사회학자 · 인권 운동가", "미국"),
        ForeignName("Malcolm X", "맬컴 엑스", "인권 운동가", "미국"),
        ForeignName("Cesar Chavez", "세사르 차베스", "노동 운동가", "미국"),
        ForeignName("Desmond Tutu", "데즈먼드 투투", "성공회 대주교 · 인권 운동가", "남아프리카공화국"),
        ForeignName("Kofi Annan", "코피 아난", "외교관 · 유엔 사무총장", "가나"),
        ForeignName("Vaclav Havel", "바츨라프 하벨", "극작가 · 체코 대통령", "체코"),
        ForeignName("Ruth Bader Ginsburg", "루스 베이더 긴즈버그", "법률가 · 대법관", "미국"),
        ForeignName("Thomas Paine", "토머스 페인", "사상가 · 저술가", "영국 · 미국"),
        ForeignName("Frederick the Great", "프리드리히 대왕", "프로이센 국왕", "프로이센"),
        ForeignName("Marcus Garvey", "마커스 가비", "사회 운동가", "자메이카"),
        ForeignName("Jawaharlal Nehru", "자와할랄 네루", "정치인 · 인도 총리", "인도"),
        ForeignName("Simon Bolivar", "시몬 볼리바르", "군인 · 독립운동가", "베네수엘라")
    ]

    // MARK: - 경영 · 경제

    static let business: [ForeignName] = [
        ForeignName("Jeff Bezos", "제프 베이조스", "기업인", "미국"),
        ForeignName("Elon Musk", "일론 머스크", "기업인", "남아프리카공화국 · 미국"),
        ForeignName("Richard Branson", "리처드 브랜슨", "기업인", "영국"),
        ForeignName("John D. Rockefeller", "존 D. 록펠러", "기업인", "미국"),
        ForeignName("Sam Walton", "샘 월턴", "기업인", "미국"),
        ForeignName("Ray Kroc", "레이 크록", "기업인", "미국"),
        ForeignName("Estee Lauder", "에스티 로더", "기업인", "미국"),
        ForeignName("Howard Schultz", "하워드 슐츠", "기업인", "미국"),
        ForeignName("Sheryl Sandberg", "셰릴 샌드버그", "기업인", "미국"),
        ForeignName("Indra Nooyi", "인드라 누이", "기업인", "인도 · 미국"),
        ForeignName("Jack Ma", "마윈", "기업인", "중국"),
        ForeignName("Charlie Munger", "찰리 멍거", "투자가", "미국"),
        ForeignName("Ray Dalio", "레이 달리오", "투자가", "미국"),
        ForeignName("Benjamin Graham", "벤저민 그레이엄", "투자가 · 경제학자", "미국"),
        ForeignName("Peter Thiel", "피터 틸", "기업인 · 투자가", "미국"),
        ForeignName("Reid Hoffman", "리드 호프먼", "기업인 · 투자가", "미국"),
        ForeignName("Larry Page", "래리 페이지", "기업인", "미국"),
        ForeignName("Mark Zuckerberg", "마크 저커버그", "기업인", "미국"),
        ForeignName("Tim Cook", "팀 쿡", "기업인", "미국"),
        ForeignName("Satya Nadella", "사티아 나델라", "기업인", "인도 · 미국"),
        ForeignName("Jack Welch", "잭 웰치", "경영자", "미국"),
        ForeignName("Tom Peters", "톰 피터스", "경영 사상가", "미국"),
        ForeignName("Clayton Christensen", "클레이턴 크리스텐슨", "경영학자", "미국"),
        ForeignName("Michael Porter", "마이클 포터", "경영학자", "미국"),
        ForeignName("W. Edwards Deming", "W. 에드워즈 데밍", "통계학자 · 품질경영 이론가", "미국"),
        ForeignName("Seth Godin", "세스 고딘", "마케팅 저술가", "미국"),
        ForeignName("Simon Sinek", "사이먼 시넥", "저술가 · 강연자", "영국 · 미국"),
        ForeignName("John C. Maxwell", "존 맥스웰", "리더십 저술가", "미국"),
        ForeignName("Napoleon Hill", "나폴레온 힐", "자기계발 저술가", "미국"),
        ForeignName("Zig Ziglar", "지그 지글러", "강연자 · 저술가", "미국"),
        ForeignName("Jim Rohn", "짐 론", "강연자 · 저술가", "미국"),
        ForeignName("Tony Robbins", "토니 로빈스", "강연자 · 저술가", "미국"),
        ForeignName("Brian Tracy", "브라이언 트레이시", "강연자 · 저술가", "캐나다 · 미국"),
        ForeignName("Robin Sharma", "로빈 샤르마", "저술가", "캐나다"),
        ForeignName("Og Mandino", "오그 만디노", "저술가", "미국"),
        ForeignName("Norman Vincent Peale", "노먼 빈센트 필", "목사 · 저술가", "미국"),
        ForeignName("Earl Nightingale", "얼 나이팅게일", "방송인 · 저술가", "미국"),
        ForeignName("Wayne Dyer", "웨인 다이어", "심리학자 · 저술가", "미국"),
        ForeignName("Deepak Chopra", "디팩 초프라", "의사 · 저술가", "인도 · 미국"),
        ForeignName("Adam Grant", "애덤 그랜트", "조직심리학자", "미국"),
        ForeignName("James Clear", "제임스 클리어", "저술가", "미국"),
        ForeignName("Cal Newport", "칼 뉴포트", "컴퓨터과학자 · 저술가", "미국")
    ]

    // MARK: - 스포츠

    static let athletes: [ForeignName] = [
        ForeignName("Babe Ruth", "베이브 루스", "야구 선수", "미국"),
        ForeignName("Serena Williams", "세리나 윌리엄스", "테니스 선수", "미국"),
        ForeignName("Wayne Gretzky", "웨인 그레츠키", "아이스하키 선수", "캐나다"),
        ForeignName("Kobe Bryant", "코비 브라이언트", "농구 선수", "미국"),
        ForeignName("LeBron James", "르브론 제임스", "농구 선수", "미국"),
        ForeignName("Usain Bolt", "우사인 볼트", "육상 선수", "자메이카"),
        ForeignName("Arnold Schwarzenegger", "아널드 슈워제네거", "보디빌더 · 배우 · 정치인", "오스트리아 · 미국"),
        ForeignName("Billie Jean King", "빌리 진 킹", "테니스 선수", "미국"),
        ForeignName("Jackie Robinson", "재키 로빈슨", "야구 선수", "미국"),
        ForeignName("Tiger Woods", "타이거 우즈", "골프 선수", "미국"),
        ForeignName("Roger Federer", "로저 페더러", "테니스 선수", "스위스"),
        ForeignName("Michael Phelps", "마이클 펠프스", "수영 선수", "미국"),
        ForeignName("Simone Biles", "시몬 바일스", "체조 선수", "미국"),
        ForeignName("Nadia Comaneci", "나디아 코마네치", "체조 선수", "루마니아"),
        ForeignName("Jesse Ventura", "제시 벤투라", "레슬러 · 정치인", "미국"),
        ForeignName("Pat Riley", "팻 라일리", "농구 감독", "미국"),
        ForeignName("Bill Bradley", "빌 브래들리", "농구 선수 · 정치인", "미국")
    ]

    // MARK: - 예술 · 음악 · 영화

    static let artists: [ForeignName] = [
        ForeignName("Michelangelo", "미켈란젤로", "조각가 · 화가", "이탈리아"),
        ForeignName("Rembrandt", "렘브란트", "화가", "네덜란드"),
        ForeignName("Claude Monet", "클로드 모네", "화가", "프랑스"),
        ForeignName("Salvador Dali", "살바도르 달리", "화가", "스페인"),
        ForeignName("Frida Kahlo", "프리다 칼로", "화가", "멕시코"),
        ForeignName("Georgia O'Keeffe", "조지아 오키프", "화가", "미국"),
        ForeignName("Henri Matisse", "앙리 마티스", "화가", "프랑스"),
        ForeignName("Andy Warhol", "앤디 워홀", "화가 · 영화감독", "미국"),
        ForeignName("Auguste Rodin", "오귀스트 로댕", "조각가", "프랑스"),
        ForeignName("Edgar Degas", "에드가 드가", "화가", "프랑스"),
        ForeignName("Paul Cezanne", "폴 세잔", "화가", "프랑스"),
        ForeignName("Wassily Kandinsky", "바실리 칸딘스키", "화가", "러시아"),
        ForeignName("Wolfgang Amadeus Mozart", "볼프강 아마데우스 모차르트", "작곡가", "오스트리아"),
        ForeignName("Johann Sebastian Bach", "요한 제바스티안 바흐", "작곡가", "독일"),
        ForeignName("Frederic Chopin", "프레데리크 쇼팽", "작곡가 · 피아니스트", "폴란드"),
        ForeignName("Igor Stravinsky", "이고르 스트라빈스키", "작곡가", "러시아"),
        ForeignName("Leonard Bernstein", "레너드 번스타인", "지휘자 · 작곡가", "미국"),
        ForeignName("Bob Dylan", "밥 딜런", "가수 · 작곡가", "미국"),
        ForeignName("John Lennon", "존 레넌", "가수 · 작곡가", "영국"),
        ForeignName("Paul McCartney", "폴 매카트니", "가수 · 작곡가", "영국"),
        ForeignName("Jimi Hendrix", "지미 헨드릭스", "기타리스트", "미국"),
        ForeignName("Bob Marley", "밥 말리", "가수 · 작곡가", "자메이카"),
        ForeignName("Louis Armstrong", "루이 암스트롱", "재즈 음악가", "미국"),
        ForeignName("Duke Ellington", "듀크 엘링턴", "재즈 작곡가 · 피아니스트", "미국"),
        ForeignName("Miles Davis", "마일스 데이비스", "재즈 음악가", "미국"),
        ForeignName("Ella Fitzgerald", "엘라 피츠제럴드", "재즈 가수", "미국"),
        ForeignName("Frank Sinatra", "프랭크 시나트라", "가수 · 배우", "미국"),
        ForeignName("Elvis Presley", "엘비스 프레슬리", "가수", "미국"),
        ForeignName("Freddie Mercury", "프레디 머큐리", "가수", "영국"),
        ForeignName("David Bowie", "데이비드 보위", "가수 · 작곡가", "영국"),
        ForeignName("Alfred Hitchcock", "앨프리드 히치콕", "영화감독", "영국 · 미국"),
        ForeignName("Charlie Chaplin", "찰리 채플린", "영화감독 · 배우", "영국"),
        ForeignName("Orson Welles", "오슨 웰스", "영화감독 · 배우", "미국"),
        ForeignName("Stanley Kubrick", "스탠리 큐브릭", "영화감독", "미국"),
        ForeignName("Steven Spielberg", "스티븐 스필버그", "영화감독", "미국"),
        ForeignName("Martin Scorsese", "마틴 스코세이지", "영화감독", "미국"),
        ForeignName("Akira Kurosawa", "구로사와 아키라", "영화감독", "일본"),
        ForeignName("Marilyn Monroe", "메릴린 먼로", "배우", "미국"),
        ForeignName("Katharine Hepburn", "캐서린 헵번", "배우", "미국"),
        ForeignName("Meryl Streep", "메릴 스트립", "배우", "미국"),
        ForeignName("Denzel Washington", "덴절 워싱턴", "배우", "미국"),
        ForeignName("Robin Williams", "로빈 윌리엄스", "배우 · 코미디언", "미국"),
        ForeignName("Jim Carrey", "짐 캐리", "배우 · 코미디언", "캐나다"),
        ForeignName("Morgan Freeman", "모건 프리먼", "배우", "미국"),
        ForeignName("Clint Eastwood", "클린트 이스트우드", "배우 · 영화감독", "미국"),
        ForeignName("Groucho Marx", "그루초 막스", "코미디언 · 배우", "미국"),
        ForeignName("W. C. Fields", "W. C. 필즈", "코미디언 · 배우", "미국"),
        ForeignName("Woody Allen", "우디 앨런", "영화감독 · 각본가", "미국"),
        ForeignName("Maya Deren", "마야 데렌", "영화감독", "우크라이나 · 미국"),
        ForeignName("Frank Lloyd Wright", "프랭크 로이드 라이트", "건축가", "미국"),
        ForeignName("Le Corbusier", "르 코르뷔지에", "건축가", "스위스 · 프랑스"),
        ForeignName("Yves Saint Laurent", "이브 생로랑", "패션 디자이너", "프랑스"),
        ForeignName("Christian Dior", "크리스티앙 디오르", "패션 디자이너", "프랑스"),
        ForeignName("Dieter Rams", "디터 람스", "산업 디자이너", "독일")
    ]

    // MARK: - 종교 · 영성

    static let spiritual: [ForeignName] = [
        ForeignName("Jesus Christ", "예수", "기독교의 중심 인물", nil),
        ForeignName("Muhammad", "무함마드", "이슬람교의 예언자", nil),
        ForeignName("Pope Francis", "프란치스코 교황", "교황", "아르헨티나"),
        ForeignName("Pope John Paul II", "요한 바오로 2세", "교황", "폴란드"),
        ForeignName("Saint Francis of Assisi", "아시시의 프란치스코", "수도자", "이탈리아"),
        ForeignName("Martin Luther", "마르틴 루터", "신학자 · 종교개혁가", "독일"),
        ForeignName("John Wesley", "존 웨슬리", "신학자 · 목사", "영국"),
        ForeignName("Thomas Merton", "토머스 머튼", "수도자 · 저술가", "미국"),
        ForeignName("Billy Graham", "빌리 그레이엄", "목사", "미국"),
        ForeignName("Dietrich Bonhoeffer", "디트리히 본회퍼", "신학자 · 목사", "독일"),
        ForeignName("Ram Dass", "람 다스", "명상 지도자 · 저술가", "미국"),
        ForeignName("Swami Vivekananda", "스와미 비베카난다", "수행자 · 사상가", "인도"),
        ForeignName("Paramahansa Yogananda", "파라마한사 요가난다", "요가 수행자", "인도"),
        ForeignName("Sri Chinmoy", "스리 친모이", "명상 지도자", "인도"),
        ForeignName("Shunryu Suzuki", "스즈키 슌류", "선승", "일본 · 미국"),
        ForeignName("Pema Chodron", "페마 초드론", "불교 수행자 · 저술가", "미국"),
        ForeignName("Jack Kornfield", "잭 콘필드", "명상 지도자", "미국"),
        ForeignName("Sharon Salzberg", "샤론 샬츠버그", "명상 지도자", "미국"),
        ForeignName("Jon Kabat-Zinn", "존 카밧진", "명상 지도자 · 의학자", "미국")
    ]

    // MARK: - 사람이 아닌 출처
    //
    // ZenQuotes 는 속담과 경전도 "저자" 자리에 넣어 보낸다. 사람이 아니므로
    // 국적은 비우고 성격만 적는다.

    static let sayings: [ForeignName] = [
        ForeignName("Anonymous", "작자 미상", "출처 미상", nil),
        ForeignName("Unknown", "작자 미상", "출처 미상", nil),
        ForeignName("Proverb", "속담", "속담", nil),
        ForeignName("Chinese Proverb", "중국 속담", "속담", nil),
        ForeignName("Japanese Proverb", "일본 속담", "속담", nil),
        ForeignName("Korean Proverb", "한국 속담", "속담", nil),
        ForeignName("Indian Proverb", "인도 속담", "속담", nil),
        ForeignName("African Proverb", "아프리카 속담", "속담", nil),
        ForeignName("Irish Proverb", "아일랜드 속담", "속담", nil),
        ForeignName("Turkish Proverb", "튀르키예 속담", "속담", nil),
        ForeignName("Zen Proverb", "선(禪) 격언", "격언", nil),
        ForeignName("Buddhist Proverb", "불교 격언", "격언", nil),
        ForeignName("Native American Proverb", "아메리카 원주민 속담", "속담", nil),
        ForeignName("Latin Proverb", "라틴 격언", "격언", nil),
        ForeignName("Zen Saying", "선(禪) 격언", "격언", nil),
        ForeignName("Talmud", "탈무드", "경전", nil),
        ForeignName("Bhagavad Gita", "바가바드 기타", "경전", nil),
        ForeignName("Tao Te Ching", "도덕경", "경전", nil),
        ForeignName("Dhammapada", "법구경", "경전", nil),
        ForeignName("The Bible", "성경", "경전", nil),
        ForeignName("Bible", "성경", "경전", nil),
        ForeignName("Quran", "쿠란", "경전", nil),
        ForeignName("Upanishads", "우파니샤드", "경전", nil),
        ForeignName("I Ching", "주역", "경전", nil)
    ]
}
