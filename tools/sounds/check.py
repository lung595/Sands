#!/usr/bin/env python3
"""Verify ring files: codec, duration, size and click-free loop points.

    python3 tools/sounds/check.py FILE.ogg [...]

Fails (exit 1) when a file is not Opus/Vorbis, exceeds 6 s or 60 KB, or when
its first/last decoded samples are not near zero, under 0.005 or -46 dBFS (a click when looping).
"""
import json
import os
import struct
import subprocess
import sys

MAX_SECONDS, MAX_BYTES, EDGE_LIMIT = 6.0, 60 * 1024, 0.005


def probe(path):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "stream=codec_name,sample_rate,channels:format=duration",
         "-of", "json", path], check=True, capture_output=True, text=True).stdout
    data = json.loads(out)
    return data["streams"][0], float(data["format"]["duration"])


def edges(path):
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", path, "-f", "s16le", "-ac", "1", "-"],
                         check=True, capture_output=True).stdout
    samples = struct.unpack("<%dh" % (len(raw) // 2), raw)
    peak = max(abs(s) for s in samples)
    # Rise time: first sample reaching 25 % of the peak, in milliseconds. It
    # must be short enough to be heard at the Gentle alarm's 30 % volume.
    rise = next(i for i, v in enumerate(samples) if abs(v) >= peak / 4) * 1000 / 48000
    return samples[0] / 32768, samples[-1] / 32768, peak / 32768, rise


def main(paths):
    bad = False
    for path in paths:
        stream, seconds = probe(path)
        size = os.path.getsize(path)
        first, last, peak, rise = edges(path)
        ok = (stream["codec_name"] in ("opus", "vorbis") and seconds <= MAX_SECONDS
              and size <= MAX_BYTES and abs(first) < EDGE_LIMIT and abs(last) < EDGE_LIMIT)
        bad |= not ok
        print("%-4s %-16s %s %.2fs %5.1fKB first=%+.5f last=%+.5f peak=%.2f rise=%.0fms"
              % ("ok" if ok else "FAIL", os.path.basename(path), stream["codec_name"],
                 seconds, size / 1024, first, last, peak, rise))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
