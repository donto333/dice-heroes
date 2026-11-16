"""영웅 음성 대사표(data/voice_lines.json)를 만든다.
영웅마다 목소리(ElevenLabs 기본 제공 목소리)와 8가지 상황 대사를 정한다.
select(도감·대표 영웅 클릭)와 skill(어빌리티)은 영웅마다 직접 쓰고, 나머지는 성격 묶음에서 돌아가며 고른다."""
import json

V = {  # 목소리 이름 → id (모두 ElevenLabs 기본 제공/전문 성우 목소리. 복제 목소리는 쓰지 않는다)
 "kang": "8G6jifm9f1BhHXadvwOt", "mark": "cCwaxHZZF7rVaQK2aOys", "leesin": "3W5c5BG9zeaCYO9gC4v0",
 "harry": "SOYHLrjzK2X1ezoPC6cr", "adam": "pNInz6obpgDQGcFmaJgB", "jangho": "UmYoqGlufKxhJ6NCx5Mv",
 "dohyeon": "FQ3MuLxZh0jHcZmA5vW1", "deoksu": "IAETYMYM3nJvjnlkVTKI", "andy": "RlynaiseqcfHE3bZpqe4",
 "eden": "djgqDYFKEhIzR0zpgWY7", "juan": "hjCvGtSCRPyjYwe2lDf1", "bill": "pqHfZKP75CvOlQylNhV4",
 "george": "JBFqnCBsd6RMkjVDRZzb", "callum": "N2lVS1w4EtoT3dr4eOWO", "brian": "nPcz6obpgDQGcFmaJgB",
 "sujin": "9cino9hfS3ougiPeFvp1", "luna": "Ss1VfT7ri4lqnvTDWII0", "yooni": "n2fbxG88jqAoaVPUy3IG",
 "sena": "vJ170fCwESgE1tjW39So", "dain": "7kc4OBeoZqw3n2gxf0Bt", "hyunmi": "JxIGrv4AVuvbo1Dxzryu",
}
V["brian"] = "nPczCjzI2devNBz1zQrb"

SETS = {  # 성격 묶음: 상황마다 후보 여러 개. 영웅 순서에 따라 돌아가며 고른다.
 "warrior": {"idle": ["언제 싸우는가.", "몸이 근질거리는군.", "적은 어디 있나."], "move": ["간다!", "진격!", "앞으로!"],
             "attack": ["받아라!", "베어 주마!", "덤벼라!"], "defend": ["막아 낸다!", "어림없다!", "오너라!"],
             "win": ["승리다!", "이것이 실력이다.", "적수가 없군!"], "lose": ["분하다...", "다음엔 지지 않는다.", "크윽..."]},
 "sage": {"idle": ["다음 수를 생각하는 중이오.", "서두를 것 없소.", "흐름을 읽어야 하오."], "move": ["가 봅시다.", "한 걸음씩.", "길이 보이오."],
          "attack": ["수는 이미 읽었소.", "허점이 보이오!", "지금이오!"], "defend": ["예상한 대로요.", "침착하게.", "물러서지 않소."],
          "win": ["계산대로요.", "좋은 승부였소.", "지혜의 승리요."], "lose": ["내 수가 얕았소.", "다시 배워야겠소.", "허, 졌구려."]},
 "deity": {"idle": ["인간의 시간은 느리구나.", "기다려 주마.", "하늘이 지켜본다."], "move": ["길을 열어라.", "내가 간다.", "따르라."],
           "attack": ["심판을 받아라!", "무릎 꿇어라!", "힘을 보여 주마!"], "defend": ["닿지 못한다.", "감히!", "소용없다."],
           "win": ["당연한 결과다.", "하늘의 뜻이다.", "잘 싸웠다, 인간."], "lose": ["이럴 수가...", "방심했군.", "다음은 없다."]},
 "inventor": {"idle": ["좋은 생각이 날 것 같아요.", "잠깐, 계산 중입니다.", "흥미롭군요."], "move": ["출발합니다!", "실험 삼아 가 보죠.", "앞으로 가요!"],
              "attack": ["이건 어떻습니까!", "실험 시작!", "받아 보시죠!"], "defend": ["대비해 뒀습니다.", "막을 수 있어요!", "예상 범위입니다."],
              "win": ["성공입니다!", "실험은 대성공!", "해냈어요!"], "lose": ["실패도 공부죠.", "다시 해 보겠습니다.", "계산이 틀렸군요."]},
 "trickster": {"idle": ["심심한데.", "뭐 재밌는 일 없나?", "슬슬 움직여 볼까."], "move": ["가 볼까!", "따라와 봐!", "휙!"],
               "attack": ["잡았다!", "어디 보자!", "한 방 간다!"], "defend": ["어이쿠, 안 맞지!", "거기 아니야!", "헤헤, 막았다!"],
               "win": ["내가 이겼지!", "쉽네, 쉬워!", "한 판 더 할래?"], "lose": ["에이, 졌네.", "봐준 거야!", "다음엔 두고 봐."]},
 "gentle": {"idle": ["천천히 해요.", "기다리고 있을게요.", "마음을 가다듬어요."], "move": ["갈게요.", "함께 가요.", "조심히 가요."],
            "attack": ["물러서지 않아요!", "미안하지만, 갑니다!", "용기를 내요!"], "defend": ["지켜 낼게요.", "괜찮아요, 막을게요.", "버텨요!"],
            "win": ["우리가 해냈어요!", "모두 덕분이에요.", "잘 됐어요!"], "lose": ["다음엔 더 잘할게요.", "괜찮아요, 다시 해요.", "아쉬워요..."]},
}

