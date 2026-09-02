import 'package:flutter/material.dart';
import 'dart:async';
import '../screens/cwl_match_detail_screen.dart';

class WarDashboardWidget extends StatefulWidget {
  final Map<String, dynamic> warData;
  final String myClanTag;

  const WarDashboardWidget({
    super.key,
    required this.warData,
    required this.myClanTag,
  });

  @override
  State<WarDashboardWidget> createState() => _WarDashboardWidgetState();
}

class _WarDashboardWidgetState extends State<WarDashboardWidget> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  DateTime _parseCocDate(String input) {
    try {
      if (input.length >= 15 && input.contains('T')) {
        String clean = input.replaceAll('.000Z', '').replaceAll('Z', '');
        String y = clean.substring(0, 4);
        String m = clean.substring(4, 6);
        String d = clean.substring(6, 8);
        String h = clean.substring(9, 11);
        String min = clean.substring(11, 13);
        String sec = clean.substring(13, 15);
        return DateTime.parse('$y-$m-${d}T$h:$min:${sec}Z').toLocal();
      }
    } catch (e) {
      debugPrint("Lỗi Parse Date: $e");
    }
    return DateTime.now();
  }

  String _formatTimeLeft(DateTime endTime) {
    Duration diff = endTime.difference(_now);
    if (diff.isNegative) return "00h 00m 00s";
    return "${diff.inHours.toString().padLeft(2, '0')}h ${(diff.inMinutes % 60).toString().padLeft(2, '0')}m ${(diff.inSeconds % 60).toString().padLeft(2, '0')}s";
  }

  bool _isMyClan(Map<String, dynamic>? clanNode) {
    if (clanNode == null) return false;
    String nodeTag = clanNode['tag']?.toString().toUpperCase() ?? '';
    String cleanMy = widget.myClanTag.replaceAll('#', '').toUpperCase();
    return nodeTag.replaceAll('#', '') == cleanMy;
  }

  Widget _buildRegularWar() {
    final data = widget.warData['data'] ?? {};
    final state = data['state'] ?? 'unknown';

    if (state == 'notInWar') {
      return _buildMessage("CLAN ĐANG NGHỈ NGƠI (KHÔNG CÓ WAR)");
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderTitle("WAR THƯỜNG (2 NGÀY)"),
          _buildRegularWarStats(data, data['attacksPerMember'] ?? 2),
        ],
      ),
    );
  }

  Widget _buildRegularWarStats(Map<String, dynamic> warNode, int attacksPerMember) {
    final state = warNode['state'];
    String endTimeStr = warNode['endTime'] ?? '';
    if (state == 'preparation') endTimeStr = warNode['startTime'] ?? '';

    DateTime targetTime = _parseCocDate(endTimeStr);

    var myClan = _isMyClan(warNode['clan']) ? warNode['clan'] : warNode['opponent'];
    var enemyClan = _isMyClan(warNode['clan']) ? warNode['opponent'] : warNode['clan'];

    if (myClan == null || enemyClan == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      color: const Color(0xFF141615),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                state == 'preparation' ? "ĐANG CHUẨN BỊ" : (state == 'warEnded' ? "ĐÃ KẾT THÚC" : "ĐANG ĐÁNH"),
                style: TextStyle(color: state == 'preparation' ? const Color(0xFFE2B714) : (state == 'warEnded' ? const Color(0xFF666666) : const Color(0xFF4CAF50)), fontWeight: FontWeight.bold, fontSize: 13),
              ),
              Text(
                state == 'warEnded' ? "" : _formatTimeLeft(targetTime),
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'Courier'),
              ),
            ],
          ),
          const Divider(color: Color(0xFF333333), height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: _buildClanScore(myClan, true)),
              const Text("  VS  ", style: TextStyle(color: Color(0xFF666666), fontWeight: FontWeight.bold)),
              Expanded(child: _buildClanScore(enemyClan, false)),
            ],
          ),

          if (state == 'inWar') ...[
            const Divider(color: Color(0xFF333333), height: 24),
            Text("> DANH SÁCH CHƯA ĐÁNH XONG:", style: const TextStyle(color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
            const SizedBox(height: 8),
            _buildMissingAttacks(myClan['members'] ?? [], attacksPerMember),
          ]
        ],
      ),
    );
  }

  Widget _buildMissingAttacks(List<dynamic> members, int attacksPerMember) {
    List<Widget> missingList = [];
    members.sort((a, b) => (a['mapPosition'] ?? 99).compareTo(b['mapPosition'] ?? 99));

    for (var m in members) {
      int attacksUsed = m['attacks']?.length ?? 0;
      if (attacksUsed < attacksPerMember) {
        missingList.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Row(
                children: [
                  Text("[${m['mapPosition']}] ", style: const TextStyle(color: Color(0xFF666666), fontSize: 12)),
                  Expanded(child: Text(m['name'] ?? '', style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13))),
                  Text(
                      "$attacksUsed/$attacksPerMember lượt",
                      style: TextStyle(color: attacksUsed == 0 ? const Color(0xFFB54545) : const Color(0xFFE2B714), fontSize: 12, fontWeight: FontWeight.bold)
                  ),
                ],
              ),
            )
        );
      }
    }
    if (missingList.isEmpty) return const Text("> TUYỆT VỜI! MỌI NGƯỜI ĐÃ ĐÁNH HẾT.", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 12, fontWeight: FontWeight.bold));
    return Column(children: missingList);
  }

  Widget _buildClanScore(Map<String, dynamic> clan, bool isMine) {
    int stars = clan['stars'] ?? 0;
    double percent = (clan['destructionPercentage'] ?? 0).toDouble();
    String name = clan['name'] ?? 'Unknown';

    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(name, style: TextStyle(color: isMine ? const Color(0xFF4CAF50) : const Color(0xFFB54545), fontWeight: FontWeight.bold, fontSize: 14), overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Color(0xFFE2B714), size: 14),
            Text(" $stars", style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
        Text("${percent.toStringAsFixed(1)}%", style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
      ],
    );
  }

  Widget _buildCwlWar() {
    final Map<String, dynamic>? groupData = widget.warData['groupData'];

    if (groupData == null || groupData.isEmpty) {
      return _buildMessage("DỮ LIỆU CWL TRỐNG HOẶC CHƯA BẮT ĐẦU");
    }

    final List<dynamic> clans = groupData['clans'] ?? [];
    if (clans.isEmpty) {
      return _buildMessage("KHÔNG TÌM THẤY DANH SÁCH 8 CLAN TRONG BẢNG");
    }

    Set<int> allThs = {};
    Map<String, Map<int, int>> clanRawCounts = {};

    for (var clan in clans) {
      String tag = clan['tag']?.toString() ?? '';
      clanRawCounts[tag] = {};

      final members = clan['members'] as List<dynamic>? ?? [];
      for (var m in members) {
        int th = m['townHallLevel'] ?? 0;
        if (th > 0) {
          allThs.add(th);
          clanRawCounts[tag]![th] = (clanRawCounts[tag]![th] ?? 0) + 1;
        }
      }
    }

    List<int> sortedTh = allThs.toList()..sort((a, b) => b.compareTo(a));
    List<String> thColumns = [];
    int cutoffTh = 0;

    int maxSpecificCols = 6;
    if (sortedTh.length <= maxSpecificCols + 1) {
      thColumns = sortedTh.map((e) => e.toString()).toList();
    } else {
      for (int i = 0; i < maxSpecificCols; i++) {
        thColumns.add(sortedTh[i].toString());
      }
      cutoffTh = sortedTh[maxSpecificCols];
      thColumns.add("≤$cutoffTh");
    }

    Map<String, Map<String, int>> processedCounts = {};
    Map<String, int> columnMax = {};
    for (var col in thColumns) {
      columnMax[col] = 0;
    }

    for (var clan in clans) {
      String tag = clan['tag']?.toString() ?? '';
      processedCounts[tag] = {};
      for (var col in thColumns) {
        processedCounts[tag]![col] = 0;
      }

      clanRawCounts[tag]?.forEach((th, count) {
        if (thColumns.contains(th.toString())) {
          processedCounts[tag]![th.toString()] = count;
        } else {
          processedCounts[tag]!["≤$cutoffTh"] = (processedCounts[tag]!["≤$cutoffTh"] ?? 0) + count;
        }
      });

      for (var col in thColumns) {
        if (processedCounts[tag]![col]! > columnMax[col]!) {
          columnMax[col] = processedCounts[tag]![col]!;
        }
      }
    }

    int nameFlex = 8;
    int colFlex = thColumns.length > 5 ? 2 : 3;
    double fontSizeCol = thColumns.length > 5 ? 11 : 13;
    double fontSizeHead = thColumns.length > 5 ? 9 : 10;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0A0C0B),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            child: Column(
              children: [
                Container(
                  color: const Color(0xFF141615),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: nameFlex,
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                            decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFF333333), width: 1))),
                            child: const Text("TÊN HỘI", style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1.0)),
                          ),
                        ),
                        ...thColumns.map((col) => Expanded(
                          flex: colFlex,
                          child: Center(child: Text(col.startsWith('≤') ? col : "TH$col", style: TextStyle(color: const Color(0xFF888888), fontWeight: FontWeight.bold, fontSize: fontSizeHead))),
                        )),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFF333333)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: clans.map((clan) {
                        String tag = clan['tag']?.toString() ?? '';
                        bool isMine = _isMyClan(clan);

                        return Container(
                          decoration: BoxDecoration(
                            color: isMine ? const Color(0x224CAF50) : Colors.transparent,
                            border: const Border(bottom: BorderSide(color: Color(0xFF1A1C1B), width: 1)),
                          ),
                          child: IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: nameFlex,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                                    decoration: const BoxDecoration(border: Border(right: BorderSide(color: Color(0xFF333333), width: 1))),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 18, height: 18,
                                          child: Image.network(
                                            clan['badgeUrls']?['small'] ?? '',
                                            errorBuilder: (c, e, s) => const Icon(Icons.shield, size: 14, color: Colors.grey),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            clan['name'] ?? 'Unknown',
                                            style: TextStyle(
                                              color: isMine ? const Color(0xFF4CAF50) : const Color(0xFFE0E0E0),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                            maxLines: 1, overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                ...thColumns.map((col) {
                                  int count = processedCounts[tag]![col] ?? 0;
                                  bool isMax = count > 0 && count == columnMax[col];

                                  return Expanded(
                                    flex: colFlex,
                                    child: Center(
                                      child: Text(
                                        count > 0 ? count.toString() : "-",
                                        style: TextStyle(
                                          color: isMax ? const Color(0xFFE2B714) : (count > 0 ? const Color(0xFFE0E0E0) : const Color(0xFF444444)),
                                          fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                                          fontSize: fontSizeCol,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CwlMatchDetailScreen(
                  allWars: widget.warData['allWars'] ?? [],
                  allGroupWars: widget.warData['allGroupWars'] ?? [], // TRUYỀN TOÀN BỘ 28 TRẬN
                  groupData: widget.warData['groupData'] ?? {},        // TRUYỀN DỮ LIỆU GROUP
                  myTag: widget.myClanTag,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: Colors.green,
            alignment: Alignment.center,
            child: const Text(
              "[ XEM CHI TIẾT TRẬN ĐẤU ]",
              style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, letterSpacing: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderTitle(String title) {
    return Column(
      children: [
        const Icon(Icons.shield, color: Color(0xFF4CAF50), size: 32),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMessage(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(msg, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888888), fontSize: 14)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.warData['type'];

    if (type == 'CWL') {
      return Container(
        color: const Color(0xFF0A0C0B),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                color: const Color(0xFF141615),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.arrow_back, color: Color(0xFF4CAF50)),
                    ),
                    const SizedBox(width: 16),
                    const Text("CLAN WAR LEAGUE", style: TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ],
                ),
              ),
              Expanded(child: Padding(padding: const EdgeInsets.all(12.0), child: _buildCwlWar())),
            ],
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C0B),
        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: type == 'REGULAR' ? _buildRegularWar() : _buildMessage("KHÔNG CÓ DỮ LIỆU WAR CHO CLAN NÀY"),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF4CAF50)),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("ĐÓNG [ X ]", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}