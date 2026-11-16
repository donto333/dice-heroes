"""고쳐 달라고 한 음성만 다시 만든다(v3 + 연기 지시, 안정도 0.5). REDO: 영웅 id → 상황 목록(빈 목록이면 8개 모두)."""
import json, os, time, urllib.request
REDO = {"sejong": ["attack"], "athena": ["defend"], "heracles": [], "haetae": [], "tengu": [], "fabre": [],
        "zhugeliang": [], "zhouyu": [], "jangyeongsil": []}
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("data/voice_lines.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for hero_id, kinds in REDO.items():
    hero = table["heroes"][hero_id]
    for kind in (kinds or table["kinds"]):
        body = json.dumps({"text": "[%s] %s" % (hero["tags"][kind], hero["lines"][kind]), "model_id": "eleven_v3",
                           "voice_settings": {"stability": 0.5}}).encode()
        for attempt in range(4):
            try:
                request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % hero["voice"], data=body,
                                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
                open("out/b/%s_%s.mp3" % (hero_id, kind), "wb").write(urllib.request.urlopen(request, timeout=180).read())
                made += 1
                break
            except Exception as error:
                print("다시 시도 %s_%s: %s" % (hero_id, kind, error))
                time.sleep(6)
print("끝. 만든 것 %d개" % made)
