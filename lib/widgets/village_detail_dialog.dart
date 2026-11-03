import '../theme/app_theme.dart';
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
  final VoidCallback? onToggleRealEta;
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
    this.onToggleRealEta,
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
  late bool _showRealEta;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.villageName);
    _trackHome = widget.initialTrackHome;
    _trackBuilder = widget.initialTrackBuilder;
    _showRealEta = widget.showRealEta;

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

  String _formatBoostTime(DateTime endTime, DateTime now) {
    final diff = endTime.difference(now);
    if (diff.isNegative) return "0s";
    if (_showRealEta) {
      String timeStr = "${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}";
      if (endTime.day != now.day) {
        timeStr = "${endTime.day}/${endTime.month} $timeStr";
      }
      return timeStr;
    } else {
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
  }

  Widget _buildActiveBoostsList(List<MapEntry<String, DateTime?>> boosts) {
    final now = DateTime.now();
    final activeList = boosts
        .where((e) => e.value != null && e.value!.isAfter(now))
        .toList();
    if (activeList.isEmpty) return const SizedBox.shrink();

    final Color boostColor = AppColors.warn;

    return Padding(
      padding: EdgeInsets.only(left: AppTheme.isModern ? 4.0 : 12.0, top: 4.0, bottom: 2.0),
      child: Column(
        children: activeList.map((entry) {
          final timeStr = _formatBoostTime(entry.value!, now);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              children: [
                Icon(Icons.bolt, size: 14, color: boostColor),
                const SizedBox(width: 6),
                if (AppTheme.isModern) ...[
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(
                        color: boostColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: boostColor.withValues(alpha: 0.16),
                      borderRadius: AppTheme.brSm,
                      border: Border.all(color: boostColor.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      timeStr,
                      style: TextStyle(
                        color: boostColor,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    entry.key,
                    style: TextStyle(
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
                      style: TextStyle(color: AppColors.border, fontSize: 12),
                    ),
                  ),
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: boostColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTrackingToggle(String label, bool value, VoidCallback onTap) {
    if (AppTheme.isModern) {
      return InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: value ? widget.themeColor.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: value ? widget.themeColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                value ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                color: value ? widget.themeColor : AppColors.textDim,
                size: 15,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: value ? AppColors.text : AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: value ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      );
    }

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
              color: value ? widget.themeColor : AppColors.borderStrong,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: value ? AppColors.text : AppColors.textMuted, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _handleCycleGroupOptimistic(String groupName, List<UpgradeItem> items) {
    if (items.isEmpty) return;
    bool hasSystem = false;
    bool hasFullscreen = false;

    for (var item in items) {
      if (item.alarmType == AlarmType.system) hasSystem = true;
      if (item.alarmType == AlarmType.fullscreen) hasFullscreen = true;
    }

    AlarmType targetType = hasSystem
        ? AlarmType.fullscreen
        : (hasFullscreen ? AlarmType.none : AlarmType.system);

    setState(() {
      for (var item in items) {
        item.alarmType = targetType;
      }
    });

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

    Widget wrapGroupCard(Widget groupContent) {
      if (AppTheme.isTerminal) return groupContent;
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: AppTheme.brMd,
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: groupContent,
      );
    }

    return AdaptiveDialog(
      accentColor: widget.themeColor,
      terminalBorderWidth: 2.0,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    AppTheme.label("${AppStrings.dialog.titlePrefix}${widget.village.tag}"),
                    style: TextStyle(
                      color: widget.themeColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: AppTheme.ls(1.5),
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    AppTheme.label(AppStrings.dialog.btnClose),
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Text(
                  AppTheme.label(AppStrings.dialog.labelVillageName),
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                ),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      hintText: AppTheme.label(AppStrings.dialog.hintEnterVillageName),
                      hintStyle: TextStyle(color: AppColors.textDim),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      border: InputBorder.none,
                    ),
                    onChanged: widget.onNameChanged,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),
            InkWell(
              borderRadius: AppTheme.brSm,
              onTap: () {
                setState(() => _showRealEta = !_showRealEta);
                widget.onToggleRealEta?.call();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppTheme.label(AppStrings.dialog.labelTimeFormat),
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                    Container(
                      padding: AppTheme.isModern
                          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
                          : EdgeInsets.zero,
                      decoration: AppTheme.isModern
                          ? BoxDecoration(
                              color: (_showRealEta ? AppColors.ok : widget.themeColor).withValues(alpha: 0.16),
                              borderRadius: AppTheme.brSm,
                              border: Border.all(
                                color: (_showRealEta ? AppColors.ok : widget.themeColor).withValues(alpha: 0.45),
                              ),
                            )
                          : null,
                      child: Text(
                        AppTheme.label(_showRealEta ? AppStrings.dialog.timeFormatExact : AppStrings.dialog.timeFormatCountdown),
                        style: TextStyle(
                          color: _showRealEta ? AppColors.ok : widget.themeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),
            Text(
              AppTheme.label(AppStrings.dialog.baseAlarmsToggleLabel),
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 12,
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

            wrapGroupCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogLine(
                    widget.isBuilderBase ? AppStrings.dialog.groupBuilderNight : AppStrings.dialog.groupBuilder,
                    "${activeB.length}/$totalB ${AppStrings.dialog.statusWorkingSuffix}",
                    isTracked: currentTracked,
                    onTap: () => _handleCycleGroupOptimistic(
                      widget.isBuilderBase ? AppStrings.dialog.logGroupNameBuilderNight : AppStrings.dialog.logGroupNameBuilder,
                      activeB,
                    ),
                  ),
                  _buildActiveBoostsList(builderBoostEntries),
                  _buildDetailList(activeB, isTracked: currentTracked, boostEndTime: builderGroupBoostEnd),
                ],
              ),
            ),
            const SizedBox(height: 12),

            wrapGroupCard(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogLine(
                    widget.isBuilderBase ? AppStrings.dialog.groupLabNight : AppStrings.dialog.groupLabMain,
                    "${activeL.length} ${AppStrings.dialog.statusUpgradingSuffix}",
                    isTracked: currentTracked,
                    onTap: () => _handleCycleGroupOptimistic(
                      widget.isBuilderBase ? AppStrings.dialog.logGroupNameLabNight : AppStrings.dialog.logGroupNameLabMain,
                      activeL,
                    ),
                  ),
                  _buildActiveBoostsList(labBoostEntries),
                  _buildDetailList(activeL, isTracked: currentTracked, boostEndTime: labGroupBoostEnd),
                ],
              ),
            ),
            const SizedBox(height: 12),

            if (!widget.isBuilderBase) ...[
              wrapGroupCard(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildLogLine(
                      AppStrings.dialog.groupPet,
                      "${activeP.length} ${AppStrings.dialog.statusUpgradingSuffix}",
                      isTracked: _trackHome,
                      onTap: () => _handleCycleGroupOptimistic(AppStrings.dialog.logGroupNamePet, activeP),
                    ),
                    _buildActiveBoostsList(petBoostEntries),
                    _buildDetailList(activeP, isTracked: _trackHome, boostEndTime: petGroupBoostEnd),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLogLine(String text, String status, {required bool isTracked, VoidCallback? onTap}) {
    if (AppTheme.isModern) {
      return InkWell(
        onTap: isTracked ? onTap : null,
        borderRadius: AppTheme.brSm,
        child: Opacity(
          opacity: isTracked ? 1.0 : 0.5,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  text.replaceFirst(RegExp(r'^>\s*'), ''),
                  style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: AppTheme.brSm,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(color: AppColors.textSoft, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
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
              Text(text, style: TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.bold)),
              Expanded(
                child: Text(
                  AppStrings.dialog.separatorDots,
                  maxLines: 1,
                  overflow: TextOverflow.clip,
                  style: TextStyle(color: AppColors.borderStrong, fontSize: 13),
                ),
              ),
              Text(status, style: TextStyle(color: AppColors.text, fontSize: 13)),
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
      padding: EdgeInsets.only(left: AppTheme.isModern ? 4.0 : 12.0, top: 4.0, bottom: 4.0),
      child: Column(
        children: items.map((item) {
          final diff = item.realEta.difference(now);
          String timeStr = "0s";

          if (!diff.isNegative) {
            if (_showRealEta) {
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
          Color stateColor = AppColors.textDim;

          if (item.alarmType == AlarmType.system) {
            iconData = Icons.notifications;
            stateColor = AppColors.ok;
          } else if (item.alarmType == AlarmType.fullscreen) {
            iconData = Icons.alarm;
            stateColor = widget.themeColor;
          }

          final bool finishesBeforeBoostEnds = boostEndTime != null &&
              boostEndTime.isAfter(now) &&
              item.realEta.isBefore(boostEndTime);

          return InkWell(
            borderRadius: AppTheme.brSm,
            onTap: isTracked
                ? () {
                    AlarmType nextType;
                    if (item.alarmType == AlarmType.system) {
                      nextType = AlarmType.fullscreen;
                    } else if (item.alarmType == AlarmType.fullscreen) {
                      nextType = AlarmType.none;
                    } else {
                      nextType = AlarmType.system;
                    }

                    setState(() {
                      item.alarmType = nextType;
                    });

                    widget.onCycleItem(item);
                  }
                : null,
            splashColor: widget.themeColor.withValues(alpha: 0.3),
            highlightColor: widget.themeColor.withValues(alpha: 0.1),
            child: Opacity(
              opacity: isTracked ? 1.0 : 0.5,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  children: [
                    Icon(iconData, size: 15, color: stateColor),
                    const SizedBox(width: 6),
                    if (finishesBeforeBoostEnds)
                      Text(
                        "! ",
                        style: TextStyle(
                          color: AppColors.warn,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    if (AppTheme.isModern) ...[
                      Expanded(
                        child: Text(
                          "${AppStrings.gameData.getName(item.dataId)} (Lv.${item.level})",
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: stateColor, fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.14),
                          borderRadius: AppTheme.brSm,
                          border: Border.all(color: stateColor.withValues(alpha: 0.32)),
                        ),
                        child: Text(
                          timeStr,
                          style: TextStyle(color: stateColor, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ] else ...[
                      Text("${AppStrings.gameData.getName(item.dataId)} (Lv.${item.level})", style: TextStyle(color: stateColor, fontSize: 12)),
                      Expanded(
                        child: Text(
                          AppStrings.dialog.separatorDots,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(color: AppColors.border, fontSize: 12),
                        ),
                      ),
                      Text(timeStr, style: TextStyle(color: stateColor, fontSize: 12)),
                    ],
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
