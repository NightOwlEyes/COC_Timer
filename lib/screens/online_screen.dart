import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/terminal_frame_painter.dart';
import '../widgets/terminal_header.dart';
import '../services/coc_api_service.dart';
import '../widgets/war_dashboard_widget.dart';
import '../utils/app_strings.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final TextEditingController _tagController = TextEditingController();

  bool _isLoading = false;
  String _statusText = "> SẴN SÀNG KẾT NỐI API...";

  List<Map<String, dynamic>> _savedClans = [];

  // Đồng hồ và con trỏ nhấp nháy y hệt TerminalScreen
  Timer? _clockTimer;
  String _currentTime = "";
  final ValueNotifier<bool> _showCursor = ValueNotifier(true);
  Timer? _cursorTimer;

  // Lấy state từ SharedPreferences để hiển thị cho Header
  bool _showRealEta = true;

  @override
  void initState() {
    super.initState();
    _loadSavedClans();
    _loadSettings();
    _startClockTimer();

    // Khởi tạo con trỏ nhấp nháy
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

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _showRealEta = prefs.getBool('show_real_eta') ?? true;
      });
    }
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
      setState(() => _statusText = "> CLAN NÀY ĐÃ CÓ TRONG DANH SÁCH!");
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isLoading = true;
      _statusText = "> ĐANG TÌM KIẾM CLAN [ $tagInput ] TRÊN SERVER...";
    });

    try {
      final clanInfo = await CocApiService.verifyAndGetClanInfo(tagInput);

      if (!mounted) return;

      if (clanInfo != null) {
        setState(() {
          _savedClans.add(clanInfo);
          _statusText = "> ĐÃ THÊM CLAN: ${clanInfo['name']}";
          _tagController.clear();
          _isLoading = false;
        });
        _saveClansToPrefs();
      } else {
        setState(() {
          _isLoading = false;
          _statusText = "> LỖI: KHÔNG TÌM THẤY CLAN (SAI MÃ HOẶC MẠNG KÉM)";
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.toString().contains("BẢO TRÌ")) {
          _statusText = "> $e";
        } else {
          _statusText = "> LỖI KẾT NỐI API: $e";
        }
      });
    }
  }

  void _deleteClan(String tag) {
    setState(() {
      _savedClans.removeWhere((clan) => clan['tag'] == tag);
      _statusText = "> ĐÃ XÓA CLAN KHỎI DANH SÁCH.";
    });
    _saveClansToPrefs();
  }

  Future<void> _openWarDashboard(String clanTag, String clanName) async {
    setState(() {
      _isLoading = true;
      _statusText = "> ĐANG TẢI DỮ LIỆU WAR CỦA [ $clanName ]...";
    });

    try {
      final result = await CocApiService.fetchWarData(clanTag);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        if (result['type'] == 'REGULAR' || result['type'] == 'CWL') {
          _statusText = "> TẢI DỮ LIỆU WAR THÀNH CÔNG!";
          showDialog(
            context: context,
            builder: (ctx) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(16.0),
              child: WarDashboardWidget(
                warData: result,
                myClanTag: clanTag,
              ),
            ),
          );
        } else {
          _statusText = "> CLAN [ $clanName ] KHÔNG CÓ TRẬN WAR NÀO.";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        if (e.toString().contains("BẢO TRÌ")) {
          _statusText = "> $e";
        } else {
          _statusText = "> LỖI TẢI DỮ LIỆU WAR: $e";
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
                    // SỬ DỤNG CHUNG TERMINAL HEADER
                    TerminalHeader(
                      isOnline: true,
                      showRealEta: _showRealEta,
                      currentTime: _currentTime,
                      onToggleEta: () {}, // Vô hiệu hóa tính năng cài đặt ở màn online để tránh rườm rà
                      onLanguageChange: () {},
                      onSettingsTap: () {},
                      onUpdateTap: () {},
                      onToggleServer: () => Navigator.pop(context), // ẤN VÀO NÚT SERVER ĐỂ QUAY VỀ
                    ),
                    const SizedBox(height: 9.5),

                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // KHUNG LOGO BANNER (ĐỒNG BỘ THIẾT KẾ VỚI SECURITY TAG CỦA MÀN HÌNH LOCAL)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: const BoxDecoration(
                                color: Color(0x224CAF50),
                                border: Border.symmetric(horizontal: BorderSide(color: Color(0xFF4CAF50), width: 1)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("■", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
                                  SizedBox(width: 12),
                                  Text(
                                    "C L A N   C O N N E C T",
                                    style: TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 4.0),
                                  ),
                                  SizedBox(width: 12),
                                  Text("■", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 10)),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // GIAO DIỆN NHẬP CODE ĐỒNG BỘ Y HỆT TERMINAL INPUT AREA (DÁN JSON)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "T H Ê M   C L A N   T H E O   D Õ I",
                                  style: TextStyle(color: Color(0xFF555555), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 3.0),
                                ),
                                const SizedBox(height: 12),

                                // KHUNG NHẬP LIỆU LỚN
                                Container(
                                  height: 110, // Chiều cao giống khung dán JSON
                                  color: const Color(0xFF111111), // Màu xám đen
                                  child: Stack(
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.all(12.0),
                                        child: TextField(
                                          controller: _tagController,
                                          enabled: !_isLoading,
                                          maxLines: null,
                                          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontFamily: 'Courier'),
                                          textCapitalization: TextCapitalization.characters,
                                          decoration: const InputDecoration.collapsed(
                                            hintText: "DÁN MÃ TAG VÀO ĐÂY (VD: #2YGYCUCC8)...",
                                            hintStyle: TextStyle(color: Color(0xFF444444), fontSize: 12),
                                          ),
                                        ),
                                      ),
                                      // NÚT DÁN Ở GÓC TRÊN BÊN PHẢI NHƯ MÀN HÌNH LOCAL
                                      Positioned(
                                        top: 10,
                                        right: 10,
                                        child: InkWell(
                                          onTap: _pasteFromClipboard,
                                          child: Container(
                                            color: const Color(0xFF333333),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                            child: const Text("DÁN", style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 11)),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // NÚT XÁC NHẬN DÍNH LIỀN BÊN DƯỚI
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF4CAF50), // Màu xanh lá đặc trưng của màn Online
                                      disabledBackgroundColor: const Color(0xFF222222),
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                      elevation: 0,
                                    ),
                                    onPressed: _isLoading ? null : _addNewClan,
                                    child: _isLoading
                                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                                        : const Text("X Á C   N H Ậ N   ►", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 3.0)),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 30),

                            // DANH SÁCH CLAN ĐÃ LƯU
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4.0),
                              child: Text("> DANH SÁCH CLAN:", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                            const SizedBox(height: 12),

                            if (_savedClans.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(border: Border.all(color: const Color(0xFF333333), style: BorderStyle.solid), color: const Color(0xFF141615)),
                                child: const Center(
                                  child: Text("CHƯA CÓ CLAN NÀO ĐƯỢC THÊM.", textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF666666), fontSize: 12, height: 1.5)),
                                ),
                              )
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _savedClans.length,
                                itemBuilder: (context, index) {
                                  final clan = _savedClans[index];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF333333), width: 1), color: const Color(0xFF141615)),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: _isLoading ? null : () => _openWarDashboard(clan['tag'], clan['name']),
                                        splashColor: const Color(0x334CAF50),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12.0),
                                          child: Row(
                                            children: [
                                              // LOGO CLAN
                                              Container(
                                                width: 45, height: 45,
                                                decoration: const BoxDecoration(color: Color(0xFF0A0C0B)),
                                                child: clan['badgeUrl'].toString().isNotEmpty
                                                    ? Image.network(clan['badgeUrl'], errorBuilder: (c, e, s) => const Icon(Icons.shield, color: Color(0xFF4CAF50)))
                                                    : const Icon(Icons.shield, color: Color(0xFF4CAF50)),
                                              ),
                                              const SizedBox(width: 16),
                                              // THÔNG TIN
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(clan['name'], style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 16, fontWeight: FontWeight.bold)),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Text(clan['tag'], style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontFamily: 'Courier')),
                                                        const Text("  |  ", style: TextStyle(color: Color(0xFF444444))),
                                                        Text("Lv.${clan['clanLevel']}", style: const TextStyle(color: Color(0xFFE2B714), fontSize: 12, fontWeight: FontWeight.bold)),
                                                      ],
                                                    )
                                                  ],
                                                ),
                                              ),
                                              // NÚT XÓA
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline, color: Color(0xFFB54545), size: 22),
                                                onPressed: () => _deleteClan(clan['tag']),
                                              )
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    // KHUNG TRẠNG THÁI CUỐI CÙNG (CÙNG VỊ TRÍ, BỐ CỤC Y HỆT TERMINAL SCREEN)
                    Row(
                      children: [
                        Expanded(
                          child: Text(_statusText, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.clip, maxLines: 1),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _showCursor,
                          builder: (context, show, child) => Opacity(
                            opacity: show ? 1.0 : 0.0,
                            child: const Text("█", style: TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
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