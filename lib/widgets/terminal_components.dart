import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/app_strings.dart';

class TerminalLogo extends StatelessWidget {
  const TerminalLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset('assets/LogoMain.png', height: 80),
        const SizedBox(height: 16),
        Text(
          AppStrings.terminal.logoTitle,
          style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4.0),
        ),
        const SizedBox(height: 12),
        Text(
          AppStrings.terminal.logoSubtitle,
          style: const TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.5),
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(child: Container(height: 1, color: const Color(0xFF333333))),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10.0),
              child: Icon(Icons.diamond, size: 10, color: Color(0xFF666666)),
            ),
            Expanded(child: Container(height: 1, color: const Color(0xFF333333))),
          ],
        )
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
    return Column(
      children: [
        Text(AppStrings.terminal.labelTapToSwitchServer, style: const TextStyle(color: Color(0xFF666666), fontSize: 10, letterSpacing: 1.0)),
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
                style: const TextStyle(color: Color(0xFF888888), fontSize: 12, letterSpacing: 1.0),
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
                      fontFamily: 'monospace',
                      color: isQuickPasteActive ? const Color(0xFF4CAF50) : const Color(0xFF888888),
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
              style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 14),
              decoration: InputDecoration(
                hintText: AppStrings.terminal.inputHint,
                hintStyle: const TextStyle(color: Color(0xFF444444)),
                filled: true,
                fillColor: const Color(0xFF141615),
                border: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide.none),
                focusedBorder: const OutlineInputBorder(borderRadius: BorderRadius.zero, borderSide: BorderSide(color: Color(0xFF666666), width: 1)),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              child: InkWell(
                onTap: onPaste,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: const Color(0xFF333333),
                  child: Text(AppStrings.terminal.btnPaste, style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ],
        ),
        const SizedBox(height: 20),
        Material(
          color: const Color(0xFFB0B3A6),
          child: InkWell(
            onTap: onSubmit,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 18),
              alignment: Alignment.center,
              child: Text(
                AppStrings.terminal.btnSubmit,
                style: const TextStyle(color: Color(0xFF111111), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0),
              ),
            ),
          ),
        ),
      ],
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
    return Column(
      children: [
        if (!xiaomiAcknowledged && Platform.isAndroid)
          InkWell(
            onTap: onXiaomiTap,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0x33B54545),
                border: Border.all(color: const Color(0xFFB54545), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFB54545), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.terminal.btnXiaomiPermission,
                    style: const TextStyle(color: Color(0xFFB54545), fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          )
        else
          InkWell(
            onTap: onXiaomiTap,
            child: Text(
                AppStrings.terminal.btnXiaomiPermission,
                style: const TextStyle(color: Color(0xFF666666), fontSize: 11, fontWeight: FontWeight.bold)
            ),
          ),

        if (showHowTo) ...[
          const SizedBox(height: 16),
          Text(AppStrings.terminal.footerHowtoTitle, style: const TextStyle(color: Color(0xFF666666), fontSize: 11, letterSpacing: 1.0)),
          const SizedBox(height: 4),
          Text(AppStrings.terminal.footerHowtoDesc, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF888888), fontSize: 11, letterSpacing: 1.0)),
        ]
      ],
    );
  }
}