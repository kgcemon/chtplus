"""Regenerates every Android and iOS launcher icon from tool/icon/app_icon.png.

Run it after replacing that one file:

    python tool/generate_app_icons.py

The master should be a square PNG, ideally 1024x1024 — anything smaller is
upscaled and the large icons (Android xxxhdpi, the iOS 1024 store icon) come
out soft.

Android keeps the transparent corners. iOS icons must be fully opaque or the
App Store rejects the build, so those are flattened onto white.

Android 8+ also gets an adaptive icon: the launcher masks it to whatever shape
the phone uses (circle, squircle, teardrop), so the artwork is drawn on its own
108dp layer over a flat background colour.
"""

import json
import os
import sys

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MASTER = os.path.join(ROOT, 'tool', 'icon', 'app_icon.png')

ANDROID_RES = os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res')
ANDROID_SIZES = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}

# The adaptive foreground layer is always 108dp square, so each density needs
# 108/48 = 2.25x the legacy icon.
ADAPTIVE_SIZES = {folder: int(size * 2.25) for folder, size in ANDROID_SIZES.items()}

# Only the middle 72 of those 108dp are guaranteed to survive the launcher's
# mask. The logo is a circle that fills its frame, so drawing it at 70% lets it
# meet the edges of a circular mask, with the couple of percent that spills over
# the safe zone being the outer rim of the ring — invisible once cropped.
ADAPTIVE_LOGO_SCALE = 0.70

# Shows through wherever the mask is wider than the logo (the corners of a
# squircle, for instance). White keeps the yellow ring crisp; swap it for the
# brand green '#FF145C39' if you'd rather have a green tile.
ADAPTIVE_BACKGROUND = '#FFFFFFFF'

IOS_ICONSET = os.path.join(ROOT, 'ios', 'Runner', 'Assets.xcassets', 'AppIcon.appiconset')
IOS_BACKGROUND = (255, 255, 255)


def load_master():
    if not os.path.exists(MASTER):
        sys.exit(f'Master icon not found: {MASTER}')
    image = Image.open(MASTER).convert('RGBA')
    if image.width != image.height:
        sys.exit(f'The master icon must be square, got {image.width}x{image.height}')
    if image.width < 512:
        print(f'Warning: the master is only {image.width}px. 1024x1024 gives a much sharper result.')
    return image


def resize(image, size):
    return image.resize((size, size), Image.LANCZOS)


def write_android(master):
    for folder, size in sorted(ANDROID_SIZES.items(), key=lambda kv: kv[1]):
        target = os.path.join(ANDROID_RES, folder, 'ic_launcher.png')
        os.makedirs(os.path.dirname(target), exist_ok=True)
        resize(master, size).save(target, 'PNG')
        print(f'android {size:>4}px  {folder}/ic_launcher.png')


def write_adaptive(master):
    for folder, canvas in sorted(ADAPTIVE_SIZES.items(), key=lambda kv: kv[1]):
        logo = resize(master, int(round(canvas * ADAPTIVE_LOGO_SCALE)))
        layer = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
        offset = (canvas - logo.width) // 2
        layer.paste(logo, (offset, offset), logo)

        target = os.path.join(ANDROID_RES, folder, 'ic_launcher_foreground.png')
        os.makedirs(os.path.dirname(target), exist_ok=True)
        layer.save(target, 'PNG')
        print(f'adaptive{canvas:>4}px  {folder}/ic_launcher_foreground.png')

    colors = os.path.join(ANDROID_RES, 'values', 'ic_launcher_background.xml')
    os.makedirs(os.path.dirname(colors), exist_ok=True)
    with open(colors, 'w', encoding='utf-8') as handle:
        handle.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<resources>\n'
            '    <!-- Written by tool/generate_app_icons.py -->\n'
            f'    <color name="ic_launcher_background">{ADAPTIVE_BACKGROUND}</color>\n'
            '</resources>\n'
        )
    print('adaptive       values/ic_launcher_background.xml')

    anydpi = os.path.join(ANDROID_RES, 'mipmap-anydpi-v26', 'ic_launcher.xml')
    os.makedirs(os.path.dirname(anydpi), exist_ok=True)
    with open(anydpi, 'w', encoding='utf-8') as handle:
        handle.write(
            '<?xml version="1.0" encoding="utf-8"?>\n'
            '<!-- Written by tool/generate_app_icons.py -->\n'
            '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
            '    <background android:drawable="@color/ic_launcher_background" />\n'
            '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
            '</adaptive-icon>\n'
        )
    print('adaptive       mipmap-anydpi-v26/ic_launcher.xml')


def write_ios(master):
    contents_path = os.path.join(IOS_ICONSET, 'Contents.json')
    with open(contents_path, encoding='utf-8') as handle:
        contents = json.load(handle)

    # Several entries share one file (iphone and ipad reuse the same @2x), so
    # collect the largest pixel size asked for per filename and render once.
    wanted = {}
    for entry in contents['images']:
        filename = entry.get('filename')
        if not filename:
            continue
        points = float(entry['size'].split('x')[0])
        scale = int(entry['scale'].rstrip('x'))
        pixels = int(round(points * scale))
        wanted[filename] = max(wanted.get(filename, 0), pixels)

    for filename, size in sorted(wanted.items(), key=lambda kv: kv[1]):
        flat = Image.new('RGB', (size, size), IOS_BACKGROUND)
        scaled = resize(master, size)
        flat.paste(scaled, (0, 0), scaled)
        flat.save(os.path.join(IOS_ICONSET, filename), 'PNG')
        print(f'ios     {size:>4}px  {filename}')


def main():
    master = load_master()
    print(f'Master: {MASTER} ({master.width}x{master.height})\n')
    write_android(master)
    write_adaptive(master)
    write_ios(master)
    print('\nDone. Rebuild the app to see the new icon.')


if __name__ == '__main__':
    main()
