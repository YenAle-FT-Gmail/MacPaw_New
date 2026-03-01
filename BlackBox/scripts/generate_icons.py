#!/usr/bin/env python3
"""Generate BlackBox app icon assets."""
from PIL import Image, ImageDraw, ImageFilter, ImageFont
import math, os

OUT = os.path.expanduser("~/Documents/GitHub/MacPaw_New/BlackBox/BlackBox/Resources")
WEB = os.path.expanduser("~/Documents/GitHub/MacPaw_New/BlackBox/Website")

size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))

# Background
bg = Image.new('RGBA', (size, size), (0, 0, 0, 0))
bg_draw = ImageDraw.Draw(bg)
bg_draw.rounded_rectangle([0, 0, size-1, size-1], radius=220, fill=(10, 14, 23, 255))
img = Image.alpha_composite(img, bg)

# Glow
glow = Image.new('RGBA', (size, size), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
cx, cy = size // 2, size // 2 - 20
for i in range(80, 0, -1):
    alpha = int(3 * (80 - i) / 80)
    radius = 280 + i * 2
    glow_draw.ellipse([cx-radius, cy-radius, cx+radius, cy+radius], fill=(0, 255, 102, alpha))
glow = glow.filter(ImageFilter.GaussianBlur(40))
img = Image.alpha_composite(img, glow)

# Orb
orb = Image.new('RGBA', (size, size), (0, 0, 0, 0))
orb_draw = ImageDraw.Draw(orb)
orb_r = 200
for i in range(orb_r, 0, -1):
    frac = i / orb_r
    g_val = int(30 + (255 - 30) * (1 - frac))
    b_val = int(15 + (102 - 15) * (1 - frac))
    a_val = int(255 * (0.4 + 0.6 * (1 - frac)))
    orb_draw.ellipse([cx-i, cy-i, cx+i, cy+i], fill=(0, g_val, b_val, a_val))

# Inner highlight
for i in range(80, 0, -1):
    frac = i / 80
    hx, hy = cx - 60, cy - 60
    a_val = int(80 * (1 - frac))
    orb_draw.ellipse([hx-i, hy-i, hx+i, hy+i], fill=(200, 255, 220, a_val))
img = Image.alpha_composite(img, orb)

# Orbit ring
ring = Image.new('RGBA', (size, size), (0, 0, 0, 0))
ring_draw = ImageDraw.Draw(ring)
ring_r = 260
for angle_deg in range(360):
    angle = math.radians(angle_deg)
    x = cx + ring_r * math.cos(angle)
    y = cy + ring_r * math.sin(angle)
    alpha = int(40 + 30 * math.sin(angle * 2))
    ring_draw.ellipse([x-1, y-1, x+1, y+1], fill=(0, 255, 102, alpha))

dot_angle = math.radians(-45)
dot_x = cx + ring_r * math.cos(dot_angle)
dot_y = cy + ring_r * math.sin(dot_angle)
for i in range(12, 0, -1):
    a = int(255 * (12 - i) / 12)
    ring_draw.ellipse([dot_x-i, dot_y-i, dot_x+i, dot_y+i], fill=(0, 255, 102, a))
img = Image.alpha_composite(img, ring)

# BB text
txt = Image.new('RGBA', (size, size), (0, 0, 0, 0))
txt_draw = ImageDraw.Draw(txt)
try:
    font = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 72)
except:
    font = ImageFont.load_default()
txt_draw.text((size//2, size - 140), 'BB', fill=(255, 255, 255, 200), font=font, anchor='mm')
img = Image.alpha_composite(img, txt)

# Save main icon
img.save(os.path.join(OUT, 'AppIcon.png'))
print('AppIcon.png created (1024x1024)')

# Smaller sizes
for s in [512, 256, 128, 64, 32, 16]:
    resized = img.resize((s, s), Image.LANCZOS)
    resized.save(os.path.join(OUT, f'AppIcon_{s}.png'))
    print(f'AppIcon_{s}.png created')

# Favicon for website
favicon = img.resize((32, 32), Image.LANCZOS)
favicon.save(os.path.join(WEB, 'favicon.png'))
print('favicon.png created')

# OG image (1200x630)
og = Image.new('RGBA', (1200, 630), (10, 14, 23, 255))
orb_og = img.resize((300, 300), Image.LANCZOS)
og.paste(orb_og, (450, 40), orb_og)
og_draw = ImageDraw.Draw(og)
try:
    font_lg = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 48)
    font_md = ImageFont.truetype('/System/Library/Fonts/Menlo.ttc', 22)
except:
    font_lg = ImageFont.load_default()
    font_md = font_lg
og_draw.text((600, 380), 'BLACKBOX', fill=(255, 255, 255, 230), font=font_lg, anchor='mm')
og_draw.text((600, 430), 'Privacy Audit System for macOS', fill=(255, 255, 255, 120), font=font_md, anchor='mm')

# Line accent
og_draw.line([(400, 470), (800, 470)], fill=(0, 255, 102, 80), width=2)
og_draw.text((600, 510), 'Your Mac remembers everything.', fill=(0, 255, 102, 180), font=font_md, anchor='mm')

og.convert('RGB').save(os.path.join(WEB, 'og-image.jpg'), quality=90)
print('og-image.jpg created (1200x630)')

print('\nAll assets generated!')
