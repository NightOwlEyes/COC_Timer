import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alarm/alarm.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

import '../models/village_models.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';

class ScheduleService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();
  static const MethodChannel _fsiChannel = MethodChannel('coctimer/fsi_permission');

  // --- QUẢN LÝ SỰ KIỆN DÁN NHANH (QUICK-PASTE) ---
  static const int _quickPasteNotificationId = 9999;
  static const String _quickPastePayload = 'QUICK_PASTE_ACTION';
  static final ValueNotifier<int> quickPasteTrigger = ValueNotifier<int>(0);
  static bool isQuickPasteActive = false;

  static Future<void> init() async {
    await Alarm.init();

    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    // Bắt sự kiện khi người dùng chạm vào thông báo lúc app đang chạy ngầm/mở
    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == _quickPastePayload) {
          quickPasteTrigger.value++;
        }
      },
    );

    // Kiểm tra xem app có được mở lên từ trạng thái tắt hẳn thông qua thông báo Dán Nhanh không
    final NotificationAppLaunchDetails? launchDetails = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse?.payload == _quickPastePayload) {
      quickPasteTrigger.value++;
    }

    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        'coc_timer_system_final_v2',
        AppStrings.schedule.channelName,
        description: AppStrings.schedule.channelDescription,
        importance: Importance.max,
        playSound: true,
        sound: RawResourceAndroidNotificationSound('ring1'),
      );
      await androidImpl?.createNotificationChannel(channel);

      // Tạo kênh riêng hoàn toàn im lặng cho Thông báo Dán Nhanh
      final AndroidNotificationChannel quickPasteChannel = AndroidNotificationChannel(
        'coc_timer_quick_paste_channel',
        AppStrings.schedule.quickPasteChannelName,
        description: AppStrings.schedule.channelQuickPasteDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await androidImpl?.createNotificationChannel(quickPasteChannel);
    }

    // Khôi phục trạng thái Dán Nhanh nếu lần trước người dùng đang bật
    final prefs = await SharedPreferences.getInstance();
    isQuickPasteActive = prefs.getBool('quick_paste_enabled') ?? false;
    if (isQuickPasteActive) {
      await showQuickPasteNotification();
    }
  }

  // BẬT/CẬP NHẬT THÔNG BÁO DÁN NHANH
  static Future<void> showQuickPasteNotification({String? customStatus}) async {
    isQuickPasteActive = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quick_paste_enabled', true);

    final String title = AppStrings.schedule.quickPasteNotificationTitle;
    final String body = customStatus ?? AppStrings.schedule.quickPasteNotificationBody;

    final androidDetails = AndroidNotificationDetails(
      'coc_timer_quick_paste_channel',
      AppStrings.schedule.quickPasteChannelName,
      channelDescription: AppStrings.schedule.channelQuickPasteDesc,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      playSound: false,
      enableVibration: false,
      visibility: NotificationVisibility.public,
      icon: 'ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(presentSound: false);
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      id: _quickPasteNotificationId,
      title: title,
      body: body,
      notificationDetails: details,
      payload: _quickPastePayload,
    );
  }

  // TẮT THÔNG BÁO DÁN NHANH
  static Future<void> cancelQuickPasteNotification() async {
    isQuickPasteActive = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('quick_paste_enabled', false);
    await _notificationsPlugin.cancel(id: _quickPasteNotificationId);
  }

  static Future<void> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      bool hasPermission = await androidImpl?.areNotificationsEnabled() ?? false;

      if (!hasPermission) {
        final bool? granted = await androidImpl?.requestNotificationsPermission();
        hasPermission = granted ?? false;
      }

      await androidImpl?.requestExactAlarmsPermission();

      if (hasPermission) {
        final prefs = await SharedPreferences.getInstance();
        final bool hasWelcomed = prefs.getBool('has_sent_welcome') ?? false;

        if (!hasWelcomed) {
          Future.delayed(const Duration(seconds: 2), () async {
            await _fireWelcomeNotification();
            await prefs.setBool('has_sent_welcome', true);
          });
        }
      }

      try {
        final bool canUseFsi = await _fsiChannel.invokeMethod('canUseFullScreenIntent');
        if (canUseFsi != true) {
          debugPrint(AppStrings.schedule.debugFsiPermissionMissing);
          await _fsiChannel.invokeMethod('openFullScreenIntentSettings');
        }
      } on PlatformException catch (e) {
        debugPrint(AppStrings.format(
            AppStrings.schedule.debugFsiPermissionCheckError, {'e': e.toString()}));
      }

      try {
        final bool isIgnoring = await _fsiChannel.invokeMethod('isIgnoringBatteryOptimizations');
        if (isIgnoring != true) {
          debugPrint(AppStrings.schedule.debugBatteryOptimizationActive);
          await _fsiChannel.invokeMethod('requestIgnoreBatteryOptimizations');
        }
      } on PlatformException catch (e) {
        debugPrint(AppStrings.format(
            AppStrings.schedule.debugBatteryPermissionCheckError, {'e': e.toString()}));
      }
    }
  }

  static int _generateUniqueId(String instanceId) {
    int hash = 5381;
    for (int i = 0; i < instanceId.length; i++) {
      hash = ((hash << 5) + hash) + instanceId.codeUnitAt(i);
    }
    return hash.abs() & 0x7FFFFFFF;
  }

  static Future<void> syncItemSchedule(String villageTag, String villageName, UpgradeItem item) async {
    final int id = _generateUniqueId(item.instanceId);

    await _cancelSystemNotification(id);
    await _cancelFullScreenAlarm(id);

    if (item.realEta.isBefore(DateTime.now())) return;

    DateTime triggerTime = item.realEta.subtract(Duration(minutes: RuleManager.preAlarmMinutes));
    if (triggerTime.isBefore(DateTime.now())) {
      triggerTime = DateTime.now().add(const Duration(seconds: 2));
    }

    switch (item.alarmType) {
      case AlarmType.none:
        debugPrint(AppStrings.format(AppStrings.schedule.debugAlarmDisabledLog,
            {'id': id.toString(), 'instanceId': item.instanceId}));
        break;
      case AlarmType.system:
        await _scheduleSystemNotification(
            id, triggerTime, "${item.typeString} (Lv.${item.level})", villageTag, villageName);
        debugPrint(AppStrings.format(AppStrings.schedule.debugSystemNotificationScheduledLog,
            {'id': id.toString(), 'realEta': triggerTime.toString()}));
        break;
      case AlarmType.fullscreen:
        await _scheduleFullScreenAlarm(
            id, triggerTime, "${item.typeString} (Lv.${item.level})", villageTag, villageName);
        debugPrint(AppStrings.format(AppStrings.schedule.debugFullscreenAlarmScheduledLog,
            {'id': id.toString(), 'realEta': triggerTime.toString()}));
        break;
    }
  }

  static Future<void> cancelAllForVillage(VillageData village) async {
    void cancelList(List<UpgradeItem> items) {
      for (var item in items) {
        final int id = _generateUniqueId(item.instanceId);
        _cancelSystemNotification(id);
        _cancelFullScreenAlarm(id);
      }
    }
    cancelList(village.buildersItems);
    cancelList(village.petItems);
    cancelList(village.labItems);
    cancelList(village.builders2Items);
    cancelList(village.lab2Items);
  }

  static Future<void> _fireWelcomeNotification() async {
    final androidDetails = AndroidNotificationDetails(
      'coc_timer_system_final_v2',
      AppStrings.schedule.channelName,
      channelDescription: AppStrings.schedule.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ring1'),
      audioAttributesUsage: AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(presentSound: true, sound: 'ring1.mp3');
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.show(
      id: 8888,
      title: AppStrings.schedule.welcomeNotificationTitle,
      body: AppStrings.schedule.welcomeNotificationBody,
      notificationDetails: details,
    );
  }

  static Future<void> _scheduleSystemNotification(
      int id, DateTime time, String itemName, String tag, String villageName) async {
    final androidDetails = AndroidNotificationDetails(
      'coc_timer_system_final_v2',
      AppStrings.schedule.channelName,
      channelDescription: AppStrings.schedule.channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('ring1'),
      audioAttributesUsage: AudioAttributesUsage.notification,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      icon: 'ic_notification',
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: 'ring1.mp3',
    );
    final details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: AppStrings.schedule.notificationTitle,
      body: AppStrings.format(AppStrings.schedule.notificationBody, {
        'itemName': itemName,
        'villageName': villageName,
        'tag': tag,
      }),
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  static Future<void> _cancelSystemNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> _scheduleFullScreenAlarm(
      int id, DateTime time, String itemName, String tag, String villageName) async {
    final alarmSettings = AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: 'assets/ring.mp3',
      loopAudio: true,
      vibrate: true,
      androidFullScreenIntent: true,
      volumeSettings: const VolumeSettings.fixed(
        volume: null,
      ),
      notificationSettings: NotificationSettings(
        title: AppStrings.schedule.alarmNotificationTitle,
        body: AppStrings.format(AppStrings.schedule.alarmNotificationBody, {
          'itemName': itemName,
          'villageName': villageName,
          'tag': tag,
        }),
        stopButton: AppStrings.schedule.alarmStopButton,
        icon: 'ic_notification',
      ),
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  static Future<void> _cancelFullScreenAlarm(int id) async {
    await Alarm.stop(id);
  }

  static Future<void> handleAlarmDismiss() async {
    if (Platform.isAndroid) {
      try {
        await _fsiChannel.invokeMethod('handleAlarmDismiss');
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.schedule.debugAlarmDismissError, {'e': e.toString()}));
      }
    }
  }

  static Future<void> allowScreenTimeout() async {
    if (Platform.isAndroid) {
      try {
        await _fsiChannel.invokeMethod('allowScreenTimeout');
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.schedule.debugScreenTimeoutError, {'e': e.toString()}));
      }
    }
  }

  static Future<void> enableAlarmMode() async {
    if (Platform.isAndroid) {
      try {
        await _fsiChannel.invokeMethod('enableAlarmMode');
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.schedule.debugEnableAlarmModeError, {'e': e.toString()}));
      }
    }
  }

  static Future<void> disableAlarmMode() async {
    if (Platform.isAndroid) {
      try {
        await _fsiChannel.invokeMethod('disableAlarmMode');
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.schedule.debugDisableAlarmModeError, {'e': e.toString()}));
      }
    }
  }

  static Future<void> syncWarSchedule(String clanTag, String clanName, DateTime endTime) async {
    final int preId = _generateUniqueId("WAR_PRE_$clanTag");
    final int endId = _generateUniqueId("WAR_END_$clanTag");

    await _cancelSystemNotification(preId);
    await _cancelFullScreenAlarm(preId);
    await _cancelSystemNotification(endId);
    await _cancelFullScreenAlarm(endId);

    if (endTime.isBefore(DateTime.now())) return;

    if (RuleManager.warPreAlarmEnabled) {
      DateTime preTime = endTime.subtract(Duration(minutes: RuleManager.warPreAlarmMinutes));
      if (preTime.isBefore(DateTime.now())) {
        preTime = DateTime.now().add(const Duration(seconds: 5));
      }

      if (RuleManager.warPreAlarmType == AlarmType.system) {
        await _scheduleSystemNotification(
            preId, preTime, AppStrings.schedule.warPreAlarmTitle, clanTag, clanName);
      } else if (RuleManager.warPreAlarmType == AlarmType.fullscreen) {
        await _scheduleFullScreenAlarm(
            preId, preTime, AppStrings.schedule.warPreAlarmTitle, clanTag, clanName);
      }
    }

    if (RuleManager.warEndAlarmEnabled) {
      if (endTime.isAfter(DateTime.now())) {
        if (RuleManager.warEndAlarmType == AlarmType.system) {
          await _scheduleSystemNotification(
              endId, endTime, AppStrings.schedule.warEndAlarmTitle, clanTag, clanName);
        } else if (RuleManager.warEndAlarmType == AlarmType.fullscreen) {
          await _scheduleFullScreenAlarm(
              endId, endTime, AppStrings.schedule.warEndAlarmTitle, clanTag, clanName);
        }
      }
    }
  }

  static Future<void> cancelWarSchedule(String clanTag) async {
    final int preId = _generateUniqueId("WAR_PRE_$clanTag");
    final int endId = _generateUniqueId("WAR_END_$clanTag");

    await _cancelSystemNotification(preId);
    await _cancelFullScreenAlarm(preId);
    await _cancelSystemNotification(endId);
    await _cancelFullScreenAlarm(endId);

    debugPrint(AppStrings.format(AppStrings.schedule.debugCancelledWarAlarms, {'clanTag': clanTag}));
  }
}