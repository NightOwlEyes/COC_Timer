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
- **main.dart**: Điểm khởi đầu của ứng dụng. Khởi tạo các dịch vụ nền (`ScheduleService`, `RuleManager`), đăng ký chạy ngầm Workmanager, thiết lập giao diện Terminal và quản lý các quyền cơ bản khi khởi động.
  *App entry point. Initializes background services (`ScheduleService`, `RuleManager`), registers Workmanager tasks, sets up the Terminal UI, and manages basic permissions on startup.*

### 📁 models/ (Định nghĩa dữ liệu) / models/ (Data Definitions)
- **village_models.dart**: Chứa các lớp dữ liệu cốt lõi như `VillageData`, `UpgradeItem`, `BoostData` (quản lý thời gian các loại Thuốc, Lương khô, Súp, Tháp đồng hồ, Học việc) và enum `AlarmType` (None, System, Fullscreen).
  *Contains core data classes such as `VillageData`, `UpgradeItem`, `BoostData` (manages durations for Potions, Consumables, Clock Tower, Apprentices), and the `AlarmType` enum (None, System, Fullscreen).*

### 📁 services/ (Dịch vụ hệ thống) / services/ (System Services)
- **schedule_service.dart**: Xử lý logic báo thức và thông báo, quản lý tính năng "Dán Nhanh" (Quick Paste) kèm cơ chế tự động watchdog kiểm tra định kỳ và đẩy lại thông báo nếu bị gạt mất trên Android cao, tích hợp gói `alarm` và `flutter_local_notifications`. Điều khiển các quyền Android (FSI, Exact Alarms, Battery Optimization).
  *Handles alarm and notification logic, manages "Quick Paste" feature with watchdog auto-reposting on newer Android versions, integrating `alarm` and `flutter_local_notifications`. Controls Android permissions (FSI, Exact Alarms, Battery Optimization).*
- **coc_api_service.dart**: Giao tiếp với Clash of Clans API (thông qua Cloudflare Worker). Hỗ trợ lấy thông tin Clan, dữ liệu War/CWL và tên người chơi từ Player Tag.
  *Communicates with the Clash of Clans API (via Cloudflare Worker). Supports fetching Clan info, War/CWL data, and player names from Player Tags.*
- **war_sync_service.dart**: Dịch vụ chạy ngầm định kỳ bằng `Workmanager`. Tự động cập nhật lịch War/CWL và duy trì trạng thái thông báo Dán Nhanh (Quick Paste watchdog) khi app đóng.
  *Periodic background service using `Workmanager`. Automatically syncs War/CWL schedules and maintains Quick Paste notification status (watchdog) when the app is closed.*

### 📁 screens/ (Màn hình chính) / screens/ (Main Screens)
- **terminal_screen.dart**: Giao diện người dùng chính (Local Server). Xử lý nhập JSON, quản lý danh sách các làng, tích hợp tính năng "Dán Nhanh" (kèm popup hướng dẫn khi bật), hộp thoại nhắc nhở tái nhập JSON khi nâng cấp/dùng thuốc khi mở app, và kiểm tra cập nhật ứng dụng.
  *Main user interface (Local Server). Handles JSON input, manages village list, integrates "Quick Paste" feature (with onboarding popup), app-open reimport reminder dialog, and app update checks.*
- **online_screen.dart**: Giao diện quản lý Clan và theo dõi War (Online Server). Cho phép thêm Clan bằng Tag, hiển thị danh sách Clan và trạng thái đồng bộ API.
  *UI for managing Clans and tracking Wars (Online Server). Allows adding Clans by Tag, displays Clan lists, and API sync status.*
- **war_detail_screen.dart**: Hiển thị chi tiết trận War hiện tại hoặc 7 ngày CWL. Bao gồm tỉ số, phần trăm phá hủy, lượt tấn công của thành viên và đếm ngược thời gian.
  *Displays details of the current War or 7-day CWL. Includes score, destruction percentage, member attacks, and time countdown.*

### 📁 utils/ (Tiện ích & Logic) / utils/ (Utilities & Logic)
- **app_strings.dart**: Quản lý tập trung các chuỗi văn bản và đa ngôn ngữ (Vi/En). Chứa các interface và dictionary để chuyển đổi ngôn ngữ toàn ứng dụng.
  *Centralized management of text strings and multi-language support (Vi/En). Contains interfaces and dictionaries for app-wide language switching.*
