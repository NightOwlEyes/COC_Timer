import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/village_models.dart';
import '../utils/app_strings.dart';
import '../utils/game_data.dart';
import '../utils/rule_manager.dart';
import '../utils/village_manager.dart';
import 'coc_api_service.dart';
import 'schedule_service.dart';

/// Entrypoint chạy ngầm khi AI agent gửi lệnh ADB lúc ứng dụng đang tắt.
@pragma('vm:entry-point')
void aiCommandEntrypoint() {
  WidgetsFlutterBinding.ensureInitialized();
  AiCommandService.registerHeadlessChannel();
}

/// Dịch vụ xử lý lệnh tự động hoá từ AI agent thông qua ADB (MethodChannel `coctimer/ai_command`).
class AiCommandService {
  static const MethodChannel _channel = MethodChannel('coctimer/ai_command');
  static const GameDataEn _gameDataEn = GameDataEn();

  static VillageManager? _foregroundVm;
  static Future<void>? _foregroundReadyFuture;
  static void Function(String statusMsg)? _onForegroundUpdated;

  /// Gắn dịch vụ vào [VillageManager] đang chạy trên giao diện chính.
  static void attachForeground(
    VillageManager vm, {
    required Future<void> readyFuture,
    void Function(String statusMsg)? onDataUpdated,
  }) {
    _foregroundVm = vm;
    _foregroundReadyFuture = readyFuture;
    _onForegroundUpdated = onDataUpdated;

    _channel.setMethodCallHandler(_handleForegroundCall);
    _channel.invokeMethod('aiReady').catchError((_) => null);
  }

  /// Gỡ liên kết khi màn hình chính bị huỷ.
  static void detachForeground() {
    _foregroundVm = null;
    _foregroundReadyFuture = null;
    _onForegroundUpdated = null;
    _channel.setMethodCallHandler(null);
  }

  /// Đăng ký handler khi chạy ở FlutterEngine ngầm (app chưa mở).
  static void registerHeadlessChannel() {
    _channel.setMethodCallHandler(_handleHeadlessCall);
    _channel.invokeMethod('aiReady').catchError((_) => null);
  }

  static Future<String> _handleForegroundCall(MethodCall call) async {
    final vm = _foregroundVm;
    if (vm == null) {
      return jsonEncode({
        'success': false,
        'action': call.method,
        'error': 'Foreground VillageManager is not attached.',
      });
    }
    if (_foregroundReadyFuture != null) {
      await _foregroundReadyFuture;
    }

    final args = _normalizeArgs(call.arguments);
    final result = await _executeCommand(
      vm,
      call.method,
      args,
      isForeground: true,
    );
    return jsonEncode(result);
  }

  static Future<String> _handleHeadlessCall(MethodCall call) async {
    try {
      await AppStrings.initLanguage();
      await RuleManager.init();

      final args = _normalizeArgs(call.arguments);
      final bool syncAlarms = args['sync_alarms'] != false;
      if (syncAlarms) {
        try {
          await ScheduleService.init();
        } catch (e) {
          debugPrint("AI headless ScheduleService init error: $e");
        }
      }

      final vm = VillageManager();
      await vm.loadSavedData();

      final result = await _executeCommand(
        vm,
        call.method,
        args,
        isForeground: false,
      );
      return jsonEncode(result);
    } catch (e) {
      return jsonEncode({
        'success': false,
        'action': call.method,
        'error': e.toString(),
      });
    }
  }

