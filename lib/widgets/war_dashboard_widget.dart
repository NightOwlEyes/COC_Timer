import 'package:flutter/material.dart';
import '../screens/war_detail_screen.dart';

/* STREAMING_CHUNK: Khởi tạo WarDashboardWidget và timer cập nhật thời gian... */
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

  bool _isMyClan(Map<String, dynamic>? clanNode) {
    if (clanNode == null) {
      return false;
    }
    String nodeTag = clanNode['tag']?.toString().toUpperCase() ?? '';
    String cleanMy = widget.myClanTag.replaceAll('#', '').toUpperCase();
    return nodeTag.replaceAll('#', '') == cleanMy;
  }

/* STREAMING_CHUNK: Xây dựng bảng phân tích CWL (Clan War League)... */
  Widget _buildCwlWar() {
    final Map<String, dynamic>? groupData = widget.warData['groupData'];

    if (groupData == null || groupData.isEmpty) {
      return _buildMessage("> DỮ LIỆU CWL TRỐNG");
    }

    final List<dynamic> clans = groupData['clans'] ?? [];

    if (clans.isEmpty) {
      return _buildMessage("> KHÔNG TÌM THẤY DANH SÁCH CLAN");
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

    List<int> sortedTh = allThs.toList()
      ..sort((a, b) => b.compareTo(a));
    List<String> thColumns = [];
    int cutoffTh = 0;
    int maxCols = 5;

    if (sortedTh.length <= maxCols + 1) {
      thColumns = sortedTh.map((e) => e.toString()).toList();
    } else {
      for (int i = 0; i < maxCols; i++) {
        thColumns.add(sortedTh[i].toString());
      }
      cutoffTh = sortedTh[maxCols];
      thColumns.add("<$cutoffTh");
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
          String key = thColumns.last;
          processedCounts[tag]![key] =
              (processedCounts[tag]![key] ?? 0) + count;
        }
      });
      for (var col in thColumns) {
        if (processedCounts[tag]![col]! > columnMax[col]!) {
          columnMax[col] = processedCounts[tag]![col]!;
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionHeader("CLAN WAR LEAGUE - PHÂN TÍCH ĐỘI HÌNH"),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          color: const Color(0xFF141615),
          child: Row(
            children: [
              const Expanded(flex: 4,
                  child: Text("TÊN HỘI", style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 10,
                      fontWeight: FontWeight.bold))),
              ...thColumns.map((col) =>
                  Expanded(
                    child: Center(child: Text(
                        col.contains('<') ? col : "TH$col",
                        style: const TextStyle(color: Color(0xFF666666),
                            fontSize: 10,
                            fontWeight: FontWeight.bold))),
                  )),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: clans.length,
            itemBuilder: (ctx, i) {
              var clan = clans[i];
              String tag = clan['tag']?.toString() ?? '';
              bool isMine = _isMyClan(clan);

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                decoration: BoxDecoration(
                  color: isMine ? const Color(0x224CAF50) : (i % 2 == 0
                      ? const Color(0xFF0D0F0E)
                      : Colors.transparent),
                  border: const Border(
                      bottom: BorderSide(color: Color(0xFF1A1C1B), width: 1)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: Text(
                        clan['name'] ?? 'Unknown',
                        style: TextStyle(color: isMine
                            ? const Color(0xFF4CAF50)
                            : const Color(0xFFE0E0E0),
                            fontSize: 11,
                            fontWeight: isMine ? FontWeight.bold : FontWeight
                                .normal),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    ...thColumns.map((col) {
                      int count = processedCounts[tag]![col] ?? 0;
                      bool isMax = count > 0 && count == columnMax[col];
                      return Expanded(
                        child: Center(
                          child: Text(
                            count > 0 ? count.toString() : ".",
                            style: TextStyle(color: isMax
                                ? const Color(0xFFE2B714)
                                : (count > 0
                                ? const Color(0xFF888888)
                                : const Color(0xFF333333)), fontSize: 11),
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => WarDetailScreen(
                  // Chỉ việc quăng cục warData tổng và Tag vào, file kia tự lo
                  apiResult: widget.warData,
                  myTag: widget.myClanTag,
                ),
              ),
            );
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF4CAF50), width: 1.5),
              color: const Color(0xFF141615),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, color: Color(0xFF4CAF50),
                    size: 16),
                SizedBox(width: 8),
                Text(
                  "TRUY XUẤT CHI TIẾT TRẬN ĐẤU",
                  style: TextStyle(color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.0),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF333333), width: 1)),
      ),
      child: Text(
        title,
        style: const TextStyle(
            color: Color(0xFF4CAF50),
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

// ... existing code ...
  Widget _buildMessage(String msg) {
    return Center(
      child: Text(
        msg,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF444444), fontSize: 13),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.warData['type'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C0B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          // Thu nhỏ lề từ 16.0 xuống 8.0 để max diện tích
          child: Column( // Đã lột bỏ CustomPaint và Padding thừa ở đây
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    child: const Row(
                      children: [
                        Icon(Icons.arrow_back_ios, color: Color(0xFF666666),
                            size: 12),
                        SizedBox(width: 4),
                        Text(
                          "TRỞ VỀ",
                          style: TextStyle(color: Color(0xFF666666),
                              fontSize: 11,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    "DASHBOARD://CLAN_WAR",
                    style: TextStyle(color: Color(0xFF444444),
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: type == 'CWL'
                      ? _buildCwlWar() // Nếu là CWL thì build ma trận 7 ngày
                      : _buildMessage(
                      "> KHÔNG TÌM THẤY DỮ LIỆU WAR"), // Còn lại báo lỗi luôn vì War thường đã bị rẽ nhánh từ ngoài rồi
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}