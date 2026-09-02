import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm/alarm.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/village_models.dart';
import '../utils/village_parser.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';
import '../services/schedule_service.dart';

import '../widgets/terminal_frame_painter.dart';
import '../widgets/alarm_popup.dart';
import '../widgets/village_card.dart';
import '../widgets/village_detail_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/terminal_header.dart';
import '../widgets/terminal_components.dart';

import 'online_screen.dart'; // THÊM IMPORT MÀN HÌNH MỚI

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  final TextEditingController _jsonController = TextEditingController();
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;
  Timer? _clockTimer;
  String _currentTime = "";

  Map<String, VillageData> _villages = {};
  Map<String, String> _savedRawJsons = {};
  final Map<String, String> _villageNames = {};

  final Map<String, bool> _trackHome = {};
  final Map<String, bool> _trackBuilder = {};
  final Map<String, String> _savedAlarmStates = {};

  final Queue<AlarmSettings> _alarmQueue = Queue<AlarmSettings>();
  bool _isAlarmPopupShowing = false;
  int? _currentShowingAlarmId; // THÊM BIẾN NÀY ĐỂ TRÁNH BẬT LẠI POPUP CŨ

  String _parseStatus = AppStrings.terminal.statusWaitingJson;
  bool _showRealEta = true;
  bool _isBuilderBase = false;
  bool _xiaomiAcknowledged = false;

  String? _updateVersion;
  String? _updateUrl;

  Color get _themeColor => _isBuilderBase ? const Color(0xFFf8a4bd) : const Color(0xFFB54545);
  Color get _bgTagColor => _isBuilderBase ? const Color(0x22f8a4bd) : const Color(0x228B2B2B);

  StreamSubscription? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    RuleManager.init().then((_) {
      if (RuleManager.autoCheckUpdate) _checkGithubUpdate();
    });

    if (_alarmQueue.isEmpty && !_isAlarmPopupShowing) {
      ScheduleService.disableAlarmMode();
    }

    ScheduleService.checkAndRequestPermissions().then((_) {
      if (mounted && _alarmQueue.isEmpty && !_isAlarmPopupShowing) {
        ScheduleService.disableAlarmMode();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // FIX 1: Tăng độ trễ an toàn lên 2.5 giây khi khởi động lạnh
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted && _alarmQueue.isEmpty && !_isAlarmPopupShowing) {
          ScheduleService.disableAlarmMode();
        }
      });
    });

    _loadSavedData();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) _showCursor.value = !_showCursor.value;
    });
    _startClockTimer();

    _alarmSubscription = Alarm.ringing.listen((dynamic event) {
      try {
        // GỌI LỆNH XUYÊN MÀN HÌNH KHÓA NGAY LẬP TỨC
        ScheduleService.enableAlarmMode();

        if (mounted) {
          // BẮT SỰ KIỆN TƯƠNG THÍCH VỚI MỌI PHIÊN BẢN ALARM PACKAGE
          if (event is AlarmSettings) {
            _queueAlarm(event);
          } else {
            try {
              for (final alarmSettings in event.alarms) {
                if (alarmSettings is AlarmSettings) {
                  _queueAlarm(alarmSettings);
                }
              }
            } catch (_) {}
          }
        }
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.terminal.debugLoadGeneralError, {'e': "Alarm Stream: $e"}));
      }
    });
  }

  Future<void> _checkGithubUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final response = await http.get(
        Uri.parse('https://api.github.com/repos/NightOwlEyes/COC_Timer/releases/latest'),
        headers: {'Accept': 'application/vnd.github.v3+json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String tagName = data['tag_name'] as String;
        String htmlUrl = data['html_url'] as String;
        String latestVersion = tagName.split('-').first.replaceAll('v', '');

        if (_isVersionGreater(latestVersion, currentVersion) && mounted) {
          setState(() {
            _updateVersion = latestVersion;
            _updateUrl = htmlUrl;
          });
        }
      }
    } catch (e) { debugPrint("Lỗi kiểm tra cập nhật: $e"); }
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alarmSubscription?.cancel();
    _cursorTimer?.cancel();
    _clockTimer?.cancel();
    _jsonController.dispose();
    _showCursor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_isAlarmPopupShowing || _alarmQueue.isNotEmpty) {
        ScheduleService.enableAlarmMode();
      } else {
        // FIX LỖI MÀN HÌNH KHÓA 3: Tăng thời gian chờ lên 2.5 giây.
        // Khi báo thức Native đánh thức máy, app sẽ chuyển sang resumed TRƯỚC KHI
        // stream Alarm.ringing kịp chạy. Nếu gỡ cờ ngay lúc này, app sẽ bị giấu sau mật khẩu.
        Future.delayed(const Duration(milliseconds: 2500), () {
          if (mounted && !_isAlarmPopupShowing && _alarmQueue.isEmpty) {
            ScheduleService.disableAlarmMode();
          }
        });
      }
    }
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      try {
        final now = DateTime.now();
        bool needsUpdate = false;

        for (var village in _villages.values) {
          void checkAlarm(List<UpgradeItem> items) {
            for (var item in items) {
              final diff = item.realEta.difference(now).inSeconds;
              if (diff == 0 || diff == -1) {
                needsUpdate = true;
                if (item.alarmType != AlarmType.none && !item.isNotified) {
                  item.isNotified = true;
                }
              }
            }
          }

          checkAlarm(village.buildersItems);
          checkAlarm(village.petItems);
          checkAlarm(village.labItems);
          checkAlarm(village.builders2Items);
          checkAlarm(village.lab2Items);

          int beforeBuilders = village.buildersItems.length;
          int beforePets = village.petItems.length;
          int beforeLab = village.labItems.length;
          int beforeBuilders2 = village.builders2Items.length;
          int beforeLab2 = village.lab2Items.length;

          village.buildersItems.removeWhere((item) => item.realEta.difference(now).isNegative);
          village.petItems.removeWhere((item) => item.realEta.difference(now).isNegative);
          village.labItems.removeWhere((item) => item.realEta.difference(now).isNegative);
          village.builders2Items.removeWhere((item) => item.realEta.difference(now).isNegative);
          village.lab2Items.removeWhere((item) => item.realEta.difference(now).isNegative);

          if (beforeBuilders != village.buildersItems.length ||
              beforePets != village.petItems.length ||
              beforeLab != village.labItems.length ||
              beforeBuilders2 != village.builders2Items.length ||
              beforeLab2 != village.lab2Items.length) {
            needsUpdate = true;
          }
        }

        setState(() {
          _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        });

        if (needsUpdate) _saveDataToPrefs();
      } catch (e) {
        debugPrint("Lỗi đếm ngược thời gian: $e");
      }
    });
  }

  void _queueAlarm(AlarmSettings settings) {
    // NGĂN CHẶN LỖI NHÁY 0.5s: Nếu ID này đang được hiển thị, bỏ qua sự kiện rác
    if (_currentShowingAlarmId == settings.id) return;

    if (!_alarmQueue.any((a) => a.id == settings.id)) _alarmQueue.add(settings);
    _processNextAlarm();
  }

  Future<void> _processNextAlarm() async {
    // 1. Nếu đang có popup hiển thị, dừng lại chờ nó đóng
    if (_isAlarmPopupShowing) return;

    // 2. NẾU HÀNG ĐỢI TRỐNG: DỌN DẸP VÀ ẨN APP NGAY LẬP TỨC (Sửa lỗi kẹt Terminal)
    if (_alarmQueue.isEmpty) {
      ScheduleService.disableAlarmMode();
      ScheduleService.handleAlarmDismiss();
      return;
    }

    final alarm = _alarmQueue.removeFirst();

    // CHẶN BÁO THỨC MA: Kiểm tra xem chuông có bị tắt ngầm trước khi popup kịp mở không
    final activeAlarms = await Alarm.getAlarms();
    final stillActive = activeAlarms.any((a) => a.id == alarm.id);
    if (!stillActive) {
      _processNextAlarm(); // Bỏ qua cái đã chết, chạy đệ quy kiểm tra cái tiếp theo
      return;
    }

    _isAlarmPopupShowing = true;
    _currentShowingAlarmId = alarm.id; // Đánh dấu ID đang hiển thị

    // Chốt an toàn một lần nữa
    ScheduleService.enableAlarmMode();

    BuildContext? globalContext = ScheduleService.navigatorKey.currentContext;
    int retryCount = 0;

    // VÒNG LẶP SINH TỬ: Chờ tối đa 5 giây để UI Flutter kịp khởi tạo
    // (Rất quan trọng khi app bị đánh thức từ chế độ ngủ sâu/khóa màn hình)
    while ((globalContext == null || !globalContext.mounted) && retryCount < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      globalContext = ScheduleService.navigatorKey.currentContext;
      retryCount++;
    }

    // Nếu sau 5 giây máy vẫn lác không load nổi UI thì mới bỏ cuộc
    if (globalContext == null || !globalContext.mounted) {
      _isAlarmPopupShowing = false;
      _currentShowingAlarmId = null;
      _processNextAlarm();
      return;
    }

    showDialog(
        context: globalContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlarmPopup(settings: alarm)
    ).then((_) {
      _isAlarmPopupShowing = false;
      _currentShowingAlarmId = null; // Reset cờ khi đóng popup

      // Nghỉ nửa giây rồi gọi lại hàm, để nó tự quyết định đi tiếp hay ẩn app
      Future.delayed(const Duration(milliseconds: 500), _processNextAlarm);
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_villages_map');
    final savedNames = prefs.getString('saved_village_names');
    final savedTrackHome = prefs.getString('saved_track_home');
    final savedTrackBuilder = prefs.getString('saved_track_builder');
    final savedAlarmJson = prefs.getString('saved_alarm_states');

    if (prefs.getBool('show_real_eta') != null) _showRealEta = prefs.getBool('show_real_eta')!;
    _xiaomiAcknowledged = prefs.getBool('xiaomi_acknowledged') ?? false;

    if (savedTrackHome != null) {
      try { jsonDecode(savedTrackHome).forEach((key, value) => _trackHome[key] = value as bool); } catch (e) { debugPrint("Lỗi tải TrackHome: $e"); }
    }
    if (savedTrackBuilder != null) {
      try { jsonDecode(savedTrackBuilder).forEach((key, value) => _trackBuilder[key] = value as bool); } catch (e) { debugPrint("Lỗi tải TrackBuilder: $e"); }
    }
    if (savedAlarmJson != null) {
      try { jsonDecode(savedAlarmJson).forEach((key, value) => _savedAlarmStates[key] = value.toString()); } catch (e) { debugPrint("Lỗi tải AlarmStates: $e"); }
    }

    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        Map<String, VillageData> loadedVillages = {};
        Map<String, String> loadedRaws = {};

        decoded.forEach((key, value) {
          try {
            loadedVillages[key] = VillageParser.parse(value.toString());
            loadedRaws[key] = value.toString();
          } catch (e) { debugPrint("Lỗi Parse dữ liệu làng: $e"); }
        });

        if (mounted) {
          setState(() {
            _villages = loadedVillages;
            _savedRawJsons = loadedRaws;
            if (_villages.isNotEmpty) _parseStatus = AppStrings.terminal.statusLoadedSavedData;

            if (savedNames != null) {
              try { jsonDecode(savedNames).forEach((key, value) => _villageNames[key] = value.toString()); } catch (e) { debugPrint("Lỗi tải tên làng: $e"); }
            }
            for (var v in _villages.values) {
              _applySavedAlarmState(v, syncWithOS: false, forceApplyRules: false);
            }
          });
        }
      } catch (e) { debugPrint("Lỗi giải mã dữ liệu đã lưu: $e"); }
    }
  }

  Future<void> _applySavedAlarmState(VillageData village, {bool syncWithOS = false, bool forceApplyRules = false}) async {
    bool tHome = _trackHome[village.tag] ?? true;
    bool tBuilder = _trackBuilder[village.tag] ?? true;
    List<Future> futures = [];

    void apply(List<UpgradeItem> items, bool isTracked) {
      for (var item in items) {
        String uniqueKey = item.instanceId;
        AlarmType intendedType;

        if (forceApplyRules) {
          intendedType = RuleManager.evaluateEta(item.realEta);
          _savedAlarmStates[uniqueKey] = intendedType.name;
        } else {
          String? stateStr = _savedAlarmStates[uniqueKey];
          if (stateStr != null) {
            intendedType = stateStr == "system" ? AlarmType.system : (stateStr == "fullscreen" ? AlarmType.fullscreen : AlarmType.none);
          } else {
            intendedType = RuleManager.evaluateEta(item.realEta);
            _savedAlarmStates[uniqueKey] = intendedType.name;
          }
        }

        item.alarmType = isTracked ? intendedType : AlarmType.none;
        if (syncWithOS) {
          String vName = _villageNames[village.tag] ?? AppStrings.terminal.defaultVillageNameUnset;
          futures.add(ScheduleService.syncItemSchedule(village.tag, vName, item));
        }
      }
    }

    apply(village.buildersItems, tHome);
    apply(village.petItems, tHome);
    apply(village.labItems, tHome);
    apply(village.builders2Items, tBuilder);
    apply(village.lab2Items, tBuilder);

    if (syncWithOS) await Future.wait(futures);
  }

  Future<void> _saveAlarmStatesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_alarm_states', jsonEncode(_savedAlarmStates));
  }

  Future<void> _saveDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_villages_map', jsonEncode(_savedRawJsons));
    await prefs.setString('saved_village_names', jsonEncode(_villageNames));
    await prefs.setBool('show_real_eta', _showRealEta);
    await prefs.setString('saved_track_home', jsonEncode(_trackHome));
    await prefs.setString('saved_track_builder', jsonEncode(_trackBuilder));
  }

  void _confirmDeleteVillage(String tag) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppStrings.terminal.deleteDialogTitle, style: const TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                  textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF444444))),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.terminal.btnCancel, style: const TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB54545)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteVillage(tag);
                      },
                      child: Text(AppStrings.terminal.btnDeleteNow, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  void _deleteVillage(String tag) {
    if (!mounted) return;
    if (_villages.containsKey(tag)) ScheduleService.cancelAllForVillage(_villages[tag]!);

    setState(() {
      _villages.remove(tag);
      _savedRawJsons.remove(tag);
      _trackHome.remove(tag);
      _trackBuilder.remove(tag);
      _savedAlarmStates.removeWhere((key, value) => key.startsWith("${tag}_"));
      _parseStatus = _villages.isEmpty ? AppStrings.terminal.statusWaitingJson : AppStrings.format(AppStrings.terminal.statusVillageDeleted, {'tag': tag});
    });
    _saveDataToPrefs();
    _saveAlarmStatesToPrefs();
  }

  void _cycleAlarmForItem(String villageTag, UpgradeItem item) {
    String uniqueKey = item.instanceId;
    String currentState = _savedAlarmStates[uniqueKey] ?? RuleManager.evaluateEta(item.realEta).name;
    AlarmType nextType = currentState == "system" ? AlarmType.fullscreen : (currentState == "fullscreen" ? AlarmType.none : AlarmType.system);

    _savedAlarmStates[uniqueKey] = nextType.name;
    _saveAlarmStatesToPrefs();

    String itemName = AppStrings.gameData.getName(item.dataId);
    if (nextType == AlarmType.system) {
      _parseStatus = AppStrings.format(AppStrings.terminal.statusNotificationSetSystem, {'typeString': itemName.toUpperCase(), 'dataId': ""});
    } else if (nextType == AlarmType.fullscreen) {
      _parseStatus = AppStrings.format(AppStrings.terminal.statusAlarmSetFullscreen, {'typeString': itemName.toUpperCase(), 'dataId': ""});
    } else {
      _parseStatus = AppStrings.format(AppStrings.terminal.statusAlarmOff, {'typeString': itemName.toUpperCase(), 'dataId': ""});
    }

    _applySavedAlarmState(_villages[villageTag]!, syncWithOS: true).then((_) {
      if (mounted && _alarmQueue.isEmpty && !_isAlarmPopupShowing) ScheduleService.disableAlarmMode();
      setState(() {});
    });
  }

  void _cycleAlarmForGroup(String villageTag, String groupName, List<UpgradeItem> items) {
    if (items.isEmpty) return;
    bool hasSystem = false, hasFullscreen = false;

    for (var item in items) {
      String currentState = _savedAlarmStates[item.instanceId] ?? RuleManager.evaluateEta(item.realEta).name;
      if (currentState == "system") hasSystem = true;
      if (currentState == "fullscreen") hasFullscreen = true;
    }

    AlarmType targetType = hasSystem ? AlarmType.fullscreen : (hasFullscreen ? AlarmType.none : AlarmType.system);
    for (var item in items) {
      _savedAlarmStates[item.instanceId] = targetType.name;
    }

    _parseStatus = targetType == AlarmType.none
        ? AppStrings.format(AppStrings.terminal.statusGroupAllOff, {'groupName': groupName})
        : AppStrings.format(AppStrings.terminal.statusGroupModeChanged, {'groupName': groupName, 'alarmType': targetType.name.toUpperCase()});

    _saveAlarmStatesToPrefs();
    _applySavedAlarmState(_villages[villageTag]!, syncWithOS: true).then((_) {
      if (mounted && _alarmQueue.isEmpty && !_isAlarmPopupShowing) ScheduleService.disableAlarmMode();
      setState(() {});
    });
  }

  void _processJson() async {
    final inputData = _jsonController.text.trim();
    if (inputData.isEmpty) return;
    FocusScope.of(context).unfocus();

    try {
      final parsed = VillageParser.parse(inputData);
      if (!_villageNames.containsKey(parsed.tag)) {
        Map<String, dynamic>? result = await _promptForVillageName(parsed.tag);
        if (result != null) {
          _villageNames[parsed.tag] = (result['name'] as String).trim().isNotEmpty ? result['name'] : AppStrings.terminal.defaultVillageNameFallback;
          _trackHome[parsed.tag] = result['home'] as bool;
          _trackBuilder[parsed.tag] = result['builder'] as bool;
        } else {
          _villageNames[parsed.tag] = AppStrings.terminal.defaultVillageNameFallback;
          _trackHome[parsed.tag] = true;
          _trackBuilder[parsed.tag] = true;
        }
      }

      if (_villages.containsKey(parsed.tag)) {
        ScheduleService.cancelAllForVillage(_villages[parsed.tag]!);
        _savedAlarmStates.removeWhere((key, value) => key.startsWith("${parsed.tag}_"));
      }

      await _applySavedAlarmState(parsed, syncWithOS: true, forceApplyRules: true);
      if (!mounted) return;

      setState(() {
        _villages[parsed.tag] = parsed;
        _savedRawJsons[parsed.tag] = inputData;
        _parseStatus = AppStrings.format(AppStrings.terminal.statusUpdated, {'villageName': _villageNames[parsed.tag]!, 'tag': parsed.tag});
        _jsonController.clear();
      });
      _saveDataToPrefs();

      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      if (_alarmQueue.isEmpty && !_isAlarmPopupShowing) ScheduleService.disableAlarmMode();

    } catch (e) {
      if (mounted) setState(() => _parseStatus = AppStrings.terminal.statusErrorInvalidJson);
    }
  }

  Future<Map<String, dynamic>?> _promptForVillageName(String tag) {
    TextEditingController tempController = TextEditingController();
    bool trackHome = true, trackBuilder = true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => Dialog(
          backgroundColor: const Color(0xFF0A0C0B),
          shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF4CAF50), width: 1)),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(AppStrings.terminal.newVillageDialogTitle, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(AppStrings.format(AppStrings.terminal.newVillageDialogTagLabel, {'tag': tag}), style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(height: 16),
                TextField(
                  controller: tempController,
                  autofocus: false,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: AppStrings.terminal.newVillageNameHint,
                    hintStyle: const TextStyle(color: Color(0xFF444444)),
                    enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF444444))),
                    focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4CAF50))),
                  ),
                ),
                const SizedBox(height: 24),
                Align(alignment: Alignment.centerLeft, child: Text(AppStrings.terminal.trackingOptionsLabel, style: const TextStyle(color: Color(0xFF888888), fontSize: 12))),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16, runSpacing: 12,
                  children: [
                    InkWell(
                      onTap: () => setStateSB(() => trackHome = !trackHome),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trackHome ? Icons.check_box : Icons.check_box_outline_blank, color: trackHome ? const Color(0xFF4CAF50) : const Color(0xFF444444), size: 18),
                          const SizedBox(width: 6),
                          Text(AppStrings.terminal.trackingHomeVillage, style: TextStyle(color: trackHome ? Colors.white : const Color(0xFF888888), fontSize: 12)),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setStateSB(() => trackBuilder = !trackBuilder),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(trackBuilder ? Icons.check_box : Icons.check_box_outline_blank, color: trackBuilder ? const Color(0xFF4CAF50) : const Color(0xFF444444), size: 18),
                          const SizedBox(width: 6),
                          Text(AppStrings.terminal.trackingBuilderBase, style: TextStyle(color: trackBuilder ? Colors.white : const Color(0xFF888888), fontSize: 12)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                    onPressed: () => Navigator.pop(ctx, {'name': tempController.text, 'home': trackHome, 'builder': trackBuilder}),
                    child: Text(AppStrings.terminal.btnSaveAndAddVillage, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && mounted) {
      setState(() => _jsonController.text = data.text!);
      _processJson();
    }
  }

  void _openXiaomiSettings() async {
    setState(() => _xiaomiAcknowledged = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('xiaomi_acknowledged', true);

    if (Platform.isAndroid) {
      try {
        await const AndroidIntent(action: 'miui.intent.action.APP_PERM_EDITOR', arguments: {'extra_pkgname': 'coctimer.nightowleyes.coctimer'}).launch();
        if (mounted) setState(() => _parseStatus = AppStrings.terminal.statusXiaomiPromptSuccess);
      } catch (e) {
        if (mounted) setState(() => _parseStatus = AppStrings.terminal.statusXiaomiPromptError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: TerminalFramePainter(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.5),
                child: Column(
                  children: [
                    TerminalHeader(
                      isOnline: false,
                      showRealEta: _showRealEta,
                      currentTime: _currentTime,
                      updateUrl: _updateUrl,
                      updateVersion: _updateVersion,
                      onToggleServer: () {
                        // CHUYỂN HƯỚNG SANG MÀN HÌNH ONLINE
                        FocusManager.instance.primaryFocus?.unfocus();
                        Navigator.push(
                          context,
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => const OnlineScreen(),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                          ),
                        );
                      },
                      onToggleEta: () {
                        FocusManager.instance.primaryFocus?.unfocus();
                        setState(() => _showRealEta = !_showRealEta);
                        _saveDataToPrefs();
                      },
                      onLanguageChange: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await AppStrings.changeLanguage(AppStrings.languageCode == 'en' ? 'vi' : 'en');
                        for (var v in _villages.values) {
                          await _applySavedAlarmState(v, syncWithOS: true);
                        }
                        await Future.delayed(const Duration(milliseconds: 500));
                        if (mounted) {
                          if (_alarmQueue.isEmpty && !_isAlarmPopupShowing) ScheduleService.disableAlarmMode();
                          setState(() {});
                        }
                      },
                      onSettingsTap: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        final oldRules = jsonEncode(RuleManager.activeRules.map((r) => r.toJson()).toList());
                        final oldEnabled = jsonEncode(RuleManager.groupEnabled.map((k, v) => MapEntry(k.name, v)));
                        final oldPreAlarm = RuleManager.preAlarmMinutes;

                        await showDialog(context: context, builder: (ctx) => SettingsDialog(themeColor: _themeColor));

                        if (oldRules != jsonEncode(RuleManager.activeRules.map((r) => r.toJson()).toList()) ||
                            oldEnabled != jsonEncode(RuleManager.groupEnabled.map((k, v) => MapEntry(k.name, v))) ||
                            oldPreAlarm != RuleManager.preAlarmMinutes) {
                          if (_villages.isNotEmpty) {
                            for (var v in _villages.values) {
                              await _applySavedAlarmState(v, syncWithOS: true, forceApplyRules: true);
                            }
                            await _saveAlarmStatesToPrefs();
                            await Future.delayed(const Duration(milliseconds: 500));
                            if (mounted) {
                              if (_alarmQueue.isEmpty && !_isAlarmPopupShowing) ScheduleService.disableAlarmMode();
                              setState(() {});
                            }
                          }
                        }
                      },
                      onUpdateTap: () async {
                        try {
                          await launchUrl(Uri.parse('https://github.com/NightOwlEyes/COC_Timer/blob/main/README.md'), mode: LaunchMode.externalApplication);
                        } catch (e) { debugPrint("Không thể mở link: $e"); }
                      },
                    ),
                    const SizedBox(height: 9.5),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TerminalSecurityTag(
                                isBuilderBase: _isBuilderBase,
                                themeColor: _themeColor,
                                bgTagColor: _bgTagColor,
                                onToggle: () {
                                  FocusManager.instance.primaryFocus?.unfocus();
                                  setState(() => _isBuilderBase = !_isBuilderBase);
                                }
                            ),
                            const SizedBox(height: 30),
                            const TerminalLogo(),
                            const SizedBox(height: 30),
                            if (_villages.isNotEmpty)
                              Column(
                                children: _villages.values.map((village) => VillageCard(
                                  village: village,
                                  villageName: _villageNames[village.tag] ?? "",
                                  isBuilderBase: _isBuilderBase,
                                  themeColor: _themeColor,
                                  onDelete: () => _confirmDeleteVillage(village.tag),
                                  onTap: () {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => VillageDetailDialog(
                                        village: village, villageName: _villageNames[village.tag] ?? "",
                                        isBuilderBase: _isBuilderBase, themeColor: _themeColor, showRealEta: _showRealEta,
                                        initialTrackHome: _trackHome[village.tag] ?? true, initialTrackBuilder: _trackBuilder[village.tag] ?? true,
                                        onNameChanged: (newName) {
                                          _villageNames[village.tag] = newName; _saveDataToPrefs(); setState(() {});
                                        },
                                        onTrackingChanged: (trackH, trackB) {
                                          _trackHome[village.tag] = trackH; _trackBuilder[village.tag] = trackB; _saveDataToPrefs();
                                          _applySavedAlarmState(village, syncWithOS: true).then((_) => setState(() {}));
                                        },
                                        onCycleGroup: (groupName, items) => _cycleAlarmForGroup(village.tag, groupName, items),
                                        onCycleItem: (item) => _cycleAlarmForItem(village.tag, item),
                                      ),
                                    );
                                  },
                                )).toList(),
                              ),
                            const SizedBox(height: 30),
                            TerminalInputArea(
                              controller: _jsonController,
                              onPaste: _pasteFromClipboard,
                              onSubmit: _processJson,
                            ),
                            const SizedBox(height: 20),
                            TerminalFooter(
                              xiaomiAcknowledged: _xiaomiAcknowledged,
                              onXiaomiTap: _openXiaomiSettings,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_parseStatus, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.clip, maxLines: 1),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) => Opacity(opacity: show ? 1.0 : 0.0, child: const Text("█", style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13))),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}