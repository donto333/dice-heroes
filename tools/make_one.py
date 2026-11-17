"""레오니다스·손오공 음성 다시 만들기: v3 + 연기 지시, 안정도 0.5. 상황마다 두 번 만들어 짧은 쪽을 남긴다(늘어짐 방지)."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("data/voice_lines.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for hero_id in ["leonidas", "wukong"]:
    hero = table["heroes"][hero_id]
    for kind in table["kinds"]:
        body = json.dumps({"text": "[%s] %s" % (hero["tags"][kind], hero["lines"][kind]), "model_id": "eleven_v3",
                           "language_code": "ko", "voice_settings": {"stability": 0.5}}).encode()
        best = None
        for take in range(2):
            for attempt in range(4):
                try:
                    request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % hero["voice"],
                                                     data=body, headers={"xi-api-key": key, "Content-Type": "application/json"})
                    data = urllib.request.urlopen(request, timeout=180).read()
                    if best is None or len(data) < len(best):
                        best = data
                    break
                except Exception as error:
                    print("다시 시도 %s_%s: %s" % (hero_id, kind, error))
                    time.sleep(6)
        if best:
            open("out/b/%s_%s.mp3" % (hero_id, kind), "wb").write(best)
            made += 1
print("끝. 만든 것 %d개" % made)
