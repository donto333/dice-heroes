"""안내·적 음성 B안: tools/extra_b.json을 v3 + 연기 지시로 만든다(out/b/<id>_<상황>.mp3)."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("tools/extra_b.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for who, spec in table.items():
    for kind, text in spec["lines"].items():
        tag = spec.get("tags", {}).get(kind, spec.get("tag", ""))
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
