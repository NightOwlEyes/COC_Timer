import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/app_strings.dart';

class TerminalDialogs {
  static Future<void> checkAndShowReimportReminder(
    BuildContext context, {
    required bool Function() shouldSkip,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final bool hideReminder = prefs.getBool('hide_reimport_reminder') ?? false;
    if (hideReminder || !context.mounted || shouldSkip()) return;

    bool dontShowAgain = false;
    const Color accentColor = Color(0xFFE2B714);

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => Dialog(
          backgroundColor: const Color(0xFF0A0C0B),
          shape: const RoundedRectangleBorder(
            side: BorderSide(color: accentColor, width: 1.5),
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppStrings.terminal.reimportReminderTitle,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    AppStrings.terminal.reimportReminderDesc,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      color: Color(0xFFE0E0E0),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  InkWell(
                    onTap: () => setStateSB(() => dontShowAgain = !dontShowAgain),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dontShowAgain ? Icons.check_box : Icons.check_box_outline_blank,
                            color: dontShowAgain ? accentColor : const Color(0xFF666666),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppStrings.terminal.reimportDontShowAgain,
                              style: TextStyle(
                                fontFamily: 'monospace',
                                color: dontShowAgain ? const Color(0xFFE0E0E0) : const Color(0xFF888888),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: InkWell(
                      onTap: () async {
                        if (dontShowAgain) {
                          await prefs.setBool('hide_reimport_reminder', true);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Text(
                          AppStrings.terminal.btnUnderstood,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static void showQuickPasteInfoDialog(BuildContext context) {
    if (!context.mounted) return;
    FocusManager.instance.primaryFocus?.unfocus();
    const Color accentColor = Color(0xFF4CAF50);

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: const RoundedRectangleBorder(
          side: BorderSide(color: accentColor, width: 1.5),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.terminal.quickPasteInfoTitle,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  AppStrings.terminal.quickPasteInfoDesc,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    color: Color(0xFFE0E0E0),
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        AppStrings.terminal.btnUnderstood,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          color: accentColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static void showQuickPasteFeedbackOverlay(
    BuildContext context,
    String message, {
    required bool isSuccess,
  }) {
    if (!context.mounted) return;
    final Color borderColor = isSuccess ? const Color(0xFF4CAF50) : const Color(0xFFB54545);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: RoundedRectangleBorder(side: BorderSide(color: borderColor, width: 1.5)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: borderColor,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: borderColor,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void confirmDeleteVillage(
    BuildContext context, {
    required String tag,
    required VoidCallback onConfirm,
  }) {
    String cancelLabel = AppStrings.terminal.btnCancel.trim();
    if (!cancelLabel.startsWith('[')) cancelLabel = "[ $cancelLabel ]";

    String deleteLabel = AppStrings.terminal.btnDeleteNow.trim();
    if (!deleteLabel.startsWith('[')) deleteLabel = "[ $deleteLabel ]";

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF0A0C0B),
        shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFFB54545), width: 1)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppStrings.terminal.deleteDialogTitle,
                style: const TextStyle(color: Color(0xFFB54545), fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              Text(
                AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFFE0E0E0), fontSize: 13, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          cancelLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFF888888), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          deleteLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Color(0xFFB54545), fontSize: 13, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  static Future<Map<String, dynamic>?> promptForVillageName(
    BuildContext context,
    String tag, {
    String? prefilledName,
  }) {
    final TextEditingController tempController = TextEditingController(text: prefilledName ?? "");
    bool trackHome = true, trackBuilder = true;

    return showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => Dialog(
          backgroundColor: const Color(0xFF0A0C0B),
          shape: const RoundedRectangleBorder(side: BorderSide(color: Color(0xFF4CAF50), width: 1)),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.terminal.newVillageDialogTitle,
                    style: const TextStyle(color: Color(0xFF4CAF50), fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppStrings.format(AppStrings.terminal.newVillageDialogTagLabel, {'tag': tag}),
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: tempController,
                    autofocus: false,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppStrings.terminal.newVillageNameHint,
                      hintStyle: const TextStyle(color: Color(0xFF444444)),
                      enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF444444))),
                      focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF4CAF50))),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppStrings.terminal.trackingOptionsLabel,
                      style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      InkWell(
                        onTap: () => setStateSB(() => trackHome = !trackHome),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trackHome ? Icons.check_box : Icons.check_box_outline_blank,
                              color: trackHome ? const Color(0xFF4CAF50) : const Color(0xFF444444),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.terminal.trackingHomeVillage,
                              style: TextStyle(
                                color: trackHome ? Colors.white : const Color(0xFF888888),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => setStateSB(() => trackBuilder = !trackBuilder),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              trackBuilder ? Icons.check_box : Icons.check_box_outline_blank,
                              color: trackBuilder ? const Color(0xFF4CAF50) : const Color(0xFF444444),
                              size: 18,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              AppStrings.terminal.trackingBuilderBase,
                              style: TextStyle(
                                color: trackBuilder ? Colors.white : const Color(0xFF888888),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50)),
                      onPressed: () => Navigator.pop(ctx, {
                        'name': tempController.text,
                        'home': trackHome,
                        'builder': trackBuilder,
                      }),
                      child: Text(
                        AppStrings.terminal.btnSaveAndAddVillage,
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

