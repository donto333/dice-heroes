"""ElevenLabs로 효과음을 만든다. GitHub Actions(make-sfx.yml)에서만 돌린다.
키는 환경 변수 ELEVENLABS_API_KEY로 받고, 어디에도 찍지 않는다."""
import json, os, sys, time, urllib.request, urllib.error

key = os.environ.get("ELEVENLABS_API_KEY", "")
if not key:
    sys.exit("ELEVENLABS_API_KEY가 없습니다.")
only = set(filter(None, os.environ.get("ONLY", "").split(",")))
os.makedirs("out", exist_ok=True)
failed = 0
for sound in json.load(open("tools/sfx_prompts.json", encoding="utf-8"))["sounds"]:
    if only and sound["name"] not in only:
        continue
    body = json.dumps({"text": sound["text"], "duration_seconds": sound["seconds"], "prompt_influence": 0.5}).encode()
    request = urllib.request.Request(
        "https://api.elevenlabs.io/v1/sound-generation?output_format=mp3_44100_128", data=body,
        headers={"xi-api-key": key, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            data = response.read()
            open("out/%s.mp3" % sound["name"], "wb").write(data)
            print("만듦 %s: %d바이트, 비용 %s" % (sound["name"], len(data), response.headers.get("character-cost", "?")))
    except urllib.error.HTTPError as error:
        failed += 1
        print("실패 %s: %d %s" % (sound["name"], error.code, error.read().decode("utf-8", "replace")[:300]))
    time.sleep(1)
print("끝. 실패 %d개" % failed)
