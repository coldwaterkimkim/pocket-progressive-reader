"""Generate an original app icon from procedural silver, display and wheel shapes."""
from pathlib import Path
from PIL import Image, ImageDraw
import json

size = 1024
image = Image.new('RGB', (size, size))
pixels = image.load()
for y in range(size):
    for x in range(size):
        noise = ((x * 37 + y * 91 + x * y * 13) % 11) - 5
        value = int(219 - y / size * 22 + noise)
        pixels[x, y] = (value, value, value)
draw = ImageDraw.Draw(image)
draw.rounded_rectangle((92, 136, 932, 454), radius=34, fill='#686969')
draw.rounded_rectangle((98, 140, 926, 448), radius=30, fill='#292a28')
draw.rounded_rectangle((113, 156, 911, 432), radius=22, fill='#f0ede2')
draw.rounded_rectangle((155, 347, 710, 366), radius=9, fill='#5a5a55')
draw.rounded_rectangle((155, 298, 620, 312), radius=7, fill='#c4c2b9')
draw.ellipse((220, 526, 804, 1110), fill='#898a87')
draw.ellipse((223, 526, 801, 1104), fill='#e1e1dc', outline='#fafaf6', width=4)
draw.ellipse((393, 698, 631, 936), fill='#9a9b96')
draw.ellipse((397, 699, 627, 929), fill='#e6e6e1', outline='#f7f7f2', width=3)
out = Path(__file__).resolve().parent.parent / 'PocketReader/Assets.xcassets/AppIcon.appiconset'
image.save(out / 'AppIcon.png')
(out / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
(out.parent / 'Contents.json').write_text('{"info":{"author":"xcode","version":1}}\n')
