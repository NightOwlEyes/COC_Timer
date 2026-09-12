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
  } catch (e) {
    debugPrint(AppStrings.format(AppStrings.mainApp.debugInitBackgroundSystemError, {'e': e.toString()}));
  }
}

class CocTimerApp extends StatelessWidget {
  const CocTimerApp({super.key});

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
          textScaler: const TextScaler.linear(1.0),
        );

        // Ép toàn bộ widget con (kể cả Text, Route mới, Dialog) kế thừa font monospace
        final Widget appWithFont = DefaultTextStyle(
          style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0)),
          child: child ?? const SizedBox.shrink(),
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

      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        primaryColor: const Color(0xFFE0E0E0),
        fontFamily: 'monospace',
        textTheme: ThemeData.dark().textTheme.apply(
          fontFamily: 'monospace',
        ),
      ),
      home: const TerminalScreen(),
    );
  }
}