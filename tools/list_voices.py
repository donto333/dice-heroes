"""ElevenLabs 계정에서 쓸 수 있는 목소리 목록을 찍는다(이름·성별·나이·억양·id). 키는 찍지 않는다."""
import json, os, urllib.request
request = urllib.request.Request("https://api.elevenlabs.io/v2/voices?page_size=100", headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"]})
data = json.load(urllib.request.urlopen(request, timeout=60))
for voice in data.get("voices", []):
    labels = voice.get("labels") or {}
    print("VOICE %s | %s | %s | %s | %s | %s | %s" % (voice.get("voice_id"), voice.get("name"), labels.get("gender"), labels.get("age"), labels.get("accent"), labels.get("description") or labels.get("descriptive"), voice.get("category")))
request = urllib.request.Request("https://api.elevenlabs.io/v1/user/subscription", headers={"xi-api-key": os.environ["ELEVENLABS_API_KEY"]})
try:
    sub = json.load(urllib.request.urlopen(request, timeout=60))
    print("PLAN %s 사용 %s / %s" % (sub.get("tier"), sub.get("character_count"), sub.get("character_limit")))
except Exception as error:
    print("PLAN 확인 실패", error)
