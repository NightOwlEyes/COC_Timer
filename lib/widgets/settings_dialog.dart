import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/village_models.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';
import '../services/war_sync_service.dart';
import '../services/schedule_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/coc_api_service.dart';

class SettingsDialog extends StatefulWidget {
  final Color themeColor;

  const SettingsDialog({super.key, required this.themeColor});

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  Color get _themeColor => AppColors.settingsAccent;
  Color get _textColor => AppColors.textSoft;

  final Set<TimeRule> _errorRules = {};
  String _errorMessage = "";

  String _appVersion = "...";
  bool _isCheckingUpdate = false;
  String _updateStatusMsg = "";
  String? _updateUrl;

  bool _hasSavedClans = false;

  late TextEditingController _warPreAlarmController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadAppVersion();
    _checkSavedClansState();

    int totalMins = RuleManager.warPreAlarmMinutes;
    int hh = totalMins ~/ 60;
    int mm = totalMins % 60;
    _warPreAlarmController = TextEditingController(
      text: "${hh.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}",
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _warPreAlarmController.dispose();
    super.dispose();
  }

  Future<void> _checkSavedClansState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? clansJson = prefs.getString('saved_online_clans');
      bool hasClans = false;
      if (clansJson != null) {
        final List<dynamic> savedClans = jsonDecode(clansJson);
        hasClans = savedClans.isNotEmpty;
      }
      if (mounted) {
        setState(() {
          _hasSavedClans = hasClans;
          if (!_hasSavedClans || (!RuleManager.warPreAlarmEnabled && !RuleManager.warEndAlarmEnabled)) {
            if (RuleManager.warAutoSync) {
              RuleManager.warAutoSync = false;
              RuleManager.save();
              WarSyncService.cancelTask();
            }
          }
        });
      }
    } catch (_) {}
  }

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
    Future.delayed(Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _errorMessage = "");
      }
    });
  }

  Future<void> _handleToggleWarAutoSync() async {
    if (!_hasSavedClans) {
      _showError(AppStrings.settings.errorNoClanForWar);
      return;
    }

    if (!RuleManager.warAutoSync && !RuleManager.warPreAlarmEnabled && !RuleManager.warEndAlarmEnabled) {
      _showError(AppStrings.settings.errorBothWarAlarmsOff);
      return;
    }

    if (RuleManager.warAutoSync) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent, width: 1.5)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(AppTheme.label(AppStrings.onlineScreen.dialogWarningTitle),
                  style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                ),
              ),
            ],
          ),
          content: Text(AppTheme.label(AppStrings.settings.dialogWarningContent),
            style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.5, fontFamily: AppTheme.font),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppTheme.label(AppStrings.onlineScreen.btnCancelDialog),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppTheme.label(AppStrings.onlineScreen.btnForceDisable),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                    ),
                  ),
                ),
              ],
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
              _updateUrl = 'https://github.com/NightOwlEyes/COC_Timer/blob/main/README.md';
              _updateStatusMsg = AppStrings.format(
                AppStrings.settings.statusUpdateAvailable,
                {'newVersion': "v$latestVersion"},
              );
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

    Future.delayed(Duration(milliseconds: 300), () {
      if (!mounted) return;
      setState(() => _errorRules.removeAll(conflicts));
      Future.delayed(Duration(milliseconds: 300), () {
        if (!mounted) return;
        setState(() => _errorRules.addAll(conflicts));
        Future.delayed(Duration(milliseconds: 300), () {
          if (!mounted) return;
          setState(() => _errorRules.removeAll(conflicts));
        });
      });
    });
  }

  Future<void> _addNewRuleSlot(AlarmType targetAction) async {
    // Tìm khung giờ trống đầu tiên để khởi tạo ô nhập trực tiếp
    final List<(int, int)> candidates = [
      (360, 720),   // 06:00 -> 12:00
      (720, 1080),  // 12:00 -> 18:00
      (1080, 1319), // 18:00 -> 21:59
      (0, 359),     // 00:00 -> 05:59
    ];

    for (final slot in candidates) {
      if (!RuleManager.hasOverlap(slot.$1, slot.$2, targetAction)) {
        await RuleManager.addRule(slot.$1, slot.$2, targetAction);
        if (mounted) setState(() {});
        return;
      }
    }

    // Nếu 4 khung giờ mẫu bị vướng, quét từng phút tìm khoảng trống >= 15 phút
    int? freeStart;
    for (int m = 0; m < 1440; m++) {
      if (!RuleManager.hasOverlap(m, m, targetAction)) {
        freeStart ??= m;
        int endCandidate = m + 59 <= 1439 ? m + 59 : 1439;
        if (!RuleManager.hasOverlap(freeStart, endCandidate, targetAction)) {
          await RuleManager.addRule(freeStart, endCandidate, targetAction);
          if (mounted) setState(() {});
          return;
        }
      } else {
        freeStart = null;
      }
    }

    if (freeStart != null) {
      await RuleManager.addRule(freeStart, freeStart, targetAction);
      if (mounted) setState(() {});
      return;
    }

    _showError(AppStrings.settings.errorOverlap);
  }

  Future<bool> _updateRuleTimeInline(TimeRule rule, int pickedMins, {required bool isStart}) async {
    int newStart = isStart ? pickedMins : rule.startMins;
    int newEnd = isStart ? rule.endMins : pickedMins;

    if (newStart == 0 && newEnd == 0) newEnd = 1439;

    if (RuleManager.hasOverlap(newStart, newEnd, rule.action, excludeRule: rule)) {
      _showError(AppStrings.settings.errorOverlap);
      return false;
    }

    await RuleManager.updateRule(rule, newStart, newEnd);
    if (mounted) setState(() {});
    return true;
  }

  Widget _buildTerminalBox(String title, Color borderColor, Widget content) {
    if (AppTheme.isModern) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: AppTheme.brMd,
          border: Border.all(color: borderColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppTheme.label(title),
              style: TextStyle(color: borderColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            content,
          ],
        ),
      );
    }
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: EdgeInsets.only(top: 8, bottom: 20),
          padding: EdgeInsets.only(top: 24, left: 16, right: 16, bottom: 16),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: content,
        ),
        Positioned(
          left: 16,
          top: 0,
          child: Container(
            color: AppColors.surfaceAlt,
            padding: EdgeInsets.symmetric(horizontal: 4),
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
    if (AppTheme.isModern) {
      return Container(
        width: 44,
        height: 24,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isOn ? color : AppColors.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isOn ? color : AppColors.border),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 180),
          alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
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

  Widget _buildThemeSetting() {
    final bool isTerminal = AppTheme.isTerminal;
    return _buildTerminalBox(
      AppStrings.settings.themeConfigTitle,
      _themeColor,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            AppTheme.label(AppStrings.settings.themeConfigTitle),
            style: TextStyle(color: _themeColor, fontSize: 14),
          ),
          Row(
            children: [
              InkWell(
                borderRadius: AppTheme.brSm,
                onTap: () async {
                  await AppTheme.setMode(AppThemeMode.terminal);
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: AppTheme.isModern ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : EdgeInsets.zero,
                  decoration: AppTheme.isModern && isTerminal
                      ? BoxDecoration(
                          color: _themeColor.withValues(alpha: 0.2),
                          borderRadius: AppTheme.brSm,
                          border: Border.all(color: _themeColor),
                        )
                      : null,
                  child: Text(
                    isTerminal ? "[ TERMINAL ]" : "TERMINAL",
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      color: isTerminal ? AppColors.ok : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: isTerminal ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              InkWell(
                borderRadius: AppTheme.brSm,
                onTap: () async {
                  await AppTheme.setMode(AppThemeMode.modern);
                  if (mounted) setState(() {});
                },
                child: Container(
                  padding: AppTheme.isModern ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : EdgeInsets.zero,
                  decoration: AppTheme.isModern && !isTerminal
                      ? BoxDecoration(
                          color: _themeColor.withValues(alpha: 0.2),
                          borderRadius: AppTheme.brSm,
                          border: Border.all(color: _themeColor),
                        )
                      : null,
                  child: Text(
                    !isTerminal ? AppStrings.settings.themeModern : AppTheme.label(AppStrings.settings.themeModern),
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      color: !isTerminal ? AppColors.ok : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: !isTerminal ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: AppTheme.brLg),
      child: GlassDialogSurface(
        color: AppColors.surfaceAlt,
        borderRadius: AppTheme.brLg,
        child: Padding(
          padding: EdgeInsets.all(16),
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
                          if (AppTheme.isTerminal)
                            Container(width: 10, height: 10, color: _themeColor)
                          else
                            Icon(Icons.tune_rounded, color: _themeColor, size: 20),
                          SizedBox(width: 8),
                          Text(
                            AppStrings.settings.settingsTitle.replaceAll("■", "").trim(),
                            style: TextStyle(color: _themeColor, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Text(AppTheme.label(AppStrings.dialog.btnClose), style: TextStyle(color: AppColors.textMuted, fontSize: 14, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                if (_errorMessage.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 16),
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),

                _buildThemeSetting(),
                ...[AlarmType.system, AlarmType.none].map((type) => _buildRuleGroup(type)),
                _buildPreAlarmSetting(),
                _buildQuickPasteSetting(),
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
    Color groupColor = isEnabled ? _themeColor : AppColors.borderStrong;
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

          SizedBox(height: 20),

          if (rules.isNotEmpty)
            ...rules.asMap().entries.map((entry) {
              int idx = entry.key;
              TimeRule rule = entry.value;

              bool isError = _errorRules.contains(rule);
              Color itemColor = isError ? AppColors.accent : groupColor;

              return Column(
                key: ObjectKey(rule),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: EdgeInsets.only(left: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(AppTheme.label(AppStrings.settings.settingsFrom), style: TextStyle(color: _textColor, fontSize: 14)),
                        SizedBox(width: 12),
                        _InlineRuleTimeBox(
                          minutes: rule.startMins,
                          color: itemColor,
                          onTimeChanged: (mins) => _updateRuleTimeInline(rule, mins, isStart: true),
                        ),

                        SizedBox(width: 16),
                        Text(AppTheme.label(AppStrings.settings.settingsTo), style: TextStyle(color: _textColor, fontSize: 14)),
                        SizedBox(width: 12),
                        _InlineRuleTimeBox(
                          minutes: rule.endMins,
                          color: itemColor,
                          onTimeChanged: (mins) => _updateRuleTimeInline(rule, mins, isStart: false),
                        ),

                        Spacer(),
                        InkWell(
                          onTap: () {
                            RuleManager.removeRule(rule).then((_) {
                              if (mounted) setState(() {});
                            });
                          },
                          child: Text(AppTheme.label(AppStrings.settings.btnDeleteRule), style: TextStyle(color: itemColor, fontSize: 14)),
                        )
                      ],
                    ),
                  ),
                  if (idx < rules.length - 1)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 48, top: 12, bottom: 12),
                        child: Text(AppTheme.label(AppStrings.settings.settingsAnd), style: TextStyle(color: _textColor, fontSize: 14)),
                      ),
                    ),
                ],
              );
            }),

          SizedBox(height: 20),

          Center(
            child: InkWell(
              onTap: () => _addNewRuleSlot(type),
              child: Text(AppTheme.label(AppStrings.settings.settingsBtnAdd), style: TextStyle(color: groupColor, fontSize: 14)),
            ),
          )
        ],
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
          Text(AppTheme.label(AppStrings.settings.labelPreAlarm),
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

  Widget _buildQuickPasteSetting() {
    bool isAutoReturn = RuleManager.quickPasteAutoReturn;
    Color itemColor = isAutoReturn ? _themeColor : AppColors.borderStrong;

    return _buildTerminalBox(
      AppStrings.settings.quickPasteConfigTitle,
      _themeColor,
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(AppTheme.label(AppStrings.settings.quickPasteAutoReturnLabel),
              style: TextStyle(color: itemColor, fontSize: 14),
            ),
          ),
          SizedBox(width: 12),
          InkWell(
            onTap: () {
              setState(() {
                RuleManager.quickPasteAutoReturn = !RuleManager.quickPasteAutoReturn;
                RuleManager.save();
              });
            },
            child: _buildTerminalSwitch(isAutoReturn, itemColor),
          ),
        ],
      ),
    );
  }

  Widget _buildWarSettings() {
    bool isPreEnabled = _hasSavedClans && RuleManager.warPreAlarmEnabled;
    bool isEndEnabled = _hasSavedClans && RuleManager.warEndAlarmEnabled;
    bool isAuto = _hasSavedClans && RuleManager.warAutoSync;

    Color boxBorderColor = _hasSavedClans ? _themeColor : AppColors.borderStrong;
    Color preColor = isPreEnabled ? _themeColor : AppColors.borderStrong;
    Color endColor = isEndEnabled ? _themeColor : AppColors.borderStrong;
    Color autoColor = isAuto ? _themeColor : AppColors.borderStrong;

    Widget buildTypeBtn(AlarmType type, Color color, VoidCallback onTap) {
      String txt = type == AlarmType.system ? AppStrings.settings.btnTypeNotification : AppStrings.settings.btnTypeAlarm;
      return InkWell(
        onTap: onTap,
        child: Text(txt, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
      );
    }

    return _buildTerminalBox(
      AppStrings.settings.warAlarmConfigTitle,
      boxBorderColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // KHỐI 1: BÁO TRƯỚC KHI KẾT THÚC (NHẬP TAY ĐỊNH DẠNG HH:MM, TỐI ĐA 6 TIẾNG)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppTheme.label(AppStrings.settings.warPreAlarmLabel), style: TextStyle(color: preColor, fontSize: 14)),
              InkWell(
                onTap: () async {
                  if (!_hasSavedClans) {
                    _showError(AppStrings.settings.errorNoClanForWar);
                    return;
                  }
                  setState(() {
                    RuleManager.warPreAlarmEnabled = !RuleManager.warPreAlarmEnabled;
                    if (!RuleManager.warPreAlarmEnabled && !RuleManager.warEndAlarmEnabled) {
                      RuleManager.warAutoSync = false;
                      WarSyncService.cancelTask();
                    }
                    RuleManager.save();
                  });
                  await _syncAllWarSchedules();
                },
                child: _buildTerminalSwitch(isPreEnabled, preColor),
              ),
            ],
          ),
          if (isPreEnabled) ...[
            SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 90,
                  child: TextField(
                    controller: _warPreAlarmController,
                    style: TextStyle(color: preColor, fontSize: 15, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.datetime,
                    decoration: InputDecoration(
                      hintText: "00:00",
                      hintStyle: TextStyle(color: AppColors.borderStrong),
                      contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: preColor, width: 1.2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.zero,
                        borderSide: BorderSide(color: preColor, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
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
                          _warPreAlarmController.selection = TextSelection.collapsed(offset: 5);
                          _showError(AppStrings.settings.errorInvalidTime);
                        } else if (m > 59) {
                          m = 59;
                          totalMins = h * 60 + 59;
                          _warPreAlarmController.text = "${h.toString().padLeft(2, '0')}:59";
                          _warPreAlarmController.selection = TextSelection.collapsed(offset: 5);
                        }

                        RuleManager.warPreAlarmMinutes = totalMins;
                        RuleManager.save();

                        _debounceTimer?.cancel();
                        _debounceTimer = Timer(Duration(milliseconds: 800), () {
                          _syncAllWarSchedules();
                        });
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
                  await _syncAllWarSchedules();
                }),
              ],
            ),
          ],
          SizedBox(height: 16),
          Divider(color: AppColors.border, thickness: 1, height: 1),
          SizedBox(height: 16),

          // KHỐI 2: BÁO ĐÚNG LÚC KẾT THÚC
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppTheme.label(AppStrings.settings.warEndAlarmLabel), style: TextStyle(color: endColor, fontSize: 14)),
              InkWell(
                onTap: () async {
                  if (!_hasSavedClans) {
                    _showError(AppStrings.settings.errorNoClanForWar);
                    return;
                  }
                  setState(() {
                    RuleManager.warEndAlarmEnabled = !RuleManager.warEndAlarmEnabled;
                    if (!RuleManager.warPreAlarmEnabled && !RuleManager.warEndAlarmEnabled) {
                      RuleManager.warAutoSync = false;
                      WarSyncService.cancelTask();
                    }
                    RuleManager.save();
                  });
                  await _syncAllWarSchedules();
                },
                child: _buildTerminalSwitch(isEndEnabled, endColor),
              ),
            ],
          ),
          if (isEndEnabled) ...[
            SizedBox(height: 8),
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

          SizedBox(height: 16),
          Divider(color: AppColors.border, thickness: 1, height: 1),
          SizedBox(height: 16),

          // KHỐI 3: TỰ ĐỘNG CHẠY NGẦM
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(AppTheme.label(AppStrings.settings.warAutoSyncLabel), style: TextStyle(color: autoColor, fontSize: 14)),
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
    Color autoUpdateColor = isAutoUpdate ? _themeColor : AppColors.textDim;

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
                SizedBox(width: 12),
                Text(AppTheme.label(AppStrings.settings.settingsAutoCheckUpdate),
                  style: TextStyle(color: autoUpdateColor, fontSize: 14),
                )
              ],
            ),
          ),

          if (_updateUrl == null) ...[
            SizedBox(height: 16),
            InkWell(
              onTap: _isCheckingUpdate ? null : _checkForUpdates,
              child: Text(
                _isCheckingUpdate ? "[ . . . ]" : AppStrings.settings.btnCheckUpdateNow,
                style: TextStyle(color: _themeColor, fontSize: 14),
              ),
            ),
          ],

          SizedBox(height: 12),

          Text(
            AppStrings.format(AppStrings.settings.labelVersion, {'version': _appVersion}),
            style: TextStyle(color: AppColors.textMuted, fontSize: 14),
          ),

          if (_updateStatusMsg.isNotEmpty) ...[
            SizedBox(height: 8),
            InkWell(
              onTap: _updateUrl != null ? _launchUpdateUrl : null,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 2.0),
                child: Text(
                  _updateStatusMsg,
                  style: TextStyle(
                    color: _updateUrl != null ? _themeColor : AppColors.textMuted,
                    fontSize: 14,
                    fontWeight: _updateUrl != null ? FontWeight.bold : FontWeight.normal,
                    fontStyle: _updateUrl != null ? FontStyle.normal : FontStyle.italic,
                  ),
                ),
              ),
            ),
          ],

          SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: AppColors.surfaceAlt,
                      shape: RoundedRectangleBorder(side: BorderSide(color: _themeColor, width: 1.5)),
                      title: Text(AppTheme.label(AppStrings.settings.privacyDialogTitle), style: TextStyle(color: _themeColor, fontSize: 14, fontWeight: FontWeight.bold)),
                      content: Text(AppTheme.label(AppStrings.settings.privacyDialogContent),
                        style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.5, fontFamily: AppTheme.font),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(AppTheme.label(AppStrings.dialog.btnClose), style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                  );
                },
                child: Text(AppTheme.label(AppStrings.settings.btnPrivacyPolicy), style: TextStyle(color: _themeColor, fontSize: 14)),
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
                child: Text(AppTheme.label(AppStrings.settings.btnLicenses), style: TextStyle(color: _themeColor, fontSize: 14)),
              ),
            ],
          )
        ],
      ),
    );
  }
}

