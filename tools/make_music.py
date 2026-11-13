"""배경음악 두 곡을 코드로 작곡해 WAV로 만든다. (직접 만든 곡이라 저작권 걱정이 없다)

- bgm_lobby.wav: 로비·메뉴. D장조, 차분하고 웅장한 느낌, 20초 반복.
- bgm_match.wav: 대전. A단조, 빠르고 긴장감 있게, 15초 반복.
실행: python3 tools/make_music.py  →  assets/audio/
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio"
NOTE = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def freq(name, octave):
    n = NOTE[name] + 12 * (octave + 1)
    return 440.0 * 2 ** ((n - 69) / 12)


def env(length, attack=0.01, release=0.08):
    t = np.arange(length) / RATE
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    r = np.clip((length / RATE - t) / max(release, 1e-4), 0, 1)
    return a * r


def tone(f, dur, kind="sine", vol=0.2, attack=0.01, release=0.1, decay=0.0):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    phase = 2 * np.pi * f * t
    if kind == "sine":
        w = np.sin(phase)
    elif kind == "triangle":
        w = 2 / np.pi * np.arcsin(np.sin(phase))
    elif kind == "square":
        w = np.sign(np.sin(phase)) * 0.6
    elif kind == "pluck":
        w = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)
    else:
        w = np.sin(phase)
    e = env(n, attack, release)
    if decay > 0:
        e = e * np.exp(-t / decay)
    return w * e * vol


def mix(track, sound, at):
    start = int(at * RATE)
    end = min(len(track), start + len(sound))
    track[start:end] += sound[: end - start]


def chord_notes(root, quality, octave):
    steps = [0, 4, 7] if quality == "maj" else [0, 3, 7]
    base = NOTE[root] + 12 * (octave + 1)
    return [440.0 * 2 ** ((base + s - 69) / 12) for s in steps]


def noise(dur, vol, decay):
    n = int(dur * RATE)
    t = np.arange(n) / RATE
    rng = np.random.default_rng(3)
    return rng.uniform(-1, 1, n) * np.exp(-t / decay) * vol


def kick(vol=0.5):
    n = int(0.18 * RATE)
    t = np.arange(n) / RATE
    f = 120 * np.exp(-t * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 14) * vol


def lobby():
    bar = 2.5
    progression = [("D", "maj"), ("A", "maj"), ("B", "min"), ("G", "maj")] * 2
    total = bar * len(progression)
    track = np.zeros(int(total * RATE) + RATE)
    melody = [
        [("F#", 5, 0, 1), ("A", 5, 1, 1), ("D", 6, 2, 2)],
        [("C#", 6, 0, 1.5), ("A", 5, 1.5, 0.5), ("E", 5, 2, 2)],
        [("D", 6, 0, 1), ("B", 5, 1, 1), ("F#", 5, 2, 2)],
        [("G", 5, 0, 1), ("A", 5, 1, 1), ("B", 5, 2, 1), ("A", 5, 3, 1)],
        [("F#", 5, 0, 1), ("A", 5, 1, 1), ("D", 6, 2, 1.5), ("E", 6, 3.5, 0.5)],
        [("E", 6, 0, 2), ("C#", 6, 2, 2)],
        [("D", 6, 0, 1), ("F#", 6, 1, 1), ("E", 6, 2, 1), ("D", 6, 3, 1)],
        [("B", 5, 0, 1), ("A", 5, 1, 1), ("D", 6, 2, 2)],
    ]
    beat = bar / 4
    for i, (root, quality) in enumerate(progression):
        t0 = i * bar
        notes = chord_notes(root, quality, 4)
        for f in notes:
            mix(track, tone(f, bar, "triangle", 0.05, attack=0.4, release=0.6), t0)
        mix(track, tone(freq(root, 2), bar, "triangle", 0.16, attack=0.02, release=0.3), t0)
        arp = notes + [notes[1] * 2]
        for k in range(8):
            mix(track, tone(arp[k % 4] * 2, beat / 2, "pluck", 0.045, attack=0.005, release=0.1, decay=0.25), t0 + k * beat / 2)
        for name, octave, start, length in melody[i]:
            mix(track, tone(freq(name, octave), length * beat, "sine", 0.09, attack=0.03, release=0.2), t0 + start * beat)
    return track[: int(total * RATE)]


def battle():
    bar = 1.875
    progression = [("A", "min"), ("F", "maj"), ("C", "maj"), ("G", "maj")] * 2
    total = bar * len(progression)
    track = np.zeros(int(total * RATE) + RATE)
    eighth = bar / 8
    riff = [0, 0, 2, 0, 1, 0, 2, 1]
    lead = [
        [("E", 5, 0, 2), ("A", 5, 2, 2), ("C", 6, 4, 2), ("B", 5, 6, 2)],
        [("A", 5, 0, 3), ("F", 5, 3, 1), ("A", 5, 4, 4)],
        [("G", 5, 0, 2), ("E", 5, 2, 2), ("G", 5, 4, 2), ("C", 6, 6, 2)],
        [("B", 5, 0, 4), ("D", 6, 4, 4)],
        [("E", 6, 0, 2), ("D", 6, 2, 2), ("C", 6, 4, 2), ("B", 5, 6, 2)],
        [("C", 6, 0, 3), ("A", 5, 3, 1), ("F", 5, 4, 4)],
        [("G", 5, 0, 2), ("C", 6, 2, 2), ("E", 6, 4, 4)],
        [("D", 6, 0, 2), ("B", 5, 2, 2), ("G", 5, 4, 2), ("B", 5, 6, 2)],
    ]
    for i, (root, quality) in enumerate(progression):
        t0 = i * bar
        notes = chord_notes(root, quality, 4)
        for k in range(8):
            mix(track, tone(freq(root, 2), eighth * 0.9, "square", 0.07, attack=0.003, release=0.04), t0 + k * eighth)
            mix(track, tone(notes[riff[k]] * 2, eighth * 0.8, "pluck", 0.04, attack=0.003, release=0.05, decay=0.12), t0 + k * eighth)
            mix(track, noise(0.05, 0.035, 0.015), t0 + k * eighth)
        for k in range(4):
            mix(track, kick(0.3), t0 + k * 2 * eighth)
        mix(track, noise(0.15, 0.06, 0.05), t0 + 2 * eighth)
        mix(track, noise(0.15, 0.06, 0.05), t0 + 6 * eighth)
        for name, octave, start, length in lead[i]:
            mix(track, tone(freq(name, octave), length * eighth, "triangle", 0.08, attack=0.01, release=0.08), t0 + start * eighth)
    return track[: int(total * RATE)]


def save(name, track):
    peak = np.max(np.abs(track)) or 1.0
    data = (track / peak * 0.8 * 32767).astype(np.int16)
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())
    print("저장:", OUT / name, f"{len(data) / RATE:.1f}초")


if __name__ == "__main__":
    save("bgm_lobby.wav", lobby())
    save("bgm_match.wav", battle())
