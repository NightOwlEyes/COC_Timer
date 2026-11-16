# Cấu trúc và Chức năng các file trong dự án CocTimer
# File Structure and Component Functions of the CocTimer Project

Tài liệu này mô tả chi tiết chức năng của từng thành phần trong mã nguồn và tài nguyên dự án **CocTimer**.
*This document describes in detail the function of each component in the **CocTimer** project's source code and assets.*

## 📁 Thư mục Gốc (root/) / Root Directory (root/)
- **FILE_STRUCTURE.md**: Tài liệu này, mô tả cấu trúc và chức năng các file.
  *This document — describes the project's structure and file functions.*
- **README.md / README-vi.md**: Hướng dẫn sử dụng dự án (Tiếng Anh và Tiếng Việt).
  *Project usage guide (English and Vietnamese).*
- **ADB_AI_GUIDE.md**: Hướng dẫn dùng ADB cho AI agent gửi JSON làng và nhận kết quả thời gian nâng cấp hoàn thành.
  *ADB usage guide for AI agents to import village JSON and retrieve upgrade completion results.*
- **pubspec.yaml**: Quản lý các thư viện phụ thuộc (dependencies) và khai báo tài nguyên (assets).
  *Manages project dependencies and declares assets.*
- **analysis_options.yaml**: Cấu hình các quy tắc kiểm tra mã nguồn (lint).
  *Configures source code linting rules.*

## 📁 lib/ (Mã nguồn chính) / lib/ (Main Source Code)
- **main.dart**: Điểm khởi đầu của ứng dụng. Khởi tạo các dịch vụ nền (`ScheduleService`, `RuleManager`), khởi tạo theme (`AppTheme`), đăng ký chạy ngầm Workmanager, thiết lập cấu hình giao diện (kèm lắng nghe chuyển đổi theme thời gian thực qua `ValueListenableBuilder`) và quản lý các quyền cơ bản khi khởi động.
  *App entry point. Initializes background services (`ScheduleService`, `RuleManager`), initializes themes (`AppTheme`), registers Workmanager tasks, sets up UI structure (with real-time theme switching listener via `ValueListenableBuilder`), and manages basic permissions on startup.*

### 📁 theme/ (Hệ thống giao diện song song) / theme/ (Dual Theme System)
- **app_theme.dart**: Quản lý 2 bộ theme song song (`Terminal` hoài cổ dùng font `monospace` và `Kính mờ / Glassmorphism` dùng font `JosefinSans`, riêng màu Hồng dùng font `Coiny`) kèm 7 tùy chọn màu sắc nhấn (`AppAccentColor`: Hồng, Đỏ, Cam, Vàng, Xanh lá, Xanh dương, Tím) đồng bộ cho cả Làng Chính và Làng Thợ Xây, lưu trữ cấu hình qua `SharedPreferences`, cung cấp bảng màu ngữ nghĩa `AppColors`, widget chọn màu `AccentColorPicker`, định hình bán kính bo góc `radius`, helper chuẩn hoá văn bản `AppTheme.label` và bộ widget kính mờ tối ưu GPU (`GlassBackground`, `GlassBox`, `AdaptiveDialog`, `GlassDialogSurface`).
  *Manages the dual theme system (`Terminal` retro with `monospace` and `Glassmorphism` with `JosefinSans`, or `Coiny` for Pink) plus 7 custom accent color presets (`AppAccentColor`) applied across both Home Village and Builder Base, persists preferences via `SharedPreferences`, provides semantic color tokens `AppColors`, `AccentColorPicker`, corner radiuses, text cleaner helper `AppTheme.label`, and GPU-optimized frosted glass widgets (`GlassBackground`, `GlassBox`, `AdaptiveDialog`, `GlassDialogSurface`).*

