"""손오공 새 목소리 후보 3차 남성 4개: v3 + 연기 지시, 한국어 고정, 대사마다 두 번 만들어 짧은 쪽."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("data/voice_lines.json", encoding="utf-8"))
hero = table["heroes"]["wukong"]
CANDS = {"gunju3": "7DefdtnPMJMn3TdLwgxE", "eden": "djgqDYFKEhIzR0zpgWY7", "hisc": "ykrB0QErM0FyPTtrQZFt", "kang": "8G6jifm9f1BhHXadvwOt"}
os.makedirs("out/b", exist_ok=True)
made = 0
for name, voice in CANDS.items():
    for kind in table["kinds"]:
        body = json.dumps({"text": "[젊은 남자 목소리로, 높고 경쾌하게, 장난꾸러기 원숭이처럼 까불까불 신나게, %s] %s" % (hero["tags"][kind], hero["lines"][kind]), "model_id": "eleven_v3",
                           "language_code": "ko", "voice_settings": {"stability": 0.5}}).encode()
        best = None
        for take in range(2):
            for attempt in range(4):
                try:
                    request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice,
                                                     data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
                    data = urllib.request.urlopen(request, timeout=180).read()
                    if best is None or len(data) < len(best):
                        best = data
                    break
                except Exception as error:
                    print("다시 시도 %s_%s: %s" % (name, kind, error))
                    time.sleep(6)
        if best:
            open("out/b/%s_%s.mp3" % (name, kind), "wb").write(best)
            made += 1
print("끝. 만든 것 %d개" % made)
