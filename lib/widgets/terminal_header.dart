import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

class TerminalHeader extends StatelessWidget {
  final bool showRealEta;
  final String currentTime;
  final String? updateUrl;
  final String? updateVersion;
  final VoidCallback onToggleEta;
  final VoidCallback onLanguageChange;
  final VoidCallback onSettingsTap;
  final VoidCallback onUpdateTap;
  final VoidCallback? onToggleServer;
  final bool isOnline;
  final String? customToggleLabel;

  const TerminalHeader({
    super.key,
    required this.showRealEta,
    required this.currentTime,
    this.updateUrl,
    this.updateVersion,
    required this.onToggleEta,
    required this.onLanguageChange,
    required this.onSettingsTap,
    required this.onUpdateTap,
    this.onToggleServer,
    this.isOnline = false,
    this.customToggleLabel,
  });

  @override
  Widget build(BuildContext context) {
    final offset = DateTime.now().timeZoneOffset;
    final offsetString = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()}";

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                AppStrings.terminal.headerSmallTitle,
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF666666), fontSize: 12, fontWeight: FontWeight.bold)
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onToggleEta,
              child: Row(
                children: [
                  // 2. CHỈNH SỬA LẠI DÒNG TEXT NÀY ĐỂ NÓ NHẬN LABEL CUSTOM
                  Text(
                      customToggleLabel ?? "${AppStrings.terminal.labelRealTime}: ",
                      style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11)
                  ),
                  Text(
                    showRealEta ? AppStrings.terminal.toggleOn : AppStrings.terminal.toggleOff,
// ... (Phần code dưới giữ nguyên y chang) ...
                    style: TextStyle(
                        fontFamily: 'monospace',
                        color: showRealEta ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                        fontSize: 11,
                        fontWeight: FontWeight.bold
                    ),
                  )
                ],
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onLanguageChange,
              child: Row(
                children: [
                  Text(AppStrings.terminal.labelLanguage, style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11)),                  Text(
                    AppStrings.languageCode == 'en' ? "[ EN ]" : "[ VI ]",
                    style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: onToggleServer ?? () {},
              child: Text(
                  isOnline ? AppStrings.terminal.labelServerOnline : AppStrings.terminal.labelServer,                  style: TextStyle(
                      fontFamily: 'monospace',
                      color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                      fontSize: 12,
                      fontWeight: FontWeight.bold
                  )
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text("$offsetString $currentTime", style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF666666), fontSize: 12)),
            ),
            const SizedBox(height: 6),
            if (updateUrl != null) ...[
              InkWell(
                onTap: onUpdateTap,
                child: Text(
                  AppStrings.format(AppStrings.terminal.btnUpdateAvailable, {'version': "v$updateVersion"}),
                  style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
            ],
            InkWell(
              onTap: onSettingsTap,
              child: Text(
                AppStrings.terminal.btnSettings,
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }
}