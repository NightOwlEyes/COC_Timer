import '../theme/app_theme.dart';
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
    _checkTimer = Timer.periodic(Duration(milliseconds: 500), (timer) async {
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
      child: AdaptiveDialog(
        borderColor: AppColors.accent,
        borderWidth: 2.0,
        backgroundColor: AppColors.surfaceAlt,
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.alarm_on, color: AppColors.accent, size: 48),
              SizedBox(height: 16),
              Text(
                AppTheme.label(AppStrings.alarm.title),
                style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              SizedBox(height: 16),
              Text(
                widget.settings.notificationSettings.body,
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.5),
              ),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: AppColors.accent),
                    shape: RoundedRectangleBorder(borderRadius: AppTheme.brMd),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: AppColors.text,
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
                    AppTheme.label(AppStrings.alarm.btnConfirmAndClose),
                    style: TextStyle(fontWeight: FontWeight.bold),
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