  static Map<String, dynamic> _normalizeArgs(dynamic raw) {
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _executeCommand(
    VillageManager vm,
    String method,
    Map<String, dynamic> args, {
    required bool isForeground,
  }) async {
    switch (method) {
      case 'importJson':
        return _handleImportJson(vm, args, isForeground: isForeground);
      case 'queryUpgrades':
        return _handleQueryUpgrades(vm, args);
      default:
        return {
          'success': false,
          'action': method,
          'error': 'Unsupported AI command: $method',
        };
    }
  }

  static Future<Map<String, dynamic>> _handleImportJson(
    VillageManager vm,
    Map<String, dynamic> args, {
    required bool isForeground,
  }) async {
    final String rawJson = (args['json'] ?? '').toString().trim();
    if (rawJson.isEmpty) {
      return {
        'success': false,
        'action': 'import_json',
        'error': 'Missing JSON input. Pass --es file, --es base64, or --es json.',
      };
    }

    final bool syncAlarms = args['sync_alarms'] != false;
    final String? customName = args['name']?.toString().trim();

    try {
      final res = await vm.importVillageJson(rawJson, syncWithOS: syncAlarms);
      String finalStatus = res.statusMsg;

      if (res.isNewVillage) {
        String? resolvedName = (customName != null && customName.isNotEmpty) ? customName : null;
        if (resolvedName == null) {
          try {
            resolvedName = await CocApiService.fetchPlayerName(res.tag)
                .timeout(const Duration(milliseconds: 2500));
          } catch (_) {
            resolvedName = null;
          }
        }
        final String fallbackName = (resolvedName != null && resolvedName.isNotEmpty)
            ? resolvedName
            : res.tag;
        finalStatus = await vm.finalizeNewVillage(
          res.tag,
          {
            'name': fallbackName,
            'home': true,
            'builder': true,
          },
          fallbackName,
          syncWithOS: syncAlarms,
        );
      } else if (customName != null && customName.isNotEmpty) {
        vm.villageNames[res.tag] = customName;
        await vm.saveDataToPrefs();
      }

      if (isForeground) {
        _onForegroundUpdated?.call(finalStatus);
      }

      final now = DateTime.now();
      final village = vm.villages[res.tag];
      if (village == null) {
        return {
          'success': false,
          'action': 'import_json',
          'error': 'Village parsed but not found in state.',
        };
      }

      final String vName = vm.villageNames[res.tag] ?? res.tag;
      final report = buildVillageReport(
        village,
        vName,
        trackHome: vm.trackHome[res.tag] ?? true,
        trackBuilder: vm.trackBuilder[res.tag] ?? true,
        now: now,
      );

      return {
        'success': true,
        'action': 'import_json',
        'is_new_village': res.isNewVillage,
        'status_message': finalStatus,
        'queried_at_local': _formatLocalDateTime(now),
        'queried_at_iso': now.toUtc().toIso8601String(),
        'queried_timestamp': now.millisecondsSinceEpoch ~/ 1000,
        'villages_count': vm.villages.length,
        ...report,
      };
    } catch (e) {
      return {
        'success': false,
        'action': 'import_json',
        'error': 'Invalid village JSON or import failure: $e',
      };
    }
  }

  static Map<String, dynamic> _handleQueryUpgrades(
    VillageManager vm,
    Map<String, dynamic> args,
  ) {
    final now = DateTime.now();
    vm.tickCleanup(now);

    final String? filterTag = args['tag']?.toString().trim().toUpperCase();
    final List<Map<String, dynamic>> villageReports = [];

    for (final entry in vm.villages.entries) {
      if (filterTag != null && filterTag.isNotEmpty && entry.key.toUpperCase() != filterTag) {
        continue;
      }
      final v = entry.value;
      villageReports.add(
        buildVillageReport(
          v,
          vm.villageNames[entry.key] ?? entry.key,
          trackHome: vm.trackHome[entry.key] ?? true,
          trackBuilder: vm.trackBuilder[entry.key] ?? true,
          now: now,
        ),
      );
    }

    return {
      'success': true,
      'action': 'query_upgrades',
      'queried_at_local': _formatLocalDateTime(now),
      'queried_at_iso': now.toUtc().toIso8601String(),
      'queried_timestamp': now.millisecondsSinceEpoch ~/ 1000,
      'villages_count': villageReports.length,
      'villages': villageReports,
    };
  }

  /// Tạo báo cáo JSON chi tiết các công trình/nghiên cứu đang nâng và thời gian hoàn tất.
  static Map<String, dynamic> buildVillageReport(
    VillageData v,
    String villageName, {
    required bool trackHome,
    required bool trackBuilder,
    required DateTime now,
  }) {
    final activeHomeBuilders = v.activeBuilders;
    final activeHomeLab = v.activeLab;
    final activeHomePets = v.activePets;
    final activeNightBuilders = v.activeBuilders2;
    final activeNightLab = v.activeLab2;

    final int homeBTotal = v.totalBuilders;
    final int homeLTotal = v.totalLab;
    final int homePTotal = activeHomePets.length > 1 ? activeHomePets.length : 1;
    final int nightBTotal = v.totalBuilders2;
    final int nightLTotal = v.totalLab2;

    final List<Map<String, dynamic>> upgrades = [];

    void addItems(List<UpgradeItem> items, String base, String category) {
      for (final item in items) {
        final int remSec = item.realEta.difference(now).inSeconds.clamp(0, 999999999);
        upgrades.add({
          'base': base,
          'category': category,
          'data_id': item.dataId,
          'name': AppStrings.gameData.getName(item.dataId),
          'name_en': _gameDataEn.getName(item.dataId),
          'level': item.level,
          'is_extra': item.isExtra,
          'finish_at_local': _formatLocalDateTime(item.realEta),
          'finish_at_iso': item.realEta.toUtc().toIso8601String(),
          'finish_timestamp': item.realEta.millisecondsSinceEpoch ~/ 1000,
          'remaining_seconds': remSec,
          'remaining_formatted': _formatDuration(remSec),
          'alarm_type': item.alarmType.name,
        });
      }
    }

    addItems(activeHomeBuilders, 'home', 'builder');
    addItems(activeHomeLab, 'home', 'lab');
    addItems(activeHomePets, 'home', 'pet');
    addItems(activeNightBuilders, 'builder_base', 'builder');
    addItems(activeNightLab, 'builder_base', 'lab');

    upgrades.sort((a, b) => (a['finish_timestamp'] as int).compareTo(b['finish_timestamp'] as int));

    int calcBoostRemaining(int boostSeconds) {
      if (boostSeconds <= 0) return 0;
      final end = DateTime.fromMillisecondsSinceEpoch((v.timestamp + boostSeconds) * 1000);
      final diff = end.difference(now).inSeconds;
      return diff > 0 ? diff : 0;
    }

    return {
      'tag': v.tag,
      'name': villageName,
      'data_timestamp': v.timestamp,
      'track_home': trackHome,
      'track_builder': trackBuilder,
      'summary': {
        'home': {
          'builders': '${activeHomeBuilders.length}/$homeBTotal',
          'builders_busy': activeHomeBuilders.length,
          'builders_total': homeBTotal,
          'builders_idle': (homeBTotal - activeHomeBuilders.length).clamp(0, homeBTotal),
          'lab': '${activeHomeLab.length}/$homeLTotal',
          'lab_busy': activeHomeLab.length,
          'lab_total': homeLTotal,
          'lab_idle': (homeLTotal - activeHomeLab.length).clamp(0, homeLTotal),
          'pets': '${activeHomePets.length}/$homePTotal',
          'pets_busy': activeHomePets.length,
          'pets_total': homePTotal,
          'pets_idle': (homePTotal - activeHomePets.length).clamp(0, homePTotal),
        },
        'builder_base': {
          'builders': '${activeNightBuilders.length}/$nightBTotal',
          'builders_busy': activeNightBuilders.length,
          'builders_total': nightBTotal,
          'builders_idle': (nightBTotal - activeNightBuilders.length).clamp(0, nightBTotal),
          'lab': '${activeNightLab.length}/$nightLTotal',
          'lab_busy': activeNightLab.length,
          'lab_total': nightLTotal,
          'lab_idle': (nightLTotal - activeNightLab.length).clamp(0, nightLTotal),
        },
      },
      'boosts_remaining_seconds': {
        'builder_potion': calcBoostRemaining(v.boosts.builderBoost),
        'lab_potion': calcBoostRemaining(v.boosts.labBoost),
        'pet_potion': calcBoostRemaining(v.boosts.petBoost),
        'builder_bite': calcBoostRemaining(v.boosts.builderConsumable),
        'study_soup': calcBoostRemaining(v.boosts.labConsumable),
        'clocktower': calcBoostRemaining(v.boosts.clocktowerBoost),
        'builder_apprentice': calcBoostRemaining(v.boosts.builderHelperTimer),
        'lab_assistant': calcBoostRemaining(v.boosts.labHelperTimer),
      },
      'next_completion': upgrades.isNotEmpty ? upgrades.first : null,
      'upgrades': upgrades,
    };
  }

  static String _formatLocalDateTime(DateTime dt) {
    final local = dt.toLocal();
    String p2(int n) => n.toString().padLeft(2, '0');
    return '${local.year}-${p2(local.month)}-${p2(local.day)} ${p2(local.hour)}:${p2(local.minute)}:${p2(local.second)}';
  }

  static String _formatDuration(int totalSeconds) {
    if (totalSeconds <= 0) return '0s';
    final int days = totalSeconds ~/ 86400;
    final int hours = (totalSeconds % 86400) ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    if (days > 0) return '${days}d ${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${seconds}s';
  }
}