- **game_data.dart**: Chứa từ điển dữ liệu thô ánh xạ ID công trình và lính từ game.
  *Contains raw data dictionary mapping building and troop IDs from the game.*
- **rule_manager.dart**: Quản lý logic các quy tắc báo thức tự động, kiểm tra đụng độ thời gian và lưu trữ cấu hình người dùng (bao gồm cấu hình War Auto-Sync).
  *Manages automatic alarm rule logic, checks for time conflicts, and stores user configuration (including War Auto-Sync config).*
- **village_parser.dart**: Thuật toán phân tích JSON trích xuất từ game, tính toán thời gian hoàn thành thực tế (`realEta`) sau khi áp dụng các loại Buff và hiệu ứng Trợ lý/Học việc, đồng thời trích xuất thời lượng các loại buff vào `BoostData`.
  *Algorithm that parses JSON extracted from the game, calculates the actual completion time (`realEta`) after applying Buffs and Apprentices, and extracts boost durations into `BoostData`.*

### 📁 widgets/ (Thành phần giao diện) / widgets/ (UI Components)
- **alarm_popup.dart**: Giao diện báo thức toàn màn hình (Full-screen Overlay) khi có công trình hoàn tất.
  *Full-screen alarm overlay UI shown when a building is completed.*
- **settings_dialog.dart**: Hộp thoại cấu hình hệ thống quy tắc báo thức, cài đặt War và cập nhật ứng dụng.
  *Dialog for configuring the alarm rule system, War settings, and app updates.*
- **village_detail_dialog.dart**: Hộp thoại chi tiết xem và chỉnh sửa nâng cấp cho Local Server; hiển thị đếm ngược thời gian tác dụng của các loại thuốc/vật phẩm hỗ trợ/học việc và gắn dấu chấm than (`!`) cảnh báo các công trình hoàn tất trước khi thuốc hết hạn.
  *Detail dialog for viewing/editing upgrades for Local Server; displays countdowns for active boosts/apprentices and marks upgrades finishing before boost expiry with an exclamation mark (`!`).*
- **village_card.dart**: Thành phần hiển thị tóm tắt trạng thái làng trên màn hình Local.
  *Component that displays a summary of village status on the Local screen.*
- **war_dashboard_widget.dart**: Bảng điều khiển phân tích CWL, hiển thị ma trận Town Hall của 8 Clan trong bảng đấu.
  *CWL analysis dashboard, displaying the Town Hall matrix of 8 Clans in the group.*
- **terminal_frame_painter.dart**: CustomPainter tạo hiệu ứng khung viền kỹ thuật số Retro.
  *CustomPainter that renders the retro digital border-frame effect.*
- **terminal_header.dart**: Hộp chứa tiêu đề, đồng hồ, nút chuyển đổi Server và Ngôn ngữ.
  *Header container displaying title, clock, Server and Language toggles.*
- **terminal_components.dart**: Các thành phần UI phong cách Terminal gồm Logo, Thẻ chuyển đổi server, Khu vực nhập liệu (hỗ trợ bật/tắt Dán Nhanh) và Footer thông tin hệ thống.
  *Terminal-style UI components including Logo, Server toggle tag, Input area (supports toggling Quick Paste), and system info Footer.*

## 📁 assets/ (Tài nguyên) / assets/ (Assets)
- **LogoMain.png**: Logo chính hiển thị trong giao diện Terminal.
- **ring.mp3**: Âm thanh báo thức tùy chỉnh cho chế độ Full-screen.
- **icon.png**: Biểu tượng ứng dụng.
- **donate-qr.png**: Mã QR ủng hộ dự án.

## 📁 Dictionary/ (Dữ liệu hỗ trợ) / Dictionary/ (Supporting Data)
- **Mapping.txt**: Bảng ánh xạ ID công trình và tên hiển thị dùng để cập nhật dữ liệu cho `game_data.dart`.
  *Table mapping building IDs to display names, used to update data for `game_data.dart`.*

## 📁 Screenshot/ (Hình ảnh minh họa) / Screenshot/ (Screenshots)
- **1.png, 2.png, 3.png**: Ảnh minh họa giao diện ứng dụng (Tiếng Việt).
  *App screenshots (Vietnamese).*
- **1en.png, 2en.png, 3en.png**: Ảnh minh họa giao diện ứng dụng (Tiếng Anh).
  *App screenshots (English).*
