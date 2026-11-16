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

class _AlarmPopupState extends State<AlarmPopup> with WidgetsBindingObserver {
  Timer? _checkTimer;
  bool _isClosing = false; // CHỐT AN TOÀN TRÁNH DOUBLE POP
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Kiểm tra ngay khi mở và định kỳ mỗi 400ms xem chuông có bị tắt trên thanh thông báo / màn hình khóa không
    _verifyStillRinging();
    _checkTimer = Timer.periodic(const Duration(milliseconds: 400), (_) {
      _verifyStillRinging();
    });
  }

  Future<void> _verifyStillRinging() async {
    if (_isClosing || _isChecking) return;
    _isChecking = true;
    try {
      final bool stillRinging = await Alarm.isRinging(widget.settings.id);
      if (!stillRinging && !_isClosing) {
        _isClosing = true;
        _checkTimer?.cancel();
        await Alarm.stop(widget.settings.id);
        if (mounted) {
          Navigator.pop(context);
        }
      }
    } finally {
      _isChecking = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _verifyStillRinging();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String rawTitle = widget.settings.notificationSettings.title.trim();
    final String displayTitle = rawTitle.isNotEmpty ? rawTitle : AppStrings.alarm.title;

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
                AppTheme.label(displayTitle),
                textAlign: TextAlign.center,
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
