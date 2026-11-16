"""음성 시험판: 천하에서 쓰는 한국어 역할 목소리와 긴 대사로 영웅 5명을 두 가지 방식(A: multilingual_v2, B: v3+연기 지시)으로 만든다."""
import json, os, sys, time, urllib.request, urllib.error

key = os.environ.get("ELEVENLABS_API_KEY", "")
if not key:
    sys.exit("ELEVENLABS_API_KEY가 없습니다.")
table = json.load(open("tools/pilot_lines.json", encoding="utf-8"))
os.makedirs("out", exist_ok=True)
made = failed = cost = 0


def speak(name, voice, text, model, settings):
    global made, failed, cost
    body = json.dumps({"text": text, "model_id": model, "language_code": "ko", "voice_settings": settings}).encode()
    for attempt in range(3):
        request = urllib.request.Request(
            "https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice, data=body,
            headers={"xi-api-key": key, "Content-Type": "application/json"})
        try:
            with urllib.request.urlopen(request, timeout=180) as response:
                open("out/%s.mp3" % name, "wb").write(response.read())
                made += 1
                cost += int(response.headers.get("character-cost", "0") or 0)
            return
        except urllib.error.HTTPError as error:
            detail = error.read().decode("utf-8", "replace")[:300]
            if error.code == 429 and attempt < 2:
                time.sleep(6)
                continue
            if "language_code" in detail and "language_code" in json.loads(body):
                body = json.dumps({"text": text, "model_id": model, "voice_settings": settings}).encode()
                continue
            failed += 1
            print("실패 %s: %d %s" % (name, error.code, detail))
            return


for hero_id, hero in table["heroes"].items():
    for kind, line in hero["lines"].items():
        speak("%s_%s_A" % (hero_id, kind), hero["voice"], line["text"], "eleven_multilingual_v2",
              {"stability": 0.3, "similarity_boost": 0.85, "style": 0.6, "use_speaker_boost": True})
        speak("%s_%s_B" % (hero_id, kind), hero["voice"], "%s %s" % (line["tag"], line["text"]), "eleven_v3",
              {"stability": 0.0})
        time.sleep(0.3)
    print("영웅 %s 끝 (지금까지 %d개, 비용 %d)" % (hero_id, made, cost))
print("끝. 만든 것 %d개, 실패 %d개, 비용 %d자" % (made, failed, cost))
