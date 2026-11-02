import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:alarm/alarm.dart';

import '../models/village_models.dart';
import '../services/schedule_service.dart';
import '../services/coc_api_service.dart';
import '../widgets/alarm_popup.dart';
import 'village_parser.dart';
import 'app_strings.dart';
import 'rule_manager.dart';

class VillageManager {
  Map<String, VillageData> villages = {};
  Map<String, String> savedRawJsons = {};
  final Map<String, String> villageNames = {};
  final Map<String, bool> trackHome = {};
  final Map<String, bool> trackBuilder = {};
  final Map<String, String> savedAlarmStates = {};

  bool showRealEta = true;
  bool xiaomiAcknowledged = false;
  bool isQuickPasteActive = false;

  final Queue<AlarmSettings> _alarmQueue = Queue<AlarmSettings>();
  bool _isAlarmPopupShowing = false;
  int? _currentShowingAlarmId;

  bool get isAlarmIdle => _alarmQueue.isEmpty && !_isAlarmPopupShowing;

  void queueAlarm(AlarmSettings settings) {
    if (_currentShowingAlarmId == settings.id) return;
    if (!_alarmQueue.any((a) => a.id == settings.id)) {
      _alarmQueue.add(settings);
    }
    processNextAlarm();
  }

  Future<void> processNextAlarm() async {
    if (_isAlarmPopupShowing) return;

    if (_alarmQueue.isEmpty) {
      ScheduleService.disableAlarmMode();
      ScheduleService.handleAlarmDismiss();
      return;
    }

    final alarm = _alarmQueue.removeFirst();

    final activeAlarms = await Alarm.getAlarms();
    final stillActive = activeAlarms.any((a) => a.id == alarm.id);
    if (!stillActive) {
      processNextAlarm();
      return;
    }

    _isAlarmPopupShowing = true;
    _currentShowingAlarmId = alarm.id;

    ScheduleService.enableAlarmMode();

    BuildContext? globalContext = ScheduleService.navigatorKey.currentContext;
    int retryCount = 0;

    while ((globalContext == null || !globalContext.mounted) && retryCount < 10) {
      await Future.delayed(const Duration(milliseconds: 500));
      globalContext = ScheduleService.navigatorKey.currentContext;
      retryCount++;
    }

    if (globalContext == null || !globalContext.mounted) {
      _isAlarmPopupShowing = false;
      _currentShowingAlarmId = null;
      processNextAlarm();
      return;
    }

    showDialog(
      context: globalContext,
      barrierDismissible: false,
      builder: (dialogContext) => AlarmPopup(settings: alarm),
    ).then((_) {
      _isAlarmPopupShowing = false;
      _currentShowingAlarmId = null;
      Future.delayed(const Duration(milliseconds: 500), processNextAlarm);
    });
  }

