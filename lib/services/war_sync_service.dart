import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'coc_api_service.dart';
import '../utils/rule_manager.dart';
import 'schedule_service.dart';

// BẮT BUỘC PHẢI LÀ TOP-LEVEL FUNCTION ĐỂ WORKMANAGER GỌI ĐƯỢC KHI APP TẮT
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      debugPrint("Native Workmanager: Đang chạy task $task");

      // Khởi tạo các service cần thiết khi chạy ngầm
      await RuleManager.init();
      await ScheduleService.init();

      if (!RuleManager.warAutoSync) return Future.value(true);

      final prefs = await SharedPreferences.getInstance();
      final String? clansJson = prefs.getString('saved_online_clans');

      if (clansJson != null) {
        final List<dynamic> savedClans = jsonDecode(clansJson);

        for (var clan in savedClans) {
          String tag = clan['tag'];
          String name = clan['name'];

          // Tránh bị Rate Limit, delay nhẹ 1 giây giữa các Clan
          await Future.delayed(const Duration(seconds: 1));

          var result = await CocApiService.fetchWarData(tag);

          // Xử lý War Thường
          if (result['type'] == 'REGULAR' && result['data']['state'] == 'inWar') {
            DateTime endTime = _parseCocDate(result['data']['endTime']);
            await ScheduleService.syncWarSchedule(tag, name, endTime);
          }
          // Xử lý CWL (Lấy trận đang đánh hôm nay)
          else if (result['type'] == 'CWL' && result['currentWar'] != null) {
            DateTime endTime = _parseCocDate(result['currentWar']['endTime']);
            await ScheduleService.syncWarSchedule(tag, name, endTime);
          }
        }
      }
      return Future.value(true);
    } catch (err) {
      debugPrint("Lỗi Workmanager: $err");
      return Future.value(false);
    }
  });
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

class WarSyncService {
  static const String taskName = "syncWarDataTask";

  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher,
    );
  }

  static void registerPeriodicTask() {
    Workmanager().registerPeriodicTask(
      "war_sync_unique_id",
      taskName,
      frequency: const Duration(hours: 12), // Quét 12 tiếng 1 lần để tiết kiệm pin
      constraints: Constraints(
        networkType: NetworkType.connected, // Chỉ chạy khi có mạng
      ),
    );
  }

  static void cancelTask() {
    Workmanager().cancelByUniqueName("war_sync_unique_id");
  }
}