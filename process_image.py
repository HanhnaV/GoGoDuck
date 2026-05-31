import sys
import os
import glob

try:
    from PIL import Image
    import rembg
except ImportError:
    print("Pillow or rembg is not installed yet.")
    sys.exit(0)

# Find the image
image_paths = glob.glob('C:/Users/Cuong/.gemini/antigravity/**/media__1780045749246.jpg', recursive=True)
if not image_paths:
    print("Image not found.")
    sys.exit(1)
image_path = image_paths[0]
print(f"Found image: {image_path}")

output_dir = "d:/duck/GoGoDuck/assets/images"

if not os.path.exists(output_dir):
    os.makedirs(output_dir)

try:
    img = Image.open(image_path)
    print(f"Image loaded successfully. Size: {img.size}")
    
    # Let's try removing background on the full image
    img_no_bg = rembg.remove(img)
    
    # Save the full image without background
    output_path = os.path.join(output_dir, "character_full.png")
    img_no_bg.save(output_path)
    print(f"Saved background-removed image to {output_path}")
    
except Exception as e:
    print(f"Error processing image: {e}")