### 📁 models/ (Định nghĩa dữ liệu) / models/ (Data Definitions)
- **village_models.dart**: Chứa các lớp dữ liệu cốt lõi như `VillageData` (tính toán động số lượng thợ xây `totalBuilders` và slot phòng thí nghiệm `totalLab` khi thuê Thợ xây / Nhà nghiên cứu Yêu tinh (`extra: true`), tự động cảnh báo slot chính đang rảnh và tự động quay về 6/6, 1/1 khi hoàn tất), `UpgradeItem` (hỗ trợ cờ hiệu `isExtra` cho thợ xây và nghiên cứu thuê), `BoostData` (quản lý thời gian các loại Thuốc, Lương khô, Súp, Tháp đồng hồ, Học việc) và enum `AlarmType` (None, System, Fullscreen).
  *Contains core data classes such as `VillageData` (dynamically calculates `totalBuilders` and laboratory slots `totalLab` when renting Goblin Builder / Goblin Researcher (`extra: true`), automatically alerts when regular slots are idle, and resets to 6/6, 1/1 upon completion), `UpgradeItem` (supports `isExtra` flag for rented builders and researchers), `BoostData` (manages durations for Potions, Consumables, Clock Tower, Apprentices), and the `AlarmType` enum (None, System, Fullscreen).*

### 📁 services/ (Dịch vụ hệ thống) / services/ (System Services)
- **schedule_service.dart**: Xử lý logic báo thức và thông báo, quản lý tính năng "Dán Nhanh" (Quick Paste) kèm cơ chế tự động watchdog kiểm tra định kỳ và đẩy lại thông báo nếu bị gạt mất trên Android cao, tích hợp gói `alarm` và `flutter_local_notifications`. Điều khiển các quyền Android (FSI, Exact Alarms, Battery Optimization) và đồng bộ thông báo/báo thức đa ngôn ngữ.
  *Handles alarm and notification logic, manages "Quick Paste" feature with watchdog auto-reposting on newer Android versions, integrating `alarm` and `flutter_local_notifications`. Controls Android permissions (FSI, Exact Alarms, Battery Optimization) and multi-language alert sync.*
- **coc_api_service.dart**: Giao tiếp với Clash of Clans API (thông qua Cloudflare Worker). Hỗ trợ lấy thông tin Clan, dữ liệu War/CWL và tên người chơi từ Player Tag.
  *Communicates with the Clash of Clans API (via Cloudflare Worker). Supports fetching Clan info, War/CWL data, and player names from Player Tags.*
- **war_sync_service.dart**: Dịch vụ chạy ngầm định kỳ bằng `Workmanager`. Tự động cập nhật lịch War/CWL và duy trì trạng thái thông báo Dán Nhanh (Quick Paste watchdog) khi app đóng.
  *Periodic background service using `Workmanager`. Automatically syncs War/CWL schedules and maintains Quick Paste notification status (watchdog) when the app is closed.*
- **ai_command_service.dart**: Dịch vụ tiếp nhận và xử lý lệnh tự động hoá từ AI agent qua ADB (`MethodChannel 'coctimer/ai_command'`), hỗ trợ nạp JSON (`importJson`) và truy vấn thời gian hoàn thành công trình (`queryUpgrades`) cả khi app đang mở lẫn khi chạy ngầm qua entrypoint `aiCommandEntrypoint`.
  *Service that handles AI agent automation commands via ADB (`MethodChannel 'coctimer/ai_command'`), supporting JSON import (`importJson`) and upgrade completion queries (`queryUpgrades`) in both foreground and headless background mode (`aiCommandEntrypoint`).*

### 📁 screens/ (Màn hình chính) / screens/ (Main Screens)
- **terminal_screen.dart**: Giao diện người dùng chính (Local Server). Điều khiển vòng đời ứng dụng, đồng hồ hiển thị, nhận tín hiệu Dán Nhanh từ thông báo, liên kết với `AiCommandService` để cập nhật UI khi nhận lệnh ADB, tự động ẩn Header khi cuộn ở chế độ màn hình ngang, tích hợp nền ánh sáng `GlassBackground`, kết nối với `VillageManager` và `TerminalDialogs` để quản lý danh sách làng, nhận diện chuông đang reo và xử lý dữ liệu.
  *Main user interface (Local Server). Controls app lifecycle, clock display, receives Quick Paste triggers from notifications, binds `AiCommandService` to refresh UI on ADB commands, auto-hides Header on scroll in landscape mode, integrates `GlassBackground` ambient lighting, and connects with `VillageManager` and `TerminalDialogs` for village list, ringing alarm detection, and state handling.*
