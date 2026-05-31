import io
import sys
import subprocess
from PIL import Image

# Tự động cài đặt thư viện nếu chưa có
try:
    from rembg import remove
except ImportError:
    print("Đang cài đặt thư viện rembg...")
    subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'rembg', 'onnxruntime'])
    from rembg import remove

def clean_spritesheet_with_rembg(input_path, output_path):
    print(f'Đang xử lý ảnh: {input_path}...')
    img = Image.open(input_path).convert('RGBA')
    
    # Ép kích thước về 1024x1023 để chia đều 4 cột x 3 hàng (Frame 256x341)
    img = img.resize((1024, 1023), Image.Resampling.LANCZOS)
    
    cell_w = 256
    cell_h = 341
    
    # Tạo một bức ảnh nền trong suốt hoàn toàn
    out_img = Image.new('RGBA', (1024, 1023), (0, 0, 0, 0))
    
    for row in range(3):
        for col in range(4):
            x = col * cell_w
            y = row * cell_h
            
            # Cắt từng chú vịt ra riêng lẻ
            frame = img.crop((x, y, x + cell_w, y + cell_h))
            
            # Sử dụng công nghệ AI của rembg để tách nền từng chú vịt cực chuẩn
            clean_frame = remove(frame)
            
            # Dán chú vịt đã tách nền trở lại vào khung lưới
            out_img.paste(clean_frame, (x, y))
            
    out_img.save(output_path, 'PNG')
    print(f'Đã lưu thành công: {output_path}')

if __name__ == "__main__":
    # Thay đổi đường dẫn tới thư mục chứa ảnh gốc của bạn
    input_blue = 'media__1780146353243.jpg'
    input_red = 'media__1780146353260.jpg'
    input_yellow = 'media__1780146353277.jpg'
    
    # Gọi hàm xử lý
    try:
        clean_spritesheet_with_rembg(input_blue, 'duck_blue_spritesheet.png')
        clean_spritesheet_with_rembg(input_red, 'duck_red_spritesheet.png')
        clean_spritesheet_with_rembg(input_yellow, 'duck_yellow_spritesheet.png')
        print("Hoàn tất toàn bộ!")
    except Exception as e:
        print(f"Có lỗi xảy ra: {e}")
