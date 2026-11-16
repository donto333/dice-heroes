"""안내 음성 아나운서풍 후보(K~O): tools/extra_e.json, v3 + 연기 지시 + 언어 고정(ko)."""
import json, os, time, urllib.request, urllib.error
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("tools/extra_e.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for who, spec in table["cands"].items():
    for kind, text in table[spec["set"]].items():
        tag = "방송 아나운서처럼 또렷하게, 차분하고 아쉬운 어조로" if kind == "lose" else table["tag"]
        payload = {"text": "[%s] %s" % (tag, text), "model_id": "eleven_v3", "language_code": "ko", "voice_settings": {"stability": 0.5}}
        for attempt in range(4):
            try:
                request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % spec["voice"],
                                                 data=json.dumps(payload).encode(), headers={"xi-api-key": key, "Content-Type": "application/json"})
                open("out/b/announcer_%s_%s.mp3" % (who, kind), "wb").write(urllib.request.urlopen(request, timeout=180).read())
                made += 1
                break
            except Exception as error:
                print("다시 시도 %s_%s: %s" % (who, kind, error))
                time.sleep(6)
print("끝. 만든 것 %d개" % made)
