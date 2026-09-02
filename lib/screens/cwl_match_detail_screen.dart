import 'package:flutter/material.dart';

class CwlMatchDetailScreen extends StatefulWidget {
  final List<dynamic> allWars;
  final List<dynamic> allGroupWars;
  final Map<String, dynamic> groupData;
  final String myTag;

  const CwlMatchDetailScreen({
    super.key,
    required this.allWars,
    this.allGroupWars = const [],
    this.groupData = const {},
    required this.myTag,
  });

  @override
  State<CwlMatchDetailScreen> createState() => _CwlMatchDetailScreenState();
}

class _CwlMatchDetailScreenState extends State<CwlMatchDetailScreen> {
  int selectedRound = 0;
  List<Map<String, dynamic>> sevenDaysData = [];

  // MA TRẬN ROUND-ROBIN CHUẨN CỦA SUPERCELL (0-indexed cho 8 Clan)
  final List<List<List<int>>> cwlMatrix = [
    [[0, 5], [1, 2], [3, 7], [4, 6]], // Ngày 1
    [[0, 7], [1, 6], [2, 5], [3, 4]], // Ngày 2
    [[0, 4], [1, 7], [2, 6], [3, 5]], // Ngày 3
    [[0, 1], [2, 7], [3, 6], [4, 5]], // Ngày 4
    [[0, 3], [1, 5], [2, 4], [6, 7]], // Ngày 5
    [[0, 6], [1, 4], [2, 3], [5, 7]], // Ngày 6
    [[0, 2], [1, 3], [4, 7], [5, 6]], // Ngày 7
  ];

