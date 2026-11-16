"""안내 음성 새 후보(G~J): D안의 경쾌한 말투를 한국어 발음으로. tools/extra_d.json, v3 + 연기 지시 + 언어 고정(ko)."""
import json, os, time, urllib.request, urllib.error
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("tools/extra_d.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for who, spec in table.items():
    if who in ("lines", "tag"):
        continue
    for kind, text in table["lines"].items():
        tag = "아쉬워하며 힘이 빠져서" if kind == "lose" else table["tag"]
        payload = {"text": "[%s] %s" % (tag, text), "model_id": "eleven_v3", "language_code": "ko", "voice_settings": {"stability": 0.5}}
        for attempt in range(4):
            try:
                request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % spec["voice"],
                                                 data=json.dumps(payload).encode(), headers={"xi-api-key": key, "Content-Type": "application/json"})
                open("out/b/%s_%s.mp3" % (who, kind), "wb").write(urllib.request.urlopen(request, timeout=180).read())
                made += 1
                break
            except urllib.error.HTTPError as error:
                detail = error.read().decode("utf-8", "replace")[:200]
                print("다시 시도 %s_%s: %d %s" % (who, kind, error.code, detail))
                if "language" in detail:
                    payload.pop("language_code", None)
                time.sleep(4)
            except Exception as error:
                print("다시 시도 %s_%s: %s" % (who, kind, error))
                time.sleep(6)
print("끝. 만든 것 %d개" % made)