H = [  # id, 목소리, 성격, 클릭 대사, 스킬 대사
 ("lubu", "mark", "warrior", "천하에 나를 막을 자 없다.", "천하무쌍!"),
 ("yisunsin", "kang", "sage", "신에게는 아직 열두 척의 배가 있소.", "학익진을 펼쳐라!"),
 ("alexander", "adam", "warrior", "세상 끝까지 가 보겠다.", "정복하라!"),
 ("machao", "deoksu", "warrior", "서량의 마초, 나간다!", "추격이다!"),
 ("eulji", "leesin", "sage", "살수의 물길은 내가 아오.", "계략에 걸렸소!"),
 ("leonidas", "harry", "warrior", "여기는 한 발도 못 지나간다.", "버텨라!"),
 ("hanxin", "juan", "sage", "병사는 많을수록 좋소.", "예기를 세워라!"),
 ("ganning", "callum", "trickster", "방울 소리 들리나? 내가 왔다.", "연달아 간다!"),
 ("choiyoung", "jangho", "warrior", "황금 보기를 돌같이 하라.", "철벽이다!"),
 ("robinhood", "andy", "trickster", "셔우드의 명궁, 여기 있지.", "잠깐 빌려 갈게!"),
 ("mulan", "yooni", "warrior", "아버지를 대신해 싸우겠어요.", "다시 일어선다!"),
 ("gyebaek", "brian", "warrior", "돌아갈 곳은 없다.", "물러서라!"),
 ("sejong", "eden", "sage", "백성을 위한 일이라면 무엇이든.", "훈민정음!"),
 ("zhugeliang", "dohyeon", "sage", "와룡이 깨어났소.", "팔진도를 펼치겠소."),
 ("davinci", "george", "inventor", "세상은 온통 궁금한 것투성이지요.", "만능 설계!"),
 ("zhouyu", "andy", "sage", "동남풍이 불어오는군.", "교란하라!"),
 ("jangyeongsil", "deoksu", "inventor", "하늘의 시간을 재어 보겠습니다.", "아는 것이 힘이지요!"),
 ("archimedes", "bill", "inventor", "유레카! 알아냈다!", "철벽의 원리!"),
 ("sunwu", "leesin", "sage", "싸우지 않고 이기는 것이 으뜸이오.", "계략이오!"),
 ("choichiwon", "juan", "sage", "글로 세상을 움직여 보겠소.", "학문의 힘이오."),
 ("libai", "callum", "trickster", "달 아래 한 잔, 시 한 수 어떤가.", "바람아 불어라!"),
 ("marcopolo", "andy", "trickster", "동방에는 놀라운 것이 많답니다.", "항해술!"),
 ("hypatia", "dain", "sage", "별의 길을 함께 읽어 봐요.", "모두 잊으세요."),
 ("seohui", "eden", "sage", "말 한마디로 땅을 지키겠소.", "힘을 내시오!"),
 ("zeus", "adam", "deity", "나는 천둥의 왕 제우스다.", "번개여, 내려라!"),
 ("wukong", "deoksu", "trickster", "제천대성 손오공 납신다!", "근두운아, 가자!"),
 ("dangun", "kang", "deity", "널리 인간을 이롭게 하라.", "홍익인간!"),
 ("athena", "hyunmi", "deity", "지혜가 승리를 이끕니다.", "가호를 내리노라."),
 ("heracles", "harry", "warrior", "열두 과업도 해냈다!", "맹공이다!"),
 ("gumiho", "sena", "trickster", "어머, 나한테 반했어?", "뒤를 조심해."),
 ("anubis", "dohyeon", "deity", "저승의 저울이 기다린다.", "두려워하라."),
 ("dokkaebi", "callum", "trickster", "금 나와라 뚝딱!", "되돌려 주마, 뚝딱!"),
 ("haetae", "jangho", "deity", "불과 재앙은 내가 막는다.", "버틴다!"),
 ("perseus", "andy", "warrior", "메두사도 내가 베었다.", "칼날을 받아라!"),
 ("tengu", "brian", "trickster", "산의 바람은 내 것이다.", "돌격!"),
 ("isis", "luna", "gentle", "생명의 숨결을 드릴게요.", "치유의 손길을."),
 ("tesla", "mark", "inventor", "미래는 나의 것입니다.", "번개 코일, 가동!"),
 ("nightingale", "sujin", "gentle", "등불은 꺼지지 않아요.", "모두 일어나세요!"),
 ("edison", "bill", "inventor", "천 번 실패해도 한 번 성공하면 됩니다.", "발명 완성!"),
 ("wright", "deoksu", "inventor", "오늘은 하늘을 날 겁니다!", "탐험 비행!"),
 ("amundsen", "juan", "warrior", "남극의 추위도 견뎠습니다.", "항로를 잡아라!"),
 ("verne", "george", "inventor", "상상한 것은 이루어집니다.", "책에서 읽었지요!"),
 ("pasteur", "eden", "gentle", "보이지 않는 적과 싸웁니다.", "축복이 있기를."),
 ("houdini", "callum", "trickster", "어떤 자물쇠도 나를 못 가두지!", "짜잔, 응급 처치!"),
 ("earhart", "yooni", "inventor", "하늘에는 한계가 없어요.", "전속력 질주!"),
 ("twain", "bill", "trickster", "이야기 하나 들려줄까?", "다시 시작해 볼까!"),
 ("fabre", "george", "gentle", "작은 것들을 가만히 들여다봐요.", "단단히 지켜요."),
 ("bangjeonghwan", "sujin", "gentle", "어린이는 내일의 희망이에요.", "모두 힘내요!"),
]
H[37] = ("nightingale", "sujin", "gentle", "등불은 꺼지지 않아요.", "모두 일어나세요!")
H[47] = ("bangjeonghwan", "deoksu", "gentle", "어린이는 내일의 희망이에요.", "모두 힘내요!")

