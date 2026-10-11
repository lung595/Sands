"""Writes the single self-contained before/after page from the pictures made by before-after.sh."""
import base64
import sys

work, out = sys.argv[1:3]
STORES = ["default settings", "custom sound file", "launcher prefix shown", "long sound name"]
WIDTHS = [(228, "Narrowest real width: 228 px (404 px page minus the 176 px section rail)"),
          (404, "Plain page at the minimum window: 404 px")]


def img(side, theme, w, p):
    with open(f"{work}/{side}-{theme}-{w}-{p}.png", "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


sections = []
for theme in ("dark", "light"):
    for w, title in WIDTHS:
        figs = []
        for p, store in enumerate(STORES):
            for side, name in (("before", "Before (DMS rows)"), ("after", "After (own rows)")):
                figs.append(f"<figure><figcaption>{name}, {store}</figcaption><img src='{img(side, theme, w, p)}'></figure>")
        sections.append(f"<section class={theme}><h2>{title}, {theme} palette</h2><div class=row>{''.join(figs)}</div></section>")

page = f"""<!doctype html><meta charset=utf-8><title>NAK-425 Sands settings, before and after</title>
<style>body{{background:#141218;color:#e6e0e9;font:15px system-ui;margin:24px}}h2{{font-weight:500}}
.row{{display:flex;gap:20px;flex-wrap:wrap;align-items:flex-start}}figure{{margin:0}}
figcaption{{font-size:13px;color:#cac4d0;margin-bottom:6px;max-width:260px}}img{{border:1px solid #49454f}}</style>
<h1>Sands settings: before and after (NAK-425)</h1>
<p>Rendered offscreen from the real settings page with made-up data, in the dark and the light palette. The DMS widgets (toggle, dropdown, slider, text field, button) are layout stand-ins, so the look of the controls is approximate; what is proven is where the texts and controls sit. The "before" page uses the DMS rows and fails the overlap test; the "after" page passes it.</p>
<p><b>One layout change to approve:</b> the list of a choice row (Hourglass, Sound) now always sits under its title, full width. In DMS it sits beside the title from about 404 px up, with a 200 px list. One layout at every width, and a long sound name gets the whole row. In the wide "before" pictures the list is beside its title.</p>
<p>A list value longer than the list itself is elided, as in the DMS dropdown; the test fails on one that does not fit.</p>
{''.join(sections)}"""
with open(out, "w") as f:
    f.write(page)
