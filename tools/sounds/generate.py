#!/usr/bin/env python3
"""Render the Hourglass ring of Sands as OGG/Opus.

    python3 tools/sounds/generate.py OUT_DIR

Needs python3 and ffmpeg with libopus, nothing else. Rendering is bit-exact:
the same script gives the same file. Silt Chime is not made here: it is a CC0
sound downloaded once by hand (see the README, Credits).
"""
import argparse
import os
import subprocess
import sys
import tempfile

import dsp
import rings

BITRATE = "40k"
TARGET_RMS = 0.105  # about -17 LUFS on this sparse, decaying ring


def encode(wav_path, ogg_path):
    # bitexact flags drop the encoder tag and fix the Ogg serial number, so a
    # second run produces a byte-identical file.
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", wav_path, "-ac", "1", "-ar", "48000",
         "-map_metadata", "-1", "-fflags", "+bitexact", "-flags:a", "+bitexact",
         "-c:a", "libopus", "-b:a", BITRATE, "-application", "audio", ogg_path],
        check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("out")
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    with tempfile.TemporaryDirectory() as work:
        wav_path = os.path.join(work, "hourglass.wav")
        dsp.write_wav(wav_path, dsp.match_loudness(rings.hourglass(), TARGET_RMS))
        encode(wav_path, os.path.join(args.out, "hourglass.ogg"))
        print("wrote hourglass.ogg")


if __name__ == "__main__":
    sys.exit(main())
