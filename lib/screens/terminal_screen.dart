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

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> {
  final TextEditingController _jsonController = TextEditingController();
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;
  Timer? _clockTimer;
  String _currentTime = "";

  Map<String, VillageData> _villages = {};
  Map<String, String> _savedRawJsons = {};
  final Map<String, String> _villageNames = {};
  final Map<String, TextEditingController> _nameControllers = {};

  final Map<String, String> _savedAlarmStates = {};
  final Set<int> _activePopups = {}; // THÊM BIẾN NÀY ĐỂ NHỚ CÁC POPUP ĐANG HIỆN

  String _parseStatus = "> CHỜ DỮ LIỆU JSON";

  bool _showRealEta = false;

  StreamSubscription? _alarmSubscription;

  @override
  void initState() {
    super.initState();

    ScheduleService.checkAndRequestPermissions();

    _loadSavedData();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) {
        _showCursor.value = !_showCursor.value;
      }
    });
    _startClockTimer();

    _alarmSubscription = Alarm.ringing.listen((alarmSet) {
      for (final alarmSettings in alarmSet.alarms) {
        _showFullscreenPopup(alarmSettings);
      }
    });
  }

  @override
  void dispose() {
    _alarmSubscription?.cancel();
    _cursorTimer?.cancel();
    _clockTimer?.cancel();
    _jsonController.dispose();
    _showCursor.dispose();
    for (var controller in _nameControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _getController(String tag) {
    if (!_nameControllers.containsKey(tag)) {
      _nameControllers[tag] = TextEditingController(text: _villageNames[tag] ?? "");
    }
    return _nameControllers[tag]!;
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
    // CHỐT AN TOÀN TRÁNH VÒNG LẶP ĐẺ POPUP
    if (_activePopups.contains(settings.id)) return;
    _activePopups.add(settings.id); // Đánh dấu ID này đang được hiện Popup

    // LẤY CONTEXT TỪ HỆ THỐNG TOÀN CỤC (AN TOÀN TUYỆT ĐỐI)
    final globalContext = ScheduleService.navigatorKey.currentContext;
    if (globalContext == null) return;

    showDialog(
        context: globalContext,
        barrierDismissible: false,
        builder: (dialogContext) {
          // Gọi sang Widget riêng biệt để quản lý bộ đếm tự động tắt
          return _AlarmPopup(settings: settings);
        }
    ).then((_) {
      // Hàm then() sẽ chạy ngay khi bạn đóng Popup (bằng nút hoặc vuốt thông báo)
      // Giải phóng ID để lần sau báo thức này còn có thể hiện lại
      _activePopups.remove(settings.id);
    });
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedData = prefs.getString('saved_villages_map');
    final savedNames = prefs.getString('saved_village_names');
    final savedAlarmJson = prefs.getString('saved_alarm_states');

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
            // Phục hồi trạng thái chuông
            for (var v in _villages.values) {
              _applySavedAlarmState(v, syncWithOS: false);
            }
          });
        }
      } catch (e) {
        debugPrint("Lỗi load: $e");
      }
    } // Đóng if (savedData != null)
  } // Đóng hàm _loadSavedData

  void _applySavedAlarmState(VillageData village, {bool syncWithOS = false}) {
    void apply(List<UpgradeItem> items) {
      for (var item in items) {
        String uniqueKey = item.instanceId;
        String? stateStr = _savedAlarmStates[uniqueKey];
        if (stateStr != null) {
          if (stateStr == "none") {
            item.alarmType = AlarmType.none; // Đã bổ sung dòng lệnh bị thiếu
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
  }

  void _deleteVillage(String tag) {
    if (!mounted) return;

    if (_villages.containsKey(tag)) {
      ScheduleService.cancelAllForVillage(_villages[tag]!);
    }

    setState(() {
      _villages.remove(tag);
      _savedRawJsons.remove(tag);
      _villageNames.remove(tag);
      _nameControllers[tag]?.dispose();
      _nameControllers.remove(tag);

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

      // SỬA LỖI: Đồng bộ sử dụng instanceId thay vì cấu trúc cũ
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

  void _processJson() {
    final inputData = _jsonController.text.trim();
    if (inputData.isEmpty) return;
    FocusScope.of(context).unfocus();

    try {
      final parsed = VillageParser.parse(inputData);

      if (_villages.containsKey(parsed.tag)) {
        ScheduleService.cancelAllForVillage(_villages[parsed.tag]!);
        _savedAlarmStates.removeWhere((key, value) => key.startsWith("${parsed.tag}_"));
      }

      _applySavedAlarmState(parsed, syncWithOS: true);

      setState(() {
        _villages[parsed.tag] = parsed;
        _savedRawJsons[parsed.tag] = inputData;
        _parseStatus = "> ĐÃ NHẬP DỮ LIỆU LÀNG: ${parsed.tag}";
        _jsonController.clear();
      });
      _saveDataToPrefs();
    } catch (e) {
      setState(() {
        _parseStatus = "> LỖI! HÃY KIỂM TRA LẠI JSON";
      });
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null) {
      if (!mounted) return; // Thêm chốt an toàn
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
        if (!mounted) return; // Thêm chốt an toàn
        setState(() {
          _parseStatus = "> HÃY TÍCH XANH TẤT CẢ!";
        });
      } catch (e) {
        if (!mounted) return; // Thêm chốt an toàn
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
              onTap: () => setState(() => _showRealEta = !_showRealEta),
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
            const Text("SERVER: COC-01", style: TextStyle(color: Color(0xFF666666), fontSize: 12)),
            const SizedBox(height: 4),
            Text("UTC+7 $_currentTime", style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
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
        final activeBuilders = village.activeBuilders;
        final activePets = village.activePets;
        final activeLab = village.activeLab;

        int petCount = activePets.length;
        int labCount = activeLab.length;

        return Padding(
          padding: const EdgeInsets.only(bottom: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                      "MÃ LÀNG: ${village.tag}",
                      style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14, fontWeight: FontWeight.bold)
                  ),
                  InkWell(
                    onTap: () => _deleteVillage(village.tag),
                    child: const Text(
                      "[ XÓA ]",
                      style: TextStyle(
                        color: Color(0xFF8B2B2B),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text("TÊN LÀNG: ", style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
                  Expanded(
                    child: TextField(
                      controller: _getController(village.tag),
                      style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        hintText: "[ NHẬP TÊN LÀNG... ]",
                        hintStyle: TextStyle(color: Color(0xFF444444)),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                        border: InputBorder.none,
                      ),
                      onChanged: (value) {
                        _villageNames[village.tag] = value;
                        _saveDataToPrefs();
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildLogLine("> THỢ XÂY", "${activeBuilders.length}/${village.totalBuilders} ĐANG LÀM", onTap: () => _cycleAlarmForGroup(village.tag, "THỢ XÂY", activeBuilders)),
              _buildDetailList(village.tag, activeBuilders),
              const SizedBox(height: 8),

              _buildLogLine("> LINH THÚ", "$petCount ĐANG NÂNG", onTap: () => _cycleAlarmForGroup(village.tag, "LINH THÚ", activePets)),
              _buildDetailList(village.tag, activePets),
              const SizedBox(height: 8),

              _buildLogLine("> PHÒNG THÍ NGHIỆM", "$labCount ĐANG NÂNG", onTap: () => _cycleAlarmForGroup(village.tag, "PHÒNG THÍ NGHIỆM", activeLab)),
              _buildDetailList(village.tag, activeLab),

              const SizedBox(height: 16),
              const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLogLine(String text, String status, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text(text, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
            const Expanded(
              child: Text(
                " ......................................",
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(color: Color(0xFF444444), fontSize: 13),
              ),
            ),
            Text(status, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailList(String villageTag, List<UpgradeItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 8.0),
      child: Column(
        children: items.map((item) {
          final diff = item.realEta.difference(DateTime.now());
          String timeStr = "0s";

          if (!diff.isNegative) {
            if (_showRealEta) {
              timeStr = "${item.realEta.hour.toString().padLeft(2, '0')}:${item.realEta.minute.toString().padLeft(2, '0')}";
              if (item.realEta.day != DateTime.now().day) {
                timeStr = "${item.realEta.day}/${item.realEta.month} $timeStr";
              }
            } else {
              if (diff.inDays > 0) {
                timeStr = "${diff.inDays}d ${diff.inHours % 24}h";
              } else if (diff.inHours > 0) {
                timeStr = "${diff.inHours}h ${diff.inMinutes % 60}m";
              } else if (diff.inMinutes > 0) {
                timeStr = "${diff.inMinutes}m ${diff.inSeconds % 60}s";
              } else {
                timeStr = "${diff.inSeconds}s";
              }
            }
          }

          IconData iconData = Icons.notifications_off;
          Color stateColor = const Color(0xFF444444); // TẮT: Màu Xám

          if (item.alarmType == AlarmType.system) {
            iconData = Icons.notifications;
            stateColor = const Color(0xFF4CAF50); // THÔNG BÁO: Màu Xanh Lá
          } else if (item.alarmType == AlarmType.fullscreen) {
            iconData = Icons.alarm;
            stateColor = const Color(0xFFB54545); // BÁO THỨC: Màu Đỏ
          }

          return InkWell(
            onTap: () => _cycleAlarmForItem(villageTag, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  Icon(iconData, size: 14, color: stateColor),
                  const SizedBox(width: 6),
                  Text("${item.typeString} ${item.dataId}", style: TextStyle(color: stateColor, fontSize: 12)),
                  const Expanded(
                    child: Text(
                      " ......................................",
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(color: Color(0xFF333333), fontSize: 12),
                    ),
                  ),
                  // Đổi màu bộ đếm thời gian đồng bộ với stateColor
                  Text(timeStr, style: TextStyle(color: stateColor, fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
        // THÊM NÚT SỬA LỖI Ở ĐÂY
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

// ==============================================================================
// THÊM CLASS WIDGET MỚI DÀNH RIÊNG CHO POPUP BÁO THỨC ĐỂ XỬ LÝ LOGIC TỰ ĐỘNG TẮT
// ==============================================================================
class _AlarmPopup extends StatefulWidget {
  final AlarmSettings settings;
  const _AlarmPopup({required this.settings});

  @override
  State<_AlarmPopup> createState() => _AlarmPopupState();
}

class _AlarmPopupState extends State<_AlarmPopup> {
  Timer? _checkTimer;
  bool _isClosing = false; // CHỐT AN TOÀN TRÁNH DOUBLE POP

  @override
  void initState() {
    super.initState();
    // Vòng lặp 1 giây: Kiểm tra xem chuông có bị người dùng tắt ngầm từ thanh thông báo OS không
    _checkTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final activeAlarms = await Alarm.getAlarms();
      final stillActive = activeAlarms.any((a) => a.id == widget.settings.id);

      if (!stillActive && !_isClosing) {
        _isClosing = true; // Đóng chốt an toàn
        timer.cancel();    // Hủy vòng lặp ngay lập tức để không kích hoạt lần 2
        if (mounted) {
          Navigator.pop(context);
          ScheduleService.handleAlarmDismiss();
        }
      }
    });
  }

  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C0B),
          border: Border.all(color: const Color(0xFFB54545), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.alarm_on, color: Color(0xFFB54545), size: 48),
            const SizedBox(height: 16),
            const Text(
              "■ TÍN HIỆU HOÀN TẤT ■",
              style: TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
            ),
            const SizedBox(height: 16),
            Text(
              widget.settings.notificationSettings.body,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFB54545)),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: const Color(0xFFE0E0E0),
                ),
                onPressed: () {
                  if (_isClosing) return; // Nếu vòng lặp Timer đã ra lệnh đóng, thì vô hiệu hóa nút bấm
                  _isClosing = true;
                  _checkTimer?.cancel(); // Dừng ngay vòng lặp kiểm tra

                  Alarm.stop(widget.settings.id); // Dừng chuông
                  Navigator.pop(context); // Đóng popup
                  ScheduleService.handleAlarmDismiss(); // Thu nhỏ app nếu đang khóa màn hình
                },
                child: const Text("[ XÁC NHẬN & ĐÓNG CẢNH BÁO ]", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}