- **online_screen.dart**: Giao diện quản lý Clan và theo dõi War (Online Server). Cho phép thêm Clan bằng Tag, hiển thị danh sách Clan, trạng thái đồng bộ API, tự động kiểm tra điều kiện kích hoạt đồng bộ War và hỗ trợ tự động ẩn Header khi cuộn ở chế độ màn hình ngang.
  *UI for managing Clans and tracking Wars (Online Server). Allows adding Clans by Tag, displays Clan lists, API sync status, automatically validates war auto-sync prerequisites, and supports auto-hiding Header on scroll in landscape mode.*
- **war_detail_screen.dart**: Hiển thị chi tiết trận War hiện tại hoặc 7 ngày CWL. Bao gồm tỉ số, phần trăm phá hủy, lượt tấn công của thành viên và đếm ngược thời gian.
  *Displays details of the current War or 7-day CWL. Includes score, destruction percentage, member attacks, and time countdown.*

### 📁 utils/ (Tiện ích & Logic) / utils/ (Utilities & Logic)
- **village_manager.dart**: Quản lý tập trung toàn bộ dữ liệu làng, hàng đợi chuông báo (`AlarmSettings`), kiểm tra chuông đang reo khi mở app (`checkActiveRingingAlarms`), cơ chế quét dọn các nâng cấp hoàn thành theo thời gian thực (`tickCleanup`), lưu trữ cục bộ (`SharedPreferences`), nhập JSON, chu kỳ đổi trạng thái chuông báo và đồng bộ thông báo khi đổi ngôn ngữ.
  *Centralized manager for village data, alarm queues (`AlarmSettings`), checking active ringing alarms on app launch (`checkActiveRingingAlarms`), real-time upgrade completion cleanup (`tickCleanup`), local persistence (`SharedPreferences`), JSON import, alarm cycling, and multi-language alert synchronization.*
- **app_strings.dart**: Quản lý tập trung các chuỗi văn bản và đa ngôn ngữ (Vi/En). Chứa các interface và dictionary để chuyển đổi ngôn ngữ toàn ứng dụng (bao gồm nhãn cấu hình giao diện `Terminal` / `Kính mờ`).
  *Centralized management of text strings and multi-language support (Vi/En). Contains interfaces and dictionaries for app-wide language switching (including `Terminal` / `Glass` theme labels).*
- **game_data.dart**: Chứa từ điển dữ liệu thô ánh xạ ID công trình và lính từ game.
  *Contains raw data dictionary mapping building and troop IDs from the game.*
- **rule_manager.dart**: Quản lý logic các quy tắc báo thức tự động, kiểm tra đụng độ thời gian và lưu trữ cấu hình người dùng (bao gồm cấu hình War Auto-Sync, thời gian nhắc trước nâng cấp mặc định 2 phút, và cài đặt tự động quay lại game sau khi dán nhanh `quickPasteAutoReturn`).
  *Manages automatic alarm rule logic, checks for time conflicts, and stores user configuration (including War Auto-Sync config, 2-minute default early reminder, and `quickPasteAutoReturn` setting).*
- **village_parser.dart**: Thuật toán phân tích JSON trích xuất từ game, tính toán thời gian hoàn thành thực tế (`realEta`) sau khi áp dụng các loại Buff và hiệu ứng Trợ lý/Học việc, nhận diện chính xác cờ hiệu `extra == true` của Thợ xây Yêu tinh, đồng thời trích xuất thời lượng các loại buff vào `BoostData`.
  *Algorithm that parses JSON extracted from the game, calculates the actual completion time (`realEta`) after applying Buffs and Apprentices, accurately detects the `extra == true` flag for the Goblin Builder, and extracts boost durations into `BoostData`.*

### 📁 widgets/ (Thành phần giao diện) / widgets/ (UI Components)
- **terminal_dialogs.dart**: Tập hợp toàn bộ các hộp thoại và popup của màn hình chính (sử dụng `AdaptiveDialog` hỗ trợ cả Terminal và Kính mờ): nhắc nhở nhập lại JSON khi mở app, hướng dẫn Dán Nhanh, popup phản hồi kết quả Dán Nhanh, hộp thoại xác nhận xoá làng và hộp thoại đặt tên làng mới.
  *Collection of all dialogs and popups for the main screen (using `AdaptiveDialog` to support both Terminal and Glassmorphism): app-open reimport reminder, Quick Paste onboarding, Quick Paste feedback overlay, delete village confirmation, and new village naming dialog.*
