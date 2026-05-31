import os
import glob
import math
from PIL import Image

def is_background_color(r, g, b):
    # The checkerboard is mostly grey colors around 164 and 118, with some variations.
    # We will mark any pixel where R, G, B are very close to each other (grey) 
    # and their value is between 100 and 180 as background.
    # Also, we check the exact background colors we found.
    if abs(r - g) < 15 and abs(g - b) < 15 and abs(r - b) < 15:
        if 100 <= r <= 180:
            return True
    return False

def remove_background(img_path, out_path, rotate=False):
    print(f"Processing {img_path}...")
    img = Image.open(img_path).convert("RGBA")
    data = img.getdata()
    
    new_data = []
    for item in data:
        r, g, b, a = item
        # We also want to remove white-ish edge artifacts from JPEG compression
        if is_background_color(r, g, b):
            new_data.append((255, 255, 255, 0))
        else:
            new_data.append(item)
            
    img.putdata(new_data)
    
    if rotate:
        # Rotate 90 degrees clockwise
        img = img.rotate(-90, expand=True)
        
    img.save(out_path, "PNG")
    print(f"Saved {out_path}")

files = [
    ('C:/Users/Cuong/.gemini/antigravity/brain/be924342-980c-4dd7-af71-493620688a44/media__1780146353243.jpg', 'd:/duck/GoGoDuck/assets/images/duck_blue_spritesheet.png', False),
    ('C:/Users/Cuong/.gemini/antigravity/brain/be924342-980c-4dd7-af71-493620688a44/media__1780146353260.jpg', 'd:/duck/GoGoDuck/assets/images/duck_red_spritesheet.png', False),
    ('C:/Users/Cuong/.gemini/antigravity/brain/be924342-980c-4dd7-af71-493620688a44/media__1780146353277.jpg', 'd:/duck/GoGoDuck/assets/images/duck_yellow_spritesheet.png', False),
    ('C:/Users/Cuong/.gemini/antigravity/brain/be924342-980c-4dd7-af71-493620688a44/media__1780146353288.jpg', 'd:/duck/GoGoDuck/assets/images/track_horizontal.png', True),
]

for src, dst, rot in files:
    if os.path.exists(src):
        remove_background(src, dst, rot)
    else:
        print(f"File not found: {src}")
