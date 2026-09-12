import 'package:flutter/material.dart';
import 'dart:async';
import '../utils/app_strings.dart';

class WarDetailScreen extends StatefulWidget {
  final Map<String, dynamic> apiResult;
  final String myTag;

  const WarDetailScreen({
    super.key,
    required this.apiResult,
    required this.myTag,
  });

  @override
  State<WarDetailScreen> createState() => _WarDetailScreenState();
}

class _WarDetailScreenState extends State<WarDetailScreen> {
  int selectedRound = 0;
  List<dynamic> roundsData = [];
  Timer? _countdownTimer;
  bool isCwl = false;
  int attacksPerMember = 2; // Mặc định cho War thường là 2

  // Ma trận chuẩn Supercell Round-Robin (Dành riêng cho CWL)
  final List<List<List<int>>> cwlMatrix = [
    [[0, 5], [1, 2], [3, 7], [4, 6]],
    [[0, 7], [1, 6], [2, 5], [3, 4]],
    [[0, 4], [1, 7], [2, 6], [3, 5]],
    [[0, 1], [2, 7], [3, 6], [4, 5]],
    [[0, 3], [1, 5], [2, 4], [6, 7]],
    [[0, 6], [1, 4], [2, 3], [5, 7]],
    [[0, 2], [1, 3], [4, 7], [5, 6]],
  ];

