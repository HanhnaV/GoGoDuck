import sys
import os
import glob
import shutil

try:
    from PIL import Image
    import rembg
except ImportError:
    print("Pillow or rembg is not installed yet.")
    sys.exit(0)

# Find all media files
image_paths = glob.glob('C:/Users/Cuong/.gemini/antigravity/brain/be924342-980c-4dd7-af71-493620688a44/media__*.*')
output_dir = "d:/duck/GoGoDuck/assets/images"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

for path in image_paths:
    filename = os.path.basename(path)
    print(f"Processing {filename}...")
    
    if filename.endswith('.jpg'):
        try:
            img = Image.open(path)
            # Remove background
            img_no_bg = rembg.remove(img)
            # Save the full image without background
            output_name = filename.replace('.jpg', '.png')
            output_path = os.path.join(output_dir, output_name)
            img_no_bg.save(output_path)
            print(f"Saved background-removed image to {output_path}")
        except Exception as e:
            print(f"Error processing image {filename}: {e}")
    elif filename.endswith('.png'):
        try:
            # Just copy the PNG (assume it's the track)
            output_path = os.path.join(output_dir, "track.png")
            shutil.copy2(path, output_path)
            print(f"Copied track image to {output_path}")
        except Exception as e:
            print(f"Error copying PNG {filename}: {e}")

print("Done processing all images.")