  bool tickCleanup(DateTime now) {
    bool needsUpdate = false;

    for (var village in villages.values) {
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

    return needsUpdate;
  }

  Future<bool> loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_villages_map');
    final savedNames = prefs.getString('saved_village_names');
    final savedTrackHome = prefs.getString('saved_track_home');
    final savedTrackBuilder = prefs.getString('saved_track_builder');
    final savedAlarmJson = prefs.getString('saved_alarm_states');

    if (prefs.getBool('show_real_eta') != null) {
      showRealEta = prefs.getBool('show_real_eta')!;
    }
    xiaomiAcknowledged = prefs.getBool('xiaomi_acknowledged') ?? false;
    isQuickPasteActive = prefs.getBool('quick_paste_enabled') ?? false;

    if (savedTrackHome != null) {
      try {
        jsonDecode(savedTrackHome).forEach((key, value) => trackHome[key] = value as bool);
      } catch (e) {
        debugPrint("Lỗi tải TrackHome: $e");
      }
    }
    if (savedTrackBuilder != null) {
      try {
        jsonDecode(savedTrackBuilder).forEach((key, value) => trackBuilder[key] = value as bool);
      } catch (e) {
        debugPrint("Lỗi tải TrackBuilder: $e");
      }
    }
    if (savedAlarmJson != null) {
      try {
        jsonDecode(savedAlarmJson).forEach((key, value) => savedAlarmStates[key] = value.toString());
      } catch (e) {
        debugPrint("Lỗi tải AlarmStates: $e");
      }
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
          } catch (e) {
            debugPrint("Lỗi Parse dữ liệu làng: $e");
          }
        });

        villages = loadedVillages;
        savedRawJsons = loadedRaws;

        if (savedNames != null) {
          try {
            jsonDecode(savedNames).forEach((key, value) => villageNames[key] = value.toString());
          } catch (e) {
            debugPrint("Lỗi tải tên làng: $e");
          }
        }
        for (var v in villages.values) {
          await applySavedAlarmState(v, syncWithOS: false, forceApplyRules: false);
        }
        return villages.isNotEmpty;
      } catch (e) {
        debugPrint("Lỗi giải mã dữ liệu đã lưu: $e");
      }
    }
    return false;
  }

  Future<void> applySavedAlarmState(
    VillageData village, {
    bool syncWithOS = false,
    bool forceApplyRules = false,
  }) async {
    bool tHome = trackHome[village.tag] ?? true;
    bool tBuilder = trackBuilder[village.tag] ?? true;
    List<Future> futures = [];

    void apply(List<UpgradeItem> items, bool isTracked) {
      for (var item in items) {
        String uniqueKey = item.instanceId;
        AlarmType intendedType;

        if (forceApplyRules) {
          intendedType = RuleManager.evaluateEta(item.realEta);
          savedAlarmStates[uniqueKey] = intendedType.name;
        } else {
          String? stateStr = savedAlarmStates[uniqueKey];
          if (stateStr != null) {
            intendedType = stateStr == "system"
                ? AlarmType.system
                : (stateStr == "fullscreen" ? AlarmType.fullscreen : AlarmType.none);
          } else {
            intendedType = RuleManager.evaluateEta(item.realEta);
            savedAlarmStates[uniqueKey] = intendedType.name;
          }
        }

        item.alarmType = isTracked ? intendedType : AlarmType.none;
        if (syncWithOS) {
          String vName = villageNames[village.tag] ?? AppStrings.terminal.defaultVillageNameUnset;
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

  Future<void> resyncAllVillages({bool forceApplyRules = false}) async {
    for (var v in villages.values) {
      await applySavedAlarmState(v, syncWithOS: true, forceApplyRules: forceApplyRules);
    }
    if (forceApplyRules) {
      await saveAlarmStatesToPrefs();
    }
  }

  Future<({String tag, bool isNewVillage, String statusMsg})> importVillageJson(String inputData) async {
    final parsed = VillageParser.parse(inputData);
    final String tag = parsed.tag;
    final bool isNewVillage = !villageNames.containsKey(tag);

    if (villages.containsKey(tag)) {
      ScheduleService.cancelAllForVillage(villages[tag]!);
      savedAlarmStates.removeWhere((key, value) => key.startsWith("${tag}_"));
    } else {
      trackHome[tag] = true;
      trackBuilder[tag] = true;
      villageNames[tag] = AppStrings.terminal.defaultVillageNameSearching;
    }

    villages[tag] = parsed;
    savedRawJsons[tag] = inputData;

    await applySavedAlarmState(parsed, syncWithOS: !isNewVillage, forceApplyRules: true);

    final String statusMsg = isNewVillage
        ? AppStrings.format(AppStrings.terminal.statusFetchingVillageName, {'tag': tag})
        : AppStrings.format(AppStrings.terminal.statusUpdated, {'villageName': villageNames[tag]!, 'tag': tag});

    await saveDataToPrefs();
    if (!isNewVillage) {
      await saveAlarmStatesToPrefs();
      if (isQuickPasteActive) {
        ScheduleService.showQuickPasteNotification(
          customStatus: AppStrings.format(AppStrings.terminal.quickPasteUpdated, {
            'name': villageNames[tag]!,
            'tag': tag,
          }),
        );
      }
    }

    return (tag: tag, isNewVillage: isNewVillage, statusMsg: statusMsg);
  }

  Future<String> finalizeNewVillage(
    String tag,
    Map<String, dynamic>? result,
    String? fetchedName,
  ) async {
    String statusMsg;
    if (result != null) {
      villageNames[tag] = (result['name'] as String).trim().isNotEmpty
          ? result['name']
          : AppStrings.terminal.defaultVillageNameFallback;
      trackHome[tag] = result['home'] as bool;
      trackBuilder[tag] = result['builder'] as bool;
      statusMsg = AppStrings.format(
        AppStrings.terminal.statusSavedSettings,
        {'name': villageNames[tag]!},
      );
    } else {
      villageNames[tag] = (fetchedName != null && fetchedName.isNotEmpty)
          ? fetchedName
          : AppStrings.terminal.defaultVillageNameFallback;
      statusMsg = AppStrings.format(
        AppStrings.terminal.statusSavedDefault,
        {'name': villageNames[tag]!},
      );
    }

    await saveDataToPrefs();
    await applySavedAlarmState(villages[tag]!, syncWithOS: true, forceApplyRules: true);
    await saveAlarmStatesToPrefs();

    if (isQuickPasteActive) {
      ScheduleService.showQuickPasteNotification(
        customStatus: AppStrings.format(AppStrings.terminal.quickPasteAdded, {
          'name': villageNames[tag]!,
          'tag': tag,
        }),
      );
    }

    return statusMsg;
  }

  Future<void> saveAlarmStatesToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_alarm_states', jsonEncode(savedAlarmStates));
  }

  Future<void> saveDataToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_villages_map', jsonEncode(savedRawJsons));
    await prefs.setString('saved_village_names', jsonEncode(villageNames));
    await prefs.setBool('show_real_eta', showRealEta);
    await prefs.setString('saved_track_home', jsonEncode(trackHome));
    await prefs.setString('saved_track_builder', jsonEncode(trackBuilder));
  }

  String deleteVillage(String tag) {
    if (villages.containsKey(tag)) {
      ScheduleService.cancelAllForVillage(villages[tag]!);
    }

    villages.remove(tag);
    savedRawJsons.remove(tag);
    villageNames.remove(tag);
    trackHome.remove(tag);
    trackBuilder.remove(tag);
    savedAlarmStates.removeWhere((key, value) => key.startsWith("${tag}_"));

    saveDataToPrefs();
    saveAlarmStatesToPrefs();

    return villages.isEmpty
        ? AppStrings.terminal.statusWaitingJson
        : AppStrings.format(AppStrings.terminal.statusVillageDeleted, {'tag': tag});
  }

  Future<String> cycleAlarmForItem(String villageTag, UpgradeItem item) async {
    String uniqueKey = item.instanceId;
    String currentState = savedAlarmStates[uniqueKey] ?? RuleManager.evaluateEta(item.realEta).name;
    AlarmType nextType = currentState == "system"
        ? AlarmType.fullscreen
        : (currentState == "fullscreen" ? AlarmType.none : AlarmType.system);

    savedAlarmStates[uniqueKey] = nextType.name;
    await saveAlarmStatesToPrefs();

    String itemName = AppStrings.gameData.getName(item.dataId);
    String statusMsg;
    if (nextType == AlarmType.system) {
      statusMsg = AppStrings.format(
        AppStrings.terminal.statusNotificationSetSystem,
        {'typeString': itemName.toUpperCase(), 'dataId': ""},
      );
    } else if (nextType == AlarmType.fullscreen) {
      statusMsg = AppStrings.format(
        AppStrings.terminal.statusAlarmSetFullscreen,
        {'typeString': itemName.toUpperCase(), 'dataId': ""},
      );
    } else {
      statusMsg = AppStrings.format(
        AppStrings.terminal.statusAlarmOff,
        {'typeString': itemName.toUpperCase(), 'dataId': ""},
      );
    }

    await applySavedAlarmState(villages[villageTag]!, syncWithOS: true);
    return statusMsg;
  }

  Future<String> cycleAlarmForGroup(
    String villageTag,
    String groupName,
    List<UpgradeItem> items,
  ) async {
    if (items.isEmpty) return "";
    bool hasSystem = false, hasFullscreen = false;

    for (var item in items) {
      String currentState = savedAlarmStates[item.instanceId] ?? RuleManager.evaluateEta(item.realEta).name;
      if (currentState == "system") hasSystem = true;
      if (currentState == "fullscreen") hasFullscreen = true;
    }

    AlarmType targetType = hasSystem
        ? AlarmType.fullscreen
        : (hasFullscreen ? AlarmType.none : AlarmType.system);
    for (var item in items) {
      savedAlarmStates[item.instanceId] = targetType.name;
    }

    final String statusMsg = targetType == AlarmType.none
        ? AppStrings.format(AppStrings.terminal.statusGroupAllOff, {'groupName': groupName})
        : AppStrings.format(
            AppStrings.terminal.statusGroupModeChanged,
            {'groupName': groupName, 'alarmType': targetType.name.toUpperCase()},
          );

    await saveAlarmStatesToPrefs();
    await applySavedAlarmState(villages[villageTag]!, syncWithOS: true);
    return statusMsg;
  }

  static Future<String?> fetchPlayerNameWithRetry(String tag) async {
    String? fetchedName;
    for (int i = 0; i < 3; i++) {
      try {
        fetchedName = await CocApiService.fetchPlayerName(tag).timeout(
          const Duration(seconds: 4),
          onTimeout: () => null,
        );
        if (fetchedName != null && fetchedName.isNotEmpty) {
          break;
        }
      } catch (e) {
        debugPrint("Lỗi API lần ${i + 1}: $e");
      }
      if (i < 2) {
        await Future.delayed(const Duration(milliseconds: 1500));
      }
    }
    return fetchedName;
  }

  static Future<({String version, String url})?> checkGithubUpdate() async {
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

        if (_isVersionGreater(latestVersion, currentVersion)) {
          return (version: latestVersion, url: htmlUrl);
        }
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra cập nhật: $e");
    }
    return null;
  }

  static bool _isVersionGreater(String newVersion, String currentVersion) {
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
}
