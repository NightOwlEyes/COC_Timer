import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:alarm/alarm.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'dart:io';
import '../models/village_models.dart';

/// File này đóng vai trò là Cầu nối (Wrapper) giữa App của bạn và Hệ điều hành.
class ScheduleService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const MethodChannel _fsiChannel = MethodChannel('coctimer/fsi_permission');

  /// Khởi tạo các package (Được gọi một lần duy nhất ở main.dart)
  static Future<void> init() async {
    // Khởi tạo Alarm cho báo thức toàn màn hình
    await Alarm.init();

    // Khởi tạo Timezone
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    // BẬT LẠI ICON TỐI GIẢN TỪ THƯ MỤC DRAWABLE
    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('ic_notification');
    const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
    const InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _notificationsPlugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      // Danh sách các Channel ID cũ đã từng sử dụng và cần loại bỏ
      final oldChannels = [
        'coc_timer_channel_v5',
        'coc_timer_channel_v6',
        'coc_timer_channel_v7',
        'coc_timer_channel_v8',
        'coc_timer_channel_v9',
        'coc_timer_channel_v10'
      ];

      for (String channelId in oldChannels) {
        try {
          // SỬA LỖI TẠI ĐÂY: Thêm named parameter "channelId:"
          await androidImpl?.deleteNotificationChannel(channelId: channelId);
          debugPrint("Đã xóa dọn dẹp channel cũ: $channelId");
        } catch (e) {
          debugPrint("Không thể xóa channel $channelId: $e");
        }
      }
    }
  }

  /// Hàm xin quyền thông báo và báo thức (Dành cho Android 13+)
  static Future<void> checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidImpl = _notificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await androidImpl?.requestNotificationsPermission();
      await androidImpl?.requestExactAlarmsPermission();

      // Kiểm tra & xin quyền Full Screen Intent (bắt buộc từ Android 14+)
      try {
        final bool canUseFsi = await _fsiChannel.invokeMethod('canUseFullScreenIntent');
        if (canUseFsi != true) {
          debugPrint("Chưa có quyền Full Screen Intent, mở màn hình cài đặt...");
          await _fsiChannel.invokeMethod('openFullScreenIntentSettings');
        }
      } on PlatformException catch (e) {
        debugPrint('Lỗi kiểm tra FSI permission: $e');
      }

      // THÊM MỚI: Yêu cầu cấp quyền bỏ qua tối ưu hóa Pin (Chống Delay)
      try {
        final bool isIgnoring = await _fsiChannel.invokeMethod('isIgnoringBatteryOptimizations');
        if (isIgnoring != true) {
          debugPrint("Đang bị tối ưu hóa pin, yêu cầu cấp quyền Bỏ qua...");
          await _fsiChannel.invokeMethod('requestIgnoreBatteryOptimizations');
        }
      } on PlatformException catch (e) {
        debugPrint('Lỗi kiểm tra Battery permission: $e');
      }
    }
  }

  /// SỬA LỖI BUG "BÁO THỨC MA": Tạo ID dạng số nguyên (int) CỐ ĐỊNH thay vì dùng .hashCode
  static int _generateUniqueId(String instanceId) {
    int hash = 5381;
    for (int i = 0; i < instanceId.length; i++) {
      hash = ((hash << 5) + hash) + instanceId.codeUnitAt(i);
    }
    // Trả về số nguyên dương 32-bit (Do Local Notification chỉ nhận ID 32-bit)
    return hash.abs() & 0x7FFFFFFF;
  }

  /// Cập nhật (hoặc xóa) lịch hẹn cho MỘT công trình cụ thể
  static Future<void> syncItemSchedule(String villageTag, String villageName, UpgradeItem item) async {
    final int id = _generateUniqueId(item.instanceId);

    // Xóa tất cả các lịch hẹn cũ (của cả 2 chế độ) ứng với ID này trước cho sạch
    await _cancelSystemNotification(id);
    await _cancelFullScreenAlarm(id);

    // Bỏ qua nếu thời gian đã ở trong quá khứ
    if (item.realEta.isBefore(DateTime.now())) return;

    // Lên lịch mới tùy theo chế độ
    switch (item.alarmType) {
      case AlarmType.none:
        debugPrint("Đã tắt báo thức cho ID: $id (Chuỗi gốc: ${item.instanceId})");
        break;
      case AlarmType.system:
        await _scheduleSystemNotification(id, item.realEta, "${item.typeString} ${item.dataId}", villageTag, villageName);
        debugPrint("Hẹn THÔNG BÁO HỆ THỐNG cho ID: $id vào lúc ${item.realEta}");
        break;
      case AlarmType.fullscreen:
        await _scheduleFullScreenAlarm(id, item.realEta, "${item.typeString} ${item.dataId}", villageTag, villageName);
        debugPrint("Hẹn BÁO THỨC TOÀN MÀN HÌNH cho ID: $id vào lúc ${item.realEta}");
        break;
    }
  }

  /// HỦY TOÀN BỘ lịch hẹn của một Làng (Khi người dùng bấm xóa làng)
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
  }

  // ===========================================================================
  // KHU VỰC THỰC THI OS
  // ===========================================================================

  static Future<void> _scheduleSystemNotification(int id, DateTime time, String itemName, String tag, String villageName) async {
    // TĂNG CHANNEL LÊN V11 VÀ ÉP KIỂU ALARM ĐỂ CHỐNG DELAY KHI ĐỌC FILE TỪ Ổ CỨNG
    const androidDetails = AndroidNotificationDetails(
      'coc_timer_channel_v11',
      'COC Timer Notifications',
      channelDescription: 'Thông báo khi nâng cấp hoàn thành',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('ring1'),

      // 2 DÒNG CỐT LÕI ĐỂ CHỐNG DELAY KHI DÙNG CHUÔNG CUSTOM:
      audioAttributesUsage: AudioAttributesUsage.alarm, // Ép dùng luồng âm thanh Báo thức (ưu tiên cao nhất)
      category: AndroidNotificationCategory.alarm,      // Khai báo với OS đây là báo thức, không phải thông báo rác
    );
    const iosDetails = DarwinNotificationDetails(
      presentSound: true,
      sound: 'ring1.mp3',
    );
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: '■ TÍN HIỆU HOÀN TẤT ■',
      body: '$itemName tại $villageName ($tag) đã hoàn thành.',
      scheduledDate: tz.TZDateTime.from(time, tz.local),
      notificationDetails: details,
      // GIỮ NGUYÊN ALARM CLOCK
      androidScheduleMode: AndroidScheduleMode.alarmClock,
    );
  }

  static Future<void> _cancelSystemNotification(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  static Future<void> _scheduleFullScreenAlarm(int id, DateTime time, String itemName, String tag, String villageName) async {
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
        title: '■ TÍN HIỆU HOÀN TẤT ■',
        body: 'Hạng mục: $itemName\nLàng: $villageName\n(Mã: $tag)',
        stopButton: 'ĐÓNG CẢNH BÁO',
        icon: 'ic_notification',
      ),
    );
    await Alarm.set(alarmSettings: alarmSettings);
  }

  static Future<void> _cancelFullScreenAlarm(int id) async {
    await Alarm.stop(id);
  }

  /// Xử lý UX: Đưa app xuống nền nếu người dùng tắt báo thức lúc đang ở màn hình khóa
  static Future<void> handleAlarmDismiss() async {
    if (Platform.isAndroid) {
      try {
        await _fsiChannel.invokeMethod('handleAlarmDismiss');
      } catch (e) {
        debugPrint('Lỗi handleAlarmDismiss: $e');
      }
    }
  }
}