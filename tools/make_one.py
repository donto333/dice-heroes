"""언어별 음성 시험판: 영웅 5명 × 대사 3개, 안내 음성 4개를 영어·베트남어로.
A = 영어 원어 목소리(premade), B = 지금 한국어 캐릭터 목소리 그대로. v3 + 연기 지시 + 언어 고정."""
import json, os, time, urllib.request
key = os.environ["ELEVENLABS_API_KEY"]
d = json.load(open("tools/pilot_lang.json", encoding="utf-8"))
os.makedirs("out/b", exist_ok=True)
made = 0
def speak(path, voice, text, lang):
    global made
    body = json.dumps({"text": text, "model_id": "eleven_v3", "language_code": lang, "voice_settings": {"stability": 0.5}}).encode()
    for attempt in range(4):
        try:
            req = urllib.request.Request("https://api.elevenlabs.io/v1/text-to-speech/%s?output_format=mp3_44100_128" % voice, data=body,
                                         headers={"xi-api-key": key, "Content-Type": "application/json"})
            open(path, "wb").write(urllib.request.urlopen(req, timeout=180).read())
            made += 1
            return
        except Exception as error:
            print("다시 시도 %s: %s" % (path, error))
            time.sleep(6)
PICK = {"select": 0, "attack": 3, "win": 6}
for hid, h in d["heroes"].items():
    for kind, i in PICK.items():
        for lang in ("en", "vi"):
            tag, text = h[lang][i]
            for way, voice in (("a", h["en_native"]), ("b", h["ko_voice"])):
                speak("out/b/%s_%s_%s_%s.mp3" % (hid, kind, lang, way), voice, "[%s] %s" % (tag, text), lang)
a = d["announcer"]
for i, kind in enumerate(a["kinds"]):
    if kind not in ("start", "turn", "battle", "win"):
        continue
    for lang, tag in (("en", "energetic sports announcer, clear and powerful"), ("vi", "bình luận viên thể thao, rõ ràng và mạnh mẽ")):
        for way, voice in (("a", a["en_native"]), ("b", a["ko_voice"])):
            speak("out/b/announcer_%s_%s_%s.mp3" % (kind, lang, way), voice, "[%s] %s" % (tag, a[lang][i]), lang)
print("끝. 만든 것 %d개" % made)