- **alarm_popup.dart**: Giao diện báo thức toàn màn hình (Full-screen Overlay) khi có công trình hoàn tất, đồng bộ trạng thái tắt chuông với thanh thông báo/màn hình khoá và ngăn chặn thao tác vô tình đóng bảng khi chuông đang đổ.
  *Full-screen alarm overlay UI shown when a building is completed, synchronizing dismissal state with notifications/lockscreen and preventing accidental dismissal while ringing.*
- **settings_dialog.dart**: Hộp thoại cấu hình hệ thống: chuyển đổi qua lại giữa 2 giao diện (`[ TERMINAL ]` / `[ KÍNH MỜ ]`), chọn 7 màu nhấn tùy chỉnh, quy tắc báo thức tự động (hỗ trợ nhập giờ trực tiếp HH:MM), cài đặt War (tự động tắt đồng bộ ngầm khi tắt cả 2 báo thức hoặc chưa có Clan), cấu hình tính năng Dán Nhanh (tự động quay lại game) và kiểm tra cập nhật ứng dụng.
  *System configuration dialog: switching between the 2 themes (`[ TERMINAL ]` / `[ GLASS ]`) and 7 custom accent colors, automatic alarm rule system (supports direct HH:MM input), War settings (auto-disables sync if both alerts are off or no Clans exist), Quick Paste auto-return setting, and app updates.*
- **village_detail_dialog.dart**: Hộp thoại chi tiết xem và chỉnh sửa nâng cấp cho Local Server (hỗ trợ khung kính mờ `AdaptiveDialog`); hỗ trợ nút chuyển đổi kiểu thời gian (`[ MỐC GIỜ ]` / `[ ĐẾM NGƯỢC ]`) có khoảng cách rõ ràng cho cả thời gian hoàn thành công trình và đếm ngược vật phẩm hỗ trợ/học việc, gắn dấu chấm than (`!`) cảnh báo các công trình hoàn tất trước khi thuốc hết hạn.
  *Detail dialog for viewing/editing upgrades for Local Server (supports frosted glass `AdaptiveDialog`); supports time format toggle (`[ EXACT TIME ]` / `[ COUNTDOWN ]`) with clean spacing for both upgrade completion times and boost/apprentice durations, and marks upgrades finishing before boost expiry with an exclamation mark (`!`).*
- **village_card.dart**: Thành phần hiển thị tóm tắt trạng thái làng trên màn hình Local (hỗ trợ chạm/chạm giữ để sao chép mã làng nhanh, theo dõi thợ rảnh và phòng thí nghiệm rảnh khi có Goblin extra, tự động chuyển đổi giữa bố cục dòng lệnh Terminal và thẻ kính mờ `GlassBox` kèm các ô chỉ số có icon trực quan).
  *Component that displays a summary of village status on the Local screen (supports tap/long-press to copy village tag, tracking idle builders and idle laboratory when Goblin extras are active, automatically adapts between Terminal command-line layout and frosted glass `GlassBox` cards with icon stat tiles).*
- **war_dashboard_widget.dart**: Bảng điều khiển phân tích CWL, hiển thị ma trận Town Hall của 8 Clan trong bảng đấu.
  *CWL analysis dashboard, displaying the Town Hall matrix of 8 Clans in the group.*
- **terminal_frame_painter.dart**: CustomPainter tạo hiệu ứng khung viền góc chữ L kỹ thuật số ở chế độ Terminal (tự động ẩn khi ở chế độ Kính mờ).
  *CustomPainter that renders the L-corner digital border-frame effect in Terminal mode (automatically hidden in Glassmorphism mode).*
- **terminal_header.dart**: Hộp chứa tiêu đề, đồng hồ, nút chuyển đổi Server, Ngôn ngữ và Cài đặt. Ở màn hình dọc, nút cập nhật phiên bản mới nằm gọn bên dưới nút chọn ngôn ngữ; ở màn hình ngang rộng, tự động dàn bố cục 3 cột (đưa đồng hồ và nút cập nhật ra giữa). Hỗ trợ giao diện nút thuốc (pill badges) kính mờ ở chế độ `Glassmorphism`.
  *Header container displaying title, clock, Server, Language, and Settings toggles. In portrait mode, places the update button neatly below the language selector; on wide landscape displays, automatically uses a 3-column layout (centering clock and update button). Supports frosted glass pill badges in `Glassmorphism` mode.*