  @override
  void initState() {
    super.initState();
    isCwl = widget.apiResult['type'] == 'CWL';

    if (isCwl) {
      attacksPerMember = 1; // CWL mặc định 1 turn đánh
      _buildSevenDaysSchedule();
    } else {
      dynamic data = widget.apiResult['data'];
      attacksPerMember = data['attacksPerMember'] ?? 2;
      roundsData.add(data); // War thường chỉ có 1 trận duy nhất
    }

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
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

  void _buildSevenDaysSchedule() {
    List<dynamic> allWars = widget.apiResult['allWars'] ?? [];
    List<dynamic> allGroupWars = widget.apiResult['allGroupWars'] ?? [];
    Map<String, dynamic> groupData = widget.apiResult['groupData'] ?? {};

    List<dynamic> realWars = allWars.where((w) => w != null && w['startTime'] != null).toList();
    realWars.sort((a, b) => _parseCocDate(a['startTime']).compareTo(_parseCocDate(b['startTime'])));

    String cleanMyTag = widget.myTag.replaceAll('#', '').toUpperCase();

    dynamic latestMyWarLineup = {'name': AppStrings.warDetail.statusUnknown, 'tag': widget.myTag, 'members': []};
    if (realWars.isNotEmpty) {
      var lastWar = realWars.last;
      String tagC = lastWar['clan']['tag'].toString().replaceAll('#', '').toUpperCase();
      latestMyWarLineup = (tagC == cleanMyTag) ? lastWar['clan'] : lastWar['opponent'];
    }

    List<dynamic> clans = groupData['clans'] ?? [];
    int myIndex = clans.indexWhere((c) {
      String tag = c['tag']?.toString().replaceAll('#', '').toUpperCase() ?? '';
      return tag == cleanMyTag;
    });

    int autoSelectIndex = 0;
    bool foundInWar = false;
    int teamSize = realWars.isNotEmpty ? (realWars.first['teamSize'] ?? 15) : (groupData['teamSize'] ?? 15);

    for (int day = 0; day < 7; day++) {
      if (day < realWars.length) {
        var actualWar = realWars[day];
        roundsData.add(actualWar);

        if (actualWar['state'] == 'inWar') {
          autoSelectIndex = day;
          foundInWar = true;
        } else if (actualWar['state'] == 'preparation' && !foundInWar) {
          autoSelectIndex = day;
        }
      } else {
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

        String oppTag = oppIndex != -1 && clans.length > oppIndex ? (clans[oppIndex]['tag'] ?? '').toString().toUpperCase() : "";

        dynamic latestEnemyLineup;
        if (oppTag.isNotEmpty && allGroupWars.isNotEmpty) {
          List<dynamic> enemyWars = allGroupWars.where((w) {
            if (w == null || w.isEmpty) return false;
            return (w['clan']?['tag'] ?? '').toString().toUpperCase() == oppTag || (w['opponent']?['tag'] ?? '').toString().toUpperCase() == oppTag;
          }).toList();

          if (enemyWars.isNotEmpty) {
            enemyWars.sort((a, b) => _parseCocDate(a['startTime']).compareTo(_parseCocDate(b['startTime'])));
            var latestEnemyWar = enemyWars.last;
            latestEnemyLineup = ((latestEnemyWar['clan']?['tag'] ?? '').toString().toUpperCase() == oppTag) ? latestEnemyWar['clan'] : latestEnemyWar['opponent'];
          }
        }

        dynamic enemyClanData = latestEnemyLineup ?? (oppIndex != -1 ? clans[oppIndex] : {'name': AppStrings.warDetail.statusCalculating, 'tag': '---', 'members': []});

        roundsData.add({
          'state': 'future',
          'clan': latestMyWarLineup,
          'opponent': enemyClanData,
          'teamSize': teamSize,
        });
      }
    }

    if (realWars.isNotEmpty && !foundInWar && realWars.every((w) => w['state'] == 'warEnded')) {
      autoSelectIndex = realWars.length - 1;
    }
    selectedRound = autoSelectIndex;
  }

  Widget _buildCountdownText(dynamic dayData) {
    if (dayData == null) return const SizedBox();
    DateTime now = DateTime.now();

    if (dayData['state'] == 'inWar' && dayData['endTime'] != null) {
      DateTime endTime = _parseCocDate(dayData['endTime']);
      Duration diff = endTime.difference(now);

      if (diff.isNegative) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: Color(0xFF666666), size: 14),
            Text(AppStrings.warDetail.statusEndedCalculating, style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
          ],
        );
      }
      String formatted = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}";
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_right, color: Color(0xFFB54545), size: 14),
          Text(AppStrings.format(AppStrings.warDetail.statusEndsIn, {'time': formatted}), style: const TextStyle(color: Color(0xFFB54545), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (dayData['state'] == 'preparation' && dayData['startTime'] != null) {
      DateTime startTime = _parseCocDate(dayData['startTime']);
      Duration diff = startTime.difference(now);

      if (diff.isNegative) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chevron_right, color: Color(0xFF666666), size: 14),
            Text(AppStrings.warDetail.statusPrepCalculating, style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
          ],
        );
      }
      String formatted = "${diff.inHours.toString().padLeft(2, '0')}:${(diff.inMinutes % 60).toString().padLeft(2, '0')}";
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_right, color: Color(0xFFE2B714), size: 14),
          Text(AppStrings.format(AppStrings.warDetail.statusStartsIn, {'time': formatted}), style: const TextStyle(color: Color(0xFFE2B714), fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      );
    } else if (dayData['state'] == 'warEnded') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.chevron_right, color: Color(0xFF666666), size: 14),
          Text(AppStrings.warDetail.statusEnded, style: const TextStyle(color: Color(0xFF666666), fontSize: 11)),
        ],
      );
    }
    return const SizedBox();
  }

  Widget _buildAttackResult(dynamic member, Map<String, int> oppMap, bool isMe) {
    if (member == null || member['attacks'] == null) return const SizedBox();
    List<dynamic> attacks = member['attacks'];

    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: attacks.map((atk) {
        int? targetPos = oppMap[atk['defenderTag']];
        int stars = atk['stars'] ?? 0;
        int pct = atk['destructionPercentage'] ?? 0;

        Widget textW = Text(
          targetPos != null ? "[#$targetPos] ${pct.toString().padLeft(3, ' ')}%" : "${pct.toString().padLeft(3, ' ')}%",
          style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
        );

        Widget starsW = Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            bool filled = i < stars;
            return Icon(
              filled ? Icons.star : Icons.star_border,
              size: 12,
              color: filled ? const Color(0xFFE2B714) : const Color(0xFF444444),
            );
          }),
        );

        return Padding(
          padding: const EdgeInsets.only(top: 2.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: isMe
                ? [textW, const SizedBox(width: 4), starsW]
                : [starsW, const SizedBox(width: 4), textW],
          ),
        );
      }).toList(),
    );
  }

  void _showMissedAttacksDialog(List<dynamic> myMembers, List<dynamic> enemyMembers, String myClanName, String enemyClanName) {
    bool showMyClan = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) {
          List<dynamic> targetMembers = showMyClan ? myMembers : enemyMembers;
          // So sánh với số lượt tấn công quy định
          List<dynamic> missed = targetMembers.where((m) {
            int count = m['attacks'] == null ? 0 : (m['attacks'] as List).length;
            return count < attacksPerMember;
          }).toList();

          return Dialog(
            backgroundColor: const Color(0xFF0A0C0B),
            shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1)),
            insetPadding: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.search, color: Color(0xFFB54545), size: 16),
                          const SizedBox(width: 4),
                          Text(AppStrings.warDetail.dialogTitleMissedAttacks, style: const TextStyle(color: Color(0xFFB54545), fontSize: 13, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      InkWell(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close, color: Color(0xFF666666), size: 18),
                      )
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => setStateSB(() => showMyClan = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: showMyClan ? const Color(0xFF4CAF50).withValues(alpha: 0.2) : Colors.transparent,
                              border: Border.all(color: showMyClan ? const Color(0xFF4CAF50) : const Color(0xFF333333), width: 1),
                            ),
                            child: Text(
                              myClanName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: showMyClan ? const Color(0xFF4CAF50) : const Color(0xFF666666),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: InkWell(
                          onTap: () => setStateSB(() => showMyClan = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: !showMyClan ? const Color(0xFFE2B714).withValues(alpha: 0.1) : Colors.transparent,
                              border: Border.all(color: !showMyClan ? const Color(0xFFE2B714) : const Color(0xFF333333), width: 1),
                            ),
                            child: Text(
                              enemyClanName,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: !showMyClan ? const Color(0xFFE2B714) : const Color(0xFF666666),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (missed.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check_circle_outline, color: Color(0xFF4CAF50), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              showMyClan ? AppStrings.warDetail.dialogMyClanCompleted : AppStrings.warDetail.dialogEnemyCompleted,
                              style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: missed.length,
                        itemBuilder: (c, i) {
                          int atkCount = missed[i]['attacks'] == null ? 0 : (missed[i]['attacks'] as List).length;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 56,
                                  child: Text(
                                    "[#${missed[i]['mapPosition'].toString().padLeft(2, '0')}]",
                                    softWrap: false,
                                    style: const TextStyle(color: Color(0xFF666666), fontSize: 12),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    missed[i]['name'] ?? AppStrings.warDetail.statusUnknown,
                                    style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  AppStrings.format(AppStrings.warDetail.dialogAttacksCount, {'atkCount': atkCount.toString(), 'maxAttacks': attacksPerMember.toString()}),
                                  style: TextStyle(
                                    color: showMyClan ? const Color(0xFF4CAF50) : const Color(0xFFE2B714),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
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
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (roundsData.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A0C0B),
        body: Center(
          child: Text(AppStrings.warDetail.loadingData, style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 12)),
        ),
      );
    }

    dynamic dayData = roundsData[selectedRound];
    bool isFuture = dayData['state'] == 'future';
    bool isWarEnded = dayData['state'] == 'warEnded';

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
    int myStars = myClan['stars'] ?? 0;
    double myPct = (myClan['destructionPercentage'] ?? 0.0).toDouble();
    int enemyStars = enemyClan['stars'] ?? 0;
    double enemyPct = (enemyClan['destructionPercentage'] ?? 0.0).toDouble();

    List<dynamic> myMembers = List.from(myClan['members'] ?? []);
    List<dynamic> enemyMembers = List.from(enemyClan['members'] ?? []);

    myMembers.sort((a, b) => (a['mapPosition'] ?? 999).compareTo(b['mapPosition'] ?? 999));
    enemyMembers.sort((a, b) => (a['mapPosition'] ?? 999).compareTo(b['mapPosition'] ?? 999));

    if (myMembers.length > teamSize) myMembers = myMembers.sublist(0, teamSize);
    if (enemyMembers.length > teamSize) enemyMembers = enemyMembers.sublist(0, teamSize);

    Map<String, int> myTagToPos = {};
    int myTotalAttacks = 0;
    for (int i = 0; i < myMembers.length; i++) {
      if (myMembers[i]['tag'] != null) myTagToPos[myMembers[i]['tag']] = i + 1;
      if (myMembers[i]['attacks'] != null) {
        myTotalAttacks += (myMembers[i]['attacks'] as List).length;
      }
    }

    Map<String, int> enemyTagToPos = {};
    int enemyTotalAttacks = 0;
    for (int i = 0; i < enemyMembers.length; i++) {
      if (enemyMembers[i]['tag'] != null) enemyTagToPos[enemyMembers[i]['tag']] = i + 1;
      if (enemyMembers[i]['attacks'] != null) {
        enemyTotalAttacks += (enemyMembers[i]['attacks'] as List).length;
      }
    }

    int maxAttacks = teamSize * attacksPerMember;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0C0B),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // 1. HEADER
              Align(
                alignment: Alignment.centerLeft,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_back_ios, color: Color(0xFF666666), size: 12),
                      const SizedBox(width: 4),
                      Text(
                        AppStrings.warDetail.btnBack,
                        style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // 2. DAY SELECTOR (Chỉ hiện khi là CWL) - ĐÃ CẬP NHẬT LOGIC MÀU SẮC
              if (isCwl) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    bool isSelected = index == selectedRound;

                    int outcome = 0; // 0: chưa/đang war, 1: thắng, -1: thua, 2: hoà
                    if (index < roundsData.length) {
                      var rData = roundsData[index];
                      if (rData['state'] == 'warEnded') {
                        String c1Tag = (rData['clan']?['tag'] ?? '').toString().replaceAll('#', '').toUpperCase();
                        bool isMine = c1Tag == cleanMyTag;

                        var myC = isMine ? rData['clan'] : rData['opponent'];
                        var enC = isMine ? rData['opponent'] : rData['clan'];

                        if (myC != null && enC != null) {
                          int mS = myC['stars'] ?? 0;
                          double mP = (myC['destructionPercentage'] ?? 0.0).toDouble();
                          int eS = enC['stars'] ?? 0;
                          double eP = (enC['destructionPercentage'] ?? 0.0).toDouble();

                          // Logic tính thắng thua: Sao -> % phá huỷ -> Hoà
                          if (mS > eS) {
                            outcome = 1;
                          } else if (mS < eS) {
                            outcome = -1;
                          } else if (mP > eP) {
                            outcome = 1;
                          } else if (mP < eP) {
                            outcome = -1;
                          } else {
                            outcome = 2;
                          }
                        }
                      }
                    }

                    // Setup màu nền
                    Color? bgColor;
                    if (outcome == 1) {
                      bgColor = const Color(0xFF4CAF50).withValues(alpha: 0.2); // Xanh - Thắng
                    } else if (outcome == -1) {
                      bgColor = const Color(0xFFB54545).withValues(alpha: 0.2); // Đỏ - Thua
                    } else if (outcome == 2) {
                      bgColor = const Color(0xFFE2B714).withValues(alpha: 0.2); // Vàng - Hoà
                    }

                    // Setup màu chữ cho phù hợp với nền
                    Color txtColor = const Color(0xFF888888); // Mặc định cho ngày chưa đánh
                    if (outcome == 1) {
                      txtColor = const Color(0xFF4CAF50);
                    } else if (outcome == -1) {
                      txtColor = const Color(0xFFB54545);
                    } else if (outcome == 2) {
                      txtColor = const Color(0xFFE2B714);
                    } else if (isSelected) {
                      txtColor = const Color(0xFF4CAF50); // Đang chọn & chưa kết thúc
                    }

                    return GestureDetector(
                      onTap: () => setState(() => selectedRound = index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 8),
                        decoration: BoxDecoration(
                          color: bgColor,
                          border: isSelected
                              ? const Border(bottom: BorderSide(color: Color(0xFF4CAF50), width: 2))
                              : null,
                        ),
                        child: Text(
                          "${index + 1}",
                          style: TextStyle(
                            color: txtColor,
                            fontSize: 15,
                            fontWeight: isSelected || outcome != 0 ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 8),
              ],

              // 3. SCOREBOARD BOX
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0C0B),
                  border: Border.all(color: const Color(0xFF333333), width: 1),
                ),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CỘT TRÁI (PHE MÌNH)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start, // Ép sát lề trái
                            children: [
                              Text(
                                myClan['name'] ?? AppStrings.warDetail.labelMe,
                                style: const TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2), // Trả về khoảng cách 2px siêu khít
                              Text(myClan['tag'] ?? "", style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontFamily: 'monospace')),
                              const SizedBox(height: 2),

                              if (!isFuture) ...[
                                Row(
                                  children: [
                                    const Icon(Icons.star, color: Color(0xFFE2B714), size: 18),
                                    const SizedBox(width: 6),
                                    Text(
                                      myStars.toString().padLeft(2, '0'),
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 12),
                                    Text("${myPct.toStringAsFixed(1)}%", style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15)),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$myTotalAttacks/$maxAttacks",
                                  style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                              ]
                            ],
                          ),
                        ),

                        // CHỮ VS Ở GIỮA
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(AppStrings.warDetail.labelVs, style: const TextStyle(color: Color(0xFF555555), fontSize: 14, fontWeight: FontWeight.bold)),
                        ),

                        // CỘT PHẢI (KẺ ĐỊCH)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end, // Ép sát lề phải
                            children: [
                              Text(
                                enemyClan['name'] ?? AppStrings.warDetail.labelEnemy,
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Color(0xFFE2B714), fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.5),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(enemyClan['tag'] ?? "", style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontFamily: 'monospace')),
                              const SizedBox(height: 2),

                              if (!isFuture) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end, // Canh icon Sao về sát mép phải
                                  children: [
                                    Text("${enemyPct.toStringAsFixed(1)}%", style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 15)),
                                    const SizedBox(width: 12),
                                    Text(
                                      enemyStars.toString().padLeft(2, '0'),
                                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.star, color: Color(0xFFE2B714), size: 18),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  "$enemyTotalAttacks/$maxAttacks",
                                  style: TextStyle(color: const Color(0xFFE2B714), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // --- FOOTER: THỜI GIAN KẾT THÚC VÀ TÌM KIẾM ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildCountdownText(dayData),
                        if (dayData['state'] == 'inWar')
                          InkWell(
                            onTap: () => _showMissedAttacksDialog(
                              myMembers,
                              enemyMembers,
                              myClan['name'] ?? AppStrings.warDetail.labelMe,
                              enemyClan['name'] ?? AppStrings.warDetail.labelEnemy,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.search, color: Color(0xFFB54545), size: 15),
                                const SizedBox(width: 4),
                                Text(
                                  AppStrings.warDetail.btnMissedAttacks,
                                  style: const TextStyle(color: Color(0xFFB54545), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                              ],
                            ),
                          )
                        else
                          const SizedBox(), // Spacer trống giữ bố cục nếu không trong war
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 4. DANH SÁCH CHI TIẾT
              Expanded(
                child: Container(
                  decoration: BoxDecoration(border: Border.all(color: const Color(0xFF141615), width: 1)),
                  child: ListView.builder(
                    itemCount: teamSize,
                    itemBuilder: (context, i) {
                      dynamic me = i < myMembers.length ? myMembers[i] : null;
                      dynamic enemy = i < enemyMembers.length ? enemyMembers[i] : null;

                      int meAttacks = me != null && me['attacks'] != null ? (me['attacks'] as List).length : 0;
                      int enemyAttacks = enemy != null && enemy['attacks'] != null ? (enemy['attacks'] as List).length : 0;

                      bool meMissed = isWarEnded && me != null && meAttacks < attacksPerMember;
                      bool enemyMissed = isWarEnded && enemy != null && enemyAttacks < attacksPerMember;

                      return Container(
                        color: i % 2 == 0 ? const Color(0xFF111111) : const Color(0xFF0A0C0B),
                        child: Row(
                          children: [
                            // ===========================
                            // CỘT 1: PHE MÌNH
                            // ===========================
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  border: meMissed ? Border.all(color: const Color(0xFFB54545), width: 1) : null,
                                  color: meMissed ? const Color(0xFFB54545).withValues(alpha: 0.15) : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 26,
                                      child: Text(
                                        "${i + 1}.",
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            me != null ? me['name'] : "---",
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (!isFuture) _buildAttackResult(me, enemyTagToPos, true),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        me != null ? "[${me['townhallLevel']}]" : "[-]",
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Container(width: 1, height: 35, color: const Color(0xFF222222)),

                            // ===========================
                            // CỘT 2: KẺ ĐỊCH
                            // ===========================
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                                decoration: BoxDecoration(
                                  border: enemyMissed ? Border.all(color: const Color(0xFFB54545), width: 1) : null,
                                  color: enemyMissed ? const Color(0xFFB54545).withValues(alpha: 0.15) : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 40,
                                      child: Text(
                                        enemy != null ? "[${enemy['townhallLevel']}]" : "[-]",
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(color: Color(0xFFE2B714), fontSize: 11, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            enemy != null ? enemy['name'] : "---",
                                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (!isFuture) _buildAttackResult(enemy, myTagToPos, false),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 26,
                                      child: Text(
                                        ".${i + 1}",
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        softWrap: false,
                                        style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 11),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
