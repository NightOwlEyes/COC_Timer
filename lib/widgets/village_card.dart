import 'package:flutter/material.dart';
import '../models/village_models.dart';

class VillageCard extends StatelessWidget {
  final VillageData village;
  final TextEditingController nameController;
  final bool showRealEta;
  final VoidCallback onDelete;
  final ValueChanged<String> onNameChanged;
  final void Function(String groupName, List<UpgradeItem> items) onCycleGroup;
  final void Function(UpgradeItem item) onCycleItem;

  const VillageCard({
    super.key,
    required this.village,
    required this.nameController,
    required this.showRealEta,
    required this.onDelete,
    required this.onNameChanged,
    required this.onCycleGroup,
    required this.onCycleItem,
  });

  @override
  Widget build(BuildContext context) {
    final activeBuilders = village.activeBuilders;
    final activePets = village.activePets;
    final activeLab = village.activeLab;

    int petCount = activePets.length;
    int labCount = activeLab.length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                  "MÃ LÀNG: ${village.tag}",
                  style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14, fontWeight: FontWeight.bold)
              ),
              InkWell(
                onTap: onDelete,
                child: const Text(
                  "[ XÓA ]",
                  style: TextStyle(
                    color: Color(0xFF8B2B2B),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text("TÊN LÀNG: ", style: TextStyle(color: Color(0xFF888888), fontSize: 12)),
              Expanded(
                child: TextField(
                  controller: nameController,
                  style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold),
                  decoration: const InputDecoration(
                    hintText: "[ NHẬP TÊN LÀNG... ]",
                    hintStyle: TextStyle(color: Color(0xFF444444)),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 4),
                    border: InputBorder.none,
                  ),
                  onChanged: onNameChanged,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          _buildLogLine("> THỢ XÂY", "${activeBuilders.length}/${village.totalBuilders} ĐANG LÀM", onTap: () => onCycleGroup("THỢ XÂY", activeBuilders)),
          _buildDetailList(activeBuilders),
          const SizedBox(height: 8),

          _buildLogLine("> LINH THÚ", "$petCount ĐANG NÂNG", onTap: () => onCycleGroup("LINH THÚ", activePets)),
          _buildDetailList(activePets),
          const SizedBox(height: 8),

          _buildLogLine("> PHÒNG THÍ NGHIỆM", "$labCount ĐANG NÂNG", onTap: () => onCycleGroup("PHÒNG THÍ NGHIỆM", activeLab)),
          _buildDetailList(activeLab),

          const SizedBox(height: 16),
          const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
        ],
      ),
    );
  }

  Widget _buildLogLine(String text, String status, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Text(text, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
            const Expanded(
              child: Text(
                " ......................................",
                maxLines: 1,
                overflow: TextOverflow.clip,
                style: TextStyle(color: Color(0xFF444444), fontSize: 13),
              ),
            ),
            Text(status, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailList(List<UpgradeItem> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(left: 12.0, top: 4.0, bottom: 8.0),
      child: Column(
        children: items.map((item) {
          final diff = item.realEta.difference(DateTime.now());
          String timeStr = "0s";

          if (!diff.isNegative) {
            if (showRealEta) {
              timeStr = "${item.realEta.hour.toString().padLeft(2, '0')}:${item.realEta.minute.toString().padLeft(2, '0')}";
              if (item.realEta.day != DateTime.now().day) {
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
            stateColor = const Color(0xFFB54545);
          }

          return InkWell(
            onTap: () => onCycleItem(item),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 3.0),
              child: Row(
                children: [
                  Icon(iconData, size: 14, color: stateColor),
                  const SizedBox(width: 6),
                  Text("${item.typeString} ${item.dataId}", style: TextStyle(color: stateColor, fontSize: 12)),
                  const Expanded(
                    child: Text(
                      " ......................................",
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(color: Color(0xFF333333), fontSize: 12),
                    ),
                  ),
                  Text(timeStr, style: TextStyle(color: stateColor, fontSize: 12)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}