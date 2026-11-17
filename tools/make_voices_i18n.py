"""영웅·안내·적 음성을 영어·베트남어로 만든다(GitHub Actions에서만 돌린다). 키는 찍지 않는다.
대사는 data/voice_i18n.json, 목소리는 한국어 음성과 같은 것(data/voice_lines.json·voice_extra.json).
결과: out/<언어>/<id>_<상황>.mp3. v3 + 연기 지시 + 언어 고정, 안정도 0.5. ONLY=언어 하나만(en/vi), PICK=일부만."""
import json, os, sys, time, threading, urllib.request
from concurrent.futures import ThreadPoolExecutor

key = os.environ.get("ELEVENLABS_API_KEY", "")
if not key:
    sys.exit("ELEVENLABS_API_KEY가 없습니다.")
tr = json.load(open("data/voice_i18n.json", encoding="utf-8"))
voices = {h: v["voice"] for h, v in json.load(open("data/voice_lines.json", encoding="utf-8"))["heroes"].items()}
voices.update({h: v["voice"] for h, v in json.load(open("data/voice_extra.json", encoding="utf-8"))["heroes"].items()})
ENEMY_TAGS = {"enemy_gate": "stern, booming", "enemy_boss": "low, imposing", "enemy_keeper": "rough, cocky", "enemy_monster": "monstrous roar"}
## PICK=en:lubu_select,vi:announcer_n_lose 처럼 적으면 그것만 다시 만든다.
pick = set(x for x in os.environ.get("PICK", "").split(",") if x)
langs = [x for x in os.environ.get("ONLY", "en,vi").split(",") if x]
lock = threading.Lock()
count = {"made": 0, "failed": 0}


def tag_of(who, kind):
    if who in tr["tags"]:
        return tr["tags"][who][kind]
    if who.startswith("announcer"):
        return "calm and a little disappointed announcer" if kind == "lose" else "energetic sports announcer, clear and powerful"
    return ENEMY_TAGS.get(who, "")


def speak(job):
    lang, who, kind, text = job
    body = json.dumps({"text": "[%s] %s" % (tag_of(who, kind), text), "model_id": "eleven_v3", "language_code": lang,
                       "voice_settings": {"stability": 0.5}}).encode()
    for attempt in range(5):
        try:
            req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voices[who],
                                         data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
            data = urllib.request.urlopen(req, timeout=180).read()
            open("out/%s/%s_%s.mp3" % (lang, who, kind), "wb").write(data)
            with lock:
                count["made"] += 1
            return
        except Exception as error:
            time.sleep(6 * (attempt + 1))
            last = error
    with lock:
        count["failed"] += 1
    print("실패 %s %s_%s: %s" % (lang, who, kind, last))


jobs = []
for lang in langs:
    os.makedirs("out/" + lang, exist_ok=True)
    for who, table in tr[lang].items():
        for kind, text in table.items():
            if pick and "%s:%s_%s" % (lang, who, kind) not in pick:
                continue
            jobs.append((lang, who, kind, text))
with ThreadPoolExecutor(max_workers=4) as pool:
    list(pool.map(speak, jobs))
print("끝. 만든 것 %d개, 실패 %d개" % (count["made"], count["failed"]))
