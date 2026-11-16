"""안내 음성 N(Yooni·문장 대사)을 더 정확한 발음으로 다시 만든다: v3, 안정도 1.0, 한국어 고정."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("tools/extra_e.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
for kind, text in table["long"].items():
    payload = {"text": "[방송 아나운서처럼 또박또박, 정확한 표준 한국어 발음으로] %s" % text, "model_id": "eleven_v3", "language_code": "ko", "voice_settings": {"stability": 1.0}}
    for attempt in range(4):
        try:
            request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/n2fbxG88jqAoaVPUy3IG?output_format=mp3_44100_128",
                                             data=json.dumps(payload).encode(), headers={"xi-api-key": key, "Content-Type": "application/json"})
            open("out/b/announcer_n_%s.mp3" % kind, "wb").write(urllib.request.urlopen(request, timeout=180).read())
            made += 1
            break
        except Exception as error:
            print("다시 시도 %s: %s" % (kind, error))
            time.sleep(6)
print("끝. 만든 것 %d개" % made)
