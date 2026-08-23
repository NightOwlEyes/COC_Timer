# Cấu trúc và Chức năng các file trong dự án CocTimer
# File Structure and Component Functions of the CocTimer Project

Tài liệu này mô tả chi tiết chức năng của từng thành phần trong mã nguồn và tài nguyên dự án **CocTimer**.
This document describes in detail the function of each component in the **CocTimer** project's source code and assets.

## 📁 Thư mục Gốc (root/) / Root Directory (root/)
- **FILE_STRUCTURE.md**: Tài liệu này, mô tả cấu trúc và chức năng các file.
  *This document — describes the project's structure and file functions.*
- **README.md / README-vi.md**: Hướng dẫn sử dụng dự án (Tiếng Anh và Tiếng Việt).
  *Project usage guide (English and Vietnamese).*
- **pubspec.yaml**: Quản lý các thư viện phụ thuộc (dependencies) và khai báo tài nguyên (assets).
  *Manages project dependencies and declares assets.*
- **analysis_options.yaml**: Cấu hình các quy tắc kiểm tra mã nguồn (lint).
  *Configures source code linting rules.*

## 📁 lib/ (Mã nguồn chính) / lib/ (Main Source Code)
- **main.dart**: Điểm khởi đầu của ứng dụng. Khởi tạo các dịch vụ nền (`ScheduleService`, `RuleManager`), thiết lập giao diện Terminal và quản lý các quyền cơ bản khi khởi động.
  *App entry point. Initializes background services (`ScheduleService`, `RuleManager`), sets up the Terminal UI, and manages basic permissions on startup.*

### 📁 models/ (Định nghĩa dữ liệu) / models/ (Data Definitions)
- **village_models.dart**: Chứa các lớp dữ liệu cốt lõi như `VillageData`, `UpgradeItem`, `BoostData` và enum `AlarmType` (None, System, Fullscreen).
  *Contains core data classes such as `VillageData`, `UpgradeItem`, `BoostData`, and the `AlarmType` enum (None, System, Fullscreen).*

### 📁 services/ (Dịch vụ hệ thống) / services/ (System Services)
- **schedule_service.dart**: Xử lý logic báo thức và thông báo, tích hợp gói `alarm` và `flutter_local_notifications`. Quản lý các quyền hạn đặc biệt trên Android (FSI, Exact Alarms, Battery Optimization).
  *Handles alarm and notification logic, integrating the `alarm` and `flutter_local_notifications` packages. Manages special Android permissions (FSI, Exact Alarms, Battery Optimization).*

### 📁 screens/ (Màn hình chính) / screens/ (Main Screens)
- **terminal_screen.dart**: Giao diện người dùng chính theo phong cách Terminal. Xử lý nhập JSON, quản lý danh sách các làng và chuyển đổi hiển thị giữa các làng.
  *Main user interface in Terminal style. Handles JSON input, manages the village list, and switches display between villages.*

### 📁 utils/ (Tiện ích & Logic) / utils/ (Utilities & Logic)
- **app_strings.dart**: Quản lý tập trung các chuỗi văn bản và từ điển ánh xạ tên công trình/lính từ mã ID trong game.
  *Centralized management of text strings and the dictionary mapping building/troop names from in-game ID codes.*
- **rule_manager.dart**: Định nghĩa lớp `TimeRule` và quản lý logic các quy tắc báo thức tự động, kiểm tra đụng độ thời gian và lưu trữ cấu hình người dùng vào `SharedPreferences`.
  *Defines the `TimeRule` class and manages automatic alarm rule logic, checks for time conflicts, and stores user configuration in `SharedPreferences`.*
- **village_parser.dart**: Thuật toán phân tích JSON trích xuất từ game, tính toán thời gian hoàn thành thực tế (`realEta`) sau khi áp dụng các loại Buff (Tháp đồng hồ, Bình thợ xây, Sách thời gian).
  *Algorithm that parses JSON extracted from the game and calculates the actual completion time (`realEta`) after applying Buffs (Clock Tower, Builder's Potion, Book of Time).*

### 📁 widgets/ (Thành phần giao diện) / widgets/ (UI Components)
- **alarm_popup.dart**: Giao diện báo thức toàn màn hình (Full-screen Overlay) khi có công trình hoàn tất.
  *Full-screen alarm overlay UI shown when a building is completed.*
- **settings_dialog.dart**: Hộp thoại cấu hình hệ thống quy tắc báo thức và cài đặt mặc định toàn cục.
  *Dialog for configuring the alarm rule system and global default settings.*
- **village_detail_dialog.dart**: Hộp thoại chi tiết xem và chỉnh sửa nâng cấp, đổi tên và tùy chỉnh báo thức cho từng hạng mục.
  *Detail dialog for viewing/editing upgrades, renaming, and customizing alarms for each item.*
- **village_card.dart**: Thành phần hiển thị tóm tắt trạng thái làng trên màn hình chính.
  *Component that displays a summary of village status on the main screen.*
- **terminal_frame_painter.dart**: Sử dụng `CustomPainter` để tạo hiệu ứng khung viền kỹ thuật số Retro cho giao diện.
  *Uses `CustomPainter` to render the retro digital border-frame effect for the UI.*

## 📁 assets/ (Tài nguyên) / assets/ (Assets)
- **LogoMain.png**: Logo chính hiển thị trong giao diện Terminal.
  *Main logo displayed in the Terminal UI.*
- **ring.mp3**: Âm thanh báo thức tùy chỉnh cho chế độ Full-screen.
  *Custom alarm sound for Full-screen mode.*
- **icon.png**: Biểu tượng ứng dụng.
  *App icon.*

## 📁 Dictionary/ (Dữ liệu hỗ trợ) / Dictionary/ (Supporting Data)
- **Mapping.xlsx**: Bảng ánh xạ ID công trình và tên hiển thị dùng để cập nhật dữ liệu cho `app_strings.dart`.
  *Table mapping building IDs to display names, used to update data for `app_strings.dart`.*