class _InlineRuleTimeBox extends StatefulWidget {
  final int minutes;
  final Color color;
  final Future<bool> Function(int newMins) onTimeChanged;

  const _InlineRuleTimeBox({
    required this.minutes,
    required this.color,
    required this.onTimeChanged,
  });

  @override
  State<_InlineRuleTimeBox> createState() => _InlineRuleTimeBoxState();
}

class _InlineRuleTimeBoxState extends State<_InlineRuleTimeBox> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  String _formatMins(int mins) {
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatMins(widget.minutes));
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void didUpdateWidget(covariant _InlineRuleTimeBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minutes != widget.minutes && !_focusNode.hasFocus) {
      _controller.text = _formatMins(widget.minutes);
    }
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _commitOrRevert(_controller.text);
    }
  }

  Future<void> _commitOrRevert(String rawText) async {
    String digits = rawText.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      _controller.text = _formatMins(widget.minutes);
      return;
    }
    if (digits.length <= 2) {
      digits = "${digits.padLeft(2, '0')}00";
    } else if (digits.length == 3) {
      digits = "0$digits";
    } else if (digits.length > 4) {
      digits = digits.substring(0, 4);
    }

    int h = int.tryParse(digits.substring(0, 2)) ?? 0;
    int m = int.tryParse(digits.substring(2, 4)) ?? 0;
    if (h > 23) h = 23;
    if (m > 59) m = 59;

    int totalMins = h * 60 + m;
    if (totalMins == widget.minutes) {
      _controller.text = _formatMins(widget.minutes);
      return;
    }

    bool ok = await widget.onTimeChanged(totalMins);
    if (!mounted) return;
    if (ok) {
      _controller.text = _formatMins(totalMins);
    } else {
      _controller.text = _formatMins(widget.minutes);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      child: TextField(
        controller: _controller,
        focusNode: _focusNode,
        style: TextStyle(
          color: widget.color,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          fontFamily: AppTheme.font,
        ),
        textAlign: TextAlign.center,
        keyboardType: TextInputType.datetime,
        decoration: InputDecoration(
          hintText: "00:00",
          hintStyle: TextStyle(color: AppColors.borderStrong),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: widget.color, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.zero,
            borderSide: BorderSide(color: widget.color, width: 1.5),
          ),
          filled: true,
          fillColor: AppColors.surface,
        ),
        onChanged: (val) async {
          String clean = val.replaceAll(RegExp(r'[^0-9]'), '');
          if (clean.length > 4) clean = clean.substring(0, 4);

          String formatted = clean;
          if (clean.length >= 3) {
            formatted = "${clean.substring(0, clean.length - 2)}:${clean.substring(clean.length - 2)}";
          }

          if (_controller.text != formatted && formatted.length <= 5) {
            _controller.value = TextEditingValue(
              text: formatted,
              selection: TextSelection.collapsed(offset: formatted.length),
            );
          }

          if (clean.length == 4) {
            int h = int.tryParse(clean.substring(0, 2)) ?? 0;
            int m = int.tryParse(clean.substring(2, 4)) ?? 0;
            if (h > 23) h = 23;
            if (m > 59) m = 59;

            String clampedStr = "${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}";
            if (_controller.text != clampedStr) {
              _controller.value = TextEditingValue(
                text: clampedStr,
                selection: TextSelection.collapsed(offset: 5),
              );
            }

            int totalMins = h * 60 + m;
            if (totalMins != widget.minutes) {
              bool ok = await widget.onTimeChanged(totalMins);
              if (!ok && mounted) {
                final fallback = _formatMins(widget.minutes);
                _controller.value = TextEditingValue(
                  text: fallback,
                  selection: TextSelection.collapsed(offset: fallback.length),
                );
              }
            }
          }
        },
        onSubmitted: (val) => _commitOrRevert(val),
      ),
    );
  }
}
