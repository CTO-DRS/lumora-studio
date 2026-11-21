#!/usr/bin/env python3
"""Generates the Android and iOS launcher icons from design/v1.2/app_icon.png.

Usage: python3 tool/generate_icons.py <path to app_icon.png>
Requires Pillow. Android gets legacy icons for every density plus an
adaptive icon (the artwork scaled into the 66 % safe zone on #07061A);
iOS gets every AppIcon size without an alpha channel.
"""
import json
import os
import sys

from PIL import Image

SRC = sys.argv[1] if len(sys.argv) > 1 else 'design/v1.2/app_icon.png'
ICON_BG = (0x07, 0x06, 0x1A)
RES = 'android/app/src/main/res'
DENSITIES = {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}

art = Image.open(SRC).convert('RGB')


def resized(size):
    return art.resize((size, size), Image.LANCZOS)


for name, k in DENSITIES.items():
    folder = f'{RES}/mipmap-{name}'
    os.makedirs(folder, exist_ok=True)
    resized(round(48 * k)).save(f'{folder}/ic_launcher.png', optimize=True)
    # Adaptive foreground: 108 dp canvas, artwork in the central 66 %.
    canvas = round(108 * k)
    inner = round(canvas * 0.66)
    fg = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    fg.paste(resized(inner), ((canvas - inner) // 2, (canvas - inner) // 2))
    fg.save(f'{folder}/ic_launcher_foreground.png', optimize=True)

os.makedirs(f'{RES}/mipmap-anydpi-v26', exist_ok=True)
with open(f'{RES}/mipmap-anydpi-v26/ic_launcher.xml', 'w') as f:
    f.write(
        '<?xml version="1.0" encoding="utf-8"?>\n'
        '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
        '    <background android:drawable="@color/ic_launcher_background" />\n'
        '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
        '</adaptive-icon>\n'
    )

ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
contents = json.load(open(f'{ios}/Contents.json'))
for image in contents['images']:
    w = float(image['size'].split('x')[0])
    scale = int(image['scale'].rstrip('x'))
    px = round(w * scale)
    flat = Image.new('RGB', (px, px), ICON_BG)
    flat.paste(resized(px))
    flat.save(f"{ios}/{image['filename']}", optimize=True)
print('icons written')
