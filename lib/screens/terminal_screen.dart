import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alarm/alarm.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:url_launcher/url_launcher.dart';

import '../utils/village_manager.dart';
import '../utils/app_strings.dart';
import '../utils/rule_manager.dart';
import '../services/schedule_service.dart';

import '../widgets/terminal_frame_painter.dart';
import '../widgets/terminal_dialogs.dart';
import '../widgets/village_card.dart';
import '../widgets/village_detail_dialog.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/terminal_header.dart';
import '../widgets/terminal_components.dart';

import 'online_screen.dart';

class TerminalScreen extends StatefulWidget {
  const TerminalScreen({super.key});

  @override
  State<TerminalScreen> createState() => _TerminalScreenState();
}

class _TerminalScreenState extends State<TerminalScreen> with WidgetsBindingObserver {
  final TextEditingController _jsonController = TextEditingController();
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  final VillageManager _vm = VillageManager();

  Timer? _cursorTimer;
  Timer? _clockTimer;
  String _currentTime = "";

  String _parseStatus = AppStrings.terminal.statusWaitingJson;
  bool _isBuilderBase = false;
  bool _pendingQuickPaste = false;
  bool _isHeaderVisible = true;

  String? _updateVersion;
  String? _updateUrl;

  Color get _themeColor => _isBuilderBase ? AppColors.accentBase : AppColors.accent;
  Color get _bgTagColor => _isBuilderBase ? AppColors.accentBaseTint : AppColors.dangerTint;

  StreamSubscription? _alarmSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _vm.isQuickPasteActive = ScheduleService.isQuickPasteActive;
    ScheduleService.quickPasteTrigger.addListener(_onQuickPasteTriggered);

    RuleManager.init().then((_) async {
      if (RuleManager.autoCheckUpdate) {
        final updateInfo = await VillageManager.checkGithubUpdate();
        if (updateInfo != null && mounted) {
          setState(() {
            _updateVersion = updateInfo.version;
            _updateUrl = updateInfo.url;
          });
        }
      }
    });

    if (_vm.isAlarmIdle) {
      ScheduleService.disableAlarmMode();
    }