  @override
  void initState() {
    super.initState();
    _buildSevenDaysSchedule();
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

  void _buildSevenDaysSchedule() {
    List<dynamic> realWars = widget.allWars.where((w) => w != null && w['startTime'] != null).toList();
    realWars.sort((a, b) => _parseCocDate(a['startTime']).compareTo(_parseCocDate(b['startTime'])));

    String cleanMyTag = widget.myTag.replaceAll('#', '').toUpperCase();

    // Lấy teamSize từ trận đánh thực tế (nếu có) để đảm bảo bắt được 30v30, nếu không mới lấy mặc định từ groupData
    int teamSize = 15;
    if (realWars.isNotEmpty && realWars.last['teamSize'] != null) {
      teamSize = realWars.last['teamSize'] as int;
    } else if (widget.groupData['teamSize'] != null) {
      teamSize = widget.groupData['teamSize'] as int;
    }

    // 1. Lưu lại đội hình hiện tại của phe mình, ép kiểu rõ ràng để tránh lỗi Type Casting
    Map<String, dynamic> latestMyWarLineup = {'name': 'Unknown', 'tag': widget.myTag, 'members': []};
    if (realWars.isNotEmpty) {
      var lastWar = Map<String, dynamic>.from(realWars.last as Map);
      String tagC = lastWar['clan']['tag'].toString().replaceAll('#', '').toUpperCase();
      latestMyWarLineup = Map<String, dynamic>.from((tagC == cleanMyTag) ? lastWar['clan'] : lastWar['opponent']);
    } else if (widget.groupData['clans'] != null) {
      var myClanGroup = widget.groupData['clans'].firstWhere(
              (c) => c['tag']?.toString().replaceAll('#', '').toUpperCase() == cleanMyTag,
          orElse: () => null
      );
      if (myClanGroup != null) {
        latestMyWarLineup = _normalizeGroupMembers(myClanGroup, teamSize);
      }
    }

    // 2. Tìm vị trí (Index) của Clan mình trong mảng 8 Clan của Group
    List<dynamic> clans = widget.groupData['clans'] ?? [];
    int myIndex = clans.indexWhere((c) {
      String tag = c['tag']?.toString().replaceAll('#', '').toUpperCase() ?? '';
      return tag == cleanMyTag;
    });

    int autoSelectIndex = 0;
    bool foundPrep = false;

    // 3. Xây dựng đúng 7 ngày theo Ma Trận
    for (int day = 0; day < 7; day++) {
      if (day < realWars.length) {
        // DỮ LIỆU THỰC TẾ
        var actualWar = Map<String, dynamic>.from(realWars[day] as Map);
        sevenDaysData.add(actualWar);

        if (actualWar['state'] == 'preparation') {
          autoSelectIndex = day;
          foundPrep = true;
        } else if (actualWar['state'] == 'inWar' && !foundPrep) {
          autoSelectIndex = day;
        }
      } else {
        // NGÀY TƯƠNG LAI DỰ ĐOÁN
        int oppIndex = -1;
        if (myIndex != -1 && clans.length == 8) {
          for (var pair in cwlMatrix[day]) {
            if (pair[0] == myIndex) {
              oppIndex = pair[1];
            } else if (pair[1] == myIndex) {
              oppIndex = pair[0];
            }
          }
        }

        String oppTag = "";
        if (oppIndex != -1 && clans.length > oppIndex) {
          oppTag = (clans[oppIndex]['tag'] ?? '').toString().toUpperCase();
        }

        // Tìm trong lịch sử war (nếu có trận trùng đối thủ)
        dynamic latestEnemyLineup;
        if (oppTag.isNotEmpty && widget.allGroupWars.isNotEmpty) {
          List<dynamic> enemyWars = widget.allGroupWars.where((w) {
            if (w == null || w.isEmpty) return false;
            String cTag = (w['clan']?['tag'] ?? '').toString().toUpperCase();
            String oTag = (w['opponent']?['tag'] ?? '').toString().toUpperCase();
            return cTag == oppTag || oTag == oppTag;
          }).toList();

          if (enemyWars.isNotEmpty) {
            enemyWars.sort((a, b) => _parseCocDate(a['startTime']).compareTo(_parseCocDate(b['startTime'])));
            var latestEnemyWar = Map<String, dynamic>.from(enemyWars.last as Map);
            String cTag = (latestEnemyWar['clan']?['tag'] ?? '').toString().toUpperCase();
            latestEnemyLineup = Map<String, dynamic>.from((cTag == oppTag) ? latestEnemyWar['clan'] : latestEnemyWar['opponent']);
          }
        }

        Map<String, dynamic> enemyClanData;
        if (latestEnemyLineup != null && (latestEnemyLineup['members'] as List).isNotEmpty) {
          enemyClanData = latestEnemyLineup;
        } else if (oppIndex != -1 && clans.length > oppIndex) {
          // KHẮC PHỤC LỖI THIẾU THÔNG TIN: Chuẩn hóa dữ liệu từ Group API
          enemyClanData = _normalizeGroupMembers(clans[oppIndex], teamSize);
        } else {
          enemyClanData = {'name': 'Đang tính...', 'tag': '---', 'members': []};
        }

        sevenDaysData.add(<String, dynamic>{
          'state': 'future',
          'clan': latestMyWarLineup,
          'opponent': enemyClanData,
          'teamSize': teamSize,
        });
      }
    }

    if (realWars.isNotEmpty && !foundPrep && realWars.every((w) => w['state'] == 'warEnded')) {
      autoSelectIndex = realWars.length - 1;
    }
    selectedRound = autoSelectIndex;
  }

  // Hàm phụ trợ giúp chuẩn hóa danh sách thành viên (Fix mapPosition và Type Casting)
  Map<String, dynamic> _normalizeGroupMembers(dynamic clanGroupData, int teamSize) {
    var rawClan = Map<String, dynamic>.from(clanGroupData as Map);
    List<dynamic> rawMembers = List.from(rawClan['members'] ?? []);

    // FIX LỖI ÉP KIỂU: Tạo Map<String, dynamic> rõ ràng thay vì trải mảng (...m) tạo ra Map<dynamic, dynamic>
    List<Map<String, dynamic>> normalizedMembers = rawMembers.map((m) {
      Map<String, dynamic> memberMap = Map<String, dynamic>.from(m as Map);
      // Fix lỗi Supercell Group API trả về 'townHallLevel' thay vì 'townhallLevel'
      memberMap['townhallLevel'] = memberMap['townhallLevel'] ?? memberMap['townHallLevel'] ?? 1;
      return memberMap;
    }).toList();

    // Xếp các thành viên có Hall cao nhất lên trước làm giả định mapPosition
    normalizedMembers.sort((a, b) => (b['townhallLevel'] as int).compareTo(a['townhallLevel'] as int));

    if (normalizedMembers.length > teamSize) {
      normalizedMembers = normalizedMembers.sublist(0, teamSize);
    }

    for (int i = 0; i < normalizedMembers.length; i++) {
      normalizedMembers[i]['mapPosition'] = i + 1;
    }

    rawClan['members'] = normalizedMembers;
    return rawClan;
  }

  @override
  Widget build(BuildContext context) {
    if (sevenDaysData.isEmpty) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(title: const Text("CHI TIẾT TRẬN ĐẤU"), backgroundColor: Colors.black),
        body: const Center(child: Text("Đang tải dữ liệu...", style: TextStyle(color: Colors.green))),
      );
    }

