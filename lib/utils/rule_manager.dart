import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/village_models.dart';

class TimeRule {
  int startMins; // Tính bằng phút từ 00:00 (VD: 01:30 = 90)
  int endMins;   // Tính bằng phút từ 00:00
  final AlarmType action;

  TimeRule({required this.startMins, required this.endMins, required this.action});

  Map<String, dynamic> toJson() => {
    'start': startMins,
    'end': endMins,
    'action': action.name,
  };

  factory TimeRule.fromJson(Map<String, dynamic> json) {
    return TimeRule(
      startMins: json['start'],
      endMins: json['end'],
      action: AlarmType.values.firstWhere((e) => e.name == json['action'], orElse: () => AlarmType.none),
    );
  }

  // Chuyển đổi số phút sang chuỗi giờ phút (VD: 90 -> "01:30")
  String getTimeString(int mins) {
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return "$h:$m";
  }
}

class RuleManager {
  static List<TimeRule> activeRules = [];

  // LƯU TRẠNG THÁI BẬT/TẮT [X] CỦA TỪNG KHỐI
  static Map<AlarmType, bool> groupEnabled = {
    AlarmType.none: true,
    AlarmType.system: true,
    AlarmType.fullscreen: true,
  };

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstTime = !prefs.containsKey('rule_time_ranges');

    if (isFirstTime) {
      // THIẾT LẬP MẶC ĐỊNH THEO YÊU CẦU MỚI
      activeRules = [
        TimeRule(startMins: 1320, endMins: 360, action: AlarmType.system), // 22:00 -> 06:00
        TimeRule(startMins: 0, endMins: 1439, action: AlarmType.none),     // 00:00 -> 23:59
      ];
      groupEnabled = {
        AlarmType.system: true,
        AlarmType.none: false, // Tắt mặc định
      };
      await save();
    } else {
      String? rulesJson = prefs.getString('rule_time_ranges');
      if (rulesJson != null) {
        try {
          final List<dynamic> decoded = jsonDecode(rulesJson);
          activeRules = decoded.map((e) => TimeRule.fromJson(e)).toList();
        } catch (e) {
          activeRules = [];
        }
      }

      String? enabledJson = prefs.getString('rule_group_enabled');
      if (enabledJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(enabledJson);
          decoded.forEach((key, value) {
            AlarmType type = AlarmType.values.firstWhere((e) => e.name == key, orElse: () => AlarmType.system);
            groupEnabled[type] = value == true;
          });
        } catch (e) {
          // Bỏ qua lỗi parse Json nếu dữ liệu bị hỏng
        }
      }
    }
  }

  static Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> rulesJson = activeRules.map((r) => r.toJson()).toList();
    await prefs.setString('rule_time_ranges', jsonEncode(rulesJson));

    final Map<String, dynamic> enabledJson = {};
    groupEnabled.forEach((key, value) {
      enabledJson[key.name] = value;
    });
    await prefs.setString('rule_group_enabled', jsonEncode(enabledJson));
  }

  // THÊM MỚI: Hàm trả về danh sách ĐÍCH DANH các quy tắc gây ra lỗi đụng độ
  static List<TimeRule> getConflictingRules(AlarmType targetGroup) {
    List<TimeRule> conflicts = [];
    List<TimeRule> targetRules = activeRules.where((r) => r.action == targetGroup).toList();
    List<TimeRule> otherActiveRules = activeRules.where((r) => r.action != targetGroup && groupEnabled[r.action] == true).toList();

    for (var tRule in targetRules) {
      for (var oRule in otherActiveRules) {
        if (_overlap(tRule.startMins, tRule.endMins, oRule.startMins, oRule.endMins)) {
          conflicts.add(tRule);
          break; // Đã tìm thấy đụng độ cho rule này, chuyển sang rule tiếp theo
        }
      }
    }
    return conflicts;
  }

  // SỬA: Trả về bool để báo cho UI biết có Bật thành công hay không
  static Future<bool> toggleGroup(AlarmType type, bool isEnableTarget) async {
    if (isEnableTarget) {
      // NẾU MUỐN BẬT [X]: Kiểm tra xem có rule nào bị đụng độ không
      if (getConflictingRules(type).isNotEmpty) {
        return false; // Bị đụng độ, TỪ CHỐI BẬT!
      }
    }

    groupEnabled[type] = isEnableTarget;
    await save();
    return true;
  }

  static Future<void> removeRule(TimeRule rule) async {
    activeRules.remove(rule);
    await save();
  }

  static Future<void> updateRule(TimeRule rule, int newStart, int newEnd) async {
    rule.startMins = newStart;
    rule.endMins = newEnd;
    await save();
  }

  // SỬA: Thêm tham số targetAction để biết đang kiểm tra cho nhóm nào
  static bool hasOverlap(int startMins, int endMins, AlarmType targetAction, {TimeRule? excludeRule}) {
    for (var rule in activeRules) {
      if (excludeRule != null && rule == excludeRule) continue;

      // KIỂM TRA KHÁC NHÓM
      if (rule.action != targetAction) {
        // Nếu 1 trong 2 nhóm đang bị TẮT (Draft), thì cho phép nhập giờ đè lên nhau thoải mái!
        if (groupEnabled[targetAction] == false || groupEnabled[rule.action] == false) {
          continue;
        }
      }

      // KIỂM TRA CÙNG NHÓM (Hoặc cả 2 nhóm đều đang BẬT)
      if (_overlap(startMins, endMins, rule.startMins, rule.endMins)) {
        return true;
      }
    }
    return false;
  }

  static bool _overlap(int s1, int e1, int s2, int e2) {
    List<List<int>> i1 = s1 <= e1 ? [[s1, e1]] : [[s1, 1439], [0, e1]];
    List<List<int>> i2 = s2 <= e2 ? [[s2, e2]] : [[s2, 1439], [0, e2]];

    for (var a in i1) {
      for (var b in i2) {
        if (a[0] <= b[1] && b[0] <= a[1]) {
          return true;
        }
      }
    }
    return false;
  }

  static Future<bool> addRule(int startMins, int endMins, AlarmType action) async {
    // SỬA: Truyền action vào hàm kiểm tra
    if (hasOverlap(startMins, endMins, action)) return false;

    activeRules.add(TimeRule(startMins: startMins, endMins: endMins, action: action));
    await save();
    return true;
  }

  static AlarmType evaluateEta(DateTime realEta) {
    int targetMins = realEta.hour * 60 + realEta.minute;

    for (var rule in activeRules) {
      // KIỂM TRA CHỐT: Khối hành động này có đang bị Tắt [ ] hay không?
      if (groupEnabled[rule.action] != true) continue;

      bool isInside = false;
      if (rule.startMins <= rule.endMins) {
        isInside = (targetMins >= rule.startMins && targetMins <= rule.endMins);
      } else {
        isInside = (targetMins >= rule.startMins || targetMins <= rule.endMins);
      }

      if (isInside) return rule.action;
    }

    // NẾU KHÔNG TRÚNG QUY TẮC NÀO, LUÔN LUÔN LÀ BÁO THỨC
    return AlarmType.fullscreen;
  }
}