    ScheduleService.checkAndRequestPermissions().then((_) {
      if (mounted && _vm.isAlarmIdle) {
        ScheduleService.disableAlarmMode();
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _vm.checkActiveRingingAlarms();

      if (!mounted) return;
      if (ScheduleService.quickPasteTrigger.value > 0) {
        _onQuickPasteTriggered();
      } else {
        TerminalDialogs.checkAndShowReimportReminder(
          context,
          shouldSkip: () => _pendingQuickPaste || !_vm.isAlarmIdle,
        );
      }

      Future.delayed(Duration(milliseconds: 2500), () {
        if (mounted && _vm.isAlarmIdle) {
          ScheduleService.disableAlarmMode();
        }
      });
    });

    _vm.loadSavedData().then((hasVillages) {
      if (mounted) {
        setState(() {
          if (hasVillages) _parseStatus = AppStrings.terminal.statusLoadedSavedData;
        });
      }
    });

    _cursorTimer = Timer.periodic(Duration(milliseconds: 600), (timer) {
      if (mounted) _showCursor.value = !_showCursor.value;
    });
    _startClockTimer();

    _alarmSubscription = Alarm.ringing.listen((dynamic event) {
      try {
        ScheduleService.enableAlarmMode();
        if (mounted) {
          if (event is AlarmSettings) {
            _vm.queueAlarm(event);
          } else {
            try {
              for (final alarmSettings in event.alarms) {
                if (alarmSettings is AlarmSettings) {
                  _vm.queueAlarm(alarmSettings);
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

  void _onQuickPasteTriggered() {
    _pendingQuickPaste = true;
    _attemptQuickPaste();
  }

  Future<void> _attemptQuickPaste() async {
    if (!_pendingQuickPaste || !mounted) return;
    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;

    await Future.delayed(Duration(milliseconds: 300));
    if (!mounted) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    String? clipboardText = data?.text;

    if (clipboardText == null || clipboardText.trim().isEmpty) {
      await Future.delayed(Duration(milliseconds: 500));
      final retryData = await Clipboard.getData(Clipboard.kTextPlain);
      clipboardText = retryData?.text;
    }

    _pendingQuickPaste = false;

    if (clipboardText != null && clipboardText.trim().isNotEmpty) {
      setState(() => _jsonController.text = clipboardText!);
      await _processJson(fromQuickPaste: true);
    } else {
      final String emptyMsg = AppStrings.terminal.quickPasteEmpty;
      setState(() => _parseStatus = emptyMsg);
      if (mounted) {
        TerminalDialogs.showQuickPasteFeedbackOverlay(context, emptyMsg, isSuccess: false);
      }
      await Future.delayed(Duration(milliseconds: 1200));
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        if (RuleManager.quickPasteAutoReturn) {
          SystemNavigator.pop();
        }
      }
    }
  }

  Future<void> _toggleQuickPaste() async {
    FocusManager.instance.primaryFocus?.unfocus();

    if (_vm.isQuickPasteActive) {
      await ScheduleService.cancelQuickPasteNotification();
      if (mounted) {
        setState(() {
          _vm.isQuickPasteActive = false;
          _parseStatus = AppStrings.terminal.quickPasteDisabled;
        });
      }
    } else {
      await ScheduleService.showQuickPasteNotification();
      if (mounted) {
        setState(() {
          _vm.isQuickPasteActive = true;
          _parseStatus = AppStrings.terminal.quickPastePinned;
        });
        TerminalDialogs.showQuickPasteInfoDialog(context);
      }
    }
  }

  @override
  void dispose() {
    ScheduleService.quickPasteTrigger.removeListener(_onQuickPasteTriggered);
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
      ScheduleService.ensureQuickPasteNotification();
      if (_pendingQuickPaste) {
        _attemptQuickPaste();
      }

      _vm.checkActiveRingingAlarms().then((_) {
        if (!mounted) return;
        if (!_vm.isAlarmIdle) {
          ScheduleService.enableAlarmMode();
        } else {
          Future.delayed(Duration(milliseconds: 2500), () {
            if (mounted && _vm.isAlarmIdle) {
              ScheduleService.disableAlarmMode();
            }
          });
        }
      });
    }
  }

  void _startClockTimer() {
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      try {
        final now = DateTime.now();
        final bool needsUpdate = _vm.tickCleanup(now);

        setState(() {
          _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
        });

        if (needsUpdate) _vm.saveDataToPrefs();
      } catch (e) {
        debugPrint("Lỗi đếm ngược thời gian: $e");
      }
    });
  }

  Future<void> _processJson({bool fromQuickPaste = false}) async {
    final inputData = _jsonController.text.trim();
    if (inputData.isEmpty) return;
    FocusScope.of(context).unfocus();

    try {
      final res = await _vm.importVillageJson(inputData);
      if (mounted) {
        setState(() {
          _parseStatus = res.statusMsg;
          _jsonController.clear();
        });
      }

      if (res.isNewVillage) {
        await _fetchNameAndShowPopup(res.tag, fromQuickPaste: fromQuickPaste);
      } else {
        if (fromQuickPaste && mounted) {
          TerminalDialogs.showQuickPasteFeedbackOverlay(context, res.statusMsg, isSuccess: true);
          await Future.delayed(Duration(milliseconds: 900));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            if (RuleManager.quickPasteAutoReturn) {
              SystemNavigator.pop();
            }
          }
          return;
        }

        await Future.delayed(Duration(milliseconds: 500));
        if (mounted && _vm.isAlarmIdle) {
          ScheduleService.disableAlarmMode();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _parseStatus = AppStrings.terminal.statusErrorInvalidJson);
        if (fromQuickPaste) {
          TerminalDialogs.showQuickPasteFeedbackOverlay(
            context,
            AppStrings.terminal.statusErrorInvalidJson,
            isSuccess: false,
          );
          await Future.delayed(Duration(milliseconds: 1200));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            if (RuleManager.quickPasteAutoReturn) {
              SystemNavigator.pop();
            }
          }
        }
      }
    }
  }

  Future<void> _fetchNameAndShowPopup(String tag, {bool fromQuickPaste = false}) async {
    final String? fetchedName = await VillageManager.fetchPlayerNameWithRetry(tag);
    if (!mounted) return;

    setState(() {
      _parseStatus = (fetchedName != null && fetchedName.isNotEmpty)
          ? AppStrings.format(AppStrings.terminal.statusFoundNameWaitingConfirm, {'name': fetchedName})
          : AppStrings.terminal.statusApiTimeoutManualInput;
    });

    final Map<String, dynamic>? result = await TerminalDialogs.promptForVillageName(
      context,
      tag,
      prefilledName: fetchedName,
    );

    if (mounted && _vm.villages.containsKey(tag)) {
      final statusMsg = await _vm.finalizeNewVillage(tag, result, fetchedName);
      if (mounted) setState(() => _parseStatus = statusMsg);

      if (fromQuickPaste) {
        if (RuleManager.quickPasteAutoReturn) {
          await Future.delayed(Duration(milliseconds: 300));
          SystemNavigator.pop();
        }
        return;
      }

      await Future.delayed(Duration(milliseconds: 500));
      if (mounted && _vm.isAlarmIdle) {
        ScheduleService.disableAlarmMode();
      }
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && mounted) {
      setState(() => _jsonController.text = data.text!);
      _processJson();
    }
  }

  void _openXiaomiSettings() async {
    setState(() => _vm.xiaomiAcknowledged = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('xiaomi_acknowledged', true);

    if (Platform.isAndroid) {
      try {
        await AndroidIntent(
          action: 'miui.intent.action.APP_PERM_EDITOR',
          arguments: {'extra_pkgname': 'coctimer.nightowleyes.coctimer'},
        ).launch();
        if (mounted) setState(() => _parseStatus = AppStrings.terminal.statusXiaomiPromptSuccess);
      } catch (e) {
        if (mounted) setState(() => _parseStatus = AppStrings.terminal.statusXiaomiPromptError);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bool showHeader = !isLandscape || _isHeaderVisible;

    return Scaffold(
      body: GlassBackground(
        isBuilderBase: _isBuilderBase,
        child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: TerminalFramePainter(),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.5),
                child: Column(
                  children: [
                    AnimatedSize(
                      duration: Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: showHeader
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TerminalHeader(
                                  isOnline: false,
                                  showRealEta: _vm.showRealEta,
                                  currentTime: _currentTime,
                                  updateUrl: _updateUrl,
                                  updateVersion: _updateVersion,
                                  onToggleServer: () async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    final String prevLang = AppStrings.languageCode;
                                    await Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (context, animation, secondaryAnimation) => OnlineScreen(
                                          updateUrl: _updateUrl,
                                          updateVersion: _updateVersion,
                                        ),
                                        transitionsBuilder: (context, animation, secondaryAnimation, child) {
                                          return FadeTransition(opacity: animation, child: child);
                                        },
                                      ),
                                    );
                                    if (!mounted) return;
                                    if (AppStrings.languageCode != prevLang) {
                                      _parseStatus = _vm.villages.isNotEmpty
                                          ? AppStrings.terminal.statusLoadedSavedData
                                          : AppStrings.terminal.statusWaitingJson;
                                      await _vm.syncAllNotificationsForLanguageChange();
                                    }
                                    if (mounted) setState(() {});
                                  },
                                  onLanguageChange: () async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    await AppStrings.changeLanguage(AppStrings.languageCode == 'en' ? 'vi' : 'en');
                                    _parseStatus = _vm.villages.isNotEmpty
                                        ? AppStrings.terminal.statusLoadedSavedData
                                        : AppStrings.terminal.statusWaitingJson;
                                    if (mounted) setState(() {});
                                    await _vm.syncAllNotificationsForLanguageChange();
                                    await Future.delayed(Duration(milliseconds: 500));
                                    if (mounted) {
                                      if (_vm.isAlarmIdle) ScheduleService.disableAlarmMode();
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
                                      if (_vm.villages.isNotEmpty) {
                                        await _vm.resyncAllVillages(forceApplyRules: true);
                                        await Future.delayed(Duration(milliseconds: 500));
                                        if (mounted) {
                                          if (_vm.isAlarmIdle) ScheduleService.disableAlarmMode();
                                          setState(() {});
                                        }
                                      }
                                    }
                                  },
                                  onUpdateTap: () async {
                                    try {
                                      await launchUrl(
                                        Uri.parse('https://github.com/NightOwlEyes/COC_Timer/blob/main/README.md'),
                                        mode: LaunchMode.externalApplication,
                                      );
                                    } catch (e) {
                                      debugPrint("Không thể mở link: $e");
                                    }
                                  },
                                ),
                                SizedBox(height: 9.5),
                              ],
                            )
                          : SizedBox.shrink(),
                    ),
                    Expanded(
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          if (isLandscape && notification.scrollDelta != null) {
                            if (notification.scrollDelta! > 2 && notification.metrics.pixels > 20 && _isHeaderVisible) {
                              setState(() => _isHeaderVisible = false);
                            } else if ((notification.scrollDelta! < -2 || notification.metrics.pixels <= 10) && !_isHeaderVisible) {
                              setState(() => _isHeaderVisible = true);
                            }
                          }
                          return false;
                        },
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
                                },
                              ),
                              SizedBox(height: 30),
                              TerminalLogo(),
                              SizedBox(height: 30),
                              if (_vm.villages.isNotEmpty)
                                Column(
                                  children: _vm.villages.values.map((village) => VillageCard(
                                    village: village,
                                    villageName: _vm.villageNames[village.tag] ?? "",
                                    isBuilderBase: _isBuilderBase,
                                    themeColor: _themeColor,
                                    onDelete: () => TerminalDialogs.confirmDeleteVillage(
                                      context,
                                      tag: village.tag,
                                      onConfirm: () {
                                        if (!mounted) return;
                                        setState(() {
                                          _parseStatus = _vm.deleteVillage(village.tag);
                                        });
                                      },
                                    ),
                                    onTap: () {
                                      FocusManager.instance.primaryFocus?.unfocus();
                                      showDialog(
                                        context: context,
                                        builder: (ctx) => VillageDetailDialog(
                                          village: village,
                                          villageName: _vm.villageNames[village.tag] ?? "",
                                          isBuilderBase: _isBuilderBase,
                                          themeColor: _themeColor,
                                          showRealEta: _vm.showRealEta,
                                          onToggleRealEta: () {
                                            setState(() => _vm.showRealEta = !_vm.showRealEta);
                                            _vm.saveDataToPrefs();
                                          },
                                          initialTrackHome: _vm.trackHome[village.tag] ?? true,
                                          initialTrackBuilder: _vm.trackBuilder[village.tag] ?? true,
                                          onNameChanged: (newName) {
                                            _vm.villageNames[village.tag] = newName;
                                            _vm.saveDataToPrefs();
                                            setState(() {});
                                          },
                                          onTrackingChanged: (trackH, trackB) {
                                            _vm.trackHome[village.tag] = trackH;
                                            _vm.trackBuilder[village.tag] = trackB;
                                            _vm.saveDataToPrefs();
                                            _vm.applySavedAlarmState(village, syncWithOS: true).then((_) => setState(() {}));
                                          },
                                          onCycleGroup: (groupName, items) {
                                            _vm.cycleAlarmForGroup(village.tag, groupName, items).then((msg) {
                                              if (!mounted) return;
                                              if (_vm.isAlarmIdle) ScheduleService.disableAlarmMode();
                                              setState(() {
                                                if (msg.isNotEmpty) _parseStatus = msg;
                                              });
                                            });
                                          },
                                          onCycleItem: (item) {
                                            _vm.cycleAlarmForItem(village.tag, item).then((msg) {
                                              if (!mounted) return;
                                              if (_vm.isAlarmIdle) ScheduleService.disableAlarmMode();
                                              setState(() => _parseStatus = msg);
                                            });
                                          },
                                        ),
                                      );
                                    },
                                  )).toList(),
                                ),
                              SizedBox(height: 30),
                              TerminalInputArea(
                                controller: _jsonController,
                                onPaste: _pasteFromClipboard,
                                onSubmit: _processJson,
                                isQuickPasteActive: _vm.isQuickPasteActive,
                                onToggleQuickPaste: _toggleQuickPaste,
                              ),
                              SizedBox(height: 20),
                              TerminalFooter(
                                xiaomiAcknowledged: _vm.xiaomiAcknowledged,
                                onXiaomiTap: _openXiaomiSettings,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        if (AppTheme.isModern) ...[
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(color: AppColors.ok, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            AppTheme.isModern ? _parseStatus.replaceFirst(RegExp(r'^>\s*'), '') : _parseStatus,
                            style: TextStyle(
                              color: AppColors.ok,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.clip,
                            maxLines: 1,
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) => Opacity(
                            opacity: (show && AppTheme.isTerminal) ? 1.0 : 0.0,
                            child: Text(
                              "█",
                              style: TextStyle(color: AppColors.text, fontSize: 13),
                            ),
                          ),
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
    ),
    );
  }
}