    dynamic dayData = sevenDaysData[selectedRound];
    bool isFuture = dayData['state'] == 'future';

    String cleanMyTag = widget.myTag.replaceAll('#', '').toUpperCase();
    dynamic myClan;
    dynamic enemyClan;

    if (isFuture) {
      myClan = dayData['clan'];
      enemyClan = dayData['opponent'];
    } else {
      String clan1Tag = (dayData['clan']['tag'] ?? '').toString().replaceAll('#', '').toUpperCase();
      bool isMyClan1 = clan1Tag == cleanMyTag;
      myClan = isMyClan1 ? dayData['clan'] : dayData['opponent'];
      enemyClan = isMyClan1 ? dayData['opponent'] : dayData['clan'];
    }

    int teamSize = dayData['teamSize'] ?? 15;

    List<dynamic> myMembers = List.from(myClan['members'] ?? []);
    List<dynamic> enemyMembers = List.from(enemyClan['members'] ?? []);

    // Sắp xếp theo chuẩn mapPosition để khớp hàng tuyệt đối
    myMembers.sort((a, b) => (a['mapPosition'] ?? 999).compareTo(b['mapPosition'] ?? 999));
    enemyMembers.sort((a, b) => (a['mapPosition'] ?? 999).compareTo(b['mapPosition'] ?? 999));

    if (myMembers.length > teamSize) myMembers = myMembers.sublist(0, teamSize);
    if (enemyMembers.length > teamSize) enemyMembers = enemyMembers.sublist(0, teamSize);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text("CHI TIẾT ĐỘI HÌNH", style: TextStyle(fontFamily: 'Courier', fontSize: 18, color: Colors.green)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.green),
      ),
      body: Column(
        children: [
          Container(
            height: 50,
            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.green.withValues(alpha: 0.5)))),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              itemBuilder: (context, index) {
                bool isSelected = index == selectedRound;
                return GestureDetector(
                  onTap: () => setState(() => selectedRound = index),
                  child: Container(
                    width: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green.withValues(alpha: 0.2) : Colors.transparent,
                      border: isSelected ? const Border(bottom: BorderSide(color: Colors.green, width: 3)) : null,
                    ),
                    child: Text(
                      "${index + 1}",
                      style: TextStyle(
                        color: isSelected ? Colors.green : Colors.grey,
                        fontSize: 20,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Ngày ${selectedRound + 1}${isFuture ? ' (Tiên tri)' : ''}",
              style: TextStyle(color: isFuture ? Colors.orange : Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),

          Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.blueAccent.withValues(alpha: 0.4),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(
                    children: [
                      Text(myClan['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                      Text(myClan['tag'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  color: Colors.deepOrange.withValues(alpha: 0.7),
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                  child: Column(
                    children: [
                      Text(enemyClan['name'] ?? "Unknown", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15), overflow: TextOverflow.ellipsis),
                      Text(enemyClan['tag'] ?? "", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),

          Expanded(
            child: ListView.builder(
              itemCount: teamSize,
              itemBuilder: (context, i) {
                dynamic me = i < myMembers.length ? myMembers[i] : null;
                dynamic enemy = i < enemyMembers.length ? enemyMembers[i] : null;

                return Container(
                  color: i % 2 == 0 ? Colors.white.withValues(alpha: 0.05) : Colors.transparent,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          me != null ? me['name'] : "---",
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Expanded(
                        flex: 1,
                        child: Text(
                          me != null ? "${me['townhallLevel']}" : "-",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.lightBlueAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: Text(
                          enemy != null ? "${enemy['townhallLevel']}" : "-",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Text(
                          enemy != null ? enemy['name'] : "---",
                          textAlign: TextAlign.right,
                          style: const TextStyle(color: Colors.white, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}