KINDS = ["select", "idle", "move", "attack", "defend", "skill", "win", "lose"]
out = {"_comment": "영웅 음성 대사표. tools/make_voice_lines.py가 만든다. 소리 파일은 assets/audio/voice/<영웅 id>_<상황>.ogg. voice는 ElevenLabs 기본 제공 목소리 id.",
       "kinds": KINDS, "heroes": {}}
count = {}
for hero_id, voice, kind, select, skill in H:
    n = count.get(kind, 0)
    count[kind] = n + 1
    lines = {"select": select, "skill": skill}
    for situation, options in SETS[kind].items():
        lines[situation] = options[(n + KINDS.index(situation)) % len(options)]
    out["heroes"][hero_id] = {"voice": V[voice], "voice_name": voice, "lines": {k: lines[k] for k in KINDS}}
ids = [x["id"] for x in json.load(open("data/characters.json", encoding="utf-8"))["characters"]] if isinstance(json.load(open("data/characters.json", encoding="utf-8")), dict) else [x["id"] for x in json.load(open("data/characters.json", encoding="utf-8"))]
assert sorted(ids) == sorted(out["heroes"]), set(ids) ^ set(out["heroes"])
json.dump(out, open("data/voice_lines.json", "w", encoding="utf-8"), ensure_ascii=False, indent=1)
print(len(out["heroes"]), "명", sum(len(l) for h in out["heroes"].values() for l in h["lines"].values()), "자")
