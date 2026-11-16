"""ElevenLabs로 영웅 음성을 만든다(GitHub Actions에서만 돌린다). 키는 찍지 않는다.
data/voice_lines.json의 대사를 두 방식으로 만든다.
  out/a/<영웅 id>_<상황>.mp3 : multilingual_v2
  out/b/<영웅 id>_<상황>.mp3 : v3 + 연기 지시(tags)
ONLY=영웅id,영웅id 로 일부만, STYLES=a 또는 b 로 한 방식만 만들 수 있다."""
import json, os, sys, time, threading, urllib.request, urllib.error
from concurrent.futures import ThreadPoolExecutor

key = os.environ.get("ELEVENLABS_API_KEY", "")
if not key:
    sys.exit("ELEVENLABS_API_KEY가 없습니다.")
only = set(filter(None, os.environ.get("ONLY", "").split(",")))
styles = set(filter(None, os.environ.get("STYLES", "b").split(",")))
table = json.load(open(os.environ.get("VOICE_TABLE", "data/voice_lines.json"), encoding="utf-8"))
lock = threading.Lock()
count = {"made": 0, "failed": 0, "cost": 0}


def speak(path, voice, text, model, settings):
    body = json.dumps({"text": text, "model_id": model, "voice_settings": settings}).encode()
    for attempt in range(4):
        request = urllib.request.Request(
            "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice, data=body,
            headers={"xi-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                open(path, "wb").write(response.read())
                with lock:
                    count["made"] += 1
                    count["cost"] += int(response.headers.get("character-cost", "0") or 0)
            return
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:200]
            if error.code in (429, 500, 502, 503) and attempt < 3:
                time.sleep(6 * (attempt + 1))
                continue
            with lock:
                count["failed"] += 1
            print("실패 %s: %d %s" % (path, error.code, detail))
            return
        except Exception as error:
            if attempt < 3:
                time.sleep(5)
                continue
            with lock:
                count["failed"] += 1
            print("실패 %s: %s" % (path, error))
            return


jobs = []
for hero_id, hero in table["heroes"].items():
    if only and hero_id not in only:
        continue
    for kind, text in hero["lines"].items():
        if "a" in styles:
            jobs.append(("out/a/%s_%s.mp3" % (hero_id, kind), hero["voice"], text, "eleven_multilingual_v2",
                         {"stability": 0.3, "similarity_boost": 0.85, "style": 0.6, "use_speaker_boost": True}))
        if "b" in styles:
            tag = hero.get("tags", {}).get(kind, "")
            jobs.append(("out/b/%s_%s.mp3" % (hero_id, kind), hero["voice"], ("[%s] %s" % (tag, text)) if tag else text,
                         "eleven_v3", {"stability": 0.0}))
os.makedirs("out/a", exist_ok=True)
os.makedirs("out/b", exist_ok=True)
with ThreadPoolExecutor(max_workers=3) as pool:
    list(pool.map(lambda job: speak(*job), jobs))
print("끝. 만든 것 %d개, 실패 %d개, 비용 %d자" % (count["made"], count["failed"], count["cost"]))
