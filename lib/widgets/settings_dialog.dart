import 'package:flutter/material.dart';
import '../models/village_models.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';

class SettingsDialog extends StatefulWidget {
  final Color themeColor;

  const SettingsDialog({super.key, required this.themeColor});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  // THÊM: Biến lưu trữ các dòng Rule đang bị lỗi
  Set<TimeRule> _errorRules = {};

  // THÊM: Hiệu ứng nháy đỏ 2 nhịp (Blink) chuẩn phong cách Terminal
  void _triggerErrorFlash(List<TimeRule> conflicts) {
    if (!mounted) return;
    setState(() => _errorRules.addAll(conflicts));

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _errorRules.removeAll(conflicts));

      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _errorRules.addAll(conflicts));

        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _errorRules.removeAll(conflicts));
        });
      });
    });
  }

  @override
  void initState() {
    super.initState();
    RuleManager.init().then((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _openRuleBuilder(AlarmType targetAction) async {
    final BuildContext currentContext = context;
    final ScaffoldMessengerState scaffoldMessenger = ScaffoldMessenger.of(context);

    final TimeOfDay? startPicked = await showTimePicker(
      context: currentContext,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      helpText: AppStrings.settings.labelPickStart,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (startPicked == null) {
      return;
    }
    if (!currentContext.mounted) {
      return;
    }

    final TimeOfDay? endPicked = await showTimePicker(
      context: currentContext,
      initialTime: startPicked,
      helpText: AppStrings.settings.labelPickEnd,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (endPicked == null) {
      return;
    }
    if (!currentContext.mounted) {
      return;
    }

    int startMins = startPicked.hour * 60 + startPicked.minute;
    int endMins = endPicked.hour * 60 + endPicked.minute;

    // THÊM: Tự động chuyển 00:00 - 00:00 thành trọn 24 tiếng (00:00 - 23:59)
    if (startMins == 0 && endMins == 0) {
      endMins = 1439; // 1439 phút = 23:59
    }

    bool success = await RuleManager.addRule(startMins, endMins, targetAction);

    if (!success) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.settings.errorOverlap, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
          backgroundColor: const Color(0xFFB54545),
          duration: const Duration(seconds: 3),
        ),
      );
    } else {
      if (mounted) {
        setState(() {});
      }
    }
  }

  Future<void> _editRuleTime(TimeRule rule, {required bool isStart}) async {
    final currentContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    int initialMins = isStart ? rule.startMins : rule.endMins;
    TimeOfDay initialTime = TimeOfDay(hour: initialMins ~/ 60, minute: initialMins % 60);

    final TimeOfDay? picked = await showTimePicker(
      context: currentContext,
      initialTime: initialTime,
      helpText: isStart ? AppStrings.settings.labelPickStart : AppStrings.settings.labelPickEnd,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (picked == null) {
      return;
    }
    if (!currentContext.mounted) {
      return;
    }

    int pickedMins = picked.hour * 60 + picked.minute;
    int newStart = isStart ? pickedMins : rule.startMins;
    int newEnd = isStart ? rule.startMins : pickedMins;

    // THÊM: Tự động chuyển 00:00 - 00:00 thành trọn 24 tiếng (00:00 - 23:59)
    if (newStart == 0 && newEnd == 0) {
      newEnd = 1439; // 1439 phút = 23:59
    }

    if (RuleManager.hasOverlap(newStart, newEnd, rule.action, excludeRule: rule)) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(AppStrings.settings.errorOverlap, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
          backgroundColor: const Color(0xFFB54545),
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    await RuleManager.updateRule(rule, newStart, newEnd);
    if (mounted) {
      setState(() {});
    }
  }

  Widget _buildTimePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: widget.themeColor,
          onPrimary: Colors.black,
          surface: const Color(0xFF141615),
          onSurface: const Color(0xFFE0E0E0),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: widget.themeColor),
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Material(
        color: const Color(0xFF0A0C0B),
        shape: RoundedRectangleBorder(side: BorderSide(color: widget.themeColor, width: 2)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        AppStrings.settings.settingsTitle,
                        style: TextStyle(color: widget.themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Text(AppStrings.dialog.btnClose, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // BODY: CHỈ VẼ 2 KHỐI DUY NHẤT LÀ THÔNG BÁO VÀ IM LẶNG
                ...[AlarmType.system, AlarmType.none].map((type) => _buildRuleGroup(type)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleGroup(AlarmType type) {
    bool isEnabled = RuleManager.groupEnabled[type] ?? true;
    Color groupColor = isEnabled ? _getActionColor(type) : const Color(0xFF444444);
    List<TimeRule> rules = RuleManager.activeRules.where((r) => r.action == type).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        border: Border.all(color: groupColor, width: 1.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              InkWell(
                onTap: () {
                  final currentContext = context;
                  final scaffoldMessenger = ScaffoldMessenger.of(context);

                  RuleManager.toggleGroup(type, !isEnabled).then((success) {
                    if (currentContext.mounted) {
                      if (!success) {
                        // SỬA: Kích hoạt hiệu ứng nháy đỏ khi bật thất bại
                        final conflicts = RuleManager.getConflictingRules(type);
                        _triggerErrorFlash(conflicts);

                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(AppStrings.settings.errorOverlap, style: const TextStyle(color: Colors.white, fontFamily: 'monospace')),
                            backgroundColor: const Color(0xFFB54545),
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      } else {
                        setState(() {});
                      }
                    }
                  });
                },
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(border: Border.all(color: groupColor, width: 2)),
                  child: isEnabled ? Icon(Icons.close, size: 20, color: groupColor) : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "${AppStrings.settings.settingsGroupTitlePrefix}${_getActionName(type)}${AppStrings.settings.settingsGroupTitleSuffix}",
                  style: TextStyle(color: groupColor, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              )
            ],
          ),

          const SizedBox(height: 20),

          // Danh sách các khung giờ (Bọc cẩn thận chống lỗi Widget tree)
          if (rules.isNotEmpty)
            ...rules.asMap().entries.map((entry) {
              int idx = entry.key;
              TimeRule rule = entry.value;

              // SỬA: Đổi sang màu đỏ nếu Rule này nằm trong danh sách gây lỗi
              bool isError = _errorRules.contains(rule);
              Color itemColor = isError ? const Color(0xFFB54545) : groupColor;

              return Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildTimeBox(rule.getTimeString(rule.startMins), itemColor, () => _editRuleTime(rule, isStart: true)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(AppStrings.settings.settingsTo, style: TextStyle(color: itemColor, fontSize: 12)),
                      ),
                      _buildTimeBox(rule.getTimeString(rule.endMins), itemColor, () => _editRuleTime(rule, isStart: false)),

                      if (rules.length > 1) ...[
                        const SizedBox(width: 16),
                        InkWell(
                          onTap: () {
                            RuleManager.removeRule(rule).then((_) {
                              if (mounted) {
                                setState(() {});
                              }
                            });
                          },
                          child: Text(AppStrings.settings.btnDeleteRule, style: TextStyle(color: itemColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ]
                    ],
                  ),
                  if (idx < rules.length - 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(AppStrings.settings.settingsAnd, style: TextStyle(color: itemColor, fontSize: 12)),
                    ),
                ],
              );
            }),

          const SizedBox(height: 20),

          Center(
            child: InkWell(
              onTap: () => _openRuleBuilder(type),
              child: Text(AppStrings.settings.settingsBtnAdd, style: TextStyle(color: groupColor, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeBox(String time, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      // SỬA: Dùng AnimatedContainer để khung giờ chuyển màu đỏ êm ái hơn
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.5)),
        child: Text(time, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.bold)),
      ),
    );
  }

  String _getActionName(AlarmType type) {
    if (type == AlarmType.none) return AppStrings.settings.settingsActionNone;
    if (type == AlarmType.system) return AppStrings.settings.settingsActionSystem;
    return AppStrings.settings.settingsActionFullscreen;
  }

  Color _getActionColor(AlarmType type) {
    if (type == AlarmType.none) return Colors.white;
    if (type == AlarmType.system) return const Color(0xFF4CAF50);
    return widget.themeColor;
  }
}