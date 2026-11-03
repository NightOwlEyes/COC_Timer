import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widgets/terminal_frame_painter.dart';
import '../widgets/terminal_header.dart';
import '../widgets/settings_dialog.dart';
import '../widgets/terminal_components.dart';
import '../services/coc_api_service.dart';
import '../services/war_sync_service.dart';
import '../services/schedule_service.dart';
import '../widgets/war_dashboard_widget.dart';
import '../screens/war_detail_screen.dart';
import '../utils/rule_manager.dart';
import '../utils/app_strings.dart';

class OnlineScreen extends StatefulWidget {
  final String? updateUrl;
  final String? updateVersion;

  const OnlineScreen({
    super.key,
    this.updateUrl,
    this.updateVersion,
  });

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final TextEditingController _tagController = TextEditingController();

  bool _isLoading = false;
  late String _statusText;

  List<Map<String, dynamic>> _savedClans = [];

  Timer? _clockTimer;
  String _currentTime = "";
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;
  bool _isHeaderVisible = true;

  @override
  void initState() {
    super.initState();
    _statusText = AppStrings.onlineScreen.statusReadyApi;
    _loadSavedClans();
    _startClockTimer();

    _cursorTimer = Timer.periodic(Duration(milliseconds: 600), (timer) {
      if (mounted) _showCursor.value = !_showCursor.value;
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _cursorTimer?.cancel();
    _showCursor.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _startClockTimer() {
    final now = DateTime.now();
    _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    _clockTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      final now = DateTime.now();
      setState(() {
        _currentTime = "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      });
    });
  }

  Future<void> _loadSavedClans() async {
    final prefs = await SharedPreferences.getInstance();
    final String? clansJson = prefs.getString('saved_online_clans');
    if (clansJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(clansJson);
        setState(() {
          _savedClans = decoded.cast<Map<String, dynamic>>();
        });
      } catch (e) {
        debugPrint("Lỗi Parse Clans: $e");
      }
    }
    if (_savedClans.isEmpty && RuleManager.warAutoSync) {
      setState(() {
        RuleManager.warAutoSync = false;
        RuleManager.save();
        WarSyncService.cancelTask();
      });
    }
  }

  Future<void> _saveClansToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_online_clans', jsonEncode(_savedClans));
  }

  Future<void> _addNewClan() async {
    String tagInput = _tagController.text.trim().toUpperCase();
    if (tagInput.isEmpty) return;

    if (!tagInput.startsWith('#')) {
      tagInput = '#$tagInput';
    }

    if (_savedClans.any((clan) => clan['tag'] == tagInput)) {
      setState(() => _statusText = AppStrings.onlineScreen.statusClanExists);
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _statusText = AppStrings.format(AppStrings.onlineScreen.statusSearchingClan, {'tag': tagInput});
    });

    try {
      final clanInfo = await CocApiService.verifyAndGetClanInfo(tagInput);

      if (!mounted) return;

      if (clanInfo != null) {
        setState(() {
          _savedClans.add(clanInfo);
          _statusText = AppStrings.format(AppStrings.onlineScreen.statusAddedClan, {'name': clanInfo['name']});
          _tagController.clear();
          _isLoading = false;
        });
        _saveClansToPrefs();
    if (_savedClans.isEmpty && RuleManager.warAutoSync) {
      setState(() {
        RuleManager.warAutoSync = false;
        RuleManager.save();
        WarSyncService.cancelTask();
      });
    }
      } else {
        setState(() {
          _isLoading = false;
          _statusText = AppStrings.onlineScreen.statusErrorNotFound;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.toString().contains("BẢO TRÌ") || e.toString().contains("MAINTENANCE")) {
          _statusText = AppStrings.onlineScreen.statusMaintenance;
        } else {
          _statusText = AppStrings.format(AppStrings.onlineScreen.statusErrorApi, {'error': e.toString()});
        }
      });
    }
  }

