"""The synthesised ring recipe: Hourglass, the default alarm of Sands.

The pitches stay in E major pentatonic (no semitone clashes) and sit around
E5-E6 where small speakers are most efficient, so the ring is heard at the
Gentle alarm's 30 % starting volume. Every note has a short attack: audible
at once, but never a hard edge.
"""
import dsp

E5, GS5, B5, E6 = 659.26, 830.61, 987.77, 1318.51

# Glass-like partials: slightly inharmonic, the upper ones die quickly.
GLASS = [(1.0, 1.0, 1.4), (2.32, 0.35, 0.7), (4.25, 0.15, 0.35), (6.63, 0.06, 0.2)]


def hourglass():
    """Four rising glass notes, like grains settling one after the other."""
    buf = dsp.silence(3.0)
    for i, f in enumerate((E5, GS5, B5, E6)):
        dsp.mix(buf, dsp.tone(f, 2.0, GLASS, attack=0.008), at=0.30 * i, gain=0.8 + 0.1 * i)
    return dsp.finish(dsp.reverb(buf, wet=0.30, tail=1.5), 4.5)