- **terminal_components.dart**: Các thành phần UI chính gồm Logo (`TerminalLogo`), Thanh chuyển đổi Làng Chính / Căn Cứ Thợ Xây (`TerminalSecurityTag`), Khu vực nhập liệu JSON (`TerminalInputArea` hỗ trợ bật/tắt Dán Nhanh) và Thanh trạng thái hệ thống (`TerminalFooter`), tất cả đều hỗ trợ song song phong cách Terminal và Kính mờ (`GlassBox`).
  *Core UI components including Logo (`TerminalLogo`), Home Village / Builder Base switcher (`TerminalSecurityTag`), JSON Input area (`TerminalInputArea` supporting Quick Paste toggle), and system status bar (`TerminalFooter`), all supporting both Terminal and Glassmorphism (`GlassBox`) styles.*

## 📁 assets/ (Tài nguyên) / assets/ (Assets)
- **LogoMain.png**: Logo chính hiển thị trong giao diện ứng dụng.
- **ring.mp3**: Âm thanh báo thức tùy chỉnh cho chế độ Full-screen.
- **icon.png**: Biểu tượng ứng dụng.
- **donate-qr.png**: Mã QR ủng hộ dự án.
- **fonts/**: Chứa bộ font `JosefinSans` (`Regular`, `Italic`, `Medium`, `SemiBold`, `Bold`) và `Coiny-Regular.ttf` cho giao diện Glass.
  *Contains the `JosefinSans` font family (`Regular`, `Italic`, `Medium`, `SemiBold`, `Bold`) and `Coiny-Regular.ttf` for the Glass theme.*

## 📁 Dictionary/ (Dữ liệu hỗ trợ) / Dictionary/ (Supporting Data)
- **Mapping.txt**: Bảng ánh xạ ID công trình và tên hiển thị dùng để cập nhật dữ liệu cho `game_data.dart`.
  *Table mapping building IDs to display names, used to update data for `game_data.dart`.*

## 📁 Screenshot/ (Hình ảnh minh họa) / Screenshot/ (Screenshots)
- **newUI.png**: Ảnh giới thiệu nổi bật giao diện mới (Tiếng Việt).
  *Featured showcase image of the new UI (Vietnamese).*
- **newUIen.png**: Ảnh giới thiệu nổi bật giao diện mới (Tiếng Anh).
  *Featured showcase image of the new UI (English).*
- **1.png, 2.png, 3.png**: Ảnh minh họa giao diện ứng dụng (Tiếng Việt).
  *App screenshots (Vietnamese).*
- **1en.png, 2en.png, 3en.png**: Ảnh minh họa giao diện ứng dụng (Tiếng Anh).
  *App screenshots (English).*

## 📁 android/app/src/main/ (Mã nguồn Android Native) / Android Native Source
- **AndroidManifest.xml**: Khai báo quyền, `MainActivity` (kèm intent-filter cho lệnh ADB) và `AiCommandReceiver`.
  *Declares permissions, `MainActivity` (with intent filters for ADB commands), and `AiCommandReceiver`.*
- **java/coctimer/nightowleyes/coctimer/MainActivity.java**: Khởi tạo kênh `coctimer/fsi_permission` và `coctimer/ai_command` để xử lý lệnh ADB khi app đang mở.
  *Initializes `coctimer/fsi_permission` and `coctimer/ai_command` channels for foreground ADB command handling.*
- **java/coctimer/nightowleyes/coctimer/AiCommandReceiver.java**: `BroadcastReceiver` nhận lệnh `coctimer.ACTION_IMPORT_JSON` / `coctimer.ACTION_QUERY_UPGRADES` qua ADB (chạy cả khi app đang mở hoặc đã đóng bằng headless `FlutterEngine`) và xuất kết quả JSON qua broadcast STDOUT, file ngoài và Logcat.
  *`BroadcastReceiver` handling `coctimer.ACTION_IMPORT_JSON` / `coctimer.ACTION_QUERY_UPGRADES` via ADB (both foreground and headless `FlutterEngine`), outputting JSON via broadcast STDOUT, external file, and Logcat.*
