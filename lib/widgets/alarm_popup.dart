import 'package:flutter/material.dart';
import 'dart:async';
import 'package:alarm/alarm.dart';
import '../services/schedule_service.dart';

class AlarmPopup extends StatefulWidget {
  final AlarmSettings settings;
  const AlarmPopup({super.key, required this.settings});

  @override
  State<AlarmPopup> createState() => _AlarmPopupState();
}

class _AlarmPopupState extends State<AlarmPopup> {
  Timer? _checkTimer;
  bool _isClosing = false; // CHỐT AN TOÀN TRÁNH DOUBLE POP

  @override
  void initState() {
    super.initState();

    // TÔI ĐÃ XÓA ĐOẠN CODE "Future.delayed(4 giây)" Ở ĐÂY.
    // Giờ đây khi báo thức kêu, màn hình sẽ LUÔN SÁNG và KHÔNG BAO GIỜ TẮT
    // cho đến khi bạn tự tay bấm nút "Xác nhận & Đóng".

    // Vòng lặp 1 giây: Kiểm tra xem chuông có bị người dùng tắt ngầm từ thanh thông báo OS không
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final activeAlarms = await Alarm.getAlarms();
      final stillActive = activeAlarms.any((a) => a.id == widget.settings.id);

      if (!stillActive && !_isClosing) {
        _isClosing = true; // Đóng chốt an toàn
        timer.cancel();    // Hủy vòng lặp ngay lập tức để không kích hoạt lần 2
        if (mounted) {
          Navigator.pop(context);
          ScheduleService.handleAlarmDismiss();
        }
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C0B),
          border: Border.all(color: const Color(0xFFB54545), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm_on, color: Color(0xFFB54545), size: 48),
            const SizedBox(height: 16),
            const Text(
              "■ TÍN HIỆU HOÀN TẤT ■",
              style: TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
            const SizedBox(height: 16),
            Text(
              widget.settings.notificationSettings.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB54545)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: const Color(0xFFE0E0E0),
                ),
                onPressed: () {
                  if (_isClosing) return; // Nếu vòng lặp Timer đã ra lệnh đóng, vô hiệu hóa nút
                  _isClosing = true;
                  _checkTimer?.cancel(); // Dừng ngay vòng lặp kiểm tra

                  Alarm.stop(widget.settings.id); // Dừng chuông
                  Navigator.pop(context); // Đóng popup
                  ScheduleService.handleAlarmDismiss(); // Thu nhỏ app nếu đang khóa màn hình
                },
                child: const Text("[ XÁC NHẬN & ĐÓNG CẢNH BÁO ]", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}