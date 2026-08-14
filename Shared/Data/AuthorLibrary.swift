import Foundation

/// 번들에 포함된 인물 데이터.
///
/// 모든 인물은 실존 인물이며, 명언은 해당 인물이 남긴 것으로 널리 확인된 것만 사용했다.
/// 새 인물을 추가할 때는 `all` 에 항목을 넣기만 하면 `byID` 색인이 자동으로 갱신된다.
public enum AuthorLibrary {
    public static let all: [Author] = [
        Author(
            id: "churchill", name: "Winston Churchill", koreanName: "윈스턴 처칠",
            birthYear: 1874, deathYear: 1965,
            occupation: "정치인 · 작가", nationality: "영국",
            biography: "영국의 정치인이자 작가로, 제2차 세계대전 당시 영국 총리를 지냈다. 전시의 연설과 저술로 사람들에게 용기와 결단을 불어넣은 인물로 기억된다.",
            achievements: ["제2차 세계대전기 영국 총리", "1953년 노벨문학상 수상"]
        ),
        Author(
            id: "davinci", name: "Leonardo da Vinci", koreanName: "레오나르도 다 빈치",
            birthYear: 1452, deathYear: 1519,
            occupation: "화가 · 발명가 · 과학자", nationality: "이탈리아",
            biography: "르네상스를 대표하는 예술가이자 과학자로, 회화·해부학·공학을 넘나들며 방대한 노트를 남겼다. 관찰과 배움을 평생의 습관으로 삼았다.",
            achievements: ["〈모나리자〉, 〈최후의 만찬〉", "해부학·비행 장치 연구 노트"]
        ),
        Author(
            id: "seneca", name: "Seneca", koreanName: "세네카",
            birthYear: -4, deathYear: 65,
            occupation: "철학자 · 정치인", nationality: "로마",
            biography: "로마의 스토아 철학자이자 정치인으로, 네로 황제의 스승이었다. 시간과 죽음, 마음의 평정을 다룬 편지와 에세이를 남겼다.",
            achievements: ["《루킬리우스에게 보내는 편지》", "《인생의 짧음에 관하여》"]
        ),
        Author(
            id: "marcus", name: "Marcus Aurelius", koreanName: "마르쿠스 아우렐리우스",
            birthYear: 121, deathYear: 180,
            occupation: "로마 황제 · 철학자", nationality: "로마",
            biography: "로마 제국의 황제이자 스토아 철학자로, 전장에서 자신을 다잡기 위해 쓴 일기가 《명상록》으로 전해진다.",
            achievements: ["《명상록》", "오현제 시대의 마지막 황제"]
        ),
        Author(
            id: "aristotle", name: "Aristotle", koreanName: "아리스토텔레스",
            birthYear: -384, deathYear: -322,
            occupation: "철학자", nationality: "그리스",
            biography: "플라톤의 제자이자 알렉산드로스 대왕의 스승으로, 논리학·윤리학·생물학의 기초를 세웠다. 좋은 삶은 반복된 습관에서 나온다고 보았다.",
            achievements: ["《니코마코스 윤리학》", "형식 논리학의 창시"]
        ),
        Author(
            id: "socrates", name: "Socrates", koreanName: "소크라테스",
            birthYear: -470, deathYear: -399,
            occupation: "철학자", nationality: "그리스",
            biography: "질문을 통해 스스로 답을 찾게 하는 대화법으로 서양 철학의 방향을 바꾼 인물이다. 자신의 무지를 아는 것에서 지혜가 시작된다고 가르쳤다.",
            achievements: ["산파술(문답법)", "서양 윤리학의 출발점"]
        ),
        Author(
            id: "plato", name: "Plato", koreanName: "플라톤",
            birthYear: -428, deathYear: -348,
            occupation: "철학자", nationality: "그리스",
            biography: "소크라테스의 제자로 아테네에 아카데메이아를 세웠다. 대화편 형식으로 정의·교육·이상국가를 탐구했다.",
            achievements: ["《국가》, 《향연》", "아카데메이아 설립"]
        ),
        Author(
            id: "epictetus", name: "Epictetus", koreanName: "에픽테토스",
            birthYear: 55, deathYear: 135,
            occupation: "철학자", nationality: "로마(그리스계)",
            biography: "노예 신분에서 해방된 뒤 스토아 철학을 가르친 교사다. 통제할 수 있는 것과 없는 것을 구분하는 훈련을 강조했다.",
            achievements: ["《엥케이리디온(편람)》", "후대 스토아 실천철학의 표준"]
        ),
        Author(
            id: "confucius", name: "Confucius", koreanName: "공자",
            birthYear: -551, deathYear: -479,
            occupation: "사상가 · 교육자", nationality: "중국",
            biography: "춘추시대의 사상가로 배움과 예(禮), 사람 사이의 도리를 가르쳤다. 제자들이 정리한 《논어》가 동아시아 교육의 바탕이 되었다.",
            achievements: ["《논어》", "유가(儒家) 사상의 정립"]
        ),
        Author(
            id: "laotzu", name: "Lao Tzu", koreanName: "노자",
            birthYear: nil, deathYear: nil,
            occupation: "사상가", nationality: "중국",
            biography: "도가(道家)의 시조로 전해지는 인물로, 《도덕경》의 저자로 알려져 있다. 억지로 하지 않는 삶과 물처럼 부드러운 힘을 이야기했다.",
            achievements: ["《도덕경》", "도가 사상의 출발점"]
        ),
        Author(
            id: "buddha", name: "Buddha", koreanName: "붓다(석가모니)",
            birthYear: -563, deathYear: -483,
            occupation: "사상가 · 종교 창시자", nationality: "고대 인도",
            biography: "고통의 원인과 그 소멸의 길을 가르친 사상가다. 그의 가르침은 《담마파다》 등 초기 경전으로 전해진다.",
            achievements: ["사성제와 팔정도", "《담마파다》에 전하는 가르침"]
        ),
        Author(
            id: "thich", name: "Thich Nhat Hanh", koreanName: "틱낫한",
            birthYear: 1926, deathYear: 2022,
            occupation: "승려 · 평화운동가", nationality: "베트남",
            biography: "베트남 출신의 선승으로 '마음챙김'을 서구에 널리 알렸다. 걷기·먹기 같은 일상의 행위를 수행으로 삼는 법을 가르쳤다.",
            achievements: ["플럼빌리지 공동체 설립", "《화(Anger)》, 《틱낫한 명상》"]
        ),
        Author(
            id: "dalailama", name: "Dalai Lama XIV", koreanName: "달라이 라마 14세",
            birthYear: 1935, deathYear: nil,
            occupation: "종교 지도자 · 평화운동가", nationality: "티베트",
            biography: "티베트 불교의 정신적 지도자로, 비폭력과 자비를 주제로 세계 각지에서 강연해 왔다.",
            achievements: ["1989년 노벨평화상 수상", "티베트 망명정부의 정신적 지도자"]
        ),
        Author(
            id: "rumi", name: "Rumi", koreanName: "루미",
            birthYear: 1207, deathYear: 1273,
            occupation: "시인 · 신비주의 사상가", nationality: "페르시아",
            biography: "13세기 페르시아의 시인으로, 사랑과 내면의 변화를 노래한 시들이 지금까지 널리 읽힌다.",
            achievements: ["《마스나비》", "수피 문학의 대표 시인"]
        ),
        Author(
            id: "einstein", name: "Albert Einstein", koreanName: "알베르트 아인슈타인",
            birthYear: 1879, deathYear: 1955,
            occupation: "이론물리학자", nationality: "독일 · 미국",
            biography: "상대성이론으로 시간과 공간에 대한 이해를 바꿔 놓은 물리학자다. 호기심과 상상력의 가치를 자주 이야기했다.",
            achievements: ["특수·일반 상대성이론", "1921년 노벨물리학상 수상"]
        ),
        Author(
            id: "curie", name: "Marie Curie", koreanName: "마리 퀴리",
            birthYear: 1867, deathYear: 1934,
            occupation: "물리학자 · 화학자", nationality: "폴란드 · 프랑스",
            biography: "방사능 연구를 개척한 과학자로, 여성 최초의 노벨상 수상자이자 서로 다른 두 분야에서 노벨상을 받은 유일한 인물이다.",
            achievements: ["폴로늄·라듐 발견", "노벨물리학상(1903)·노벨화학상(1911)"]
        ),
        Author(
            id: "edison", name: "Thomas Edison", koreanName: "토머스 에디슨",
            birthYear: 1847, deathYear: 1931,
            occupation: "발명가 · 기업가", nationality: "미국",
            biography: "실용적인 전구와 축음기 등 1,000건이 넘는 특허를 남긴 발명가다. 실패를 데이터로 취급하는 끈질긴 실험으로 유명하다.",
            achievements: ["백열전구 실용화", "멘로파크 연구소 설립"]
        ),
        Author(
            id: "tesla", name: "Nikola Tesla", koreanName: "니콜라 테슬라",
            birthYear: 1856, deathYear: 1943,
            occupation: "전기공학자 · 발명가", nationality: "세르비아계 미국",
            biography: "교류 전력 시스템을 설계해 현대 전력망의 토대를 놓은 발명가다. 머릿속에서 장치를 완성한 뒤 제작에 들어가는 것으로 알려졌다.",
            achievements: ["교류 유도 전동기", "무선 전력 전송 실험"]
        ),
        Author(
            id: "feynman", name: "Richard Feynman", koreanName: "리처드 파인만",
            birthYear: 1918, deathYear: 1988,
            occupation: "이론물리학자", nationality: "미국",
            biography: "양자전기역학을 정립한 물리학자이자 뛰어난 교육자다. 어려운 개념을 쉬운 말로 설명하는 능력으로 유명했다.",
            achievements: ["1965년 노벨물리학상 수상", "《파인만의 물리학 강의》"]
        ),
        Author(
            id: "sagan", name: "Carl Sagan", koreanName: "칼 세이건",
            birthYear: 1934, deathYear: 1996,
            occupation: "천문학자 · 과학저술가", nationality: "미국",
            biography: "행성과학자이자 과학 대중화의 상징적 인물로, 우주를 향한 경이를 대중의 언어로 옮겼다.",
            achievements: ["다큐멘터리 〈코스모스〉", "《창백한 푸른 점》"]
        ),
        Author(
            id: "hawking", name: "Stephen Hawking", koreanName: "스티븐 호킹",
            birthYear: 1942, deathYear: 2018,
            occupation: "이론물리학자", nationality: "영국",
            biography: "블랙홀과 우주론을 연구한 물리학자로, 루게릭병과 함께 살면서도 연구와 저술을 이어 갔다.",
            achievements: ["호킹 복사 이론", "《시간의 역사》"]
        ),
        Author(
            id: "montessori", name: "Maria Montessori", koreanName: "마리아 몬테소리",
            birthYear: 1870, deathYear: 1952,
            occupation: "의사 · 교육자", nationality: "이탈리아",
            biography: "이탈리아 최초의 여성 의사 중 한 명으로, 아이의 자발성을 중심에 둔 교육법을 만들었다.",
            achievements: ["몬테소리 교육법 창안", "《어린이의 비밀》"]
        ),
        Author(
            id: "dewey", name: "John Dewey", koreanName: "존 듀이",
            birthYear: 1859, deathYear: 1952,
            occupation: "철학자 · 교육학자", nationality: "미국",
            biography: "경험을 통한 배움을 강조한 교육철학자로, 현대 학교 교육의 방향에 큰 영향을 주었다.",
            achievements: ["《민주주의와 교육》", "실용주의 교육철학의 정립"]
        ),
        Author(
            id: "plutarch", name: "Plutarch", koreanName: "플루타르코스",
            birthYear: 46, deathYear: 119,
            occupation: "역사가 · 철학자", nationality: "그리스",
            biography: "그리스와 로마 인물들의 생애를 나란히 비교한 전기 작가다. 배움과 인격에 관한 에세이도 다수 남겼다.",
            achievements: ["《플루타르코스 영웅전》", "《모랄리아》"]
        ),
        Author(
            id: "franklin", name: "Benjamin Franklin", koreanName: "벤저민 프랭클린",
            birthYear: 1706, deathYear: 1790,
            occupation: "정치인 · 발명가 · 저술가", nationality: "미국",
            biography: "미국 건국의 아버지 중 한 사람이자 인쇄업자·발명가였다. 시간 관리와 자기 규율에 관한 실용적 조언을 많이 남겼다.",
            achievements: ["피뢰침 발명", "미국 독립선언서 기초 참여"]
        ),
        Author(
            id: "lincoln", name: "Abraham Lincoln", koreanName: "에이브러햄 링컨",
            birthYear: 1809, deathYear: 1865,
            occupation: "정치인 · 변호사", nationality: "미국",
            biography: "미국 제16대 대통령으로 남북전쟁을 이끌고 노예제 폐지를 추진했다. 준비와 인내를 강조한 말들이 전해진다.",
            achievements: ["노예 해방 선언", "게티즈버그 연설"]
        ),
        Author(
            id: "roosevelt_t", name: "Theodore Roosevelt", koreanName: "시어도어 루스벨트",
            birthYear: 1858, deathYear: 1919,
            occupation: "정치인", nationality: "미국",
            biography: "미국 제26대 대통령으로 자연보호와 개혁 정책을 추진했다. 실행하는 사람의 태도를 강조했다.",
            achievements: ["국립공원 체계 확대", "1906년 노벨평화상 수상"]
        ),
        Author(
            id: "roosevelt_e", name: "Eleanor Roosevelt", koreanName: "엘리너 루스벨트",
            birthYear: 1884, deathYear: 1962,
            occupation: "사회운동가 · 외교관", nationality: "미국",
            biography: "미국의 퍼스트레이디이자 인권운동가로, 유엔 세계인권선언 작성을 이끌었다.",
            achievements: ["세계인권선언 기초 위원장", "유엔 미국 대표 역임"]
        ),
        Author(
            id: "mandela", name: "Nelson Mandela", koreanName: "넬슨 만델라",
            birthYear: 1918, deathYear: 2013,
            occupation: "정치인 · 인권운동가", nationality: "남아프리카공화국",
            biography: "27년의 수감 생활 끝에 남아공 최초의 흑인 대통령이 되어 화해와 통합을 이끌었다.",
            achievements: ["1993년 노벨평화상 수상", "아파르트헤이트 철폐 주도"]
        ),
        Author(
            id: "gandhi", name: "Mahatma Gandhi", koreanName: "마하트마 간디",
            birthYear: 1869, deathYear: 1948,
            occupation: "변호사 · 독립운동가", nationality: "인도",
            biography: "비폭력 저항으로 인도 독립운동을 이끈 지도자다. 스스로의 삶을 실험으로 여기며 절제를 실천했다.",
            achievements: ["비폭력 불복종 운동", "《나의 진리 실험 이야기》"]
        ),
        Author(
            id: "king", name: "Martin Luther King Jr.", koreanName: "마틴 루서 킹 주니어",
            birthYear: 1929, deathYear: 1968,
            occupation: "목사 · 인권운동가", nationality: "미국",
            biography: "미국 흑인 민권운동을 비폭력의 방식으로 이끈 지도자다. 연설을 통해 평등의 언어를 대중에게 새겼다.",
            achievements: ["1964년 노벨평화상 수상", "〈나에게는 꿈이 있습니다〉 연설"]
        ),
        Author(
            id: "keller", name: "Helen Keller", koreanName: "헬렌 켈러",
            birthYear: 1880, deathYear: 1968,
            occupation: "작가 · 사회운동가", nationality: "미국",
            biography: "어린 시절 시각과 청각을 모두 잃었지만 대학을 졸업하고 저술과 강연으로 장애인 권익을 위해 일했다.",
            achievements: ["《내 인생의 이야기》", "미국 시각장애인재단 활동"]
        ),
        Author(
            id: "angelou", name: "Maya Angelou", koreanName: "마야 안젤루",
            birthYear: 1928, deathYear: 2014,
            occupation: "시인 · 작가 · 인권운동가", nationality: "미국",
            biography: "자전적 작품으로 인종과 정체성을 이야기한 시인이자 작가다. 사람 사이에 남는 것은 감정이라는 말로 널리 기억된다.",
            achievements: ["《새장에 갇힌 새가 왜 노래하는지 나는 아네》", "대통령 자유훈장 수훈"]
        ),
        Author(
            id: "frankl", name: "Viktor Frankl", koreanName: "빅터 프랭클",
            birthYear: 1905, deathYear: 1997,
            occupation: "정신과 의사 · 심리학자", nationality: "오스트리아",
            biography: "강제수용소에서 살아남은 정신과 의사로, 삶의 의미를 중심에 둔 로고테라피를 창시했다.",
            achievements: ["《죽음의 수용소에서》", "로고테라피 창시"]
        ),
        Author(
            id: "jung", name: "Carl Jung", koreanName: "칼 융",
            birthYear: 1875, deathYear: 1961,
            occupation: "정신과 의사 · 심리학자", nationality: "스위스",
            biography: "분석심리학을 세운 정신과 의사로, 무의식과 자기실현의 개념을 제시했다.",
            achievements: ["분석심리학 창시", "《기억, 꿈, 사상》"]
        ),
        Author(
            id: "james_w", name: "William James", koreanName: "윌리엄 제임스",
            birthYear: 1842, deathYear: 1910,
            occupation: "심리학자 · 철학자", nationality: "미국",
            biography: "미국 심리학의 아버지로 불리며, 습관과 의지, 주의(attention)에 관한 통찰을 남겼다.",
            achievements: ["《심리학의 원리》", "실용주의 철학 정립"]
        ),
        Author(
            id: "drucker", name: "Peter Drucker", koreanName: "피터 드러커",
            birthYear: 1909, deathYear: 2005,
            occupation: "경영학자 · 저술가", nationality: "오스트리아 · 미국",
            biography: "현대 경영학의 틀을 만든 학자로, 성과와 시간 관리에 관한 실천적 원칙을 제시했다.",
            achievements: ["목표에 의한 관리(MBO)", "《경영의 실제》"]
        ),
        Author(
            id: "carnegie_d", name: "Dale Carnegie", koreanName: "데일 카네기",
            birthYear: 1888, deathYear: 1955,
            occupation: "작가 · 강연가", nationality: "미국",
            biography: "인간관계와 화술에 관한 강의를 평생 이어 간 저술가다. 상대에게 진심으로 관심을 갖는 태도를 강조했다.",
            achievements: ["《인간관계론》", "《자기관리론》"]
        ),
        Author(
            id: "covey", name: "Stephen Covey", koreanName: "스티븐 코비",
            birthYear: 1932, deathYear: 2012,
            occupation: "경영 컨설턴트 · 작가", nationality: "미국",
            biography: "원칙 중심의 자기경영을 제시한 저술가로, 우선순위와 주도성의 개념을 대중화했다.",
            achievements: ["《성공하는 사람들의 7가지 습관》", "시간관리 매트릭스"]
        ),
        Author(
            id: "ford", name: "Henry Ford", koreanName: "헨리 포드",
            birthYear: 1863, deathYear: 1947,
            occupation: "기업가 · 엔지니어", nationality: "미국",
            biography: "이동 조립라인을 도입해 자동차를 대중의 물건으로 만든 기업가다.",
            achievements: ["포드 모델 T", "대량생산 방식 확립"]
        ),
        Author(
            id: "jobs", name: "Steve Jobs", koreanName: "스티브 잡스",
            birthYear: 1955, deathYear: 2011,
            occupation: "기업가 · 제품 디자이너", nationality: "미국",
            biography: "애플의 공동 창업자로 개인용 컴퓨터와 스마트폰의 형태를 바꾼 제품들을 이끌었다.",
            achievements: ["매킨토시 · 아이폰 출시 주도", "픽사 성장 견인"]
        ),
        Author(
            id: "disney", name: "Walt Disney", koreanName: "월트 디즈니",
            birthYear: 1901, deathYear: 1966,
            occupation: "애니메이터 · 기업가", nationality: "미국",
            biography: "애니메이션 산업을 개척하고 테마파크라는 형식을 만들어 낸 인물이다.",
            achievements: ["장편 애니메이션 〈백설공주〉", "디즈니랜드 개장"]
        ),
        Author(
            id: "buffett", name: "Warren Buffett", koreanName: "워런 버핏",
            birthYear: 1930, deathYear: nil,
            occupation: "투자자 · 기업인", nationality: "미국",
            biography: "장기 투자 원칙으로 알려진 투자자로, 평판과 시간의 가치에 관한 말을 자주 남겼다.",
            achievements: ["버크셔 해서웨이 경영", "기부 서약(Giving Pledge) 참여"]
        ),
        Author(
            id: "twain", name: "Mark Twain", koreanName: "마크 트웨인",
            birthYear: 1835, deathYear: 1910,
            occupation: "소설가", nationality: "미국",
            biography: "미시시피강을 배경으로 한 소설들로 미국 문학의 목소리를 만든 작가다. 유머 속에 날카로운 통찰을 담았다.",
            achievements: ["《허클베리 핀의 모험》", "《톰 소여의 모험》"]
        ),
        Author(
            id: "emerson", name: "Ralph Waldo Emerson", koreanName: "랠프 월도 에머슨",
            birthYear: 1803, deathYear: 1882,
            occupation: "사상가 · 시인", nationality: "미국",
            biography: "미국 초월주의를 이끈 사상가로, 자기 신뢰와 자연 속의 삶을 강조했다.",
            achievements: ["《자기신뢰》", "《자연론》"]
        ),
        Author(
            id: "thoreau", name: "Henry David Thoreau", koreanName: "헨리 데이비드 소로",
            birthYear: 1817, deathYear: 1862,
            occupation: "작가 · 철학자", nationality: "미국",
            biography: "월든 호숫가에서 2년간 자급 생활을 하며 단순한 삶을 실험한 작가다.",
            achievements: ["《월든》", "《시민 불복종》"]
        ),
        Author(
            id: "shakespeare", name: "William Shakespeare", koreanName: "윌리엄 셰익스피어",
            birthYear: 1564, deathYear: 1616,
            occupation: "극작가 · 시인", nationality: "영국",
            biography: "영어권 문학에서 가장 널리 읽히는 극작가로, 인간의 감정을 다층적으로 그려 냈다.",
            achievements: ["《햄릿》, 《리어 왕》", "154편의 소네트"]
        ),
        Author(
            id: "austen", name: "Jane Austen", koreanName: "제인 오스틴",
            birthYear: 1775, deathYear: 1817,
            occupation: "소설가", nationality: "영국",
            biography: "영국 시골 사회의 결혼과 계급을 섬세한 관찰과 유머로 그린 소설가다.",
            achievements: ["《오만과 편견》", "《에마》"]
        ),
        Author(
            id: "wilde", name: "Oscar Wilde", koreanName: "오스카 와일드",
            birthYear: 1854, deathYear: 1900,
            occupation: "작가 · 극작가", nationality: "아일랜드",
            biography: "재치 있는 경구로 유명한 작가로, 희곡과 소설에서 위선을 유쾌하게 꼬집었다.",
            achievements: ["《도리언 그레이의 초상》", "《진지함의 중요성》"]
        ),
        Author(
            id: "shaw", name: "George Bernard Shaw", koreanName: "조지 버나드 쇼",
            birthYear: 1856, deathYear: 1950,
            occupation: "극작가 · 비평가", nationality: "아일랜드",
            biography: "사회 문제를 풍자한 희곡을 남긴 작가로, 촌철살인의 문장으로 널리 인용된다.",
            achievements: ["1925년 노벨문학상 수상", "《피그말리온》"]
        ),
        Author(
            id: "woolf", name: "Virginia Woolf", koreanName: "버지니아 울프",
            birthYear: 1882, deathYear: 1941,
            occupation: "소설가 · 비평가", nationality: "영국",
            biography: "의식의 흐름 기법으로 내면을 그린 모더니즘 작가다. 여성의 독립적인 조건에 관한 글도 남겼다.",
            achievements: ["《댈러웨이 부인》", "《자기만의 방》"]
        ),
        Author(
            id: "dickens", name: "Charles Dickens", koreanName: "찰스 디킨스",
            birthYear: 1812, deathYear: 1870,
            occupation: "소설가", nationality: "영국",
            biography: "빅토리아 시대 런던의 빈곤과 인정을 함께 그린 소설가다.",
            achievements: ["《크리스마스 캐럴》", "《위대한 유산》"]
        ),
        Author(
            id: "tolstoy", name: "Leo Tolstoy", koreanName: "레프 톨스토이",
            birthYear: 1828, deathYear: 1910,
            occupation: "소설가 · 사상가", nationality: "러시아",
            biography: "대작 소설과 함께 도덕적 자기 성찰을 평생의 주제로 삼은 작가다.",
            achievements: ["《전쟁과 평화》", "《안나 카레니나》"]
        ),
        Author(
            id: "dostoevsky", name: "Fyodor Dostoevsky", koreanName: "표도르 도스토옙스키",
            birthYear: 1821, deathYear: 1881,
            occupation: "소설가", nationality: "러시아",
            biography: "인간 내면의 갈등과 신념을 깊이 파고든 소설가다.",
            achievements: ["《죄와 벌》", "《카라마조프가의 형제들》"]
        ),
        Author(
            id: "goethe", name: "Johann Wolfgang von Goethe", koreanName: "요한 볼프강 폰 괴테",
            birthYear: 1749, deathYear: 1832,
            occupation: "작가 · 정치인 · 과학자", nationality: "독일",
            biography: "독일 문학의 정점으로 꼽히는 작가이자 자연 연구자였다.",
            achievements: ["《파우스트》", "《젊은 베르테르의 슬픔》"]
        ),
        Author(
            id: "nietzsche", name: "Friedrich Nietzsche", koreanName: "프리드리히 니체",
            birthYear: 1844, deathYear: 1900,
            occupation: "철학자 · 문헌학자", nationality: "독일",
            biography: "기존 가치의 재평가를 주장한 철학자로, 삶을 긍정하는 태도를 강조했다.",
            achievements: ["《차라투스트라는 이렇게 말했다》", "《선악의 저편》"]
        ),
        Author(
            id: "camus", name: "Albert Camus", koreanName: "알베르 카뮈",
            birthYear: 1913, deathYear: 1960,
            occupation: "작가 · 철학자", nationality: "프랑스",
            biography: "부조리 속에서도 삶을 이어 가는 태도를 탐구한 작가다.",
            achievements: ["1957년 노벨문학상 수상", "《이방인》, 《페스트》"]
        ),
        Author(
            id: "saint_exupery", name: "Antoine de Saint-Exupéry", koreanName: "앙투안 드 생텍쥐페리",
            birthYear: 1900, deathYear: 1944,
            occupation: "작가 · 비행사", nationality: "프랑스",
            biography: "우편 비행사로 일하며 하늘과 인간의 관계를 쓴 작가다.",
            achievements: ["《어린 왕자》", "《인간의 대지》"]
        ),
        Author(
            id: "voltaire", name: "Voltaire", koreanName: "볼테르",
            birthYear: 1694, deathYear: 1778,
            occupation: "철학자 · 작가", nationality: "프랑스",
            biography: "계몽주의를 대표하는 문필가로, 관용과 표현의 자유를 옹호했다.",
            achievements: ["《캉디드》", "《철학사전》"]
        ),
        Author(
            id: "hippocrates", name: "Hippocrates", koreanName: "히포크라테스",
            birthYear: -460, deathYear: -370,
            occupation: "의사", nationality: "그리스",
            biography: "질병을 초자연적 원인이 아닌 자연적 원인으로 설명하려 한 고대 의학의 기초를 놓은 인물이다.",
            achievements: ["히포크라테스 선서", "임상 관찰 중심의 의학"]
        ),
        Author(
            id: "nightingale", name: "Florence Nightingale", koreanName: "플로렌스 나이팅게일",
            birthYear: 1820, deathYear: 1910,
            occupation: "간호사 · 통계학자", nationality: "영국",
            biography: "크림전쟁에서 위생 개혁을 이끌고 근대 간호학을 세운 인물이다. 통계로 보건 정책을 설득한 선구자이기도 하다.",
            achievements: ["근대 간호학 확립", "보건 통계 시각화의 개척"]
        ),
        Author(
            id: "schweitzer", name: "Albert Schweitzer", koreanName: "알베르트 슈바이처",
            birthYear: 1875, deathYear: 1965,
            occupation: "의사 · 신학자 · 음악가", nationality: "독일 · 프랑스",
            biography: "아프리카 랑바레네에서 병원을 세우고 평생 의료 활동을 했다.",
            achievements: ["1952년 노벨평화상 수상", "생명 외경 사상"]
        ),
        Author(
            id: "child", name: "Julia Child", koreanName: "줄리아 차일드",
            birthYear: 1912, deathYear: 2004,
            occupation: "요리연구가 · 방송인", nationality: "미국",
            biography: "프랑스 요리를 미국 가정에 소개한 요리연구가로, 실패를 두려워하지 말라는 태도로 사랑받았다.",
            achievements: ["《프랑스 요리 예술 익히기》", "TV 〈The French Chef〉"]
        ),
        Author(
            id: "brillat", name: "Jean Anthelme Brillat-Savarin", koreanName: "브리야사바랭",
            birthYear: 1755, deathYear: 1826,
            occupation: "법률가 · 미식 저술가", nationality: "프랑스",
            biography: "미식을 하나의 학문처럼 다룬 최초의 저술가로 꼽힌다.",
            achievements: ["《미식 예찬》", "근대 미식 비평의 출발"]
        ),
        Author(
            id: "bourdain", name: "Anthony Bourdain", koreanName: "앤서니 보데인",
            birthYear: 1956, deathYear: 2018,
            occupation: "요리사 · 작가 · 방송인", nationality: "미국",
            biography: "요리사 출신 작가로, 음식을 통해 세계의 삶을 기록한 방송을 만들었다.",
            achievements: ["《키친 컨피덴셜》", "〈Parts Unknown〉"]
        ),
        Author(
            id: "pollan", name: "Michael Pollan", koreanName: "마이클 폴란",
            birthYear: 1955, deathYear: nil,
            occupation: "저널리스트 · 저술가", nationality: "미국",
            biography: "먹거리와 농업의 관계를 취재해 온 저술가다.",
            achievements: ["《잡식동물의 딜레마》", "《행복한 밥상》"]
        ),
        Author(
            id: "jordan", name: "Michael Jordan", koreanName: "마이클 조던",
            birthYear: 1963, deathYear: nil,
            occupation: "농구선수", nationality: "미국",
            biography: "NBA 역사상 가장 영향력 있는 선수로 꼽히며, 실패를 성공의 재료로 이야기한 것으로 유명하다.",
            achievements: ["NBA 우승 6회", "올림픽 금메달 2회"]
        ),
        Author(
            id: "ali", name: "Muhammad Ali", koreanName: "무하마드 알리",
            birthYear: 1942, deathYear: 2016,
            occupation: "복싱선수 · 사회운동가", nationality: "미국",
            biography: "세 차례 헤비급 세계 챔피언에 오른 복서이자, 신념을 위해 목소리를 낸 인물이다.",
            achievements: ["헤비급 세계 챔피언 3회", "1960년 올림픽 금메달"]
        ),
        Author(
            id: "owens", name: "Jesse Owens", koreanName: "제시 오언스",
            birthYear: 1913, deathYear: 1980,
            occupation: "육상선수", nationality: "미국",
            biography: "1936년 베를린 올림픽에서 4관왕에 오른 육상선수다.",
            achievements: ["올림픽 금메달 4개", "인종차별에 맞선 상징적 승리"]
        ),
        Author(
            id: "navratilova", name: "Martina Navratilova", koreanName: "마르티나 나브라틸로바",
            birthYear: 1956, deathYear: nil,
            occupation: "테니스선수", nationality: "체코 · 미국",
            biography: "단식과 복식 모두에서 최정상에 오른 테니스 선수다.",
            achievements: ["윔블던 단식 9회 우승", "그랜드슬램 통산 59회 우승"]
        ),
        Author(
            id: "wooden", name: "John Wooden", koreanName: "존 우든",
            birthYear: 1910, deathYear: 2010,
            occupation: "농구 감독 · 교육자", nationality: "미국",
            biography: "UCLA를 이끈 전설적인 감독으로, 기술보다 준비와 인격을 먼저 가르쳤다.",
            achievements: ["NCAA 우승 10회", "'성공의 피라미드' 교육"]
        ),
        Author(
            id: "lombardi", name: "Vince Lombardi", koreanName: "빈스 롬바르디",
            birthYear: 1913, deathYear: 1970,
            occupation: "미식축구 감독", nationality: "미국",
            biography: "그린베이 패커스를 이끈 감독으로, 규율과 반복 훈련을 강조했다.",
            achievements: ["슈퍼볼 1·2회 우승", "롬바르디 트로피에 이름을 남김"]
        ),
        Author(
            id: "hepburn", name: "Audrey Hepburn", koreanName: "오드리 헵번",
            birthYear: 1929, deathYear: 1993,
            occupation: "배우 · 인도주의 활동가", nationality: "영국 · 벨기에",
            biography: "영화배우로 활동한 뒤 유니세프 친선대사로 아동 구호에 헌신했다.",
            achievements: ["아카데미 여우주연상", "유니세프 친선대사 활동"]
        ),
        Author(
            id: "oprah", name: "Oprah Winfrey", koreanName: "오프라 윈프리",
            birthYear: 1954, deathYear: nil,
            occupation: "방송인 · 기업인", nationality: "미국",
            biography: "토크쇼 진행자로 시작해 미디어 기업을 일군 방송인이다.",
            achievements: ["〈오프라 윈프리 쇼〉 25년 진행", "대통령 자유훈장 수훈"]
        ),
        Author(
            id: "obama_m", name: "Michelle Obama", koreanName: "미셸 오바마",
            birthYear: 1964, deathYear: nil,
            occupation: "변호사 · 작가", nationality: "미국",
            biography: "변호사 출신으로 미국의 퍼스트레이디를 지냈고, 아동 건강과 교육 캠페인을 이끌었다.",
            achievements: ["'Let's Move!' 캠페인", "《비커밍》"]
        ),
        Author(
            id: "rogers_f", name: "Fred Rogers", koreanName: "프레드 로저스",
            birthYear: 1928, deathYear: 2003,
            occupation: "방송인 · 교육자", nationality: "미국",
            biography: "어린이 프로그램을 통해 감정을 다루는 법을 가르친 진행자다.",
            achievements: ["〈Mister Rogers' Neighborhood〉", "대통령 자유훈장 수훈"]
        ),
        Author(
            id: "mead", name: "Margaret Mead", koreanName: "마거릿 미드",
            birthYear: 1901, deathYear: 1978,
            occupation: "인류학자", nationality: "미국",
            biography: "문화가 사람의 성장에 미치는 영향을 연구한 인류학자다.",
            achievements: ["《사모아의 청소년》", "문화인류학 대중화"]
        ),
        Author(
            id: "lewis", name: "C. S. Lewis", koreanName: "C. S. 루이스",
            birthYear: 1898, deathYear: 1963,
            occupation: "작가 · 문학연구자", nationality: "영국(아일랜드 출생)",
            biography: "옥스퍼드와 케임브리지에서 가르친 문학자이자 소설가다.",
            achievements: ["《나니아 연대기》", "《순전한 기독교》"]
        ),
        Author(
            id: "tolkien", name: "J. R. R. Tolkien", koreanName: "J. R. R. 톨킨",
            birthYear: 1892, deathYear: 1973,
            occupation: "작가 · 언어학자", nationality: "영국",
            biography: "고대 영어를 연구한 언어학자이자 현대 판타지 문학의 틀을 만든 작가다.",
            achievements: ["《반지의 제왕》", "《호빗》"]
        ),
        Author(
            id: "rowling", name: "J. K. Rowling", koreanName: "J. K. 롤링",
            birthYear: 1965, deathYear: nil,
            occupation: "소설가", nationality: "영국",
            biography: "해리 포터 시리즈로 세계에서 가장 널리 읽힌 작가 중 한 명이 되었다.",
            achievements: ["《해리 포터》 시리즈", "여러 아동 자선 활동"]
        ),
        Author(
            id: "picasso", name: "Pablo Picasso", koreanName: "파블로 피카소",
            birthYear: 1881, deathYear: 1973,
            occupation: "화가 · 조각가", nationality: "스페인",
            biography: "입체주의를 창시하고 평생 작업 방식을 바꿔 간 화가다.",
            achievements: ["〈게르니카〉", "입체주의 창시"]
        ),
        Author(
            id: "vangogh", name: "Vincent van Gogh", koreanName: "빈센트 반 고흐",
            birthYear: 1853, deathYear: 1890,
            occupation: "화가", nationality: "네덜란드",
            biography: "짧은 화가 생활 동안 강렬한 색채의 작품을 남긴 후기 인상주의 화가다.",
            achievements: ["〈별이 빛나는 밤〉", "동생에게 보낸 편지들"]
        ),
        Author(
            id: "beethoven", name: "Ludwig van Beethoven", koreanName: "루트비히 판 베토벤",
            birthYear: 1770, deathYear: 1827,
            occupation: "작곡가 · 피아니스트", nationality: "독일",
            biography: "청력을 잃어 가면서도 작곡을 이어 간 고전·낭만 전환기의 작곡가다.",
            achievements: ["교향곡 9번 〈합창〉", "피아노 소나타 32곡"]
        ),
        Author(
            id: "chanel", name: "Coco Chanel", koreanName: "코코 샤넬",
            birthYear: 1883, deathYear: 1971,
            occupation: "패션 디자이너", nationality: "프랑스",
            biography: "여성복을 단순하고 실용적인 형태로 바꾼 디자이너다.",
            achievements: ["리틀 블랙 드레스", "샤넬 하우스 설립"]
        ),
        Author(
            id: "anne_frank", name: "Anne Frank", koreanName: "안네 프랑크",
            birthYear: 1929, deathYear: 1945,
            occupation: "일기 작가", nationality: "독일 · 네덜란드",
            biography: "나치를 피해 은신하며 쓴 일기가 전쟁의 참상과 한 소녀의 내면을 함께 전한다.",
            achievements: ["《안네의 일기》"]
        ),
        Author(
            id: "dickinson", name: "Emily Dickinson", koreanName: "에밀리 디킨슨",
            birthYear: 1830, deathYear: 1886,
            occupation: "시인", nationality: "미국",
            biography: "생전에는 거의 발표하지 않았지만 1,800여 편의 시를 남긴 시인이다.",
            achievements: ["사후 출간된 시집", "미국 현대시에 끼친 영향"]
        ),
        Author(
            id: "cicero", name: "Cicero", koreanName: "키케로",
            birthYear: -106, deathYear: -43,
            occupation: "정치인 · 변론가 · 철학자", nationality: "로마",
            biography: "로마 공화정 말기의 변론가로, 라틴 산문의 표준을 만들었다.",
            achievements: ["《의무론》", "로마 수사학의 정점"]
        )
    ]

    /// id → Author 색인. 조회는 O(1).
    public static let byID: [String: Author] = Dictionary(
        all.map { ($0.id, $0) },
        uniquingKeysWith: { first, _ in first }
    )

    /// 없는 id 가 들어와도 크래시하지 않고 플레이스홀더를 돌려준다.
    public static func author(id: String) -> Author {
        byID[id] ?? .unknown
    }
}
