import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/village_models.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';
import '../services/war_sync_service.dart';
import '../services/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // THÊM DÒNG NÀY
import '../services/coc_api_service.dart'; // THÊM DÒNG NÀY

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

  late TextEditingController _warPreAlarmController;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();

    // Khởi tạo controller cho định dạng hh:mm từ RuleManager.warPreAlarmMinutes
    int totalMins = RuleManager.warPreAlarmMinutes;
    int hh = totalMins ~/ 60;
    int mm = totalMins % 60;
    _warPreAlarmController = TextEditingController(
      text: "${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}",
    );
  }

  @override
  void dispose() {
    _warPreAlarmController.dispose();
    super.dispose();
  }

  // THÊM HÀM ĐỒNG BỘ LẠI LỊCH CHIẾN TRANH KHI THAY ĐỔI CẤU HÌNH
  Future<void> _syncAllWarSchedules() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? clansJson = prefs.getString('saved_online_clans');
      if (clansJson != null) {
        final List<dynamic> savedClans = jsonDecode(clansJson);
        for (var clan in savedClans) {
          String tag = clan['tag'];
          String name = clan['name'];

          var result = await CocApiService.fetchWarData(tag);
          if (result['type'] == 'REGULAR' && result['data']['state'] == 'inWar') {
            DateTime endTime = _parseCocDate(result['data']['endTime']);
            await ScheduleService.syncWarSchedule(tag, name, endTime);
          } else if (result['type'] == 'CWL' && result['currentWar'] != null) {
            DateTime endTime = _parseCocDate(result['currentWar']['endTime']);
            await ScheduleService.syncWarSchedule(tag, name, endTime);
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi sync lại lịch war: $e");
    }
  }

  DateTime _parseCocDate(String input) {
    String clean = input.replaceAll('.000Z', '').replaceAll('Z', '');
    String y = clean.substring(0, 4);
    String m = clean.substring(4, 6);
    String d = clean.substring(6, 8);
    String h = clean.substring(9, 11);
    String min = clean.substring(11, 13);
    String sec = clean.substring(13, 15);
    return DateTime.parse('$y-$m-${d}T$h:$min:${sec}Z').toLocal();
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

  Future<void> _handleToggleWarAutoSync() async {
    // NẾU ĐANG BẬT VÀ MUỐN TẮT -> HIỆN CẢNH BÁO
    if (RuleManager.warAutoSync) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D0F0E),
          shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1.5)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54545)),
              const SizedBox(width: 8),
              Text(AppStrings.onlineScreen.dialogWarningTitle, style: const TextStyle(color: Color(0xFFB54545), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ],
          ),
          content: Text(
            AppStrings.onlineScreen.dialogWarningContent,
            style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.5, fontFamily: 'monospace'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(AppStrings.onlineScreen.btnCancelDialog, style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(AppStrings.onlineScreen.btnForceDisable, style: const TextStyle(color: Color(0xFFB54545), fontWeight: FontWeight.bold, fontFamily: 'monospace')),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      RuleManager.warAutoSync = !RuleManager.warAutoSync;
      RuleManager.save();
      if (RuleManager.warAutoSync) {
        WarSyncService.registerPeriodicTask();
      } else {
        WarSyncService.cancelTask();
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
        _showError(AppStrings.settings.errorCannotOpenLink);
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
            color: const Color(0xFF0D0F0E),
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

                ...[AlarmType.system, AlarmType.none].map((type) => _buildRuleGroup(type)),
                _buildPreAlarmSetting(),
                _buildWarSettings(),
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

  Widget _buildWarSettings() {
    bool isPreEnabled = RuleManager.warPreAlarmEnabled;
    bool isEndEnabled = RuleManager.warEndAlarmEnabled;
    bool isAuto = RuleManager.warAutoSync;

    Color preColor = isPreEnabled ? _themeColor : const Color(0xFF444444);
    Color endColor = isEndEnabled ? _themeColor : const Color(0xFF444444);
    Color autoColor = isAuto ? _themeColor : const Color(0xFF444444);

    Widget buildTypeBtn(AlarmType type, Color color, VoidCallback onTap) {
      String txt = type == AlarmType.system ? AppStrings.settings.btnTypeNotification : AppStrings.settings.btnTypeAlarm;
      return InkWell(
        onTap: onTap,
        child: Text(txt, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      );
    }

    return _buildTerminalBox(
      AppStrings.settings.warAlarmConfigTitle,
      _themeColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KHỐI 1: BÁO TRƯỚC KHI KẾT THÚC (NHẬP TAY ĐỊNH DẠNG HH:MM, TỐI ĐA 6 TIẾNG)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.settings.warPreAlarmLabel, style: TextStyle(color: preColor, fontSize: 14)),
              InkWell(
                onTap: () async {
                  setState(() {
                    RuleManager.warPreAlarmEnabled = !RuleManager.warPreAlarmEnabled;
                    RuleManager.save();
                  });
                  await _syncAllWarSchedules(); // GỌI ĐỒNG BỘ LẠI LỊCH KHI BẬT/TẮT
                },
                child: _buildTerminalSwitch(isPreEnabled, preColor),
              ),
            ],
          ),
          if (isPreEnabled) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _warPreAlarmController,
                    style: TextStyle(color: preColor, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      hintText: "00:00",
                      hintStyle: const TextStyle(color: Color(0xFF444444)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: preColor, width: 1)),
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: preColor, width: 1.5)),
                      filled: true,
                      fillColor: const Color(0xFF141615),
                    ),
                    onChanged: (val) async {
                      String clean = val.replaceAll(':', '');
                      if (clean.length > 4) clean = clean.substring(0, 4);

                      if (clean.length >= 3) {
                        clean = "${clean.substring(0, clean.length - 2)}:${clean.substring(clean.length - 2)}";
                      }

                      if (_warPreAlarmController.text != clean && clean.length <= 5) {
                        _warPreAlarmController.value = TextEditingValue(
                          text: clean,
                          selection: TextSelection.collapsed(offset: clean.length),
                        );
                      }

                      final parts = clean.split(':');
                      if (parts.length == 2) {
                        int h = int.tryParse(parts[0]) ?? 0;
                        int m = int.tryParse(parts[1]) ?? 0;
                        int totalMins = h * 60 + m;

                        if (totalMins > 360) {
                          totalMins = 360;
                          _warPreAlarmController.text = "06:00";
                          _warPreAlarmController.selection = const TextSelection.collapsed(offset: 5);
                          _showError("Tối đa chỉ được nhập 6 giờ (06:00)!");
                        } else if (m > 59) {
                          m = 59;
                          totalMins = h * 60 + 59;
                          _warPreAlarmController.text = "${h.toString().padLeft(2, '0')}:59";
                          _warPreAlarmController.selection = const TextSelection.collapsed(offset: 5);
                        }

                        RuleManager.warPreAlarmMinutes = totalMins;
                        RuleManager.save();
                        await _syncAllWarSchedules(); // GỌI ĐỒNG BỘ LẠI LỊCH KHI ĐỔI SỐ PHÚT
                      }
                    },
                  ),
                ),
                buildTypeBtn(RuleManager.warPreAlarmType, preColor, () async {
                  setState(() {
                    RuleManager.warPreAlarmType = RuleManager.warPreAlarmType == AlarmType.system
                        ? AlarmType.fullscreen
                        : AlarmType.system;
                    RuleManager.save();
                  });
                  await _syncAllWarSchedules(); // GỌI ĐỒNG BỘ LẠI LỊCH KHI ĐỔI KIỂU BÁO ĐỘNG
                }),
              ],
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
          const SizedBox(height: 16),

          // KHỐI 2: BÁO ĐÚNG LÚC KẾT THÚC
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.settings.warEndAlarmLabel, style: TextStyle(color: endColor, fontSize: 14)),
              InkWell(
                onTap: () async {
                  setState(() {
                    RuleManager.warEndAlarmEnabled = !RuleManager.warEndAlarmEnabled;
                    RuleManager.save();
                  });
                  await _syncAllWarSchedules();
                },
                child: _buildTerminalSwitch(isEndEnabled, endColor),
              ),
            ],
          ),
          if (isEndEnabled) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: buildTypeBtn(RuleManager.warEndAlarmType, endColor, () async {
                setState(() {
                  RuleManager.warEndAlarmType = RuleManager.warEndAlarmType == AlarmType.system
                      ? AlarmType.fullscreen
                      : AlarmType.system;
                  RuleManager.save();
                });
                await _syncAllWarSchedules();
              }),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
          const SizedBox(height: 16),

          // KHỐI 3: TỰ ĐỘNG CHẠY NGẦM
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppStrings.settings.warAutoSyncLabel, style: TextStyle(color: autoColor, fontSize: 14)),
              InkWell(
                onTap: _handleToggleWarAutoSync,
                child: _buildTerminalSwitch(isAuto, autoColor),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
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
                  : (_updateUrl != null ? AppStrings.format(AppStrings.settings.statusUpdateAvailable, {'newVersion': "v$_appVersion"}) : AppStrings.settings.btnCheckUpdateNow),
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