import '../theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_strings.dart';

class TerminalHeader extends StatelessWidget {
  final bool showRealEta;
  final String currentTime;
  final String? updateUrl;
  final String? updateVersion;
  final VoidCallback? onToggleEta;
  final VoidCallback onLanguageChange;
  final VoidCallback onSettingsTap;
  final VoidCallback onUpdateTap;
  final VoidCallback? onToggleServer;
  final bool isOnline;
  final String? customToggleLabel;

  const TerminalHeader({
    super.key,
    this.showRealEta = true,
    required this.currentTime,
    this.updateUrl,
    this.updateVersion,
    this.onToggleEta,
    required this.onLanguageChange,
    required this.onSettingsTap,
    required this.onUpdateTap,
    this.onToggleServer,
    this.isOnline = false,
    this.customToggleLabel,
  });

  void _showDonateDialog(BuildContext context) {
    final Color accentColor = AppColors.warn;

    showDialog(
      context: context,
      builder: (ctx) => AdaptiveDialog(
        accentColor: accentColor,
        terminalBorderWidth: 1.5,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      if (AppTheme.isTerminal)
                        Container(width: 8, height: 8, color: accentColor)
                      else
                        Icon(Icons.favorite_rounded, color: accentColor, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        AppTheme.label(AppStrings.terminal.headerSupportProject),
                        style: TextStyle(
                          fontFamily: AppTheme.font,
                          color: accentColor,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: AppTheme.ls(1.0),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Text(
                      AppTheme.label(AppStrings.dialog.btnClose),
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        color: AppColors.textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                AppTheme.label(AppStrings.terminal.textSupportProject),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  color: AppColors.text,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                borderRadius: AppTheme.brMd,
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
                    color: AppColors.sponsorTint,
                    borderRadius: AppTheme.brMd,
                    border: Border.all(color: AppColors.sponsor, width: 1),
                  ),
                  child: Center(
                    child: Text(
                      AppTheme.isModern ? "♥ GITHUB SPONSORS" : "[ ♥ GITHUB SPONSORS ]",
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        color: AppColors.sponsor,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: AppTheme.ls(1.0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                AppTheme.label(AppStrings.terminal.textSupportProjectQRScanner),
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: AppTheme.brSm,
                child: Image.asset(
                  'assets/donate-qr.png',
                  width: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => SizedBox(
                    width: 180,
                    height: 100,
                    child: Center(
                      child: Text(
                        AppTheme.label(AppStrings.terminal.debugQRImageNotFound),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppTheme.font,
                          color: AppColors.textMuted,
                          fontSize: 11,
                        ),
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
    if (AppTheme.isModern) return _buildModern(context);
    return _buildTerminal(context);
  }

  Widget _buildTerminal(BuildContext context) {
    final offset = DateTime.now().timeZoneOffset;
    final offsetString = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()}";

    final size = MediaQuery.of(context).size;
    final double aspectRatio = size.height > 0 ? (size.width / size.height) : 1.0;
    final bool useWideCenterLayout = aspectRatio >= 1.55 && size.width >= 560;

    final Widget clockWidget = FittedBox(
      fit: BoxFit.scaleDown,
      alignment: useWideCenterLayout ? Alignment.center : Alignment.centerRight,
      child: Text(
        "$offsetString $currentTime",
        style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textDim, fontSize: 12),
      ),
    );

    final Widget? updateWidget = updateUrl != null
        ? InkWell(
            onTap: onUpdateTap,
            child: Text(
              AppStrings.format(AppStrings.terminal.btnUpdateAvailable, {'version': "v$updateVersion"}),
              style: TextStyle(fontFamily: AppTheme.font, color: AppColors.ok, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          )
        : null;

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
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  color: AppColors.warn,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (isOnline && onToggleEta != null) ...[
              const SizedBox(height: 6),
              InkWell(
                onTap: onToggleEta,
                child: Row(
                  children: [
                    Text(
                      customToggleLabel ?? "${AppStrings.terminal.labelRealTime}: ",
                      style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 11),
                    ),
                    Text(
                      showRealEta ? AppStrings.terminal.toggleOn : AppStrings.terminal.toggleOff,
                      style: TextStyle(
                        fontFamily: AppTheme.font,
                        color: showRealEta ? AppColors.ok : AppColors.danger,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  ],
                ),
              ),
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: onLanguageChange,
              child: Row(
                children: [
                  Text(
                    AppStrings.terminal.labelLanguage,
                    style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 11),
                  ),
                  Text(
                    AppStrings.languageCode == 'en' ? "[ EN ]" : "[ VI ]",
                    style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            if (!useWideCenterLayout && updateWidget != null) ...[
              const SizedBox(height: 6),
              updateWidget,
            ],
          ],
        ),
        if (useWideCenterLayout)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  clockWidget,
                  if (updateWidget != null) ...[
                    const SizedBox(height: 6),
                    updateWidget,
                  ],
                ],
              ),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            InkWell(
              onTap: onToggleServer ?? () {},
              child: Text(
                isOnline ? AppStrings.terminal.labelServerOnline : AppStrings.terminal.labelServer,
                style: TextStyle(
                  fontFamily: AppTheme.font,
                  color: isOnline ? AppColors.ok : AppColors.danger,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (!useWideCenterLayout) ...[
              const SizedBox(height: 6),
              clockWidget,
            ],
            const SizedBox(height: 6),
            InkWell(
              onTap: onSettingsTap,
              child: Text(
                AppStrings.terminal.btnSettings,
                style: TextStyle(fontFamily: AppTheme.font, color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModern(BuildContext context) {
    final offset = DateTime.now().timeZoneOffset;
    final offsetString = "UTC${offset.isNegative ? '-' : '+'}${offset.inHours.abs()}";

    final size = MediaQuery.of(context).size;
    final double aspectRatio = size.height > 0 ? (size.width / size.height) : 1.0;
    final bool useWideCenterLayout = aspectRatio >= 1.55 && size.width >= 560;

    final Widget clockBadge = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.schedule_rounded, size: 13, color: AppColors.textDim),
        const SizedBox(width: 4),
        Text(
          "$offsetString $currentTime",
          style: TextStyle(
            fontFamily: 'monospace',
            color: AppColors.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );

    final Widget? updateWidget = updateUrl != null
        ? GlassBox(
            onTap: onUpdateTap,
            borderRadius: BorderRadius.circular(20),
            tintColor: AppColors.ok,
            borderColor: AppColors.ok.withValues(alpha: 0.55),
            opacity: 0.14,
            blur: 12,
            showShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.system_update_alt_rounded, size: 13, color: AppColors.ok),
                const SizedBox(width: 5),
                Text(
                  AppTheme.label(AppStrings.format(
                    AppStrings.terminal.btnUpdateAvailable,
                    {'version': "v$updateVersion"},
                  )),
                  style: TextStyle(
                    color: AppColors.ok,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : null;

    final Widget? onlineSyncWidget = (isOnline && onToggleEta != null)
        ? GlassBox(
            onTap: onToggleEta,
            borderRadius: BorderRadius.circular(20),
            tintColor: showRealEta ? AppColors.ok : AppColors.danger,
            borderColor: (showRealEta ? AppColors.ok : AppColors.danger).withValues(alpha: 0.45),
            opacity: 0.12,
            blur: 12,
            showShadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  showRealEta ? Icons.sync_rounded : Icons.sync_disabled_rounded,
                  size: 13,
                  color: showRealEta ? AppColors.ok : AppColors.danger,
                ),
                const SizedBox(width: 5),
                Text(
                  "${(customToggleLabel ?? AppStrings.terminal.labelRealTime).replaceAll(':', '').trim()}: ${AppTheme.label(showRealEta ? AppStrings.terminal.toggleOn : AppStrings.terminal.toggleOff)}",
                  style: TextStyle(
                    color: showRealEta ? AppColors.ok : AppColors.danger,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CỘT TRÁI: Donate + Ngôn ngữ (và nút Cập nhật / Đồng bộ bên dưới khi ở màn hình dọc)
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  GlassBox(
                    onTap: () => _showDonateDialog(context),
                    borderRadius: BorderRadius.circular(20),
                    tintColor: AppColors.sponsor,
                    borderColor: AppColors.sponsor.withValues(alpha: 0.45),
                    opacity: 0.12,
                    blur: 12,
                    showShadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.favorite_rounded, size: 14, color: AppColors.sponsor),
                        const SizedBox(width: 5),
                        Text(
                          AppTheme.label(AppStrings.terminal.headerSmallTitle),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GlassBox(
                    onTap: onLanguageChange,
                    borderRadius: BorderRadius.circular(20),
                    opacity: 0.10,
                    blur: 12,
                    showShadow: false,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.language_rounded, size: 14, color: AppColors.accent),
                        const SizedBox(width: 5),
                        Text(
                          AppStrings.languageCode.toUpperCase(),
                          style: TextStyle(
                            color: AppColors.text,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (onlineSyncWidget != null) ...[
                const SizedBox(height: 6),
                onlineSyncWidget,
              ],
              if (!useWideCenterLayout && updateWidget != null) ...[
                const SizedBox(height: 6),
                updateWidget,
              ],
            ],
          ),
        ),

        // CỘT GIỮA: Khi màn hình ngang rộng
        if (useWideCenterLayout)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                clockBadge,
                if (updateWidget != null) ...[
                  const SizedBox(height: 6),
                  updateWidget,
                ],
              ],
            ),
          ),

        // CỘT PHẢI: Server + Cài đặt ở hàng trên, Đồng hồ ở hàng dưới (khi màn hình dọc)
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassBox(
                  onTap: onToggleServer,
                  borderRadius: BorderRadius.circular(20),
                  tintColor: isOnline ? AppColors.ok : AppColors.accent,
                  borderColor: (isOnline ? AppColors.ok : AppColors.accent).withValues(alpha: 0.45),
                  opacity: 0.12,
                  blur: 12,
                  showShadow: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isOnline ? AppColors.ok : AppColors.accent,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isOnline ? AppColors.ok : AppColors.accent).withValues(alpha: 0.7),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isOnline ? "ONLINE" : "LOCAL",
                        style: TextStyle(
                          color: AppColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GlassBox(
                  onTap: onSettingsTap,
                  borderRadius: BorderRadius.circular(20),
                  opacity: 0.10,
                  blur: 12,
                  showShadow: false,
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.tune_rounded, size: 17, color: AppColors.text),
                ),
              ],
            ),
            if (!useWideCenterLayout) ...[
              const SizedBox(height: 6),
              clockBadge,
            ],
          ],
        ),
      ],
    );
  }
}
