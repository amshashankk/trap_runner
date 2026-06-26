#!/usr/bin/env python3
"""Generate Play Store listing graphics into store/.

  store/icon_512.png              512x512 app icon (Play listing)
  store/feature_graphic.png       1024x500 feature graphic
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = "/Users/amshashankk/StudioProjects/trap_runner"
SRC = os.path.join(ROOT, "assets", "icon", "app_icon.png")
OUT = os.path.join(ROOT, "store")
os.makedirs(OUT, exist_ok=True)

BLACK_FONT = "/System/Library/Fonts/Supplemental/Arial Black.ttf"
BOLD_FONT = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"

YELLOW = (247, 255, 3)
RED = (214, 69, 69)
DARK = (27, 36, 64)

# --- 512 icon ---
icon = Image.open(SRC).convert("RGBA").resize((512, 512), Image.LANCZOS)
icon.convert("RGB").save(os.path.join(OUT, "icon_512.png"))
print("icon_512.png")

# --- 1024x500 feature graphic ---
W, H = 1024, 500
fg = Image.new("RGB", (W, H), YELLOW)
d = ImageDraw.Draw(fg)

# right: the icon art (its background is the same yellow -> seamless)
art = Image.open(SRC).convert("RGBA").resize((430, 430), Image.LANCZOS)
fg.paste(art, (W - 430 - 40, (H - 430) // 2), art)

# left: title
trap_f = ImageFont.truetype(BLACK_FONT, 150)
run_f = ImageFont.truetype(BLACK_FONT, 110)
sub_f = ImageFont.truetype(BOLD_FONT, 34)

d.text((55, 95), "TRAP", font=trap_f, fill=RED)
d.text((55, 245), "RUNNER", font=run_f, fill=DARK)
d.text((60, 380), "The level fights back.", font=sub_f, fill=DARK)

fg.save(os.path.join(OUT, "feature_graphic.png"))
print("feature_graphic.png", fg.size)
print("DONE")
