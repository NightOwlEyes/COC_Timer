import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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
  // MÀU CHỦ ĐẠO MỚI (Green Terminal) - Ghi đè màu mặc định
  final Color _themeColor = const Color(0xFF97a87c);

  // Màu xám sáng cho các liên từ
  final Color _textColor = const Color(0xFFAAAAAA);

  final Set<TimeRule> _errorRules = {};
  String _errorMessage = "";

  String _appVersion = "...";
  bool _isCheckingUpdate = false;
  String _updateStatusMsg = "";
  String? _updateUrl;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
  }

  void _showError(String msg) {
    if (!mounted) return;
    setState(() {
      _errorMessage = msg;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _errorMessage = "");
      }
    });
  }

  Future<void> _loadAppVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _appVersion = packageInfo.version);
    } catch (e) {
      if (mounted) setState(() => _appVersion = "?._.?");
    }
  }

  Future<void> _checkForUpdates() async {
    if (_appVersion == "..." || _appVersion.contains("?")) return;

    setState(() {
      _isCheckingUpdate = true;
      _updateStatusMsg = "";
      _updateUrl = null;
    });

    try {
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/NightOwlEyes/COC_Timer/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String latestVersion = (data['tag_name'] as String).split('-').first.replaceAll('v', '');
        bool hasUpdate = _isVersionGreater(latestVersion, _appVersion);

        if (mounted) {
          setState(() {
            if (hasUpdate) {
              _updateUrl = data['html_url'] as String;
              _updateStatusMsg = AppStrings.format(AppStrings.settings.statusUpdateAvailable, {'newVersion': "v$latestVersion"});
            } else {
              _updateStatusMsg = AppStrings.settings.statusUpToDate;
            }
          });
        }
      } else {
        throw Exception("API Error");
      }
    } catch (e) {
      if (mounted) setState(() => _updateStatusMsg = AppStrings.settings.statusUpdateError);
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  bool _isVersionGreater(String newVersion, String currentVersion) {
    List<String> v1 = newVersion.split('.');
    List<String> v2 = currentVersion.split('.');
    for (int i = 0; i < 3; i++) {
      int num1 = i < v1.length ? int.tryParse(v1[i]) ?? 0 : 0;
      int num2 = i < v2.length ? int.tryParse(v2[i]) ?? 0 : 0;
      if (num1 > num2) return true;
      if (num1 < num2) return false;
    }
    return false;
  }

  Future<void> _launchUpdateUrl() async {
    if (_updateUrl != null) {
      final Uri url = Uri.parse(_updateUrl!);
      try {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } catch (e) {
        _showError("Cannot open link");
      }
    }
  }

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

  Future<void> _openRuleBuilder(AlarmType targetAction) async {
    final BuildContext currentContext = context;

    final TimeOfDay? startPicked = await showTimePicker(
      context: currentContext,
      initialTime: const TimeOfDay(hour: 6, minute: 0),
      helpText: AppStrings.settings.labelPickStart,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (startPicked == null || !currentContext.mounted) return;

    final TimeOfDay? endPicked = await showTimePicker(
      context: currentContext,
      initialTime: startPicked,
      helpText: AppStrings.settings.labelPickEnd,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (endPicked == null || !currentContext.mounted) return;

    int startMins = startPicked.hour * 60 + startPicked.minute;
    int endMins = endPicked.hour * 60 + endPicked.minute;

    if (startMins == 0 && endMins == 0) endMins = 1439;

    bool success = await RuleManager.addRule(startMins, endMins, targetAction);
    if (!success) {
      _showError(AppStrings.settings.errorOverlap);
    } else {
      if (mounted) setState(() {});
    }
  }

  Future<void> _editRuleTime(TimeRule rule, {required bool isStart}) async {
    final currentContext = context;

    int initialMins = isStart ? rule.startMins : rule.endMins;
    TimeOfDay initialTime = TimeOfDay(hour: initialMins ~/ 60, minute: initialMins % 60);

    final TimeOfDay? picked = await showTimePicker(
      context: currentContext,
      initialTime: initialTime,
      helpText: isStart ? AppStrings.settings.labelPickStart : AppStrings.settings.labelPickEnd,
      builder: _buildTimePickerTheme,
      initialEntryMode: TimePickerEntryMode.input,
    );

    if (picked == null || !currentContext.mounted) return;

    int pickedMins = picked.hour * 60 + picked.minute;
    int newStart = isStart ? pickedMins : rule.startMins;
    int newEnd = isStart ? rule.endMins : pickedMins;

    if (newStart == 0 && newEnd == 0) newEnd = 1439;

    if (RuleManager.hasOverlap(newStart, newEnd, rule.action, excludeRule: rule)) {
      _showError(AppStrings.settings.errorOverlap);
      return;
    }

    await RuleManager.updateRule(rule, newStart, newEnd);
    if (mounted) setState(() {});
  }

  Widget _buildTimePickerTheme(BuildContext context, Widget? child) {
    return Theme(
      data: ThemeData.dark().copyWith(
        colorScheme: ColorScheme.dark(
          primary: _themeColor,
          onPrimary: Colors.black,
          surface: const Color(0xFF141615),
          onSurface: const Color(0xFFE0E0E0),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: _themeColor),
        ),
      ),
      child: MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
  }

  // WIDGET VẼ KHUNG FIELDSET CHUẨN TERMINAL
  Widget _buildTerminalBox(String title, Color borderColor, Widget content) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 8, bottom: 20),
          padding: const EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: content,
        ),
        Positioned(
          left: 16,
          top: 0,
          child: Container(
            color: const Color(0xFF0D0F0E), // Background đè lên viền
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              title,
              style: TextStyle(color: borderColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
          ),
        ),
      ],
    );
  }

  // CÔNG TẮC ĐÓNG MỞ [   | X ]
  Widget _buildTerminalSwitch(bool isOn, Color color) {
    return Container(
      width: 44,
      height: 20,
      decoration: BoxDecoration(border: Border.all(color: color, width: 1.2)),
      child: Stack(
        children: [
          Center(child: Container(width: 1.2, color: color)),
          Align(
            alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
            child: SizedBox(
              width: 22,
              child: Icon(Icons.close, size: 16, color: color),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Material(
        color: const Color(0xFF0D0F0E),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // HEADER CÀI ĐẶT
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Container(width: 10, height: 10, color: _themeColor),
                          const SizedBox(width: 8),
                          Text(
                            AppStrings.settings.settingsTitle.replaceAll("■", "").trim(),
                            style: TextStyle(color: _themeColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Text(AppStrings.dialog.btnClose, style: const TextStyle(color: Color(0xFF888888), fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // KHỐI LỖI MÀU ĐỎ
                if (_errorMessage.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFB54545),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                // BODY CÁC MỤC
                ...[AlarmType.system, AlarmType.none].map((type) => _buildRuleGroup(type)),
                _buildPreAlarmSetting(),
                _buildAppInfo(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRuleGroup(AlarmType type) {
    bool isEnabled = RuleManager.groupEnabled[type] ?? true;
    Color groupColor = isEnabled ? _themeColor : const Color(0xFF444444);
    List<TimeRule> rules = RuleManager.activeRules.where((r) => r.action == type).toList();

    String title = "${AppStrings.settings.settingsSchedulePrefix}${_getActionName(type).toUpperCase()}";

    return _buildTerminalBox(
      title,
      groupColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${AppStrings.settings.settingsAutoSwitchPrefix}${_getActionName(type).toLowerCase()}",
                style: TextStyle(color: groupColor, fontSize: 14),
              ),
              InkWell(
                onTap: () {
                  RuleManager.toggleGroup(type, !isEnabled).then((success) {
                    if (mounted) {
                      if (!success) {
                        _triggerErrorFlash(RuleManager.getConflictingRules(type));
                        _showError(AppStrings.settings.errorOverlap);
                      } else {
                        setState(() {});
                      }
                    }
                  });
                },
                child: _buildTerminalSwitch(isEnabled, groupColor),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // DANH SÁCH GIỜ CĂN LỀ CHUẨN THIẾT KẾ
          if (rules.isNotEmpty)
            ...rules.asMap().entries.map((entry) {
              int idx = entry.key;
              TimeRule rule = entry.value;

              bool isError = _errorRules.contains(rule);
              Color itemColor = isError ? const Color(0xFFB54545) : groupColor;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(AppStrings.settings.settingsFrom, style: TextStyle(color: _textColor, fontSize: 14)),
                        const SizedBox(width: 12),
                        _buildTimeBox(rule.getTimeString(rule.startMins), itemColor, () => _editRuleTime(rule, isStart: true)),

                        const SizedBox(width: 16),
                        Text(AppStrings.settings.settingsTo, style: TextStyle(color: _textColor, fontSize: 14)),
                        const SizedBox(width: 12),
                        _buildTimeBox(rule.getTimeString(rule.endMins), itemColor, () => _editRuleTime(rule, isStart: false)),

                        const Spacer(),
                        InkWell(
                          onTap: () {
                            RuleManager.removeRule(rule).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          child: Text(AppStrings.settings.btnDeleteRule, style: TextStyle(color: itemColor, fontSize: 14)),
                        )
                      ],
                    ),
                  ),
                  if (idx < rules.length - 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 48, top: 12, bottom: 12),
                        child: Text(AppStrings.settings.settingsAnd, style: TextStyle(color: _textColor, fontSize: 14)),
                      ),
                    ),
                ],
              );
            }),

          const SizedBox(height: 20),

          Center(
            child: InkWell(
              onTap: () => _openRuleBuilder(type),
              child: Text(AppStrings.settings.settingsBtnAdd, style: TextStyle(color: groupColor, fontSize: 14)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeBox(String time, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(border: Border.all(color: color, width: 1.2)),
        child: Text(time, style: TextStyle(color: color, fontSize: 15)),
      ),
    );
  }

  String _getActionName(AlarmType type) {
    if (type == AlarmType.none) return AppStrings.settings.settingsActionNone;
    if (type == AlarmType.system) return AppStrings.settings.settingsActionSystem;
    return AppStrings.settings.settingsActionFullscreen;
  }

  Widget _buildPreAlarmSetting() {
    return _buildTerminalBox(
      AppStrings.settings.settingsPreAlarmTitle,
      _themeColor,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppStrings.settings.labelPreAlarm,
            style: TextStyle(color: _themeColor, fontSize: 14),
          ),
          Row(
            children: [
              InkWell(
                onTap: () {
                  if (RuleManager.preAlarmMinutes > 0) {
                    setState(() {
                      RuleManager.preAlarmMinutes -= 1;
                      RuleManager.save();
                    });
                  }
                },
                child: Text("[-]", style: TextStyle(color: _themeColor, fontSize: 16)),
              ),
              Container(
                width: 40,
                alignment: Alignment.center,
                child: Text(
                  "${RuleManager.preAlarmMinutes}",
                  style: TextStyle(color: _themeColor, fontSize: 16),
                ),
              ),
              InkWell(
                onTap: () {
                  if (RuleManager.preAlarmMinutes < 120) {
                    setState(() {
                      RuleManager.preAlarmMinutes += 1;
                      RuleManager.save();
                    });
                  }
                },
                child: Text("[+]", style: TextStyle(color: _themeColor, fontSize: 16)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    // Logic đổi màu thông minh cho Auto Update
    bool isAutoUpdate = RuleManager.autoCheckUpdate;
    Color autoUpdateColor = isAutoUpdate ? _themeColor : const Color(0xFF666666);

    return _buildTerminalBox(
      AppStrings.settings.labelAppInfo,
      _themeColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () {
              setState(() {
                RuleManager.autoCheckUpdate = !RuleManager.autoCheckUpdate;
                RuleManager.save();
              });
            },
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(border: Border.all(color: autoUpdateColor, width: 1.5)),
                  child: isAutoUpdate ? Icon(Icons.close, size: 16, color: autoUpdateColor) : null,
                ),
                const SizedBox(width: 12),
                Text(
                  AppStrings.settings.settingsAutoCheckUpdate,
                  style: TextStyle(color: autoUpdateColor, fontSize: 14),
                )
              ],
            ),
          ),

          const SizedBox(height: 16),

          InkWell(
            onTap: _isCheckingUpdate ? null : (_updateUrl != null ? _launchUpdateUrl : _checkForUpdates),
            child: Text(
              _isCheckingUpdate
                  ? "[ . . . ]"
                  : (_updateUrl != null ? AppStrings.settings.statusUpdateAvailable.replaceAll('{newVersion}', 'v$_appVersion') : AppStrings.settings.btnCheckUpdateNow),
              style: TextStyle(color: _themeColor, fontSize: 14),
            ),
          ),

          if (_updateStatusMsg.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _updateStatusMsg,
              style: TextStyle(
                  color: _updateUrl != null ? _themeColor : const Color(0xFF888888),
                  fontSize: 13,
                  fontStyle: FontStyle.italic
              ),
            ),
          ],

          const SizedBox(height: 8),

          Text(
            AppStrings.format(AppStrings.settings.labelVersion, {'version': _appVersion}),
            style: const TextStyle(color: Color(0xFF888888), fontSize: 14),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: const Color(0xFF0D0F0E),
                      shape: RoundedRectangleBorder(side: BorderSide(color: _themeColor, width: 1.5)),
                      title: Text(AppStrings.settings.privacyDialogTitle, style: TextStyle(color: _themeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                      content: Text(
                        AppStrings.settings.privacyDialogContent,
                        style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.5, fontFamily: 'monospace'),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppStrings.dialog.btnClose, style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  );
                },
                child: Text(AppStrings.settings.btnPrivacyPolicy, style: TextStyle(color: _themeColor, fontSize: 14)),
              ),
              InkWell(
                onTap: () {
                  showLicensePage(
                    context: context,
                    applicationName: 'CocTimer',
                    applicationVersion: _appVersion,
                    applicationLegalese: '© 2026 NightOwlEyes\nLicensed under GNU GPL v3.0',
                  );
                },
                child: Text(AppStrings.settings.btnLicenses, style: TextStyle(color: _themeColor, fontSize: 14)),
              ),
            ],
          )
        ],
      ),
    );
  }
}