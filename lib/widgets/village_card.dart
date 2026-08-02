import 'package:flutter/material.dart';
import '../models/village_models.dart';

class VillageCard extends StatelessWidget {
  final VillageData village;
  final String villageName;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const VillageCard({
    super.key,
    required this.village,
    required this.villageName,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    int activeBuilders = village.activeBuilders.length;
    int activeLab = village.activeLab.length;
    int activePets = village.activePets.length;

    int maxLab = activeLab > 1 ? activeLab : 1;
    int maxPets = activePets > 1 ? activePets : 1;

    String displayName = villageName.trim().isEmpty ? "<CHƯA ĐẶT TÊN>" : villageName;

    return InkWell(
      onTap: onTap,
      splashColor: const Color(0x224CAF50),
      highlightColor: const Color(0x114CAF50),
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
                        const TextSpan(text: "Tên làng: ", style: TextStyle(color: Color(0xFF888888))),
                        TextSpan(text: displayName, style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  child: const Text(
                      "[ XÓA ]",
                      style: TextStyle(color: Color(0xFFB54545), fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            RichText(
              text: TextSpan(
                style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                children: [
                  const TextSpan(text: "Mã làng: ", style: TextStyle(color: Color(0xFF555555))),
                  TextSpan(text: village.tag, style: const TextStyle(color: Color(0xFF666666))),
                ],
              ),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildStatColumn("THỢ XÂY", "$activeBuilders/${village.totalBuilders}", activeBuilders > 0),
                _buildVerticalDivider(),
                _buildStatColumn("THÍ NGHIỆM", "$activeLab/$maxLab", activeLab > 0),
                _buildVerticalDivider(),
                _buildStatColumn("LINH THÚ", "$activePets/$maxPets", activePets > 0),
              ],
            ),

            const SizedBox(height: 28),
            const Divider(color: Color(0xFF333333), thickness: 1, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 46, // Đủ cao để bao quanh cả chữ Header và Giá trị
      color: const Color(0xFF333333),
    );
  }

  Widget _buildStatColumn(String title, String value, bool isActive) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Color(0xFFE0E0E0),
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0
            ),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: TextStyle(
              color: isActive ? const Color(0xFF4CAF50) : const Color(0xFF444444), // Xanh lá nổi bật hoặc Xám chìm
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}