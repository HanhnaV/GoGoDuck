# 🦆 GoGoDuck - Realtime Multi-player Duck Racing Game

**GoGoDuck** là dự án game cá cược đua vịt 2D trực tuyến đa người chơi. Game sử dụng kiến trúc Serverless, mọi logic xử lý dữ liệu và đồng bộ trạng thái nhiều máy khách (Client) được thực hiện hoàn toàn qua hệ sinh thái Firebase.

## 🛠️ Tech Stack (Công nghệ sử dụng)
* **Framework:** Flutter (Hỗ trợ Android, iOS, Web).
* **State Management:** BLoC / Cubit (Phân tách giao diện và logic).
* **Bảo mật & Định danh:** Firebase Authentication.
* **Database (Tĩnh & Tiền tệ):** Cloud Firestore (Sử dụng Transaction để đảm bảo tính toàn vẹn).
* **Database (Động & Tốc độ cao):** Firebase Realtime Database.
* **Game Engine 2D:** Sử dụng Flutter `CustomPainter` nguyên bản, không dùng Flame để tối ưu dung lượng và thời gian phát triển.

---

## 📂 Cấu Trúc Thư Mục (Folder Directory)
Dự án áp dụng cấu trúc **Feature-First** để chia để trị. Mỗi tính năng là một module độc lập, giúp 6 Developer không bị conflict code khi làm việc chung.

```text
lib/
├── core/                   # Cốt lõi dùng chung cho toàn app
│   ├── constants/          # Chứa biến màu sắc, kích thước, tên collection Firebase
│   ├── network/            # File firebase_service.dart (Hàm gọi Database chung)
│   └── utils/              # Các hàm format tiền tệ, thời gian...
├── features/               # Các tính năng chính (Mỗi Dev thầu 1 thư mục)
│   ├── auth/               # Đăng nhập / Đăng ký
│   │   ├── bloc/           # Xử lý luồng sự kiện đăng nhập
│   │   └── view/           # Màn hình UI (auth_screen.dart)
│   ├── home/               # Sảnh chờ & Bảng xếp hạng
│   │   └── view/           # home_screen.dart, leaderboard_widget.dart
│   ├── game/               # Gameplay cốt lõi
│   │   ├── logic/          # game_logic_service.dart (Thuật toán vịt chạy)
│   │   └── view/           # game_screen.dart (CustomPainter)
│   └── betting/            # Tính năng đặt cược
│       ├── bloc/           # betting_bloc.dart (Kiểm tra số dư, trừ tiền)
│       └── view/           # Màn hình popup chọn vịt & nhập tiền
├── firebase_options.dart   # File config tự sinh của FlutterFire (Tuyệt đối không sửa tay)
└── main.dart               # Khởi tạo App, Đăng ký Routes