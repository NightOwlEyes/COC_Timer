import '../theme/app_theme.dart';
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
    if (AppTheme.isModern) return _buildModern(context);
    return _buildTerminal(context);
  }

  Widget _buildTerminal(BuildContext context) {
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
                      style: TextStyle(fontFamily: AppTheme.font, fontSize: 16),
                      children: [
                        TextSpan(text: AppStrings.card.labelVillageNamePrefix, style: TextStyle(color: AppColors.textMuted)),
                        TextSpan(text: displayName, style: TextStyle(color: AppColors.text, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                InkWell(
                  onTap: onDelete,
                  child: Text(
                    AppStrings.card.btnDelete,
                    style: TextStyle(color: themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
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
                        style: TextStyle(fontFamily: AppTheme.font, color: AppColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      backgroundColor: AppColors.surface,
                      duration: const Duration(seconds: 2),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(color: AppColors.ok, width: 1),
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  );
                }
              },
              child: RichText(
                text: TextSpan(
                  style: TextStyle(fontFamily: AppTheme.font, fontSize: 14),
                  children: [
                    TextSpan(text: AppStrings.card.labelTagPrefix, style: TextStyle(color: AppColors.textFaint)),
                    TextSpan(text: village.tag, style: TextStyle(color: AppColors.textDim)),
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
            Divider(color: AppColors.border, thickness: 1, height: 1),
          ],
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 46,
      color: AppColors.border,
    );
  }

  Widget _buildStatColumn(String title, String value, bool isActive, bool isIdle, Color activeColor) {
    Color valueColor;
    bool showExclamation = false;

    if (!isActive) {
      valueColor = AppColors.borderStrong;
    } else if (isIdle) {
      valueColor = AppColors.warn;
      showExclamation = true;
    } else {
      valueColor = activeColor;
    }

    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppColors.text,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
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

  // Giao diện Kính mờ (Glassmorphism)
  Widget _buildModern(BuildContext context) {
    int bCount = isBuilderBase ? village.activeBuilders2.length : village.activeBuilders.length;
    int bTotal = isBuilderBase ? village.totalBuilders2 : village.totalBuilders;
    int lCount = isBuilderBase ? village.activeLab2.length : village.activeLab.length;
    int pCount = isBuilderBase ? 0 : village.activePets.length;

    int maxL = lCount > 1 ? lCount : 1;
    int maxP = pCount > 1 ? pCount : 1;

    bool isIdleBuilder = bTotal > 0 && bCount < bTotal;
    bool isIdleLab = lCount == 0;
    bool isIdlePet = pCount == 0;

    String displayName = villageName.trim().isEmpty ? AppStrings.card.unnamedVillage : villageName;

    Widget statTile({
      required String title,
      required String value,
      required IconData icon,
      required Color color,
      required bool isIdle,
      required bool isActive,
    }) {
      final Color valColor = !isActive
          ? AppColors.textDim
          : (isIdle ? AppColors.warn : color);

      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: AppTheme.brMd,
            border: Border.all(
              color: isIdle
                  ? AppColors.warn.withValues(alpha: 0.45)
                  : (isActive ? color.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.14)),
              width: 1.0,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                (isActive ? color : Colors.white).withValues(alpha: 0.14),
                Colors.white.withValues(alpha: 0.04),
              ],
            ),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 14, color: color),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textSoft,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      color: valColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (isActive && isIdle) ...[
                    const SizedBox(width: 4),
                    const BlinkingExclamation(),
                  ],
                ],
              ),
            ],
          ),
        ),
      );
    }

    return GlassBox(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      borderRadius: AppTheme.brLg,
      tintColor: themeColor,
      borderColor: Colors.white.withValues(alpha: 0.22),
      opacity: 0.10,
      blur: 18.0,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: themeColor.withValues(alpha: 0.18),
                        borderRadius: AppTheme.brSm,
                        border: Border.all(color: themeColor.withValues(alpha: 0.45)),
                      ),
                      child: Icon(
                        isBuilderBase ? Icons.nightlight_round : Icons.shield_rounded,
                        size: 18,
                        color: themeColor,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          InkWell(
                            borderRadius: AppTheme.brSm,
                            onLongPress: () async {
                              await Clipboard.setData(ClipboardData(text: village.tag));
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text("Copied: ${village.tag}"),
                                    backgroundColor: const Color(0xFF1E293B),
                                    duration: const Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: AppTheme.brMd),
                                  ),
                                );
                              }
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  village.tag,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    color: AppColors.textMuted,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.copy_rounded, size: 12, color: AppColors.textDim),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.danger),
                tooltip: AppTheme.label(AppStrings.card.btnDelete),
                onPressed: onDelete,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Dãy ô thống kê kính mờ
          Row(
            children: isBuilderBase
                ? [
                    statTile(
                      title: AppStrings.card.statMasterBuilder,
                      value: "$bCount/$bTotal",
                      icon: Icons.architecture_rounded,
                      color: AppColors.builder,
                      isIdle: isIdleBuilder,
                      isActive: bCount > 0,
                    ),
                    const SizedBox(width: 8),
                    statTile(
                      title: AppStrings.card.statStarLaboratory,
                      value: "$lCount/$maxL",
                      icon: Icons.auto_awesome_rounded,
                      color: AppColors.lab,
                      isIdle: isIdleLab,
                      isActive: lCount > 0,
                    ),
                  ]
                : [
                    statTile(
                      title: AppStrings.card.statBuilder,
                      value: "$bCount/$bTotal",
                      icon: Icons.construction_rounded,
                      color: AppColors.builder,
                      isIdle: isIdleBuilder,
                      isActive: bCount > 0,
                    ),
                    const SizedBox(width: 8),
                    statTile(
                      title: AppStrings.card.statLab,
                      value: "$lCount/$maxL",
                      icon: Icons.science_rounded,
                      color: AppColors.lab,
                      isIdle: isIdleLab,
                      isActive: lCount > 0,
                    ),
                    const SizedBox(width: 8),
                    statTile(
                      title: AppStrings.card.statPet,
                      value: "$pCount/$maxP",
                      icon: Icons.pets_rounded,
                      color: AppColors.pet,
                      isIdle: isIdlePet,
                      isActive: pCount > 0,
                    ),
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
      duration: const Duration(milliseconds: 800),
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
      child: Text(
        AppTheme.isModern ? "!" : " [!]",
        style: TextStyle(
          color: AppColors.warn,
          fontSize: 15,
          fontWeight: FontWeight.bold,
          letterSpacing: AppTheme.ls(1.5),
        ),
      ),
    );
  }
}