  void _confirmDeleteClan(String tag) {
    String cancelLabel = AppStrings.terminal.btnCancel.trim();
    if (!cancelLabel.startsWith('[')) cancelLabel = "[ $cancelLabel ]";

    String deleteLabel = AppStrings.terminal.btnDeleteNow.trim();
    if (!deleteLabel.startsWith('[')) deleteLabel = "[ $deleteLabel ]";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppColors.dialogBg,
        shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent, width: 1)),
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(AppTheme.label(AppStrings.terminal.deleteDialogTitle),
                style: TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
              ),
              SizedBox(height: 16),
              Text(
                AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text, fontSize: 13, fontFamily: AppTheme.font),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cancelLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteClan(tag);
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          deleteLabel,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                        ),
                      ),
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

  void _deleteClan(String tag) {
    ScheduleService.cancelWarSchedule(tag);
    setState(() {
      _savedClans.removeWhere((clan) => clan['tag'] == tag);
      _statusText = AppStrings.onlineScreen.statusDeletedClan;
    });
    _saveClansToPrefs();
    if (_savedClans.isEmpty && RuleManager.warAutoSync) {
      setState(() {
        RuleManager.warAutoSync = false;
        RuleManager.save();
        WarSyncService.cancelTask();
      });
    }
  }

  Future<void> _openWarDashboard(String clanTag, String clanName) async {
    bool isCancelled = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => TerminalLoadingOverlay(
        clanName: clanName,
        onCancel: () {
          isCancelled = true;
          Navigator.pop(ctx);
        },
      ),
    );

    try {
      final result = await CocApiService.fetchWarData(clanTag);

      if (!mounted) return;

      if (isCancelled) {
        setState(() => _statusText = AppStrings.onlineScreen.statusCancelledFetch);
        return;
      }

      Navigator.pop(context);

      if (result['type'] == 'REGULAR') {
        setState(() => _statusText = AppStrings.onlineScreen.statusWarDataSuccess);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => WarDetailScreen(
              apiResult: result,
              myTag: clanTag,
            ),
          ),
        );
      } else if (result['type'] == 'CWL') {
        setState(() => _statusText = AppStrings.onlineScreen.statusWarDataSuccess);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (ctx) => WarDashboardWidget(
              warData: result,
              myClanTag: clanTag,
            ),
          ),
        );
      } else {
        setState(() => _statusText = AppStrings.format(AppStrings.onlineScreen.statusNoWar, {'name': clanName}));
      }
    } catch (e) {
      if (!mounted) return;
      if (isCancelled) return;

      Navigator.pop(context);
      setState(() {
        if (e.toString().contains("BẢO TRÌ") || e.toString().contains("MAINTENANCE")) {
          _statusText = AppStrings.onlineScreen.statusMaintenance;
        } else {
          _statusText = AppStrings.format(AppStrings.onlineScreen.statusWarDataError, {'error': e.toString()});
        }
      });
    }
  }

  void _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data != null && data.text != null && mounted) {
      setState(() => _tagController.text = data.text!);
    }
  }

  void _showSettingsDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => SettingsDialog(themeColor: AppColors.ok),
    );
    if (mounted) setState(() {});
  }

  Future<void> _handleToggleAutoSync() async {
    if (!RuleManager.warAutoSync) {
      if (_savedClans.isEmpty) {
        setState(() => _statusText = "> ${AppStrings.settings.errorNoClanForWar.toUpperCase()}");
        return;
      }
      if (!RuleManager.warPreAlarmEnabled && !RuleManager.warEndAlarmEnabled) {
        setState(() => _statusText = "> ${AppStrings.settings.errorBothWarAlarmsOff.toUpperCase()}");
        return;
      }
    }
    if (RuleManager.warAutoSync) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceAlt,
          shape: RoundedRectangleBorder(side: BorderSide(color: AppColors.accent, width: 1.5)),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: AppColors.accent),
              SizedBox(width: 8),
              Expanded(
                child: Text(AppTheme.label(AppStrings.onlineScreen.dialogWarningTitle),
                  style: TextStyle(color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                ),
              ),
            ],
          ),
          content: Text(AppTheme.label(AppStrings.settings.dialogWarningContent),
            style: TextStyle(color: AppColors.text, fontSize: 13, height: 1.5, fontFamily: AppTheme.font),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(AppTheme.label(AppStrings.onlineScreen.btnCancelDialog),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textMuted, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(AppTheme.label(AppStrings.onlineScreen.btnForceDisable),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    setState(() {
      RuleManager.warAutoSync = !RuleManager.warAutoSync;
      RuleManager.save();
      if (RuleManager.warAutoSync) {
        WarSyncService.registerPeriodicTask();
      } else {
        WarSyncService.cancelTask();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final showHeader = !isLandscape || _isHeaderVisible;

    return Scaffold(
      body: GlassBackground(
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
                      alignment: Alignment.topCenter,
                      child: showHeader
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TerminalHeader(
                                  isOnline: true,
                                  customToggleLabel: AppStrings.onlineScreen.labelSync,
                                  showRealEta: RuleManager.warAutoSync,
                                  onToggleEta: _handleToggleAutoSync,
                                  currentTime: _currentTime,
                                  updateUrl: widget.updateUrl,         // TRUYỀN BIẾN UPDATE TỪ CONSTRUCTOR
                                  updateVersion: widget.updateVersion, // TRUYỀN BIẾN UPDATE TỪ CONSTRUCTOR
                                  onLanguageChange: () async {
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    await AppStrings.changeLanguage(AppStrings.languageCode == 'en' ? 'vi' : 'en');
                                    _statusText = AppStrings.onlineScreen.statusReadyApi;
                                    await ScheduleService.createOrUpdateNotificationChannels();
                                    if (ScheduleService.isQuickPasteActive) {
                                      await ScheduleService.showQuickPasteNotification();
                                    }
                                    await ScheduleService.resyncSavedWarSchedules();
                                    if (mounted) {
                                      setState(() {});
                                    }
                                  },
                                  onSettingsTap: _showSettingsDialog,
                                  onUpdateTap: () async {
                                    try {
                                      await launchUrl(Uri.parse('https://github.com/NightOwlEyes/COC_Timer/blob/main/README.md'), mode: LaunchMode.externalApplication);
                                    } catch (e) { debugPrint("Không thể mở link: $e"); }
                                  },
                                  onToggleServer: () => Navigator.pop(context),
                                ),
                                SizedBox(height: 9.5),
                              ],
                            )
                          : SizedBox.shrink(),
                    ),

                    Expanded(
                      child: NotificationListener<ScrollUpdateNotification>(
                        onNotification: (notification) {
                          if (!isLandscape) return false;
                          final delta = notification.scrollDelta ?? 0.0;
                          if (delta > 3.0 && _isHeaderVisible) {
                            setState(() => _isHeaderVisible = false);
                          } else if (delta < -3.0 && !_isHeaderVisible) {
                            setState(() => _isHeaderVisible = true);
                          }
                          return false;
                        },
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(vertical: 8),
                                margin: EdgeInsets.only(top: 10, bottom: 30),
                                decoration: BoxDecoration(
                                  border: Border(
                                    top: BorderSide(color: AppColors.ok, width: 1),
                                    bottom: BorderSide(color: AppColors.ok, width: 1),
                                  ),
                                  color: AppColors.okTint,
                                ),
                                child: Center(
                                  child: Text(AppTheme.label(AppStrings.onlineScreen.bannerClanWar),
                                    style: TextStyle(fontFamily: AppTheme.font, color: AppColors.ok, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                  ),
                                ),
                              ),

                              TerminalLogo(),

                              SizedBox(height: 30),

                              if (_savedClans.isNotEmpty)
                                ListView.builder(
                                  shrinkWrap: true,
                                  physics: NeverScrollableScrollPhysics(),
                                  itemCount: _savedClans.length,
                                  itemBuilder: (context, index) {
                                    final clan = _savedClans[index];

                                    return InkWell(
                                      onTap: _isLoading ? null : () => _openWarDashboard(clan['tag'], clan['name']),
                                      splashColor: AppColors.ok.withValues(alpha: 0.2),
                                      highlightColor: AppColors.ok.withValues(alpha: 0.1),
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 16.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      style: TextStyle(fontFamily: AppTheme.font, fontSize: 16),
                                                      children: [
                                                        TextSpan(text: AppStrings.onlineScreen.labelClanName, style: TextStyle(color: AppColors.textMuted)),
                                                        TextSpan(text: clan['name'], style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                InkWell(
                                                  onTap: _isLoading ? null : () => _confirmDeleteClan(clan['tag']),
                                                  child: Text(AppTheme.label(AppStrings.onlineScreen.btnDeleteClan),
                                                      style: TextStyle(fontFamily: AppTheme.font, color: AppColors.accent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),

                                            RichText(
                                              text: TextSpan(
                                                style: TextStyle(fontFamily: AppTheme.font, fontSize: 14),
                                                children: [
                                                  TextSpan(text: AppStrings.onlineScreen.labelClanTag, style: TextStyle(color: AppColors.textFaint)),
                                                  TextSpan(text: clan['tag'], style: TextStyle(color: AppColors.textDim)),
                                                ],
                                              ),
                                            ),

                                            SizedBox(height: 28),

                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Text(AppTheme.label(AppStrings.onlineScreen.labelBadge),
                                                        style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                                      ),
                                                      SizedBox(height: 14),
                                                      SizedBox(
                                                        width: 40, height: 40,
                                                        child: clan['badgeUrl'].toString().isNotEmpty
                                                            ? Image.network(clan['badgeUrl'], errorBuilder: (c, e, s) => Icon(Icons.shield, color: AppColors.ok))
                                                            : Icon(Icons.shield, color: AppColors.ok),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                Container(
                                                  width: 1,
                                                  height: 46,
                                                  color: AppColors.border,
                                                ),

                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      Text(AppTheme.label(AppStrings.onlineScreen.labelLevel),
                                                        style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                                      ),
                                                      SizedBox(height: 14),
                                                      Text(
                                                        "${clan['clanLevel']}",
                                                        style: TextStyle(
                                                          fontFamily: AppTheme.font,
                                                          color: AppColors.ok,
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          letterSpacing: 1.5,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),

                                            SizedBox(height: 28),
                                            Divider(color: AppColors.border, thickness: 1, height: 1),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              SizedBox(height: 30),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(AppTheme.label(AppStrings.onlineScreen.labelAddClan),
                                    style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0),
                                  ),
                                  SizedBox(height: 8),

                                  Stack(
                                    children: [
                                      TextField(
                                        controller: _tagController,
                                        enabled: !_isLoading,
                                        autofocus: false,
                                        maxLines: 4,
                                        style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 14),
                                        textCapitalization: TextCapitalization.characters,
                                        decoration: InputDecoration(
                                          hintText: AppStrings.onlineScreen.hintPasteTag,
                                          hintStyle: TextStyle(fontFamily: AppTheme.font, color: AppColors.borderStrong),
                                          filled: true,
                                          fillColor: AppColors.surface,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: AppColors.textDim, width: 1)),
                                        ),
                                      ),
                                      Positioned(
                                        right: 0,
                                        top: 0,
                                        child: InkWell(
                                          onTap: _pasteFromClipboard,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                            color: AppColors.border,
                                            child: Text(AppTheme.label(AppStrings.terminal.btnPaste), style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold)),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),

                                  SizedBox(height: 20),

                                  Material(
                                    color: AppColors.buttonBg,
                                    child: InkWell(
                                      onTap: _isLoading ? null : _addNewClan,
                                      child: Container(
                                        padding: EdgeInsets.symmetric(vertical: 18),
                                        alignment: Alignment.center,
                                        child: _isLoading
                                            ? SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                            : Text(AppTheme.label(AppStrings.onlineScreen.btnConfirmAdd),
                                          style: TextStyle(fontFamily: AppTheme.font, color: AppColors.inputBg, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                        ),
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

                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_statusText, style: TextStyle(fontFamily: AppTheme.font, color: AppColors.ok, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.clip, maxLines: 1),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) => Opacity(
                            opacity: (show && AppTheme.isTerminal) ? 1.0 : 0.0,
                            child: Text("█", style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 13)),
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

class TerminalLoadingOverlay extends StatefulWidget {
  final String clanName;
  final VoidCallback onCancel;

  const TerminalLoadingOverlay({
    super.key,
    required this.clanName,
    required this.onCancel,
  });

  @override
  State<TerminalLoadingOverlay> createState() => _TerminalLoadingOverlayState();
}

class _TerminalLoadingOverlayState extends State<TerminalLoadingOverlay> {
  final List<String> _frames = ['|', '/', '-', '\\'];
  int _currentFrame = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          _currentFrame = (_currentFrame + 1) % _frames.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.dialogBg,
          border: Border.all(color: AppColors.ok, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.ok.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt_outlined, color: AppColors.ok, size: 36),
            SizedBox(height: 16),
            Text(AppTheme.label(AppStrings.onlineScreen.overlayFetchingData),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTheme.font, color: AppColors.ok, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            SizedBox(height: 12),
            Text(
              "${AppStrings.onlineScreen.overlayClanPrefix}${widget.clanName}",
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontSize: 12),
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(AppTheme.label(AppStrings.onlineScreen.overlayLoading),
                  style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 14),
                ),
                Text(
                  "[ ${_frames[_currentFrame]} ]",
                  style: TextStyle(fontFamily: AppTheme.font, color: AppColors.warn, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surfaceHigh,
                  side: BorderSide(color: AppColors.accent, width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: widget.onCancel,
                child: Text(AppTheme.label(AppStrings.onlineScreen.btnCancelDialog),
                  style: TextStyle(fontFamily: AppTheme.font, color: AppColors.accent, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
