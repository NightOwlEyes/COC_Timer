import 'package:flutter/material.dart';
import 'screens/terminal_screen.dart';
import 'services/schedule_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CHUYỂN RUNAPP LÊN TRƯỚC: Giao diện sẽ bung ra ngay lập tức
  // Xóa bỏ hoàn toàn hiện tượng kẹt ở Logo Splash Screen
  runApp(const CocTimerApp());

  // Khởi tạo các dịch vụ ngầm ở Background (Có bọc try-catch chống sập app)
  try {
    await ScheduleService.init();
  } catch (e) {
    debugPrint("Lỗi khởi tạo hệ thống ngầm: $e");
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
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0A0C0B),
        primaryColor: const Color(0xFFE0E0E0),
        fontFamily: 'monospace',
      ),
      home: const TerminalScreen(),
    );
  }
}