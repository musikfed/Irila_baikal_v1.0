#!/usr/bin/env python3
"""Deterministic original Irina Baikal desktop intro: cosmic ambience + soft Russian speech.

Dependencies: numpy, scipy, espeak (or a user-supplied --voice-wav).
Voice from espeak is a SYNTHETIC female-ish prototype, not realistic whispered recording.
"""
from __future__ import annotations
import argparse
import subprocess
import tempfile
import wave
from pathlib import Path
import numpy as np
from scipy.signal import butter, sosfilt, resample_poly

SR = 44100
DURATION = 9.25
SPEECH = 'Ирина Байкал систем один точка ноль'

def filt(x, lo=None, hi=None):
    if lo and hi: spec, typ = (lo, hi), 'bandpass'
    elif lo: spec, typ = lo, 'highpass'
    else: spec, typ = hi, 'lowpass'
    return sosfilt(butter(3, spec, btype=typ, output='sos', fs=SR), x)

def fade(n, start, end):
    t = np.arange(n)/SR
    return np.clip((t-start)/.6, 0, 1)*np.clip((end-t)/1.5, 0, 1)

def render_voice(path):
    with wave.open(str(path),'rb') as wf:
        raw=wf.readframes(wf.getnframes())
        channels, width, sr=wf.getnchannels(), wf.getsampwidth(), wf.getframerate()
    if width!=2: raise ValueError('Voice WAV must be 16-bit PCM')
    a=np.frombuffer(raw,dtype='<i2').astype(np.float64)/32768
    if channels>1: a=a.reshape(-1,channels).mean(axis=1)
    if sr!=SR:
        from math import gcd
        g=gcd(sr,SR)
        a=resample_poly(a,SR//g,sr//g)
    a=filt(a,lo=230,hi=5500)
    return a/max(.01,np.max(np.abs(a)))

def generate(target: Path, voice_path: Path|None):
    rng=np.random.default_rng(20261029)
    N=int(SR*DURATION)
    t=np.arange(N,dtype=np.float64)/SR
    env=fade(N,0.0,DURATION+.3)
    drone=(.25*np.sin(2*np.pi*110*t+.24*np.sin(2*np.pi*.065*t))
       +.19*np.sin(2*np.pi*164.81*t+.17*np.sin(2*np.pi*.097*t))
       +.15*np.sin(2*np.pi*220*t+.1*np.sin(2*np.pi*.051*t))
       +.09*np.sin(2*np.pi*329.63*t))
    drone*=.28*env*(.8+.2*np.sin(2*np.pi*.16*t))
    sky1=filt(rng.normal(size=N),lo=460,hi=6500)
    sky2=filt(rng.normal(size=N),lo=460,hi=6500)
    sky1=sky1/max(1e-6,np.std(sky1))*.018
    sky2=sky2/max(1e-6,np.std(sky2))*.018
    slow=.38+.4*np.sin(np.pi*np.clip((t-.1)/7,0,1))**2
    sky1*=slow*env
    sky2*=slow*env
    whoosh=filt(rng.normal(size=N),lo=250,hi=10000)
    whoosh/=max(1e-6,np.std(whoosh))
    whoosh*=np.exp(-((t-1.34)/.65)**2)*(.015+.025*np.minimum(1,t/2))
    chimeL=np.zeros(N)
    chimeR=np.zeros(N)
    for at,hz,amp,pan in [(0.6,659.25,.065,-.45),(1.5,880,.058,.52),(7.25,523.25,.035,-.2)]:
        offset=int(at*SR)
        tau=np.arange(N-offset)/SR
        chime=amp*np.exp(-tau*2.1)*(np.sin(2*np.pi*hz*tau)+.25*np.sin(2*np.pi*hz*2.01*tau))
        chime*=np.minimum(1,tau/.035)
        chimeL[offset:]+=chime*np.sqrt((1-pan)/2)
        chimeR[offset:]+=chime*np.sqrt((1+pan)/2)
    if voice_path is None:
        with tempfile.NamedTemporaryFile(suffix='.wav',delete=False) as v:
            path=Path(v.name)
        try:
            subprocess.run(['espeak','-v','ru+f3','-s','105','-p','67','-a','165',
                            '-w',str(path),SPEECH],check=True)
            voice=render_voice(path)
        finally:
            path.unlink(missing_ok=True)
    else:
        voice=render_voice(voice_path)
    # Breathy, soft synthetic vocal texture, not an authentic human whisper.
    venv=np.sqrt(np.maximum(0,np.convolve(voice**2,np.ones(200)/200,mode='same')))
    breath=filt(rng.normal(size=len(voice)),lo=850,hi=5200)
    breath*=.09*venv/(np.std(breath)+1e-12)
    voice=.47*voice+.15*breath
    voice*=np.minimum(1,np.arange(len(voice))/(SR*.12))
    voice*=np.minimum(1,np.arange(len(voice))[::-1]/(SR*.36))
    voiceL=np.zeros(N)
    voiceR=np.zeros(N)
    start=int(2.85*SR)
    stop=min(N,start+len(voice))
    n=stop-start
    voiceL[start:stop]+=.88*voice[:n]
    voiceR[start:stop]+=.91*voice[:n]
    for delay,gain in [(.115,.19),(.244,.12),(.41,.075)]:
        k=int(delay*SR)
        i=start+k
        end=min(N,i+len(voice))
        if end>i:
            voiceL[i:end]+=gain*voice[:end-i]
            voiceR[i:end]+=gain*.85*voice[:end-i]
    audio=np.stack((drone+sky1+whoosh*.65+chimeL+voiceL,
                    drone*.97+sky2+whoosh*.45+chimeR+voiceR),axis=1)
    audio*=min(1,.82/(np.max(np.abs(audio))+1e-12))
    audio=np.tanh(audio*1.2)/1.2
    target.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(target),'wb') as wf:
        wf.setnchannels(2)
        wf.setsampwidth(2)
        wf.setframerate(SR)
        wf.writeframes(np.int16(np.clip(audio,-1,1)*32767).tobytes())
    print(f'Wrote {target} ({DURATION}s, 44.1kHz stereo)')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--output',type=Path,default=Path('irina_intro.wav'))
    parser.add_argument('--voice-wav',type=Path,help='Optional user-approved higher-quality spoken Russian WAV')
    args=parser.parse_args()
    generate(args.output,args.voice_wav)
