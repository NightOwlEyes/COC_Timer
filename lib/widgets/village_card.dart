import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/village_models.dart';
import '../utils/app_strings.dart';

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

    // KIỂM TRA TRẠNG THÁI RẢNH (IDLE)
    bool isIdleBuilder = bTotal > 0 && bCount < bTotal;
    bool isIdleLab = lCount == 0;
    bool isIdlePet = pCount == 0;

    String displayName = villageName.trim().isEmpty ? AppStrings.card.unnamedVillage : villageName;

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
                        TextSpan(text: AppStrings.card.labelVillageNamePrefix, style: const TextStyle(color: Color(0xFF888888))),
                        TextSpan(text: displayName, style: const TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  child: Text(
                      AppStrings.card.btnDelete,
                      style: TextStyle(color: themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // TÍNH NĂNG CHẠM GIỮ ĐỂ COPY TAG LÀNG
            InkWell(
              onLongPress: () async {
                await Clipboard.setData(ClipboardData(text: village.tag));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        "> COPIED: ${village.tag}",
                        style: const TextStyle(fontFamily: 'monospace', color: Color(0xFFE0E0E0), fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      backgroundColor: const Color(0xFF141615),
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: const RoundedRectangleBorder(
                        side: BorderSide(color: Color(0xFF4CAF50), width: 1),
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  );
                }
              },
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 14),
                  children: [
                    TextSpan(text: AppStrings.card.labelTagPrefix, style: const TextStyle(color: Color(0xFF555555))),
                    TextSpan(text: village.tag, style: const TextStyle(color: Color(0xFF666666))),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: isBuilderBase
                  ? [
                _buildStatColumn(AppStrings.card.statMasterBuilder, "$bCount/$bTotal", bCount > 0, isIdleBuilder, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn(AppStrings.card.statStarLaboratory, "$lCount/$maxL", lCount > 0, isIdleLab, themeColor),
              ]
                  : [
                _buildStatColumn(AppStrings.card.statBuilder, "$bCount/$bTotal", bCount > 0, isIdleBuilder, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn(AppStrings.card.statLab, "$lCount/$maxL", lCount > 0, isIdleLab, themeColor),
                _buildVerticalDivider(),
                _buildStatColumn(AppStrings.card.statPet, "$pCount/$maxP", pCount > 0, isIdlePet, themeColor),
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

  Widget _buildStatColumn(String title, String value, bool isActive, bool isIdle, Color activeColor) {
    Color valueColor;
    bool showExclamation = false;

    if (!isActive) {
      // Khi toàn bộ về 0 -> Màu xám như cũ (Không hiển thị [!])
      valueColor = const Color(0xFF444444);
    } else if (isIdle) {
      // Khi có slot trống (nhưng lớn hơn 0) -> Màu vàng và hiện [!]
      valueColor = const Color(0xFFE2B714);
      showExclamation = true;
    } else {
      // Khi đang làm việc tối đa -> Màu theme
      valueColor = activeColor;
    }

    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
                color: Color(0xFFE0E0E0), // Tiêu đề trả về màu trắng xám như cũ
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              if (showExclamation) const BlinkingExclamation(),
            ],
          ),
        ],
      ),
    );
  }
}

// Widget nhỏ để xử lý nhấp nháy cho riêng dấu [!]
class BlinkingExclamation extends StatefulWidget {
  const BlinkingExclamation({super.key});

  @override
  State<BlinkingExclamation> createState() => _BlinkingExclamationState();
}

class _BlinkingExclamationState extends State<BlinkingExclamation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // Tốc độ nhấp nháy
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        " [!]",
        style: TextStyle(
          color: Color(0xFFE2B714),
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}