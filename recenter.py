import os
from PIL import Image

def recenter_spritesheet(path):
    print(f"Processing {path}...")
    try:
        img = Image.open(path).convert("RGBA")
    except Exception as e:
        print(f"  Error loading: {e}")
        return
        
    width, height = img.size
    frame_size = height
    num_frames = width // frame_size
    
    print(f"  Size: {width}x{height}, Frames: {num_frames}")
    
    new_img = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    
    for i in range(num_frames):
        left = i * frame_size
        box = (left, 0, left + frame_size, frame_size)
        frame = img.crop(box)
        
        # Get bounding box of the non-transparent pixels
        bbox = frame.getbbox()
        if bbox:
            # bbox is (left, upper, right, lower)
            duck_w = bbox[2] - bbox[0]
            duck_h = bbox[3] - bbox[1]
            
            # Crop exactly the duck
            duck_crop = frame.crop(bbox)
            
            # Calculate perfectly centered position
            paste_x = (frame_size - duck_w) // 2
            paste_y = (frame_size - duck_h) // 2
            
            # Create a new empty frame and paste the duck
            new_frame = Image.new("RGBA", (frame_size, frame_size), (0, 0, 0, 0))
            new_frame.paste(duck_crop, (paste_x, paste_y))
            
            # Paste the new frame back into the spritesheet
            new_img.paste(new_frame, (left, 0))
        else:
            print(f"  Warning: Frame {i} is empty!")
            
    new_img.save(path, "PNG")
    print(f"  Saved perfectly centered sheet -> {path}")

def main():
    assets_dir = 'd:/duck/GoGoDuck/assets/images/'
    files = [
        'duck_yellow_spritesheet.png',
        'duck_red_spritesheet.png',
        'duck_green_spritesheet.png',
        'duck_blue_spritesheet.png'
    ]
    
    for f in files:
        full_path = os.path.join(assets_dir, f)
        if os.path.exists(full_path):
            recenter_spritesheet(full_path)
        else:
            print(f"File not found: {full_path}")

if __name__ == "__main__":
    main()
