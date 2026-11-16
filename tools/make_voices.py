"""ElevenLabs로 영웅 음성을 만든다(GitHub Actions에서만 돌린다). 키는 찍지 않는다.
data/voice_lines.json의 대사를 out/<영웅 id>_<상황>.mp3로 만든다. ONLY=영웅id,영웅id 로 일부만 만들 수 있다."""
import json, os, sys, time, urllib.request, urllib.error

key = os.environ.get("ELEVENLABS_API_KEY", "")
if not key:
    sys.exit("ELEVENLABS_API_KEY가 없습니다.")
only = set(filter(None, os.environ.get("ONLY", "").split(",")))
table = json.load(open(os.environ.get("VOICE_TABLE", "data/voice_lines.json"), encoding="utf-8"))
os.makedirs("out", exist_ok=True)
made = failed = cost = 0
for hero_id, hero in table["heroes"].items():
    if only and hero_id not in only:
        continue
    for kind, text in hero["lines"].items():
        body = json.dumps({"text": text, "model_id": "eleven_multilingual_v2",
                           "voice_settings": {"stability": 0.4, "similarity_boost": 0.8, "style": 0.35, "use_speaker_boost": True}}).encode()
        request = urllib.request.Request(
            "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % hero["voice"], data=body,
            headers={"xi-api-key": key, "Content-Type": "application/json"})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=120) as response:
                    open("out/%s_%s.mp3" % (hero_id, kind), "wb").write(response.read())
                    made += 1
                    cost += int(response.headers.get("character-cost", "0") or 0)
                break
            except urllib.error.HTTPError as error:
                detail = error.read().decode("utf-8", "replace")[:200]
                if error.code == 429 and attempt < 2:
                    time.sleep(5)
                    continue
                failed += 1
                print("실패 %s_%s: %d %s" % (hero_id, kind, error.code, detail))
                break
        time.sleep(0.3)
    print("영웅 %s 끝 (지금까지 %d개, 비용 %d)" % (hero_id, made, cost))
print("끝. 만든 것 %d개, 실패 %d개, 비용 %d자" % (made, failed, cost))
