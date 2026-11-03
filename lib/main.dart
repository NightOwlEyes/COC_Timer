import 'theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'screens/terminal_screen.dart';
import 'services/schedule_service.dart';
import 'services/war_sync_service.dart';
import 'utils/rule_manager.dart';
import '../utils/app_strings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NẠP NGÔN NGỮ ĐÃ LƯU TỪ BỘ NHỚ
  await AppStrings.initLanguage();

  // CHUYỂN RUNAPP LÊN TRƯỚC: Giao diện sẽ bung ra ngay lập tức
  // NẠP THEME ĐÃ LƯU (TERMINAL / MODERN)
  await AppTheme.init();

  runApp(const CocTimerApp());

  // Khởi tạo các dịch vụ ngầm ở Background
  try {
    await RuleManager.init(); // Bắt buộc phải init RuleManager trước để đọc cấu hình
    await ScheduleService.init();

    // KHỞI TẠO WAR SYNC
    await WarSyncService.init();
    if (RuleManager.warAutoSync) {
      WarSyncService.registerPeriodicTask();
    }
    if (ScheduleService.isQuickPasteActive) {
      WarSyncService.registerQuickPasteWatchdog();
    }
  } catch (e) {
    debugPrint(AppStrings.format(AppStrings.mainApp.debugInitBackgroundSystemError, {'e': e.toString()}));
  }
}

class CocTimerApp extends StatefulWidget {
  const CocTimerApp({super.key});

  @override
  State<CocTimerApp> createState() => _CocTimerAppState();
}

class _CocTimerAppState extends State<CocTimerApp> {
  @override
  void initState() {
    super.initState();
    AppTheme.notifier.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    AppTheme.notifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  // Khi đổi theme: đánh dấu toàn bộ cây widget cần vẽ lại (giữ nguyên State),
  // để các token màu AppColors.* được đọc lại theo theme mới, kể cả Dialog đang mở.
  void _onThemeChanged() {
    setState(() {});
    void rebuild(Element el) {
      el.markNeedsBuild();
      el.visitChildren(rebuild);
    }
    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: ScheduleService.navigatorKey,
      title: 'COC Timer',
      debugShowCheckedModeBanner: false,

      // ==========================================
      // GIẢI PHÁP CANVAS SCALER (CHUẨN GAME ENGINE)
      // Ép toàn bộ giao diện chạy trên một "Màn hình ảo" rộng tối thiểu 390 pixels.
      // Nếu máy có màn hình hẹp hơn (VD: 320px), toàn bộ App sẽ tự động thu nhỏ lại.
      // Giữ nguyên 100% thiết kế, không rớt dòng, không vỡ layout, không cần dấu (...).
      // ==========================================
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final double screenWidth = mediaQuery.size.width;

        // Độ rộng trên thiết bị test.
        const double baseWidth = 411.0;

// ... existing code ...
        // 1. Chặn hệ điều hành phóng to font chữ hệ thống
        MediaQueryData customData = mediaQuery.copyWith(
          textScaler: TextScaler.linear(1.0),
        );

        // Ép toàn bộ widget con (kể cả Text, Route mới, Dialog) kế thừa font monospace
        final Widget appWithFont = DefaultTextStyle(
          style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text),
          child: child ?? SizedBox.shrink(),
        );

        // 2. Nếu màn hình vật lý hẹp hơn baseWidth -> Bật chế độ thu nhỏ (Scale Down)
        if (screenWidth < baseWidth) {
          final double scale = screenWidth / baseWidth;
          final double virtualHeight = mediaQuery.size.height / scale;

          customData = customData.copyWith(
            size: Size(baseWidth, virtualHeight),
            viewInsets: mediaQuery.viewInsets / scale,
            viewPadding: mediaQuery.viewPadding / scale,
            padding: mediaQuery.padding / scale,
          );

          return MediaQuery(
            data: customData,
            child: FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: baseWidth,
                height: virtualHeight,
                child: appWithFont,
              ),
            ),
          );
        }

        // 3. Nếu màn hình to (Tablet, Pro Max), giữ nguyên không can thiệp
        return MediaQuery(
          data: customData,
          child: appWithFont,
        );
      },
      // ==========================================

      theme: AppTheme.themeData,
      home: const TerminalScreen(),
    );
  }
}