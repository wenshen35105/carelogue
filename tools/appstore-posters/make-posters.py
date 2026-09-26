#!/usr/bin/env python3
"""App Store poster generator -- 1284x2778 (6.5" tier) from real screenshots.

Per poster: HTML (screenshot inlined as base64) -> Chrome headless at a TALL
viewport -> ffmpeg crop back to 1284x2778.

Why the tall viewport: rendering at exactly 2778px leaves the bottom ~85px of
the compositor output unrendered (a white band at the bottom of the PNG).
Rendering at 4000px and cropping avoids it.

Usage:
    python3 make-posters.py              # both languages
    python3 make-posters.py en-CA        # one language
    python3 make-posters.py en-CA zh-Hans

Input : docs/appstore-submission/screenshots/iphone-6.5/<lang>/NN-name.png
Output: docs/appstore-submission/posters/<lang>/NN-name.png

Requires: google-chrome (or chromium), ffmpeg on PATH.
"""
import base64
import os
import shutil
import subprocess
import sys

REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SHOTS = os.path.join(REPO, "docs", "appstore-submission", "screenshots", "iphone-6.5")
OUT = os.path.join(REPO, "docs", "appstore-submission", "posters")
WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".work")

W, H = 1284, 2778          # final poster size (App Store 6.5" tier)
VIEW_H = 4000              # render-tall-then-crop; must exceed content height (~3534)

# (slug, headline_html, sub_html) -- <em> renders in the accent orange
THEMES = [
    ("01-journeys",        "Your Health Journey,<br>Thoughtfully <em>Organized</em>.",
     "Track pregnancy milestones, lab tests &amp; visits<br>记录每一次产检与重要里程碑"),
    ("02-timeline",        "Every visit and result,<br><em>in one timeline</em>.",
     "Visits, measurements and reports — all in order<br>就诊、测量、报告，都按时间排好"),
    ("03-report-explain",  "Reports, explained<br><em>in plain language</em>.",
     "AI reads your report with you — terms, results, what to ask<br>AI 陪你读报告——术语、指标、该问什么"),
    ("04-visit-recording", "Record your visit,<br><em>transcribed on your iPhone</em>.",
     "Local transcription, English and Chinese<br>中英混说都能转写，就在本机完成"),
    ("05-visit-summary",   "After every visit,<br><em>a written summary</em>.",
     "See what was said — and share it with family<br>医生说了什么，回家还能看、能给家人看"),
    ("06-questions",       "Your questions,<br><em>ready for the doctor</em>.",
     "Write them in Chinese, show them in English<br>中文写下的问题，看诊时出示英文版"),
    ("07-paywall",         "AI features,<br><em>free for a week</em>.",
     "One subscription, no account, cancel anytime<br>一次订阅、无需账号、随时可取消"),
]

PAGE = """<!DOCTYPE html>
<html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Plus+Jakarta+Sans:wght@500;700;800&family=Noto+Sans+SC:wght@400;500;700&display=swap" rel="stylesheet">
<style>
  *{margin:0;padding:0;box-sizing:border-box}
  html,body{width:1284px;height:2778px;overflow:hidden}
  body{background:linear-gradient(168deg,#FBF8F4 0%,#F6EFE6 55%,#F0E5D8 100%);
    font-family:'Plus Jakarta Sans','Noto Sans SC',sans-serif;
    display:flex;flex-direction:column;align-items:center}
  .headline{margin-top:150px;width:1180px;text-align:center;font-size:98px;font-weight:800;line-height:1.16;color:#201D1A;letter-spacing:-2.5px}
  .headline em{color:#D9784F;font-style:normal}
  .sub{margin-top:52px;font-size:44px;color:#8A8680;font-weight:500;letter-spacing:.5px;text-align:center;line-height:1.5}
  .phone{margin-top:234px;width:1284px;background:#16161A;border-radius:152px;padding:17px;box-shadow:0 70px 140px rgba(70,45,20,.20)}
  .screen{border-radius:136px;overflow:hidden;background:#F7F5F2}
  .screen img{width:100%;display:block}
</style></head>
<body>
  <div class="headline">__HL__</div>
  <div class="sub">__SUB__</div>
  <div class="phone"><div class="screen"><img id="shot"></div></div>
<script>
  document.getElementById('shot').src = 'data:image/png;base64,__B64__';
</script>
</body></html>"""


def chrome_bin():
    for name in ("google-chrome", "chromium", "chromium-browser"):
        p = shutil.which(name)
        if p:
            return p
    sys.exit("error: google-chrome / chromium not found on PATH")


def ffmpeg_bin():
    p = shutil.which("ffmpeg")
    if not p:
        sys.exit("error: ffmpeg not found on PATH (Hermes ships one under ~/.hermes/tools/)")
    return p


def render_one(chrome, ffmpeg, lang, theme):
    slug, hl, sub = theme
    shot = os.path.join(SHOTS, lang, slug + ".png")
    if not os.path.exists(shot):
        print(f"  skip  {lang}/{slug} (no screenshot)")
        return False
    os.makedirs(WORK, exist_ok=True)
    os.makedirs(os.path.join(OUT, lang), exist_ok=True)

    b64 = base64.b64encode(open(shot, "rb").read()).decode()
    html = PAGE.replace("__HL__", hl).replace("__SUB__", sub).replace("__B64__", b64)
    hp = os.path.join(WORK, f"{lang}-{slug}.html")
    with open(hp, "w") as f:
        f.write(html)

    big = os.path.join(WORK, f"{lang}-{slug}-big.png")
    subprocess.run(
        [chrome, "--headless=new", "--disable-gpu", "--hide-scrollbars",
         "--force-device-scale-factor=1", f"--window-size={W},{VIEW_H}",
         "--virtual-time-budget=15000", "--default-background-color=FFFFFFFF",
         f"--screenshot={big}", f"file://{hp}"],
        check=True, capture_output=True, timeout=120)
    dst = os.path.join(OUT, lang, slug + ".png")
    subprocess.run(
        [ffmpeg, "-y", "-loglevel", "error", "-i", big,
         "-vf", f"crop={W}:{H}:0:0", dst],
        check=True, capture_output=True, timeout=120)
    print(f"  ok    {lang}/{slug}.png")
    return True


def main():
    chrome, ffmpeg = chrome_bin(), ffmpeg_bin()
    langs = sys.argv[1:] or ["en-CA", "zh-Hans"]
    total = 0
    for lang in langs:
        print(f"[{lang}]")
        for theme in THEMES:
            total += render_one(chrome, ffmpeg, lang, theme)
    print(f"\ndone: {total} posters -> {OUT}")


if __name__ == "__main__":
    main()
