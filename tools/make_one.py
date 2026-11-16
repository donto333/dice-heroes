"""tools/voice_redo.txt에 적힌 음성(영웅id_상황)만 A 방식으로, 더 안정된 설정으로 다시 만든다."""
import json, os, sys, time, urllib.request, urllib.error
key = os.environ["ELEVENLABS_API_KEY"]
table = json.load(open("data/voice_lines.json", encoding="utf-8"))["heroes"]
os.makedirs("out/a", exist_ok=True)
for name in open("tools/voice_redo.txt", encoding="utf-8").read().split():
    hero_id, kind = name.rsplit("_", 1)
    hero = table[hero_id]
    body = json.dumps({"text": hero["lines"][kind], "model_id": "eleven_multilingual_v2",
                       "voice_settings": {"stability": 0.6, "similarity_boost": 0.8, "style": 0.25, "use_speaker_boost": True}}).encode()
    for attempt in range(3):
        try:
            request = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % hero["voice"], data=body,
                                             headers={"xi-api-key": key, "Content-Type": "application/json"})
            open("out/a/%s.mp3" % name, "wb").write(urllib.request.urlopen(request, timeout=180).read())
            break
        except Exception as error:
            print("다시 시도 %s: %s" % (name, error))
            time.sleep(6)
print("끝")
