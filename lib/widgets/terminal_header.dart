import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
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

  void _showDonateDialog(BuildContext context) {
    const Color accentColor = Color(0xFFE2B714);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: accentColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(width: 8, height: 8, color: accentColor),
                      const SizedBox(width: 8),
                      Text(
                        AppStrings.terminal.headerSupportProject,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: accentColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Text(
                      AppStrings.dialog.btnClose,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF888888),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.terminal.textSupportProject,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFE0E0E0),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse('https://github.com/sponsors/NightOwlEyes');
                  try {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } catch (e) {
                    debugPrint("Không thể mở link tài trợ: $e");
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0x22EA4AAA),
                    border: Border.all(color: const Color(0xFFEA4AAA), width: 1),
                  ),
                  child: const Center(
                    child: Text(
                      "[ ♥ GITHUB SPONSORS ]",
                      style: TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFFEA4AAA),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.terminal.textSupportProjectQRScanner,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFF888888),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              Image.asset(
                'assets/donate-qr.png',
                width: 220,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => SizedBox(
                  width: 180,
                  height: 100,
                  child: Center(
                    child: Text(
                      AppStrings.terminal.debugQRImageNotFound,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: Color(0xFF888888),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
            InkWell(
              onTap: () => _showDonateDialog(context),
              child: Text(
                AppStrings.terminal.headerSmallTitle,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  color: Color(0xFFE2B714),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            InkWell(
              onTap: onToggleEta,
              child: Row(
                children: [
                  Text(
                    customToggleLabel ?? "${AppStrings.terminal.labelRealTime}: ",
                    style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11),
                  ),
                  Text(
                    showRealEta ? AppStrings.terminal.toggleOn : AppStrings.terminal.toggleOff,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      color: showRealEta ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
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
                  Text(
                    AppStrings.terminal.labelLanguage,
                    style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF888888), fontSize: 11),
                  ),
                  Text(
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
                isOnline ? AppStrings.terminal.labelServerOnline : AppStrings.terminal.labelServer,
                style: TextStyle(
                  fontFamily: 'monospace',
                  color: isOnline ? const Color(0xFF4CAF50) : const Color(0xFF8B2B2B),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                "$offsetString $currentTime",
                style: const TextStyle(fontFamily: 'monospace', color: Color(0xFF666666), fontSize: 12),
              ),
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