import 'package:flutter/material.dart';
import 'dart:async';
import '../models/village_models.dart';
import '../utils/app_strings.dart';

class VillageDetailDialog extends StatefulWidget {
  final VillageData village;
  final String villageName;
  final bool isBuilderBase;
  final Color themeColor;
  final bool showRealEta;
  final bool initialTrackHome;
  final bool initialTrackBuilder;
  final ValueChanged<String> onNameChanged;
  final Function(bool trackHome, bool trackBuilder) onTrackingChanged;
  final void Function(String groupName, List<UpgradeItem> items) onCycleGroup;
  final void Function(UpgradeItem item) onCycleItem;

  const VillageDetailDialog({
    super.key,
    required this.village,
    required this.villageName,
    required this.isBuilderBase,
    required this.themeColor,
    required this.showRealEta,
    required this.initialTrackHome,
    required this.initialTrackBuilder,
    required this.onNameChanged,
    required this.onTrackingChanged,
    required this.onCycleGroup,
    required this.onCycleItem,
  });

  @override
  State<VillageDetailDialog> createState() => _VillageDetailDialogState();
}

class _VillageDetailDialogState extends State<VillageDetailDialog> {
  late TextEditingController _nameController;
  Timer? _refreshTimer;

  late bool _trackHome;
  late bool _trackBuilder;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.villageName);
    _trackHome = widget.initialTrackHome;
    _trackBuilder = widget.initialTrackBuilder;

    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  DateTime? _getBoostEndTime(int durationSeconds) {
    if (durationSeconds <= 0) return null;
    final endTime = DateTime.fromMillisecondsSinceEpoch(
      (widget.village.timestamp + durationSeconds) * 1000,
    );
    if (endTime.isBefore(DateTime.now())) return null;
    return endTime;
  }

  DateTime? _maxDateTime(List<DateTime?> dates) {
    DateTime? result;
    for (final d in dates) {
      if (d != null) {
        if (result == null || d.isAfter(result)) {
          result = d;
        }
      }
    }
    return result;
  }

  String _formatCountdown(Duration diff) {
    if (diff.isNegative) return "0s";
    if (diff.inDays > 0) {
      return "${diff.inDays}d ${diff.inHours % 24}h ${diff.inMinutes % 60}m";
    } else if (diff.inHours > 0) {
      return "${diff.inHours}h ${diff.inMinutes % 60}m ${diff.inSeconds % 60}s";
    } else if (diff.inMinutes > 0) {
      return "${diff.inMinutes}m ${diff.inSeconds % 60}s";
    } else {
      return "${diff.inSeconds}s";
    }
  }

  Widget _buildActiveBoostsList(List<MapEntry<String, DateTime?>> boosts) {
    final now = DateTime.now();
    final activeList = boosts
        .where((e) => e.value != null && e.value!.isAfter(now))
        .toList();
    if (activeList.isEmpty) return const SizedBox.shrink();

    const Color boostColor = Color(0xFFE2B714);

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, top: 2.0, bottom: 2.0),
      child: Column(
        children: activeList.map((entry) {
          final diff = entry.value!.difference(now);
          final timeStr = _formatCountdown(diff);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                const Icon(Icons.bolt, size: 14, color: boostColor),
                const SizedBox(width: 6),
                Text(
                  entry.key,
                  style: const TextStyle(
                    color: boostColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Text(
                    AppStrings.dialog.separatorDots,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(color: Color(0xFF333333), fontSize: 12),
                  ),
                ),
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: boostColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrackingToggle(String label, bool value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      splashColor: widget.themeColor.withValues(alpha: 0.3),
      highlightColor: widget.themeColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 2.0),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              value ? Icons.check_box : Icons.check_box_outline_blank,
              color: value ? widget.themeColor : const Color(0xFF444444),
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: value ? const Color(0xFFE0E0E0) : const Color(0xFF888888), fontSize: 12)),
          ],
        ),
      ),
    );
  }

  // THÊM HÀM NÀY ĐỂ XỬ LÝ OPTIMISTIC UPDATE CHO NHÓM (GROUP)
  void _handleCycleGroupOptimistic(String groupName, List<UpgradeItem> items) {
    if (items.isEmpty) return;
    bool hasSystem = false;
    bool hasFullscreen = false;

    // Phân tích trạng thái hiện tại của UI
    for (var item in items) {
      if (item.alarmType == AlarmType.system) hasSystem = true;
      if (item.alarmType == AlarmType.fullscreen) hasFullscreen = true;
    }

    // Xác định trạng thái tiếp theo
    AlarmType targetType = hasSystem
        ? AlarmType.fullscreen
        : (hasFullscreen ? AlarmType.none : AlarmType.system);

    // 1. CẬP NHẬT UI TRƯỚC NGAY LẬP TỨC
    setState(() {
      for (var item in items) {
        item.alarmType = targetType;
      }
    });

    // 2. GỌI PARENT CHẠY BACKGROUND SAU (Lưu DB, set OS Alarm...)
    widget.onCycleGroup(groupName, items);
  }

  @override
  Widget build(BuildContext context) {
    final activeB = widget.isBuilderBase ? widget.village.activeBuilders2 : widget.village.activeBuilders;
    final totalB = widget.isBuilderBase ? widget.village.totalBuilders2 : widget.village.totalBuilders;
    final activeL = widget.isBuilderBase ? widget.village.activeLab2 : widget.village.activeLab;
    final activeP = widget.isBuilderBase ? <UpgradeItem>[] : widget.village.activePets;

    bool currentTracked = widget.isBuilderBase ? _trackBuilder : _trackHome;

    final bBoostEnd = _getBoostEndTime(widget.village.boosts.builderBoost);
    final bConsEnd = _getBoostEndTime(widget.village.boosts.builderConsumable);
    final bHelperEnd = _getBoostEndTime(widget.village.boosts.builderHelperTimer);

    final lBoostEnd = _getBoostEndTime(widget.village.boosts.labBoost);
    final lConsEnd = _getBoostEndTime(widget.village.boosts.labConsumable);
    final lHelperEnd = _getBoostEndTime(widget.village.boosts.labHelperTimer);

    final pBoostEnd = _getBoostEndTime(widget.village.boosts.petBoost);
    final clockEnd = _getBoostEndTime(widget.village.boosts.clocktowerBoost);

    // Thời điểm kết thúc thuốc/vật phẩm hỗ trợ của từng nhóm (dùng để đánh dấu ! công trình xong trước khi hết thuốc)
    final DateTime? builderGroupBoostEnd = widget.isBuilderBase
        ? clockEnd
        : _maxDateTime([bBoostEnd, bConsEnd]);
    final DateTime? labGroupBoostEnd = widget.isBuilderBase
        ? clockEnd
        : _maxDateTime([lBoostEnd, lConsEnd]);
    final DateTime? petGroupBoostEnd = _maxDateTime([pBoostEnd, lConsEnd]);

    final List<MapEntry<String, DateTime?>> builderBoostEntries = widget.isBuilderBase
        ? [MapEntry(AppStrings.dialog.boostClockTower, clockEnd)]
        : [
            MapEntry(AppStrings.dialog.boostBuilderPotion, bBoostEnd),
            MapEntry(AppStrings.dialog.boostBuilderConsumable, bConsEnd),
            MapEntry(AppStrings.dialog.boostBuilderHelper, bHelperEnd),
          ];

    final List<MapEntry<String, DateTime?>> labBoostEntries = widget.isBuilderBase
        ? [MapEntry(AppStrings.dialog.boostClockTower, clockEnd)]
        : [
            MapEntry(AppStrings.dialog.boostLabPotion, lBoostEnd),
            MapEntry(AppStrings.dialog.boostLabConsumable, lConsEnd),
            MapEntry(AppStrings.dialog.boostLabHelper, lHelperEnd),
          ];

    final List<MapEntry<String, DateTime?>> petBoostEntries = [
      MapEntry(AppStrings.dialog.boostPetPotion, pBoostEnd),
      MapEntry(AppStrings.dialog.boostLabConsumable, lConsEnd),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Material(
        color: const Color(0xFF0D0F0E),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: widget.themeColor, width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "${AppStrings.dialog.titlePrefix}${widget.village.tag}",
                      style: TextStyle(color: widget.themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                    ),
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Text(AppStrings.dialog.btnClose, style: const TextStyle(color: Color(0xFF888888), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Text(AppStrings.dialog.labelVillageName, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(
                          hintText: AppStrings.dialog.hintEnterVillageName,
                          hintStyle: const TextStyle(color: Color(0xFF444444)),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          border: InputBorder.none,
                        ),
                        onChanged: widget.onNameChanged,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Text(AppStrings.dialog.baseAlarmsToggleLabel, style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildTrackingToggle(AppStrings.terminal.trackingHomeVillage, _trackHome, () {
                      setState(() => _trackHome = !_trackHome);
                      widget.onTrackingChanged(_trackHome, _trackBuilder);
                    }),
                    _buildTrackingToggle(AppStrings.terminal.trackingBuilderBase, _trackBuilder, () {
                      setState(() => _trackBuilder = !_trackBuilder);
                      widget.onTrackingChanged(_trackHome, _trackBuilder);
                    }),
                  ],
                ),
                const SizedBox(height: 16),

                _buildLogLine(
                    widget.isBuilderBase ? AppStrings.dialog.groupBuilderNight : AppStrings.dialog.groupBuilder,
                    "${activeB.length}/$totalB ${AppStrings.dialog.statusWorkingSuffix}",
                    isTracked: currentTracked,
                    onTap: () => _handleCycleGroupOptimistic(widget.isBuilderBase ? AppStrings.dialog.logGroupNameBuilderNight : AppStrings.dialog.logGroupNameBuilder, activeB)
                ),
                _buildActiveBoostsList(builderBoostEntries),
                _buildDetailList(activeB, isTracked: currentTracked, boostEndTime: builderGroupBoostEnd),
                const SizedBox(height: 12),

                // Reordered: LabMain before Pet
                _buildLogLine(
                    widget.isBuilderBase ? AppStrings.dialog.groupLabNight : AppStrings.dialog.groupLabMain,
                    "${activeL.length} ${AppStrings.dialog.statusUpgradingSuffix}",
                    isTracked: currentTracked,
                    onTap: () => _handleCycleGroupOptimistic(widget.isBuilderBase ? AppStrings.dialog.logGroupNameLabNight : AppStrings.dialog.logGroupNameLabMain, activeL)
                ),
                _buildActiveBoostsList(labBoostEntries),
                _buildDetailList(activeL, isTracked: currentTracked, boostEndTime: labGroupBoostEnd),
                const SizedBox(height: 12),

                if (!widget.isBuilderBase) ...[
                  _buildLogLine(AppStrings.dialog.groupPet, "${activeP.length} ${AppStrings.dialog.statusUpgradingSuffix}", isTracked: _trackHome, onTap: () => _handleCycleGroupOptimistic(AppStrings.dialog.logGroupNamePet, activeP)),
                  _buildActiveBoostsList(petBoostEntries),
                  _buildDetailList(activeP, isTracked: _trackHome, boostEndTime: petGroupBoostEnd),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogLine(String text, String status, {required bool isTracked, VoidCallback? onTap}) {
    return InkWell(
      onTap: isTracked ? onTap : null,
      splashColor: widget.themeColor.withValues(alpha: 0.3),
      highlightColor: widget.themeColor.withValues(alpha: 0.1),
      child: Opacity(
        opacity: isTracked ? 1.0 : 0.5,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Text(text, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  AppStrings.dialog.separatorDots,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: const TextStyle(color: Color(0xFF444444), fontSize: 13),
                ),
              ),
              Text(status, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailList(List<UpgradeItem> items, {required bool isTracked, DateTime? boostEndTime}) {
    if (items.isEmpty) return const SizedBox.shrink();

    final now = DateTime.now();

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 8.0),
      child: Column(
        children: items.map((item) {
          final diff = item.realEta.difference(now);
          String timeStr = "0s";

          if (!diff.isNegative) {
            if (widget.showRealEta) {
              timeStr = "${item.realEta.hour.toString().padLeft(2, '0')}:${item.realEta.minute.toString().padLeft(2, '0')}";
              if (item.realEta.day != now.day) {
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
          Color stateColor = const Color(0xFF444444);

          if (item.alarmType == AlarmType.system) {
            iconData = Icons.notifications;
            stateColor = const Color(0xFF4CAF50);
          } else if (item.alarmType == AlarmType.fullscreen) {
            iconData = Icons.alarm;
            stateColor = widget.themeColor;
          }

          final bool finishesBeforeBoostEnds = boostEndTime != null &&
              boostEndTime.isAfter(now) &&
              item.realEta.isBefore(boostEndTime);

          return InkWell(
            onTap: isTracked ? () {
              // THÊM OPTIMISTIC UPDATE CHO TỪNG ITEM
              AlarmType nextType;
              if (item.alarmType == AlarmType.system) {
                nextType = AlarmType.fullscreen;
              } else if (item.alarmType == AlarmType.fullscreen) {
                nextType = AlarmType.none;
              } else {
                nextType = AlarmType.system;
              }

              // 1. Ép UI đổi màu ngay lập tức
              setState(() {
                item.alarmType = nextType;
              });

              // 2. Gọi logic xử lý ngầm
              widget.onCycleItem(item);
            } : null,
            splashColor: widget.themeColor.withValues(alpha: 0.3),
            highlightColor: widget.themeColor.withValues(alpha: 0.1),
            child: Opacity(
              opacity: isTracked ? 1.0 : 0.5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(iconData, size: 14, color: stateColor),
                    const SizedBox(width: 6),
                    if (finishesBeforeBoostEnds)
                      const Text(
                        "! ",
                        style: TextStyle(
                          color: Color(0xFFE2B714),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    Text("${AppStrings.gameData.getName(item.dataId)} (Lv.${item.level})", style: TextStyle(color: stateColor, fontSize: 12)),
                    Expanded(
                      child: Text(
                        AppStrings.dialog.separatorDots,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                        style: const TextStyle(color: Color(0xFF333333), fontSize: 12),
                      ),
                    ),
                    Text(timeStr, style: TextStyle(color: stateColor, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
