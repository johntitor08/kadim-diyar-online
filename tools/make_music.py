#!/usr/bin/env python3
"""Fragman müziği: epik, minör tonda bir döngü. Tamamen kodla sentezlenir (numpy + scipy).
Kullanım: python3 tools/make_music.py <çıktı.wav> <süre_sn>
Yapı: sakin giriş (pad + arpej), 6. saniyeden itibaren davul ve bas, sonda yavaşça söner."""
import sys
import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, lfilter

SR = 44100
BPM = 100
BEAT = 60.0 / BPM


def note(n):  # MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12.0)


def env(length, a=0.01, r=0.3):
    t = np.arange(length) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    tail = np.clip((t[-1] - t) / max(r, 1e-4), 0, 1) if length else t
    return e * tail


def lowpass(x, cutoff):
    b, a = butter(2, cutoff / (SR / 2), btype="low")
    return lfilter(b, a, x)


def saw(f, length):
    t = np.arange(length) / SR
    return 2.0 * (t * f - np.floor(0.5 + t * f))


def main():
    out = sys.argv[1]
    dur = float(sys.argv[2])
    n = int(dur * SR)
    mix = np.zeros(n)
    # Am - F - C - G (her akor 2 ölçü = 8 vuruş)
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    bar = BEAT * 4
    step = 0
    t0 = 0.0
    while t0 < dur:
        ch = chords[step % 4]
        length = int(min(bar * 2, dur - t0) * SR)
        start = int(t0 * SR)
        # Pad: yumuşak testere dalgaları, alçak geçiren süzgeç
        pad = sum(saw(note(m), length) + saw(note(m) * 1.003, length) for m in ch)
        pad = lowpass(pad, 1400) * env(length, 0.6, 0.8) * 0.05
        mix[start:start + length] += pad
        # Arpej (sekizlikler)
        for k in range(16):
            ts = t0 + k * BEAT / 2
            if ts >= dur:
                break
            m = ch[k % 3] + (12 if k % 4 >= 2 else 0)
            ln = int(BEAT / 2 * SR)
            s = int(ts * SR)
            seg = np.sin(2 * np.pi * note(m + 12) * np.arange(ln) / SR) * np.exp(-np.arange(ln) / SR * 9)
            mix[s:s + ln] += seg[: max(0, min(ln, n - s))] * 0.06
        # Bas (6. saniyeden sonra)
        if t0 >= 6.0:
            for k in range(8):
                ts = t0 + k * BEAT
                if ts >= dur:
                    break
                ln = int(BEAT * 0.9 * SR)
                s = int(ts * SR)
                seg = lowpass(saw(note(ch[0] - 12), ln), 400) * env(ln, 0.005, 0.2) * 0.22
                mix[s:s + ln] += seg[: max(0, min(ln, n - s))]
        t0 += bar * 2
        step += 1
    # Davul: davul (kick) her vuruşta, trampet 2 ve 4'te, zil sekizliklerde (6. saniyeden sonra)
    k_len = int(0.35 * SR)
    tk = np.arange(k_len) / SR
    kick = np.sin(2 * np.pi * (50 + 120 * np.exp(-tk * 25)) * tk) * np.exp(-tk * 9) * 0.6
    s_len = int(0.25 * SR)
    snare = (np.random.default_rng(1).uniform(-1, 1, s_len) * np.exp(-np.arange(s_len) / SR * 18)) * 0.25
    h_len = int(0.06 * SR)
    hat = lowpass(np.random.default_rng(2).uniform(-1, 1, h_len), 9000) * np.exp(-np.arange(h_len) / SR * 60) * 0.08
    beat_i = 0
    t = 6.0
    while t < dur - 0.4:
        s = int(t * SR)
        mix[s:s + k_len] += kick[: max(0, min(k_len, n - s))]
        if beat_i % 2 == 1:
            mix[s:s + s_len] += snare[: max(0, min(s_len, n - s))]
        for half in (0.0, BEAT / 2):
            hs = int((t + half) * SR)
            mix[hs:hs + h_len] += hat[: max(0, min(h_len, n - hs))]
        t += BEAT
        beat_i += 1
    # Genel zarf: girişte yavaş açılış, sonda sönme
    tt = np.arange(n) / SR
    master = np.clip(tt / 1.5, 0, 1) * np.clip((dur - tt) / 3.0, 0, 1)
    mix *= master
    mix /= max(1e-6, np.max(np.abs(mix))) / 0.85
    stereo = np.stack([mix, np.roll(mix, int(0.012 * SR))], axis=1)
    wavfile.write(out, SR, (stereo * 32767).astype(np.int16))


if __name__ == "__main__":
    main()
