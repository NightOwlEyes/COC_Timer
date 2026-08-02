import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm/alarm.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'dart:io';

import '../models/village_models.dart';
import '../utils/village_parser.dart';
import '../widgets/terminal_frame_painter.dart';
import '../services/schedule_service.dart';

import '../widgets/alarm_popup.dart';
import '../widgets/village_card.dart';
import '../widgets/village_detail_dialog.dart'; // Import File Dialog mới

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

// BƯỚC 1: Thêm "with WidgetsBindingObserver" vào class State
class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  final TextEditingController _jsonController = TextEditingController();
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;
  Timer? _clockTimer;
  String _currentTime = "";

  Map<String, VillageData> _villages = {};
  Map<String, String> _savedRawJsons = {};
  final Map<String, String> _villageNames = {};

  final Map<String, String> _savedAlarmStates = {};
  final Set<int> _activePopups = {};

  String _parseStatus = "> CHỜ DỮ LIỆU JSON";

  bool _showRealEta = true; // Mặc định là true

  StreamSubscription? _alarmSubscription;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // LOGIC MỚI: Chỉ tắt quyền đè màn hình khóa nếu mở app bình thường (không có chuông)
    if (_activePopups.isEmpty) {
      ScheduleService.disableAlarmMode();
    }

    ScheduleService.checkAndRequestPermissions();

    // KHÔI PHỤC LẠI HÀM NÀY: Để app tải lại dữ liệu làng đã lưu (Sửa lỗi cảnh báo vàng)
    _loadSavedData();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        _showCursor.value = !_showCursor.value;
      }
    });
    _startClockTimer();

    // SỬA LỖI ALARM SET TẠI ĐÂY: Vòng lặp tách từng báo thức ra khỏi AlarmSet
    _alarmSubscription = Alarm.ringing.listen((alarmSet) {
      ScheduleService.enableAlarmMode();

      if (mounted) {
        for (final alarmSettings in alarmSet.alarms) {
          _showFullscreenPopup(alarmSettings);
        }
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Hủy đăng ký
    _alarmSubscription?.cancel();
        _cursorTimer?.cancel();
        _clockTimer?.cancel();
        _jsonController.dispose();
        _showCursor.dispose();
        super.dispose();
      }

      // BƯỚC 3: THÊM HÀM NÀY - Kiểm tra liên tục mỗi khi App được bật lên hoặc mở lại từ nền
      @override
      void didChangeAppLifecycleState(AppLifecycleState state) {
        if (state == AppLifecycleState.resumed) {
          if (_activePopups.isEmpty) {
            ScheduleService.disableAlarmMode(); // Ép hệ điều hành xóa cờ ngay lập tức
          } else {
            ScheduleService.enableAlarmMode();
          }
        }
      }

      void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      bool needsUpdate = false;

      for (var villageTag in _villages.keys.toList()) {
        final village = _villages[villageTag]!;

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

        int beforeBuilders = village.buildersItems.length;
        int beforePets = village.petItems.length;
        int beforeLab = village.labItems.length;

        village.buildersItems.removeWhere((item) => item.realEta.difference(now).isNegative);
        village.petItems.removeWhere((item) => item.realEta.difference(now).isNegative);
        village.labItems.removeWhere((item) => item.realEta.difference(now).isNegative);

        if (beforeBuilders != village.buildersItems.length ||
            beforePets != village.petItems.length ||
            beforeLab != village.labItems.length) {
          needsUpdate = true;
        }
      }

      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });

      if (needsUpdate) _saveDataToPrefs();
    });
  }

  void _showFullscreenPopup(AlarmSettings settings) {
    if (_activePopups.contains(settings.id)) return;
    _activePopups.add(settings.id);

    // BẬT CỜ: Ép hiển thị đè lên màn hình khóa vì đang có báo thức
    ScheduleService.enableAlarmMode();

    final globalContext = ScheduleService.navigatorKey.currentContext;
    if (globalContext == null) return;

    showDialog(
        context: globalContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlarmPopup(settings: settings);
        }
    ).then((_) {
      _activePopups.remove(settings.id);

      // TẮT CỜ: Trả lại trạng thái màn hình khóa bình thường khi đã tắt hết báo thức
      if (_activePopups.isEmpty) {
        ScheduleService.disableAlarmMode();
      }
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_villages_map');
    final savedNames = prefs.getString('saved_village_names');
    final savedAlarmJson = prefs.getString('saved_alarm_states');
    final savedShowEta = prefs.getBool('show_real_eta');

    if (savedShowEta != null) {
      _showRealEta = savedShowEta;
    }

    if (savedAlarmJson != null) {
      try {
        final Map<String, dynamic> decodedAlarms = jsonDecode(savedAlarmJson);
        decodedAlarms.forEach((key, value) {
          _savedAlarmStates[key] = value.toString();
        });
      } catch (e) {
        debugPrint("Lỗi load trạng thái báo thức: $e");
      }
    }

    if (savedData != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(savedData);
        Map<String, VillageData> loadedVillages = {};
        Map<String, String> loadedRaws = {};

        decoded.forEach((key, value) {
          try {
            final parsed = VillageParser.parse(value.toString());
            loadedVillages[key] = parsed;
            loadedRaws[key] = value.toString();
          } catch (e) {
            debugPrint("Lỗi parse $key: $e");
          }
        });

        if (mounted) {
          setState(() {
            _villages = loadedVillages;
            _savedRawJsons = loadedRaws;
            if (_villages.isNotEmpty) _parseStatus = "> ĐÃ TẢI DỮ LIỆU LƯU TRỮ";

            if (savedNames != null) {
              try {
                final Map<String, dynamic> decodedNames = jsonDecode(savedNames);
                decodedNames.forEach((key, value) {
                  _villageNames[key] = value.toString();
                });
              } catch (e) {
                debugPrint("Lỗi load tên làng: $e");
              }
            }
            for (var v in _villages.values) {
              _applySavedAlarmState(v, syncWithOS: false);
            }
          });
        }
      } catch (e) {
        debugPrint("Lỗi load: $e");
      }
    }
  }

  void _applySavedAlarmState(VillageData village, {bool syncWithOS = false}) {
    void apply(List<UpgradeItem> items) {
      for (var item in items) {
        String uniqueKey = item.instanceId;
        String? stateStr = _savedAlarmStates[uniqueKey];
        if (stateStr != null) {
          if (stateStr == "none") {
            item.alarmType = AlarmType.none;
          } else if (stateStr == "system") {
            item.alarmType = AlarmType.system;
          } else if (stateStr == "fullscreen") {
            item.alarmType = AlarmType.fullscreen;
          }
        }
        if (syncWithOS) {
          String vName = _villageNames[village.tag] ?? "Chưa đặt tên";
          ScheduleService.syncItemSchedule(village.tag, vName, item);
        }
      }
    }
    apply(village.buildersItems);
    apply(village.petItems);
    apply(village.labItems);
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
  }

  void _confirmDeleteVillage(String tag) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFFB54545), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("XÁC NHẬN XÓA", style: TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text("Bạn có chắc chắn muốn xóa dữ liệu JSON và báo thức của làng $tag không?\n(Tên làng vẫn sẽ được ghi nhớ)",
                  textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF444444)), shape: const RoundedRectangleBorder()),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text("HỦY", style: TextStyle(color: Color(0xFF888888))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFB54545), shape: const RoundedRectangleBorder()),
                      onPressed: () {
                        Navigator.pop(ctx);
                        _deleteVillage(tag);
                      },
                      child: const Text("XÓA NGAY", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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

    if (_villages.containsKey(tag)) {
      ScheduleService.cancelAllForVillage(_villages[tag]!);
    }

    setState(() {
      _villages.remove(tag);
      _savedRawJsons.remove(tag);
      // ĐÃ XÓA DÒNG LỆNH _villageNames.remove(tag); Ở ĐÂY ĐỂ APP KHÔNG QUÊN TÊN LÀNG NỮA
      _savedAlarmStates.removeWhere((key, value) => key.startsWith("${tag}_"));

      _parseStatus = _villages.isEmpty ? "> CHỜ DỮ LIỆU JSON" : "> ĐÃ XÓA LÀNG: $tag";
    });
    _saveDataToPrefs();
    _saveAlarmStatesToPrefs();
  }

  void _cycleAlarmForItem(String villageTag, UpgradeItem item) {
    setState(() {
      if (item.alarmType == AlarmType.system) {
        item.alarmType = AlarmType.fullscreen;
        _parseStatus = "> [BÁO THỨC] ${item.typeString.toUpperCase()} ${item.dataId}";
      } else if (item.alarmType == AlarmType.fullscreen) {
        item.alarmType = AlarmType.none;
        _parseStatus = "> [ĐÃ TẮT] ${item.typeString.toUpperCase()} ${item.dataId}";
      } else {
        item.alarmType = AlarmType.system;
        _parseStatus = "> [THÔNG BÁO] ${item.typeString.toUpperCase()} ${item.dataId}";
      }

      String uniqueKey = item.instanceId;
      _savedAlarmStates[uniqueKey] = item.alarmType.name;
      _saveAlarmStatesToPrefs();
    });

    String vName = _villageNames[villageTag] ?? "Chưa đặt tên";
    ScheduleService.syncItemSchedule(villageTag, vName, item);
  }

  void _cycleAlarmForGroup(String villageTag, String groupName, List<UpgradeItem> items) {
    if (items.isEmpty) return;
    setState(() {
      bool hasSystem = items.any((i) => i.alarmType == AlarmType.system);
      bool hasFullscreen = items.any((i) => i.alarmType == AlarmType.fullscreen);

      AlarmType targetType = AlarmType.system;
      if (hasSystem) {
        targetType = AlarmType.fullscreen;
      } else if (hasFullscreen) {
        targetType = AlarmType.none;
      }

      for (var item in items) {
        item.alarmType = targetType;
        String uniqueKey = item.instanceId;
        _savedAlarmStates[uniqueKey] = targetType.name;

        String vName = _villageNames[villageTag] ?? "Chưa đặt tên";
        ScheduleService.syncItemSchedule(villageTag, vName, item);
      }

      _parseStatus = targetType == AlarmType.none
          ? "> ĐÃ TẮT TOÀN BỘ NHÓM: $groupName"
          : "> ĐÃ ĐỔI NHÓM $groupName SANG CHẾ ĐỘ ${targetType.name.toUpperCase()}";

      _saveAlarmStatesToPrefs();
    });
  }

  void _processJson() async {
    final inputData = _jsonController.text.trim();
    if (inputData.isEmpty) return;
    FocusScope.of(context).unfocus();

    try {
      final parsed = VillageParser.parse(inputData);

      if (!_villageNames.containsKey(parsed.tag)) {
        String? newName = await _promptForVillageName(parsed.tag);
        if (newName != null && newName.trim().isNotEmpty) {
          _villageNames[parsed.tag] = newName.trim();
        } else {
          _villageNames[parsed.tag] = "NightOwlEyes";
        }
      }

      if (_villages.containsKey(parsed.tag)) {
        ScheduleService.cancelAllForVillage(_villages[parsed.tag]!);
        _savedAlarmStates.removeWhere((key, value) => key.startsWith("${parsed.tag}_"));
      }

      _applySavedAlarmState(parsed, syncWithOS: true);

      setState(() {
        _villages[parsed.tag] = parsed;
        _savedRawJsons[parsed.tag] = inputData;
        _parseStatus = "> ĐÃ CẬP NHẬT: ${_villageNames[parsed.tag]} (${parsed.tag})";
        _jsonController.clear();
      });
      _saveDataToPrefs();
    } catch (e) {
      setState(() {
        _parseStatus = "> LỖI! HÃY KIỂM TRA LẠI JSON";
      });
    }
  }

  Future<String?> _promptForVillageName(String tag) {
    TextEditingController tempController = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: RoundedRectangleBorder(side: const BorderSide(color: Color(0xFF4CAF50), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("PHÁT HIỆN LÀNG MỚI", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text("Mã: $tag", style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
              const SizedBox(height: 16),
              TextField(
                controller: tempController,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: const InputDecoration(
                  hintText: "Nhập tên làng (VD: Acc Chính)...",
                  hintStyle: TextStyle(color: Color(0xFF444444)),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF444444))),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4CAF50))),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: const RoundedRectangleBorder()),
                  onPressed: () => Navigator.pop(ctx, tempController.text),
                  child: const Text("LƯU TÊN & THÊM LÀNG", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      if (!mounted) return;
      setState(() {
        _jsonController.text = data.text!;
      });
      _processJson();
    }
  }

  void _openXiaomiSettings() async {
    if (Platform.isAndroid) {
      try {
        final intent = const AndroidIntent(
          action: 'miui.intent.action.APP_PERM_EDITOR',
          arguments: {'extra_pkgname': 'coctimer.nightowleyes.coctimer'},
        );
        await intent.launch();
        if (!mounted) return;
        setState(() {
          _parseStatus = "> HÃY TÍCH XANH TẤT CẢ!";
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _parseStatus = "> LỖI: CHỈ THIẾT BỊ XIAOMI/POCO";
        });
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
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 24),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildSecurityTag(),
                            const SizedBox(height: 30),
                            _buildLogoArea(),
                            const SizedBox(height: 30),
                            _buildVillagesList(),
                            const SizedBox(height: 30),
                            _buildInputField(),
                            const SizedBox(height: 20),
                            _buildSubmitButton(),
                            const SizedBox(height: 20),
                            _buildFooter(),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _parseStatus,
                            style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold),
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) {
                            return Opacity(
                              opacity: show ? 1.0 : 0.0,
                              child: const Text("█", style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
                            );
                          },
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

  Widget _buildHeader() {
    // THÊM 2 DÒNG NÀY: Tự động tính toán múi giờ hiện tại của thiết bị (VD: +7, +9, -4)
    final offset = DateTime.now().timeZoneOffset;
    final offsetString = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("COC.TIMER", style: TextStyle(color: Color(0xFF666666), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                setState(() => _showRealEta = !_showRealEta);
                _saveDataToPrefs();
              },
              child: Row(
                children: [
                  const Text("THỜI GIAN THỰC ", style: TextStyle(color: Color(0xFF888888), fontSize: 11)),
                  Text(
                    _showRealEta ? "[ BẬT ]" : "[ TẮT ]",
                    style: TextStyle(
                        color: _showRealEta ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                    ),
                  )
                ],
              ),
            )
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text("SERVER: LOCAL", style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
            const SizedBox(height: 4),
            // SỬA DÒNG NÀY: Dùng biến offsetString vừa tạo thay vì gõ chết "UTC+7"
            Text("$offsetString $_currentTime", style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTag() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: Color(0xFF8B2B2B), width: 1),
          bottom: BorderSide(color: Color(0xFF8B2B2B), width: 1),
        ),
        color: Color(0x228B2B2B),
      ),
      child: const Center(
        child: Text(
          "■  L À N G   C H Í N H  ■",
          style: TextStyle(color: Color(0xFFB54545), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
        ),
      ),
    );
  }

  Widget _buildLogoArea() {
    return Column(
      children: [
        Image.asset('assets/LogoMain.png', height: 80),
        const SizedBox(height: 16),
        const Text(
          "C O C   T I M E R",
          style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4.0),
        ),
        const SizedBox(height: 12),
        const Text(
          "ĐẾM NGƯỢC THỜI GIAN NÂNG",
          style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: const Color(0xFF333333))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Icon(Icons.diamond, size: 10, color: Color(0xFF666666)),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFF333333))),
          ],
        )
      ],
    );
  }

  Widget _buildVillagesList() {
    if (_villages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _villages.values.map((village) {
        return VillageCard(
          village: village,
          villageName: _villageNames[village.tag] ?? "",
          onDelete: () => _confirmDeleteVillage(village.tag),
          onTap: () {
            showDialog(
              context: context,
              builder: (ctx) => VillageDetailDialog(
                village: village,
                villageName: _villageNames[village.tag] ?? "",
                showRealEta: _showRealEta,
                onNameChanged: (newName) {
                  _villageNames[village.tag] = newName;
                  _saveDataToPrefs();
                  setState(() {});
                },
                onCycleGroup: (groupName, items) => _cycleAlarmForGroup(village.tag, groupName, items),
                onCycleItem: (item) => _cycleAlarmForItem(village.tag, item),
              ),
            );
          },
        );
      }).toList(),
    );
  }

  Widget _buildInputField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("V I L L A G E   D A T A", style: TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Stack(
          children: [
            TextField(
              controller: _jsonController,
              maxLines: 4,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
              decoration: const InputDecoration(
                hintText: "DÁN JSON VÀO ĐÂY...",
                hintStyle: TextStyle(color: Color(0xFF444444)),
                filled: true,
                fillColor: Color(0xFF141615),
                border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF666666), width: 1)),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: _pasteFromClipboard,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF333333),
                  child: const Text("DÁN", style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    return Material(
      color: const Color(0xFFB0B3A6),
      child: InkWell(
        onTap: _processJson,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          alignment: Alignment.center,
          child: const Text(
            "X Á C   N H Ậ N   ►",
            style: TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        InkWell(
          onTap: _openXiaomiSettings,
          child: const Text(
              "[ CẤP QUYỀN TRÊN XIAOMI/POCO ]",
              style: TextStyle(color: Color(0xFFB54545), fontSize: 12, fontWeight: FontWeight.bold)
          ),
        ),
        const SizedBox(height: 16),
        const Text("CHƯA BIẾT CÁCH XUẤT DỮ LIỆU LÀNG?", style: TextStyle(color: Color(0xFF666666), fontSize: 11, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        const Text("CÀI ĐẶT GAME > THÊM CÀI ĐẶT > XUẤT DỮ LIỆU LÀNG THEO ĐỊNH DẠNG JSON", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF888888), fontSize: 11, letterSpacing: 1.0)),
      ],
    );
  }
}