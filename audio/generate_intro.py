#!/usr/bin/env python3
"""Irina Baikal audio v0.7: original cosmic music and clearer Russian TTS.

Synthetic eSpeak voice is NOT a realistic whispered human recording.
Usage: python audio/generate_intro.py --output irina_intro.wav
Optional licensed voice WAV: --voice-wav sample.wav
"""
from __future__ import annotations
import argparse
import subprocess
import tempfile
import wave
from math import gcd
from pathlib import Path

import numpy as np
from scipy.signal import butter, resample_poly, sosfilt

SR = 44100
START = 2.25
TAIL = 2.2
MIN_DURATION = 10.7
PARTS = ('Ирина Байкал.', 'Систем один точка ноль.')


def band(x, lo=None, hi=None):
    if lo and hi:
        kind, freq = 'bandpass', (lo, hi)
    elif lo:
        kind, freq = 'highpass', lo
    else:
        kind, freq = 'lowpass', hi
    return sosfilt(butter(3, freq, btype=kind, fs=SR, output='sos'), x)


def load_voice_wav(path):
    with wave.open(str(path), 'rb') as f:
        rate, chan, width = f.getframerate(), f.getnchannels(), f.getsampwidth()
        frames = f.readframes(f.getnframes())
    if width != 2:
        raise ValueError('WAV must contain 16-bit signed PCM samples')
    x = np.frombuffer(frames, dtype='<i2').astype(np.float64) / 32768
    if chan > 1:
        x = x.reshape(-1, chan).mean(axis=1)
    if rate != SR:
        g = gcd(rate, SR)
        x = resample_poly(x, SR // g, rate // g)
    return np.asarray(x, dtype=np.float64)


def trim_silence(x, threshold=0.009, padding_sec=.11):
    # Preserve first/last consonants: remove only silence with added padding.
    frame = int(.02 * SR)
    if len(x) < frame:
        return x
    absamp = np.maximum.reduceat(np.abs(x), np.arange(0, len(x), frame))
    valid = np.flatnonzero(absamp > threshold)
    if len(valid) == 0:
        return x
    pad = int(padding_sec * SR)
    first = max(0, int(valid[0] * frame) - pad)
    last = min(len(x), int((valid[-1] + 1) * frame) + pad)
    return x[first:last]


def synthesize_voice():
    pieces = []
    for phrase in PARTS:
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'voice.wav'
            completed = subprocess.run(
                ['espeak', '-v', 'ru+f3', '-s', '127', '-g', '4', '-p', '59',
                 '-a', '180', '-w', str(path), phrase],
                capture_output=True, text=True, check=True
            )
            if completed.stderr.strip():
                print('TTS notice:', completed.stderr.strip())
            pieces.append(trim_silence(load_voice_wav(path)))
    return np.concatenate((pieces[0], np.zeros(round(.45 * SR)), pieces[1]))


def prepare_voice(voice):
    # Prioritize intelligibility. No chorus, reverb or noise masking the consonants.
    v = band(voice, lo=110, hi=6200)
    rms = np.sqrt(np.mean(v * v)) + 1e-12
    v *= .145 / rms
    peak = np.max(np.abs(v)) + 1e-12
    if peak > .58:
        v *= .58 / peak
    fade_in = min(int(.025 * SR), len(v) // 5)
    fade_out = min(int(.07 * SR), len(v) // 5)
    v[:fade_in] *= np.linspace(0, 1, fade_in)
    v[-fade_out:] *= np.linspace(1, 0, fade_out)
    return v


def background(n, duration):
    rng = np.random.default_rng(20261029)
    t = np.arange(n) / SR
    envelope = np.clip(t / .6, 0, 1) * np.clip((duration - t) / 1.7, 0, 1)
    drone = (.25 * np.sin(2 * np.pi * 110 * t + .24 * np.sin(2 * np.pi * .065 * t))
             + .19 * np.sin(2 * np.pi * 164.81 * t + .17 * np.sin(2 * np.pi * .097 * t))
             + .15 * np.sin(2 * np.pi * 220 * t + .1 * np.sin(2 * np.pi * .051 * t))
             + .09 * np.sin(2 * np.pi * 329.63 * t))
    drone *= .28 * envelope * (.8 + .2 * np.sin(2 * np.pi * .16 * t))
    air = []
    for _ in range(2):
        x = band(rng.standard_normal(n), lo=460, hi=6500)
        x *= .018 / (np.std(x) + 1e-12)
        x *= envelope * (.38 + .4 * np.sin(np.pi * np.clip((t - .1) / duration, 0, 1)) ** 2)
        air.append(x)
    swoosh = band(rng.standard_normal(n), lo=250, hi=10000)
    swoosh /= (np.std(swoosh) + 1e-12)
    swoosh *= np.exp(-((t - 1.34) / .65) ** 2) * (.015 + .025 * np.minimum(1, t / 2))
    left = drone + air[0] + swoosh * .65
    right = drone * .97 + air[1] + swoosh * .45
    for at, hz, amp, pan in [
        (.6, 659.25, .065, -.45),
        (1.5, 880, .058, .52),
        (duration - 1.7, 523.25, .035, -.2),
    ]:
        offset = int(at * SR)
        tt = np.arange(n - offset) / SR
        ch = amp * np.exp(-tt * 2.1) * (
            np.sin(2 * np.pi * hz * tt) + .25 * np.sin(2 * np.pi * hz * 2.01 * tt)
        )
        ch *= np.minimum(1, tt / .035)
        left[offset:] += ch * np.sqrt((1 - pan) / 2)
        right[offset:] += ch * np.sqrt((1 + pan) / 2)
    return np.stack((left, right), axis=1)


def generate(out, voice_path=None):
    voice = prepare_voice(load_voice_wav(voice_path) if voice_path else synthesize_voice())
    start = int(START * SR)
    end = start + len(voice)
    duration = max(MIN_DURATION, end / SR + TAIL)
    n = int(np.ceil(duration * SR))
    music = background(n, duration)

    # Sidechain music ducking while speech is played, -13 dB, smooth transitions.
    duck = np.ones(n)
    ramp = int(.5 * SR)
    a = max(0, start - ramp)
    b = min(n, end + ramp)
    duck[start:end] = .22
    if start > a:
        duck[a:start] = np.linspace(1, .22, start - a)
    if b > end:
        duck[end:b] = np.linspace(.22, 1, b - end)
    music *= duck[:, None]

    # Voice centered. No delayed duplicates or echoes.
    music[start:end, 0] += voice * .94
    music[start:end, 1] += voice * .94
    peak = np.max(np.abs(music))
    if peak > .86:
        music *= .86 / peak

    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), 'wb') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(np.int16(np.clip(music, -1, 1) * 32767).tobytes())
    assert end + int(.8 * SR) < n, 'Speech tail must fit in exported file'
    print(f'Wrote {out}: {duration:.2f}s, {SR} Hz stereo; '
          f'voice {len(voice)/SR:.2f}s starts {START:.2f}s and ends {end/SR:.2f}s')


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('--output', type=Path, default=Path('irina_intro.wav'))
    p.add_argument('--voice-wav', type=Path)
    args = p.parse_args()
    generate(args.output, args.voice_wav)
