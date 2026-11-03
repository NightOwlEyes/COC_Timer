import '../theme/app_theme.dart';
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
    final Color accentColor = AppColors.warn;

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateSB) => AdaptiveDialog(
          borderColor: accentColor,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppTheme.label(AppStrings.terminal.reimportReminderTitle),
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      color: accentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  SizedBox(height: 14),
                  Text(
                    AppTheme.label(AppStrings.terminal.reimportReminderDesc),
                    style: TextStyle(
                      fontFamily: AppTheme.font,
                      color: AppColors.text,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 16),
                  InkWell(
                    onTap: () => setStateSB(() => dontShowAgain = !dontShowAgain),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            dontShowAgain ? Icons.check_box : Icons.check_box_outline_blank,
                            color: dontShowAgain ? accentColor : AppColors.textDim,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              AppTheme.label(AppStrings.terminal.reimportDontShowAgain),
                              style: TextStyle(
                                fontFamily: AppTheme.font,
                                color: dontShowAgain ? AppColors.text : AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12),
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
                        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        child: Text(
                          AppTheme.label(AppStrings.terminal.btnUnderstood),
                          style: TextStyle(
                            fontFamily: AppTheme.font,
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
    final Color accentColor = AppColors.ok;

    showDialog(
      context: context,
      builder: (ctx) => AdaptiveDialog(
        borderColor: accentColor,
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppTheme.label(AppStrings.terminal.quickPasteInfoTitle),
                  style: TextStyle(
                    fontFamily: AppTheme.font,
                    color: accentColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                SizedBox(height: 14),
                Text(
                  AppTheme.label(AppStrings.terminal.quickPasteInfoDesc),
                  style: TextStyle(
                    fontFamily: AppTheme.font,
                    color: AppColors.text,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => Navigator.pop(ctx),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: Text(
                        AppTheme.label(AppStrings.terminal.btnUnderstood),
                        style: TextStyle(
                          fontFamily: AppTheme.font,
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
    final Color borderColor = isSuccess ? AppColors.ok : AppColors.accent;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdaptiveDialog(
        borderColor: borderColor,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0, horizontal: 16.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                color: borderColor,
                size: 22,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    fontFamily: AppTheme.font,
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
      builder: (ctx) => AdaptiveDialog(
        borderColor: AppColors.accent,
        borderWidth: 1.0,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppTheme.label(AppStrings.terminal.deleteDialogTitle),
                style: TextStyle(color: AppColors.accent, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
              ),
              SizedBox(height: 16),
              Text(
                AppStrings.format(AppStrings.terminal.deleteDialogMessage, {'tag': tag}),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.text, fontSize: 13, fontFamily: AppTheme.font),
              ),
              SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx),
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          AppTheme.label(cancelLabel),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          AppTheme.label(deleteLabel),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.accent, fontSize: 13, fontWeight: FontWeight.bold, fontFamily: AppTheme.font),
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
        builder: (context, setStateSB) => AdaptiveDialog(
          borderColor: AppColors.ok,
          borderWidth: 1.0,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppTheme.label(AppStrings.terminal.newVillageDialogTitle),
                    style: TextStyle(color: AppColors.ok, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    AppStrings.format(AppStrings.terminal.newVillageDialogTagLabel, {'tag': tag}),
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: tempController,
                    autofocus: false,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: AppStrings.terminal.newVillageNameHint,
                      hintStyle: TextStyle(color: AppColors.borderStrong),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.borderStrong)),
                      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.ok)),
                    ),
                  ),
                  SizedBox(height: 24),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AppTheme.label(AppStrings.terminal.trackingOptionsLabel),
                      style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 12),
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
                              color: trackHome ? AppColors.ok : AppColors.borderStrong,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              AppTheme.label(AppStrings.terminal.trackingHomeVillage),
                              style: TextStyle(
                                color: trackHome ? Colors.white : AppColors.textMuted,
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
                              color: trackBuilder ? AppColors.ok : AppColors.borderStrong,
                              size: 18,
                            ),
                            SizedBox(width: 6),
                            Text(
                              AppTheme.label(AppStrings.terminal.trackingBuilderBase),
                              style: TextStyle(
                                color: trackBuilder ? Colors.white : AppColors.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.ok),
                      onPressed: () => Navigator.pop(ctx, {
                        'name': tempController.text,
                        'home': trackHome,
                        'builder': trackBuilder,
                      }),
                      child: Text(
                        AppTheme.label(AppStrings.terminal.btnSaveAndAddVillage),
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
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
