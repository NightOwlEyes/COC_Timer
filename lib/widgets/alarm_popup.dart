import 'package:flutter/material.dart';
import 'dart:async';
import 'package:alarm/alarm.dart';
import '../utils/app_strings.dart';

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

    // Vòng lặp 500ms: Kiểm tra đồng bộ xem chuông có bị người dùng tắt từ thanh thông báo / màn hình khoá không
    _checkTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      final activeAlarms = await Alarm.getAlarms();
      final stillActive = activeAlarms.any((a) => a.id == widget.settings.id);

      if (!stillActive && !_isClosing) {
        _isClosing = true;
        timer.cancel();

        await Alarm.stop(widget.settings.id);

        if (mounted) {
          Navigator.pop(context);
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
    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0F0E),
            border: Border.all(color: const Color(0xFFB54545), width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.alarm_on, color: Color(0xFFB54545), size: 48),
              const SizedBox(height: 16),
              Text(
                AppStrings.alarm.title,
                style: const TextStyle(
                  color: Color(0xFFB54545),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
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
                  onPressed: () async {
                    if (_isClosing) return;
                    _isClosing = true;
                    _checkTimer?.cancel();

                    await Alarm.stop(widget.settings.id);
                    if (context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: Text(
                    AppStrings.alarm.btnConfirmAndClose,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
