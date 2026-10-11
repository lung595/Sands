#!/usr/bin/env python3
"""Offscreen check of rising-dune.html (NAK-555, option C added by NAK-637, retouched by NAK-642).

The page is rendered by WebKitGTK on a private broadway display, so nothing
appears on the live session. Each scenario sets the switches, lets the sand
play, then reads the page's own counters and looks for overflow, a caption
off the sand and forbidden dashes. Captures go to the directory given as
argument (test evidence only). Standard library, GTK 4, WebKitGTK 6.
"""
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = sys.argv[1] if len(sys.argv) > 1 else HERE
# Second pass, "dpr2" as second argument: same page at devicePixelRatio 2 (page zoom 2 in a window twice as large).
DPR2 = len(sys.argv) > 2 and sys.argv[2] == "dpr2"
DISPLAY = ":78"
# Started before GTK loads: the backend is chosen, and its display opened, at import time.
os.environ.update(GDK_BACKEND="broadway", BROADWAY_DISPLAY=DISPLAY)
DAEMON = subprocess.Popen(["gtk4-broadwayd", DISPLAY], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
time.sleep(1)

import gi  # noqa: E402

gi.require_version("Gtk", "4.0")
gi.require_version("WebKit", "6.0")
from gi.repository import GLib, Gtk, WebKit  # noqa: E402

SET = "function set(n,v){document.querySelector('input[name='+n+'][value='+v+']').click()}"
REPORT = """JSON.stringify({stats:[...document.querySelectorAll('.stat')].map(e=>e.textContent),
done:[...document.querySelectorAll('[data-frac]')].map(e=>e.dataset.done||'0').join(''),
hscroll:document.documentElement.scrollWidth>innerWidth,
clipped:[...document.querySelectorAll('.panel *')].filter(e=>e.scrollWidth>e.clientWidth+1&&!e.matches('.tn')).map(e=>e.className||e.tagName),
dash:/[\\u2013\\u2014]/.test(document.documentElement.outerHTML),
dpr:devicePixelRatio,width:innerWidth,docWidth:document.documentElement.scrollWidth,
cScreen:(r=>[r.left+scrollX,r.top+scrollY,r.width,r.height].map(Math.round))(document.querySelector('[data-kind=c] .screen').getBoundingClientRect()),
fsRow:(function(){var hit=(a,b)=>a.left<b.right&&b.left<a.right&&a.top<b.bottom&&b.top<a.bottom,q=i=>document.getElementById(i).getBoundingClientRect(),
p=document.getElementById('fsw').closest('.panel').getBoundingClientRect(),s=q('fsw'),t=q('l-fs'),d=q('d-fs');
return {overlap:hit(s,t)||hit(s,d)||hit(t,d),inside:s.right<=p.right-24+.5&&t.left>=p.left+24-.5,titleLines:Math.round(t.height/20),switchW:s.width,switchH:s.height}})(),
toasts:document.querySelectorAll('#full .toast').length,fullCanvases:document.querySelectorAll('#full canvas').length,
contrastMin:document.getElementById('ctab').dataset.min})"""
# The page measures the caption band itself, in the 6 themes; read its table at both panel widths and both names.
TABLE = "[...document.querySelectorAll('#ctab tr')].slice(1).map(r=>r.textContent.replace(/:1/g,' ')).join('|')"
ALL_THEMES = SET + ";var o={};set('rm','off');set('width','wide');set('name','short');o.wideShort=" + TABLE + ";set('width','narrow');set('name','long');o.narrowLong=" + TABLE + ";JSON.stringify(o)"
# (name, script run first, wait in ms before the report and the capture)
SCENARIOS = [
    ("dark-640-mid", "sandsPlay()", 1200),
    ("dark-640-end", "", 3200),
    # NAK-642: option C frozen on the 30 Hz step of its highest and of its lowest crest, for the two real-size captures.
    ("c-overshoot", "sandsWaveAt('up')", 300),
    ("c-squash", "sandsWaveAt('dn')", 300),
    ("light-amber-360-long", SET + ";set('mode','light');set('colour','amber');set('width','narrow');set('name','long');sandsPlay()", 4200),
    ("light-green-360-reduced", SET + ";set('colour','green');set('rm','on');sandsPlay()", 500),
    ("themes", ALL_THEMES, 0),
]
if DPR2:
    SCENARIOS = [("dpr2-dark-640-end", "sandsPlay()", 3800), ("dpr2-c-overshoot", "sandsWaveAt('up')", 300), ("dpr2-c-squash", "sandsWaveAt('dn')", 300),
                 ("dpr2-light-amber-360-long", SCENARIOS[4][1], 4200)]


def verdict(name, text):
    """Option C (NAK-637): end time, step count, caption and contrast, read from the page's own counters."""
    try:
        data = json.loads(text)
    except ValueError:
        return
    c = [s for s in data["stats"] if s.startswith("1 flat shape")]
    if "mid" in name:
        return print("VERDICT", name, "movement running, counters read at the end")
    bad = []
    for s in c:
        moved = re.search(r"caption shown at ([\d.]+) s . movement over at ([\d.]+) s . (\d+) steps drawn", s)
        if "reduced" in name:
            if "no movement, 0 steps" not in s:
                bad.append("reduce motion still steps")
        elif "end" in name or "long" in name:
            if not moved or moved.group(2) != "2.40" or moved.group(3) != "72" or float(moved.group(1)) >= 0.8:
                bad.append("end time, steps or caption time: " + s[:120])
            if "every step: yes" not in s:
                bad.append("caption left the wave during a beat")
        if "mid" not in name and "fully on the wave: yes" not in s:
            bad.append("caption off the wave")
        ratio = re.search(r"band ([\d.]+):1", s)
        if "mid" not in name and (not ratio or float(ratio.group(1)) < 4.5):
            bad.append("contrast below 4.5")
        # NAK-642: rim against primary, and the two amplitudes the page measured on its own steps.
        rim = re.search(r"rim 3 px at ([\d.]+):1", s)
        if not rim or float(rim.group(1)) < 3:
            bad.append("rim below 3:1")
        amp = re.search(r"crest at rest (\d+) px, overshoot \+(\d+) px at ([\d.]+) s, deepest squash -(\d+) px at ([\d.]+) s", s)
        if amp:
            print("AMPLITUDE", name, "rest %s px, overshoot +%s px at %s s, squash -%s px at %s s, rim %s:1" % (amp.groups() + (rim.group(1) if rim else "?",)))
        else:
            bad.append("amplitudes not reported")
    row = data["fsRow"]
    if row["overlap"] or not row["inside"] or row["switchH"] < 44 or data["toasts"] != 2 or data["fullCanvases"] != 1:
        bad.append("full-screen row or block: %s toasts %s canvases %s" % (row, data["toasts"], data["fullCanvases"]))
    if data["hscroll"] or data["clipped"] or data["dash"] or float(data["contrastMin"]) < 4.5:
        bad.append("page: hscroll %s clipped %s dash %s min %s" % (data["hscroll"], data["clipped"], data["dash"], data["contrastMin"]))
    print("VERDICT", name, "C views:", len(c), "OK" if not bad and c else "FAIL " + "; ".join(bad))


def run(app, view, todo):
    if not todo:
        return app.quit()
    name, script, wait = todo[0]

    def report(*_):
        view.evaluate_javascript(REPORT if name != "themes" else "1", -1, None, None, None, snap)
        return False

    def first(v, res):
        if name == "themes":
            print(name, v.evaluate_javascript_finish(res).to_string())
            return app.quit()
        GLib.timeout_add(wait, report)

    def snap(v, res):
        text = v.evaluate_javascript_finish(res).to_string()
        print(name, text)
        verdict(name, text)
        view.get_snapshot(WebKit.SnapshotRegion.FULL_DOCUMENT, WebKit.SnapshotOptions.NONE, None, done)

    def done(v, res):
        v.get_snapshot_finish(res).save_to_png(os.path.join(OUT, name + ".png"))
        run(app, view, todo[1:])

    view.evaluate_javascript(script or "1", -1, None, None, None, first)
    return False


def main():
    try:
        app = Gtk.Application()

        def activate(a):
            win = Gtk.ApplicationWindow(application=a)
            win.set_default_size(2880 if DPR2 else 1440, 1800 if DPR2 else 900)
            view = WebKit.WebView()
            if DPR2:
                view.set_zoom_level(2)
            win.set_child(view)
            view.load_uri("file://" + os.path.join(HERE, "rising-dune.html"))
            win.present()
            GLib.timeout_add(1000, run, a, view, SCENARIOS)

        app.connect("activate", activate)
        app.run(None)
    finally:
        DAEMON.terminate()


if __name__ == "__main__":
    sys.exit(main())
