import '../theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

class TerminalLogo extends StatelessWidget {
  const TerminalLogo({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isModern) return _buildModern();
    return Column(
      children: [
        Image.asset('assets/LogoMain.png', height: 80),
        const SizedBox(height: 16),
        Text(
          AppStrings.terminal.logoTitle,
          style: TextStyle(color: AppColors.text, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4.0),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.terminal.logoSubtitle,
          style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: AppColors.border)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10.0),
              child: Icon(Icons.diamond, size: 10, color: AppColors.textDim),
            ),
            Expanded(child: Container(height: 1, color: AppColors.border)),
          ],
        )
      ],
    );
  }

  // Giao diện Kính mờ (Glassmorphism): Logo nằm trong khung kính mờ phát sáng
  Widget _buildModern() {
    return Row(
      children: [
        GlassBox(
          padding: const EdgeInsets.all(9),
          borderRadius: AppTheme.brMd,
          tintColor: AppColors.accent,
          borderColor: Colors.white.withValues(alpha: 0.24),
          opacity: 0.14,
          blur: 14,
          showShadow: false,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Image.asset('assets/LogoMain.png'),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppTheme.label(AppStrings.terminal.logoTitle),
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                AppTheme.label(AppStrings.terminal.logoSubtitle),
                style: TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class TerminalSecurityTag extends StatelessWidget {
  final bool isBuilderBase;
  final Color themeColor;
  final Color bgTagColor;
  final VoidCallback onToggle;

  const TerminalSecurityTag({
    super.key,
    required this.isBuilderBase,
    required this.themeColor,
    required this.bgTagColor,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isModern) return _buildModern();
    return Column(
      children: [
        Text(
          AppStrings.terminal.labelTapToSwitchServer,
          style: TextStyle(color: AppColors.textDim, fontSize: 10, letterSpacing: 1.0),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: onToggle,
          splashColor: themeColor.withValues(alpha: 0.3),
          highlightColor: themeColor.withValues(alpha: 0.1),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: themeColor, width: 1),
                bottom: BorderSide(color: themeColor, width: 1),
              ),
              color: bgTagColor,
            ),
            child: Center(
              child: Text(
                isBuilderBase ? AppStrings.terminal.tabBuilderBase : AppStrings.terminal.tabMainVillage,
                style: TextStyle(color: themeColor, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Giao diện Kính mờ: Thanh Segmented Control kính mờ 2 lựa chọn
  Widget _buildModern() {
    Widget segment(String text, IconData icon, bool selected, Color color) {
      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: selected ? null : onToggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: AppTheme.brMd,
              border: Border.all(
                color: selected ? color.withValues(alpha: 0.65) : Colors.transparent,
                width: 1.1,
              ),
              gradient: selected
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        color.withValues(alpha: 0.28),
                        color.withValues(alpha: 0.10),
                      ],
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: selected ? color : AppColors.textDim),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    AppTheme.label(text),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: selected ? AppColors.text : AppColors.textMuted,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return GlassBox(
      padding: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(AppTheme.radiusMd + 4),
      opacity: 0.09,
      blur: 16,
      showShadow: false,
      child: Row(
        children: [
          segment(AppStrings.terminal.tabMainVillage, Icons.home_rounded, !isBuilderBase, AppColors.accent),
          const SizedBox(width: 4),
          segment(AppStrings.terminal.tabBuilderBase, Icons.nightlight_round, isBuilderBase, AppColors.accentBase),
        ],
      ),
    );
  }
}

class TerminalInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final VoidCallback onPaste;
  final bool isQuickPasteActive;
  final VoidCallback? onToggleQuickPaste;

  const TerminalInputArea({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.onPaste,
    this.isQuickPasteActive = false,
    this.onToggleQuickPaste,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isModern) return _buildModern();

    final String quickPasteLabel = isQuickPasteActive
        ? AppStrings.terminal.btnQuickPasteOn
        : AppStrings.terminal.btnPinQuickPaste;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                AppStrings.terminal.inputSectionLabel,
                style: TextStyle(color: AppColors.textMuted, fontSize: 12, letterSpacing: 1.0),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onToggleQuickPaste != null)
              InkWell(
                onTap: onToggleQuickPaste,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    quickPasteLabel,
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      color: isQuickPasteActive ? AppColors.ok : AppColors.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Stack(
          children: [
            TextField(
              controller: controller,
              autofocus: false,
              maxLines: 4,
              style: TextStyle(color: AppColors.text, fontSize: 14),
              decoration: InputDecoration(
                hintText: AppStrings.terminal.inputHint,
                hintStyle: TextStyle(color: AppColors.borderStrong),
                filled: true,
                fillColor: AppColors.surface,
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.zero,
                  borderSide: BorderSide(color: AppColors.textDim, width: 1),
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: onPaste,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: AppColors.border,
                  child: Text(
                    AppStrings.terminal.btnPaste,
                    style: TextStyle(color: AppColors.text, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 20),
        Material(
          color: AppColors.buttonBg,
          child: InkWell(
            onTap: onSubmit,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Text(
                AppStrings.terminal.btnSubmit,
                style: TextStyle(color: AppColors.inputBg, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Giao diện Kính mờ (Glassmorphism)
  Widget _buildModern() {
    final String quickPasteLabel = AppTheme.label(isQuickPasteActive
        ? AppStrings.terminal.btnQuickPasteOn
        : AppStrings.terminal.btnPinQuickPaste);

    return GlassBox(
      padding: const EdgeInsets.all(16),
      borderRadius: AppTheme.brLg,
      opacity: 0.10,
      blur: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.data_object_rounded, size: 18, color: AppColors.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  AppTheme.label(AppStrings.terminal.inputSectionLabel),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w800),
                ),
              ),
              if (onToggleQuickPaste != null)
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onToggleQuickPaste,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: isQuickPasteActive
                          ? AppColors.ok.withValues(alpha: 0.18)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isQuickPasteActive
                            ? AppColors.ok.withValues(alpha: 0.55)
                            : Colors.white.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isQuickPasteActive ? Icons.bolt_rounded : Icons.push_pin_outlined,
                          size: 14,
                          color: isQuickPasteActive ? AppColors.ok : AppColors.textMuted,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          quickPasteLabel,
                          style: TextStyle(
                            color: isQuickPasteActive ? AppColors.ok : AppColors.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: false,
            maxLines: 4,
            style: TextStyle(color: AppColors.text, fontSize: 13, fontFamily: 'monospace'),
            decoration: InputDecoration(
              hintText: AppStrings.terminal.inputHint,
              hintStyle: TextStyle(color: AppColors.textDim),
              filled: true,
              fillColor: Colors.black.withValues(alpha: 0.28),
              contentPadding: const EdgeInsets.fromLTRB(14, 14, 52, 14),
              suffixIcon: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Align(
                  alignment: Alignment.topRight,
                  widthFactor: 1,
                  heightFactor: 1,
                  child: IconButton(
                    tooltip: AppTheme.label(AppStrings.terminal.btnPaste),
                    onPressed: onPaste,
                    icon: Icon(Icons.content_paste_rounded, color: AppColors.textSoft, size: 20),
                  ),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppTheme.brMd,
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              border: OutlineInputBorder(
                borderRadius: AppTheme.brMd,
                borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppTheme.brMd,
                borderSide: BorderSide(color: AppColors.accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: AppTheme.brMd,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.accent,
                  const Color(0xFF0284C7),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: AppTheme.brMd,
                onTap: onSubmit,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      AppTheme.label(AppStrings.terminal.btnSubmit),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TerminalFooter extends StatelessWidget {
  final bool xiaomiAcknowledged;
  final VoidCallback onXiaomiTap;
  final bool showHowTo;

  const TerminalFooter({
    super.key,
    required this.xiaomiAcknowledged,
    required this.onXiaomiTap,
    this.showHowTo = true,
  });

  @override
  Widget build(BuildContext context) {
    final bool modern = AppTheme.isModern;
    return Column(
      children: [
        if (!xiaomiAcknowledged && Platform.isAndroid)
          InkWell(
            onTap: onXiaomiTap,
            borderRadius: AppTheme.brMd,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.accentTint,
                borderRadius: AppTheme.brMd,
                border: Border.all(color: AppColors.accent, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppColors.accent, size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppTheme.label(AppStrings.terminal.btnXiaomiPermission),
                      style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          InkWell(
            borderRadius: AppTheme.brSm,
            onTap: onXiaomiTap,
            child: modern
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.battery_saver_rounded, size: 15, color: AppColors.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          AppTheme.label(AppStrings.terminal.btnXiaomiPermission),
                          style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : Text(
                    AppStrings.terminal.btnXiaomiPermission,
                    style: TextStyle(color: AppColors.textDim, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
          ),
        if (showHowTo) ...[
          const SizedBox(height: 16),
          Text(
            AppTheme.label(AppStrings.terminal.footerHowtoTitle),
            style: TextStyle(color: AppColors.textDim, fontSize: 11, letterSpacing: AppTheme.ls(1.0)),
          ),
          const SizedBox(height: 4),
          Text(
            AppTheme.label(AppStrings.terminal.footerHowtoDesc),
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 11, letterSpacing: AppTheme.ls(1.0)),
          ),
        ]
      ],
    );
  }
}
