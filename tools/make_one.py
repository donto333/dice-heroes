"""남은 사용량과 목소리 목록(이름·종류·언어)만 찍는다. 글자 사용 없음."""
import json, os, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
def get(url):
    return json.load(urllib.request.urlopen(urllib.request.Request(url, headers={"xi-api-key": key}), timeout=60))
s = get("https://api.elevenlabs.io/v1/user/subscription")
print("PLAN", s.get("tier"), s.get("character_count"), "/", s.get("character_limit"), "reset", s.get("next_character_count_reset_unix"))
for v in get("https://api.elevenlabs.io/v1/voices").get("voices", []):
    l = v.get("labels", {}) or {}
    langs = ",".join(x.get("language", "") for x in (v.get("verified_languages") or []))[:60]
    print("VOICE", v["voice_id"], v.get("category"), v["name"][:30], l.get("gender", ""), l.get("age", ""), l.get("accent", ""), l.get("language", ""), "|", langs)
os.makedirs("out", exist_ok=True)
open("out/ok.txt", "w").write("ok")
