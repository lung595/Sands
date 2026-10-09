"""Tiny synthesis toolkit for the Sands rings (standard library only).

Every function is deterministic: noise comes from a seeded generator passed in
by the caller, so the same script always renders the same samples.
"""
import math
import struct
import wave

RATE = 48000


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(dest, src, at=0.0, gain=1.0):
    """Add src into dest starting at `at` seconds, clipping at dest's end."""
    start = int(at * RATE)
    for i, v in enumerate(src):
        j = start + i
        if j >= len(dest):
            break
        dest[j] += v * gain


def _ramp(x):
    """Raised-cosine 0..1 ramp: no corner at either end, so no click."""
    return 0.5 - 0.5 * math.cos(math.pi * min(max(x, 0.0), 1.0))


def tone(freq, seconds, partials, attack=0.02):
    """Additive tone. partials = [(ratio, amplitude, decay_seconds), ...]."""
    out = []
    for i in range(int(seconds * RATE)):
        t = i / RATE
        s = 0.0
        for ratio, amp, decay in partials:
            s += amp * math.exp(-t / decay) * math.sin(2 * math.pi * freq * ratio * t)
        out.append(s * _ramp(t / attack))
    return out






def reverb(src, wet=0.25, tail=1.5):
    """Schroeder reverb (4 combs + 2 all-passes); returns a longer buffer."""
    n = len(src) + int(tail * RATE)
    x = src + [0.0] * (n - len(src))
    combs = []
    for delay_ms, fb in ((29.7, 0.80), (37.1, 0.78), (41.1, 0.76), (43.7, 0.74)):
        d = int(delay_ms * RATE / 1000)
        buf = [0.0] * d
        y = [0.0] * n
        for i in range(n):
            v = x[i] + buf[i % d] * fb
            buf[i % d] = v
            y[i] = v
        combs.append(y)
    wet_sig = [sum(c[i] for c in combs) / 4 for i in range(n)]
    for delay_ms in (5.0, 1.7):
        d = int(delay_ms * RATE / 1000)
        buf = [0.0] * d
        for i in range(n):
            v = wet_sig[i]
            b = buf[i % d]
            buf[i % d] = v + b * 0.7
            wet_sig[i] = b - v * 0.7
    return [x[i] * (1 - wet) + wet_sig[i] * wet for i in range(n)]


def finish(buf, seconds, peak=0.8, fade_in=0.004, fade_out=0.25):
    """Trim to `seconds`, fade both ends to exact zero, normalise to `peak`.

    The first and last samples are 0.0, so a looped ring cannot click.
    """
    buf = buf[:int(seconds * RATE)]
    buf += [0.0] * (int(seconds * RATE) - len(buf))
    n_in, n_out = int(fade_in * RATE), int(fade_out * RATE)
    for i in range(n_in):
        buf[i] *= i / n_in
    for i in range(n_out):
        buf[-1 - i] *= i / n_out
    buf[0] = buf[-1] = 0.0
    top = max(abs(v) for v in buf) or 1.0
    return [v * peak / top for v in buf]


def match_loudness(buf, target_rms, max_peak=0.95):
    """Scale so all rings feel equally loud; the peak cap keeps it clip-free."""
    rms = math.sqrt(sum(v * v for v in buf) / len(buf)) or 1.0
    gain = min(target_rms / rms, max_peak / (max(abs(v) for v in buf) or 1.0))
    return [v * gain for v in buf]


def write_wav(path, buf):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", round(max(-1, min(1, v)) * 32767)) for v in buf))
