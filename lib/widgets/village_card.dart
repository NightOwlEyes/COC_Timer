import 'package:flutter/material.dart';
import '../models/village_models.dart';

class VillageCard extends StatelessWidget {
  final VillageData village;
  final String villageName;
  final bool isBuilderBase; // NHẬN CỜ TRẠNG THÁI SERVER
  final Color themeColor;   // MÀU SẮC DỰA THEO SERVER
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const VillageCard({
    super.key,
    required this.village,
    required this.villageName,
    required this.isBuilderBase,
    required this.themeColor,
    required this.onDelete,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // TÍNH TOÁN DATA TÙY SERVER
    int bCount = isBuilderBase ? village.activeBuilders2.length : village.activeBuilders.length;
    int bTotal = isBuilderBase ? village.totalBuilders2 : village.totalBuilders;
    int lCount = isBuilderBase ? village.activeLab2.length : village.activeLab.length;
    int pCount = isBuilderBase ? 0 : village.activePets.length;

    int maxL = lCount > 1 ? lCount : 1;
    int maxP = pCount > 1 ? pCount : 1;

    String displayName = villageName.trim().isEmpty ? "<CHƯA ĐẶT TÊN>" : villageName;

    return InkWell(
      onTap: onTap,
      splashColor: themeColor.withValues(alpha: 0.2),
      highlightColor: themeColor.withValues(alpha: 0.1),
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
                  child: Text(
                      "[ XÓA ]",
                      style: TextStyle(color: themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)
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
              children: isBuilderBase
                  ? [
                _buildStatColumn("MASTER BUILDER", "$bCount/$bTotal", bCount > 0, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn("STAR LABORATORY", "$lCount/$maxL", lCount > 0, themeColor),
              ]
                  : [
                _buildStatColumn("THỢ XÂY", "$bCount/$bTotal", bCount > 0, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn("THÍ NGHIỆM", "$lCount/$maxL", lCount > 0, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn("LINH THÚ", "$pCount/$maxP", pCount > 0, themeColor),
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
      height: 46,
      color: const Color(0xFF333333),
    );
  }

  Widget _buildStatColumn(String title, String value, bool isActive, Color activeColor) {
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
              color: isActive ? activeColor : const Color(0xFF444444),
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