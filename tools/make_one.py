"""안내 음성·관문지기 새 후보(D·E·F): tools/extra_c.json을 v3 + 연기 지시로 만든다."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("tools/extra_c.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for who, spec in table.items():
    if who == "lines":
        continue
    base = who.rsplit("_", 1)[0]
    for kind, text in table["lines"][base].items():
        tag = spec.get("tags", {}).get(kind, spec.get("tag", ""))
        if base == "announcer" and kind == "lose":
            tag = "아쉬워하며 힘이 빠져서"
        body = json.dumps({"text": "[%s] %s" % (tag, text), "model_id": "eleven_v3", "voice_settings": {"stability": 0.5}}).encode()
        for attempt in range(4):
            try:
                request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % spec["voice"], data=body,
                                                 headers={"xi-api-key": key, "Content-Type": "application/json"})
                open("out/b/%s_%s.mp3" % (who, kind), "wb").write(urllib.request.urlopen(request, timeout=180).read())
                made += 1
                break
            except Exception as error:
                print("다시 시도 %s_%s: %s" % (who, kind, error))
                time.sleep(6)
print("끝. 만든 것 %d개" % made)
