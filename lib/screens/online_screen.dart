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
  const OnlineScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _statusText = AppStrings.onlineScreen.statusReadyApi;
    _loadSavedClans();
    _startClockTimer();

    _cursorTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
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

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
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
        // Bắt luôn cả tiếng Anh và tiếng Việt từ Service quăng lên
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
        backgroundColor: const Color(0xFF0A0C0B),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.terminal.deleteDialogTitle,
                style: const TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cancelLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        _deleteClan(tag);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          deleteLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB54545), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const SettingsDialog(themeColor: Color(0xFF4CAF50)),
    );
  }

  Future<void> _handleToggleAutoSync() async {
    if (RuleManager.warAutoSync) {
      bool? confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D0F0E),
          shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1.5)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54545)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppStrings.onlineScreen.dialogWarningTitle,
                  style: const TextStyle(color: Color(0xFFB54545), fontSize: 14, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          content: Text(
            AppStrings.settings.dialogWarningContent,
            style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, height: 1.5, fontFamily: 'monospace'),
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(
                      AppStrings.onlineScreen.btnCancelDialog,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: Text(
                      AppStrings.onlineScreen.btnForceDisable,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFFB54545), fontWeight: FontWeight.bold, fontFamily: 'monospace'),
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
    return Scaffold(
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: CustomPaint(
              painter: TerminalFramePainter(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.5),
                child: Column(
                  children: [
                    TerminalHeader(
                      isOnline: true,
                      customToggleLabel: AppStrings.onlineScreen.labelSync,
                      showRealEta: RuleManager.warAutoSync,
                      onToggleEta: _handleToggleAutoSync,
                      currentTime: _currentTime,
                      onLanguageChange: () async {
                        FocusManager.instance.primaryFocus?.unfocus();
                        await AppStrings.changeLanguage(AppStrings.languageCode == 'en' ? 'vi' : 'en');
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
                    const SizedBox(height: 9.5),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // === THÊM BANNER TIÊU ĐỀ Ở ĐÂY ===
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              margin: const EdgeInsets.only(top: 10, bottom: 30),
                              decoration: const BoxDecoration(
                                border: Border(
                                  top: BorderSide(color: Color(0xFF4CAF50), width: 1),
                                  bottom: BorderSide(color: Color(0xFF4CAF50), width: 1),
                                ),
                                color: Color(0x224CAF50),
                              ),
                              child: Center(
                                child: Text(
                                  AppStrings.onlineScreen.bannerClanWar,
                                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4CAF50), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
                                ),
                              ),
                            ),

                            TerminalLogo(),

                            const SizedBox(height: 30),

                            if (_savedClans.isNotEmpty)
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _savedClans.length,
                                itemBuilder: (context, index) {
                                  final clan = _savedClans[index];

                                  return InkWell(
                                    onTap: _isLoading ? null : () => _openWarDashboard(clan['tag'], clan['name']),
                                    splashColor: const Color(0xFF4CAF50).withValues(alpha: 0.2),
                                    highlightColor: const Color(0xFF4CAF50).withValues(alpha: 0.1),
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 16.0),
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
                                                    style: const TextStyle(fontFamily: 'monospace', fontSize: 16),
                                                    children: [
                                                      TextSpan(text: AppStrings.onlineScreen.labelClanName, style: const TextStyle(color: Color(0xFF888888))),
                                                      TextSpan(text: clan['name'], style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold)),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              InkWell(
                                                onTap: _isLoading ? null : () => _confirmDeleteClan(clan['tag']),
                                                child: Text(
                                                    AppStrings.onlineScreen.btnDeleteClan,
                                                    style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFB54545), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),

                                          RichText(
                                            text: TextSpan(
                                              style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                                              children: [
                                                TextSpan(text: AppStrings.onlineScreen.labelClanTag, style: const TextStyle(color: Color(0xFF555555))),
                                                TextSpan(text: clan['tag'], style: const TextStyle(color: Color(0xFF666666))),
                                              ],
                                            ),
                                          ),

                                          const SizedBox(height: 28),

                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      AppStrings.onlineScreen.labelBadge,
                                                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    SizedBox(
                                                      width: 40, height: 40,
                                                      child: clan['badgeUrl'].toString().isNotEmpty
                                                          ? Image.network(clan['badgeUrl'], errorBuilder: (c, e, s) => const Icon(Icons.shield, color: Color(0xFF4CAF50)))
                                                          : const Icon(Icons.shield, color: Color(0xFF4CAF50)),
                                                    ),
                                                  ],
                                                ),
                                              ),

                                              Container(
                                                width: 1,
                                                height: 46,
                                                color: const Color(0xFF333333),
                                              ),

                                              Expanded(
                                                child: Column(
                                                  children: [
                                                    Text(
                                                      AppStrings.onlineScreen.labelLevel,
                                                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                                    ),
                                                    const SizedBox(height: 14),
                                                    Text(
                                                      "${clan['clanLevel']}",
                                                      style: const TextStyle(
                                                        fontFamily: 'monospace',
                                                        color: Color(0xFF4CAF50),
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

                                          const SizedBox(height: 28),
                                          const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),

                            const SizedBox(height: 30),

                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppStrings.onlineScreen.labelAddClan,
                                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.0),
                                ),
                                const SizedBox(height: 8),

                                Stack(
                                  children: [
                                    TextField(
                                      controller: _tagController,
                                      enabled: !_isLoading,
                                      autofocus: false,
                                      maxLines: 4,
                                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 14),
                                      textCapitalization: TextCapitalization.characters,
                                      decoration: InputDecoration(
                                        hintText: AppStrings.onlineScreen.hintPasteTag,
                                        hintStyle: const TextStyle(fontFamily: 'monospace', color: Color(0xFF444444)),
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
                                          child: Text(AppStrings.terminal.btnPaste, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    )
                                  ],
                                ),

                                const SizedBox(height: 20),

                                Material(
                                  color: const Color(0xFF4CAF50),
                                  child: InkWell(
                                    onTap: _isLoading ? null : _addNewClan,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      alignment: Alignment.center,
                                      child: _isLoading
                                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                          : Text(
                                        AppStrings.onlineScreen.btnConfirmAdd,
                                        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
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

                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(_statusText, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.clip, maxLines: 1),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) => Opacity(
                            opacity: show ? 1.0 : 0.0,
                            child: const Text("█", style: TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 13)),
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
    _timer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
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
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0C0B),
          border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.satellite_alt_outlined, color: Color(0xFF4CAF50), size: 36),
            const SizedBox(height: 16),
            Text(
              AppStrings.onlineScreen.overlayFetchingData,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.0),
            ),
            const SizedBox(height: 12),
            Text(
              "${AppStrings.onlineScreen.overlayClanPrefix}${widget.clanName}",
              textAlign: TextAlign.center,
              style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontSize: 12),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  AppStrings.onlineScreen.overlayLoading,
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 14),
                ),
                Text(
                  "[ ${_frames[_currentFrame]} ]",
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE2B714), fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1C1B),
                  side: const BorderSide(color: Color(0xFFB54545), width: 1),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: widget.onCancel,
                child: Text(
                  AppStrings.onlineScreen.btnCancelDialog,
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFB54545), fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}