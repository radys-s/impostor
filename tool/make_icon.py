"""Render the app icon and write every size the iOS/web/Android templates use.

Run: python tool/make_icon.py   (needs Pillow and Windows Segoe UI Bold)
"""
from pathlib import Path
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
FONT = Path('C:/Windows/Fonts/segoeuib.ttf')
TOP = (255, 61, 87)      # party red
BOTTOM = (255, 184, 0)   # party yellow


def render(size=1024):
    img = Image.new('RGB', (size, size))
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        draw.line([(0, y), (size, y)], fill=tuple(round(a + (b - a) * t) for a, b in zip(TOP, BOTTOM)))
    font = ImageFont.truetype(str(FONT), int(size * 0.72))
    box = draw.textbbox((0, 0), '?', font=font)
    w, h = box[2] - box[0], box[3] - box[1]
    draw.text(((size - w) / 2 - box[0], (size - h) / 2 - box[1] - size * 0.02), '?', font=font, fill='white')
    return img


def main():
    icon = render()
    ios = ROOT / 'ios/Runner/Assets.xcassets/AppIcon.appiconset'
    for path in ios.glob('Icon-App-*.png'):
        spec = path.stem.removeprefix('Icon-App-')       # e.g. 83.5x83.5@2x
        points, scale = spec.split('@')
        px = round(float(points.split('x')[0]) * int(scale.rstrip('x')))
        icon.resize((px, px), Image.LANCZOS).save(path)
    web = ROOT / 'web'
    icon.resize((32, 32), Image.LANCZOS).save(web / 'favicon.png')
    for name, px in (('Icon-192.png', 192), ('Icon-512.png', 512), ('Icon-maskable-192.png', 192), ('Icon-maskable-512.png', 512)):
        icon.resize((px, px), Image.LANCZOS).save(web / 'icons' / name)
    for folder, px in (('mdpi', 48), ('hdpi', 72), ('xhdpi', 96), ('xxhdpi', 144), ('xxxhdpi', 192)):
        target = ROOT / f'android/app/src/main/res/mipmap-{folder}/ic_launcher.png'
        if target.exists():
            icon.resize((px, px), Image.LANCZOS).save(target)
    print('icons written')


if __name__ == '__main__':
    sys.exit(main())
