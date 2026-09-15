"""Original Pocket Kin sound design. No samples or external audio sources.
Run from the repository root: python tools/generate_audio.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 22050
OUT = Path(__file__).resolve().parents[1] / 'game' / 'assets'

def note(buffer, start, duration, midi, volume=.15):
    frequency = 440 * 2 ** ((midi - 69) / 12)
    begin = int(start * RATE)
    for i in range(int(duration * RATE)):
        t = i / RATE
        envelope = min(1, t / .035) * math.exp(-t * 2.4 / duration) * min(1, (duration - t) / .1)
        sample = (math.sin(2 * math.pi * frequency * t) + .18 * math.sin(4 * math.pi * frequency * t)) * envelope * volume
        if begin + i < len(buffer): buffer[begin + i] += sample

def save(name, buffer):
    with wave.open(str(OUT / name), 'wb') as stream:
        stream.setnchannels(1); stream.setsampwidth(2); stream.setframerate(RATE)
        stream.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, x)) * 26000)) for x in buffer))

def melody(name, notes, spacing, tail=1):
    samples = [0.] * int((len(notes) * spacing + tail) * RATE)
    for index, midi in enumerate(notes): note(samples, index * spacing, tail, midi)
    save(name, samples)

if __name__ == '__main__':
    OUT.mkdir(parents=True, exist_ok=True)
    melody('tap.wav', [79], .08, .18)
    melody('care.wav', [72, 76, 79], .12, .6)
    melody('hatch.wav', [60, 64, 67, 72, 79], .16, 1.2)
    melody('reward.wav', [72, 79, 84], .15, .9)
    melody('sleep.wav', [79, 76, 72, 67], .25, 1.5)
    melody('bubble.wav', [76, 83, 88], .06, .25)
    melody('munch.wav', [74, 81], .08, .22)
    melody('purr.wav', [64, 67, 72], .12, .5)
    # A complete 32-second four-chord music-box phrase, fading into silence
    # at the loop boundary, rather than cutting through a sustained note.
    samples = [0.] * (32 * RATE)
    chords = [(48, 55, 60, 64), (45, 52, 57, 60), (41, 48, 53, 57), (43, 50, 55, 59)]
    tune = [72, 76, 79, 76, 74, 72, 69, 72, 72, 77, 76, 72, 71, 74, 79, 74]
    for bar, chord in enumerate(chords):
        for j, midi in enumerate(chord): note(samples, bar * 8 + j * .35, 5.5, midi, .055)
    for i, midi in enumerate(tune): note(samples, i * 1.8 + .5, 1.7, midi, .08)
    save('ambient.wav', samples)
    print('Generated nine original audio files.')
