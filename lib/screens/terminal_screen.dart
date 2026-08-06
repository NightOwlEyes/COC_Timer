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
import '../utils/app_strings.dart';
import '../widgets/terminal_frame_painter.dart';
import '../services/schedule_service.dart';

import '../widgets/alarm_popup.dart';
import '../widgets/village_card.dart';
import '../widgets/village_detail_dialog.dart';

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

  final Map<String, String> _savedAlarmStates = {};
  final Set<int> _activePopups = {};

  String _parseStatus = AppStrings.terminal.statusWaitingJson;

  bool _showRealEta = true;
  bool _isBuilderBase = false;
  bool _xiaomiAcknowledged = false;

  Color get _themeColor => _isBuilderBase ? const Color(0xFFf8a4bd) : const Color(0xFFB54545);
  Color get _bgTagColor => _isBuilderBase ? const Color(0x22f8a4bd) : const Color(0x228B2B2B);

  StreamSubscription? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (_activePopups.isEmpty) {
      ScheduleService.disableAlarmMode();
    }
    ScheduleService.checkAndRequestPermissions();
    _loadSavedData();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (mounted) _showCursor.value = !_showCursor.value;
    });
    _startClockTimer();

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
      if (_activePopups.isEmpty) {
        ScheduleService.disableAlarmMode();
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
    });
  }

  void _showFullscreenPopup(AlarmSettings settings) {
    if (_activePopups.contains(settings.id)) return;
    _activePopups.add(settings.id);

    ScheduleService.enableAlarmMode();
    final globalContext = ScheduleService.navigatorKey.currentContext;
    if (globalContext == null) return;

    showDialog(
        context: globalContext,
        barrierDismissible: false,
        builder: (dialogContext) => AlarmPopup(settings: settings)
    ).then((_) {
      _activePopups.remove(settings.id);
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
    _xiaomiAcknowledged = prefs.getBool('xiaomi_acknowledged') ?? false;

    if (savedShowEta != null) _showRealEta = savedShowEta;

    if (savedAlarmJson != null) {
      try {
        final Map<String, dynamic> decodedAlarms = jsonDecode(savedAlarmJson);
        decodedAlarms.forEach((key, value) {
          _savedAlarmStates[key] = value.toString();
        });
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.terminal.debugLoadAlarmStateError, {'e': e.toString()}));
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
            debugPrint(AppStrings.format(AppStrings.terminal.debugParseVillageError, {'key': key, 'e': e.toString()}));
          }
        });

        if (mounted) {
          setState(() {
            _villages = loadedVillages;
            _savedRawJsons = loadedRaws;
            if (_villages.isNotEmpty) _parseStatus = AppStrings.terminal.statusLoadedSavedData;

            if (savedNames != null) {
              try {
                final Map<String, dynamic> decodedNames = jsonDecode(savedNames);
                decodedNames.forEach((key, value) {
                  _villageNames[key] = value.toString();
                });
              } catch (e) {
                debugPrint(AppStrings.format(AppStrings.terminal.debugLoadNameError, {'e': e.toString()}));
              }
            }
            for (var v in _villages.values) {
              _applySavedAlarmState(v, syncWithOS: false);
            }
          });
        }
      } catch (e) {
        debugPrint(AppStrings.format(AppStrings.terminal.debugLoadGeneralError, {'e': e.toString()}));
      }
    }
  }

  void _applySavedAlarmState(VillageData village, {bool syncWithOS = false}) {
    void apply(List<UpgradeItem> items) {
      for (var item in items) {
        String uniqueKey = item.instanceId;
        String? stateStr = _savedAlarmStates[uniqueKey];
        if (stateStr != null) {
          if (stateStr == "none") item.alarmType = AlarmType.none;
          else if (stateStr == "system") item.alarmType = AlarmType.system;
          else if (stateStr == "fullscreen") item.alarmType = AlarmType.fullscreen;
        }
        if (syncWithOS) {
          String vName = _villageNames[village.tag] ?? AppStrings.terminal.defaultVillageNameUnset;
          ScheduleService.syncItemSchedule(village.tag, vName, item);
        }
      }
    }
    apply(village.buildersItems);
    apply(village.petItems);
    apply(village.labItems);
    apply(village.builders2Items);
    apply(village.lab2Items);
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
              Text(AppStrings.terminal.deleteDialogTitle, style: const TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text(AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                  textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF444444)), shape: const RoundedRectangleBorder()),
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(AppStrings.terminal.btnCancel, style: const TextStyle(color: Color(0xFF888888))),
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

    if (_villages.containsKey(tag)) {
      ScheduleService.cancelAllForVillage(_villages[tag]!);
    }

    setState(() {
      _villages.remove(tag);
      _savedRawJsons.remove(tag);
      _savedAlarmStates.removeWhere((key, value) => key.startsWith("${tag}_"));
      _parseStatus = _villages.isEmpty ? AppStrings.terminal.statusWaitingJson : AppStrings.format(AppStrings.terminal.statusVillageDeleted, {'tag': tag});
    });
    _saveDataToPrefs();
    _saveAlarmStatesToPrefs();
  }

  void _cycleAlarmForItem(String villageTag, UpgradeItem item) {
    setState(() {
      String itemName = AppStrings.gameData.getName(item.dataId);
      if (item.alarmType == AlarmType.system) {
        item.alarmType = AlarmType.fullscreen;
        _parseStatus = AppStrings.format(AppStrings.terminal.statusAlarmSetFullscreen, {'typeString': itemName.toUpperCase(), 'dataId': ""});
      } else if (item.alarmType == AlarmType.fullscreen) {
        item.alarmType = AlarmType.none;
        _parseStatus = AppStrings.format(AppStrings.terminal.statusAlarmOff, {'typeString': itemName.toUpperCase(), 'dataId': ""});
      } else {
        item.alarmType = AlarmType.system;
        _parseStatus = AppStrings.format(AppStrings.terminal.statusNotificationSetSystem, {'typeString': itemName.toUpperCase(), 'dataId': ""});
      }

      String uniqueKey = item.instanceId;
      _savedAlarmStates[uniqueKey] = item.alarmType.name;
      _saveAlarmStatesToPrefs();
    });

    String vName = _villageNames[villageTag] ?? AppStrings.terminal.defaultVillageNameUnset;
    ScheduleService.syncItemSchedule(villageTag, vName, item);
  }

  void _cycleAlarmForGroup(String villageTag, String groupName, List<UpgradeItem> items) {
    if (items.isEmpty) return;
    setState(() {
      bool hasSystem = items.any((i) => i.alarmType == AlarmType.system);
      bool hasFullscreen = items.any((i) => i.alarmType == AlarmType.fullscreen);

      AlarmType targetType = AlarmType.system;
      if (hasSystem) targetType = AlarmType.fullscreen;
      else if (hasFullscreen) targetType = AlarmType.none;

      for (var item in items) {
        item.alarmType = targetType;
        String uniqueKey = item.instanceId;
        _savedAlarmStates[uniqueKey] = targetType.name;

        String vName = _villageNames[villageTag] ?? AppStrings.terminal.defaultVillageNameUnset;
        ScheduleService.syncItemSchedule(villageTag, vName, item);
      }

      _parseStatus = targetType == AlarmType.none
          ? AppStrings.format(AppStrings.terminal.statusGroupAllOff, {'groupName': groupName})
          : AppStrings.format(AppStrings.terminal.statusGroupModeChanged, {'groupName': groupName, 'alarmType': targetType.name.toUpperCase()});

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
          _villageNames[parsed.tag] = AppStrings.terminal.defaultVillageNameFallback;
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
        _parseStatus = AppStrings.format(AppStrings.terminal.statusUpdated, {'villageName': _villageNames[parsed.tag]!, 'tag': parsed.tag});
        _jsonController.clear();
      });
      _saveDataToPrefs();
    } catch (e) {
      setState(() {
        _parseStatus = AppStrings.terminal.statusErrorInvalidJson;
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
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: const RoundedRectangleBorder()),
                  onPressed: () => Navigator.pop(ctx, tempController.text),
                  child: Text(AppStrings.terminal.btnSaveAndAddVillage, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
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
    setState(() {
      _xiaomiAcknowledged = true;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('xiaomi_acknowledged', true);

    if (Platform.isAndroid) {
      try {
        final intent = const AndroidIntent(
          action: 'miui.intent.action.APP_PERM_EDITOR',
          arguments: {'extra_pkgname': 'coctimer.nightowleyes.coctimer'},
        );
        await intent.launch();
        if (!mounted) return;
        setState(() {
          _parseStatus = AppStrings.terminal.statusXiaomiPromptSuccess;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _parseStatus = AppStrings.terminal.statusXiaomiPromptError;
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
    final offset = DateTime.now().timeZoneOffset;
    final offsetString = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.terminal.headerSmallTitle, style: const TextStyle(color: Color(0xFF666666), fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            InkWell(
              onTap: () {
                FocusManager.instance.primaryFocus?.unfocus();
                setState(() => _showRealEta = !_showRealEta);
                _saveDataToPrefs();
              },
              child: Row(
                children: [
                  Text("${AppStrings.terminal.labelRealTime}: ", style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                  Text(
                    _showRealEta ? AppStrings.terminal.toggleOn : AppStrings.terminal.toggleOff,
                    style: TextStyle(
                        color: _showRealEta ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 4),
            // CỤM NÚT NGÔN NGỮ THÔ VÀ TỐI GIẢN
            InkWell(
              onTap: () async {
                FocusManager.instance.primaryFocus?.unfocus();
                String newLang = AppStrings.languageCode == 'vi' ? 'en' : 'vi';
                await AppStrings.changeLanguage(newLang);
                setState(() {});
              },
              child: Row(
                children: [
                  Text(AppStrings.languageCode == 'vi' ? "NGÔN NGỮ: " : "LANGUAGE: ", style: const TextStyle(color: Color(0xFF888888), fontSize: 11)),
                  Text(
                    AppStrings.languageCode == 'vi' ? "[ VN ]" : "[ EN ]",
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(AppStrings.terminal.labelServer, style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
            const SizedBox(height: 4),
            Text("$offsetString $_currentTime", style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityTag() {
    return Column(
      children: [
        Text(AppStrings.terminal.labelTapToSwitchServer, style: const TextStyle(color: Color(0xFF666666), fontSize: 10, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            setState(() {
              _isBuilderBase = !_isBuilderBase;
            });
          },
          splashColor: _themeColor.withValues(alpha: 0.3),
          highlightColor: _themeColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: _themeColor, width: 1),
                bottom: BorderSide(color: _themeColor, width: 1),
              ),
              color: _bgTagColor,
            ),
            child: Center(
              child: Text(
                _isBuilderBase ? AppStrings.terminal.tabBuilderBase : AppStrings.terminal.tabMainVillage,
                style: TextStyle(color: _themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoArea() {
    return Column(
      children: [
        Image.asset('assets/LogoMain.png', height: 80),
        const SizedBox(height: 16),
        Text(
          AppStrings.terminal.logoTitle,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4.0),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.terminal.logoSubtitle,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.5),
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
          isBuilderBase: _isBuilderBase,
          themeColor: _themeColor,
          onDelete: () => _confirmDeleteVillage(village.tag),
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            showDialog(
              context: context,
              builder: (ctx) => VillageDetailDialog(
                village: village,
                villageName: _villageNames[village.tag] ?? "",
                isBuilderBase: _isBuilderBase,
                themeColor: _themeColor,
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
        Text(AppStrings.terminal.inputSectionLabel, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.0)),
        const SizedBox(height: 8),
        Stack(
          children: [
            TextField(
              controller: _jsonController,
              autofocus: false,
              maxLines: 4,
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
              decoration: InputDecoration(
                hintText: AppStrings.terminal.inputHint,
                hintStyle: const TextStyle(color: Color(0xFF444444)),
                filled: true,
                fillColor: const Color(0xFF141615),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF666666), width: 1)),
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
                  child: Text(AppStrings.terminal.btnPaste, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold)),
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
          child: Text(
            AppStrings.terminal.btnSubmit,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        if (!_xiaomiAcknowledged && Platform.isAndroid)
          InkWell(
            onTap: _openXiaomiSettings,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0x33B54545),
                border: Border.all(color: const Color(0xFFB54545), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54545), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.terminal.btnXiaomiPermission,
                    style: const TextStyle(color: Color(0xFFB54545), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          InkWell(
            onTap: _openXiaomiSettings,
            child: Text(
                AppStrings.terminal.btnXiaomiPermission,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.bold)
            ),
          ),

        const SizedBox(height: 16),
        Text(AppStrings.terminal.footerHowtoTitle, style: const TextStyle(color: Color(0xFF666666), fontSize: 11, letterSpacing: 1.0)),
        const SizedBox(height: 4),
        Text(AppStrings.terminal.footerHowtoDesc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888888), fontSize: 11, letterSpacing: 1.0)),
      ],
    );
  }
}