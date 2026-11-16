import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hai giao diện song song của ứng dụng.
/// - [terminal]: Phong cách Terminal Retro (giao diện gốc).
/// - [modern]: Phong cách Kính mờ (Glassmorphism).
enum AppThemeMode { terminal, modern }

/// 7 bảng màu nhấn tùy chỉnh cho giao diện ứng dụng.
enum AppAccentColor { pink, red, orange, yellow, green, blue, purple }

extension AppAccentColorSpec on AppAccentColor {
  Color get primary {
    switch (this) {
      case AppAccentColor.pink:
        return const Color(0xFFF472B6);
      case AppAccentColor.red:
        return const Color(0xFFEF4444);
      case AppAccentColor.orange:
        return const Color(0xFFFB923C);
      case AppAccentColor.yellow:
        return const Color(0xFFFACC15);
      case AppAccentColor.green:
        return const Color(0xFF4ADE80);
      case AppAccentColor.blue:
        return const Color(0xFF38BDF8);
      case AppAccentColor.purple:
        return const Color(0xFFA78BFA);
    }
  }

  Color get deep {
    switch (this) {
      case AppAccentColor.pink:
        return const Color(0xFFDB2777);
      case AppAccentColor.red:
        return const Color(0xFFDC2626);
      case AppAccentColor.orange:
        return const Color(0xFFEA580C);
      case AppAccentColor.yellow:
        return const Color(0xFFCA8A04);
      case AppAccentColor.green:
        return const Color(0xFF16A34A);
      case AppAccentColor.blue:
        return const Color(0xFF0284C7);
      case AppAccentColor.purple:
        return const Color(0xFF7C3AED);
    }
  }

  String localizedName(String languageCode) {
    final bool isVi = languageCode == 'vi';
    switch (this) {
      case AppAccentColor.pink:
        return isVi ? 'Hồng' : 'Pink';
      case AppAccentColor.red:
        return isVi ? 'Đỏ' : 'Red';
      case AppAccentColor.orange:
        return isVi ? 'Cam' : 'Orange';
      case AppAccentColor.yellow:
        return isVi ? 'Vàng' : 'Yellow';
      case AppAccentColor.green:
        return isVi ? 'Xanh lá' : 'Green';
      case AppAccentColor.blue:
        return isVi ? 'Xanh dương (Mặc định)' : 'Blue (Default)';
      case AppAccentColor.purple:
        return isVi ? 'Tím' : 'Purple';
    }
  }
}

/// Quản lý theme hiện tại, lưu cấu hình và cung cấp các token hình dạng/font + widget kính mờ.
class AppTheme {
  static const String _prefKey = 'app_theme_mode';
  static const String _accentPrefKey = 'app_accent_color';

  static final ValueNotifier<AppThemeMode> notifier = ValueNotifier(AppThemeMode.terminal);
  static final ValueNotifier<AppAccentColor> accentNotifier = ValueNotifier(AppAccentColor.blue);
  static final ValueNotifier<int> revisionNotifier = ValueNotifier(0);
  static bool hasCustomAccent = false;

  static AppThemeMode get mode => notifier.value;
  static AppAccentColor get accentColor => accentNotifier.value;
  static bool get isTerminal => notifier.value == AppThemeMode.terminal;
  static bool get isModern => notifier.value == AppThemeMode.modern;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    notifier.value = AppThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => AppThemeMode.terminal,
    );

    final savedAccent = prefs.getString(_accentPrefKey);
    hasCustomAccent = savedAccent != null;
    accentNotifier.value = AppAccentColor.values.firstWhere(
      (c) => c.name == savedAccent,
      orElse: () => AppAccentColor.blue,
    );
  }

  static Future<void> setMode(AppThemeMode newMode) async {
    if (notifier.value == newMode) return;
    notifier.value = newMode;
    revisionNotifier.value++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newMode.name);
  }

  static Future<void> setAccentColor(AppAccentColor color) async {
    final bool changed = accentNotifier.value != color || !hasCustomAccent;
    hasCustomAccent = true;
    accentNotifier.value = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accentPrefKey, color.name);
    if (changed) {
      revisionNotifier.value++;
    }
  }

  static Future<void> toggle() =>
      setMode(isTerminal ? AppThemeMode.modern : AppThemeMode.terminal);

  // ================= TOKEN HÌNH DẠNG & FONT =================

  /// Font chính: Terminal dùng monospace, Glass dùng JosefinSans (riêng màu Hồng dùng Coiny).
  static String get font {
    if (isTerminal) return 'monospace';
    return accentColor == AppAccentColor.pink ? 'Coiny' : 'JosefinSans';
  }

  /// Bo góc: Terminal vuông vức, Glassmorphism bo mềm.
  static double get radiusSm => isTerminal ? 0 : 10;
  static double get radiusMd => isTerminal ? 0 : 14;
  static double get radiusLg => isTerminal ? 0 : 20;

  static BorderRadius get brSm => BorderRadius.circular(radiusSm);
  static BorderRadius get brMd => BorderRadius.circular(radiusMd);
  static BorderRadius get brLg => BorderRadius.circular(radiusLg);

  /// Khoảng cách chữ cho tiêu đề: Terminal giãn rộng kiểu "H O M E", Modern gọn gàng.
  static double ls(double terminalValue, [double modernValue = 0.3]) =>
      isTerminal ? terminalValue : modernValue;

  /// Chuyển chữ kiểu Terminal sang chữ gọn gàng khi ở theme Modern:
  /// - "[ CLOSE ]" -> "CLOSE"
  /// - "■  H O M E   V I L L A G E  ■" -> "HOME VILLAGE"
  /// - "X Á C   N H Ậ N   ▶" -> "XÁC NHẬN"
  static String label(String text) {
    if (isTerminal) return text;
    var t = text.trim();
    t = t.replaceAll(RegExp(r'^[■▶►◀◄]\s*'), '').replaceAll(RegExp(r'\s*[■▶►◀◄]$'), '').trim();
    if (t.startsWith('[') && t.endsWith(']') && '['.allMatches(t).length == 1) {
      t = t.substring(1, t.length - 1).trim();
    }
    if (RegExp(r'^\S( \S)+(\s{2,}\S( \S)*)*$').hasMatch(t)) {
      t = t.split(RegExp(r'\s{2,}')).map((w) => w.replaceAll(' ', '')).join(' ');
    }
    return t;
  }

  /// ThemeData cho các widget Material.
  static ThemeData get themeData {
    if (isTerminal) {
      return ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        primaryColor: AppColors.text,
        fontFamily: font,
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: font),
      );
    }
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.text,
      fontFamily: font,
      textTheme: ThemeData.dark().textTheme.apply(fontFamily: font),
      colorScheme: ColorScheme.dark(
        primary: AppColors.accent,
        secondary: AppColors.ok,
        surface: const Color(0xFF0F172A),
        error: AppColors.danger,
      ),
    );
  }
}

/// Token màu ngữ nghĩa (Semantic tokens).
/// Bộ Terminal giữ NGUYÊN 100% mã màu của giao diện gốc.
/// Bộ Modern thiết kế theo phong cách Kính mờ (Glassmorphism).
class AppColors {
  static Color _p(int terminal, int modern) =>
      Color(AppTheme.isTerminal ? terminal : modern);

  // ---- Nền & bề mặt ----
  static Color get background => _p(0xFF121212, 0xFF070B19);
  static Color get dialogBg => _p(0xFF0A0C0B, 0xD90F172A);
  static Color get surfaceAlt => _p(0xFF0D0F0E, 0x1FFFFFFF);
  static Color get surface => _p(0xFF141615, 0x26FFFFFF);
  static Color get surfaceHigh => _p(0xFF1A1C1B, 0x36FFFFFF);
  static Color get inputBg => _p(0xFF111111, 0x59060913);

  // ---- Viền & phân cách ----
  static Color get divider => _p(0xFF222222, 0x24FFFFFF);
  static Color get border => _p(0xFF333333, 0x38FFFFFF);
  static Color get borderStrong => _p(0xFF444444, 0x55FFFFFF);

  // ---- Chữ (độ tương phản >= 4.5:1 trên nền kính tối) ----
  static Color get text => _p(0xFFE0E0E0, 0xFFF8FAFC);
  static Color get textSoft => _p(0xFFAAAAAA, 0xFFE2E8F0);
  static Color get textMuted => _p(0xFF888888, 0xFFCBD5E1);
  static Color get textDim => _p(0xFF666666, 0xFF94A3B8);
  static Color get textFaint => _p(0xFF555555, 0xFF64748B);

  // ---- Màu nhấn theo làng ----
  /// Làng chính (Home Village): Đồng bộ theo màu tùy chỉnh của người dùng trên cả 2 theme.
  static Color get accent => AppTheme.accentColor.primary;

  static Color get accentTint => accent.withValues(alpha: AppTheme.isTerminal ? 0.22 : 0.18);

  static Color get accentDeep => AppTheme.accentColor.deep;

  /// Chữ/icon nổi bật trên nền nút màu nhấn [accent] (đảm bảo dễ đọc cả với màu Vàng).
  static Color get onAccent =>
      accent.computeLuminance() > 0.55 ? const Color(0xFF0F172A) : Colors.white;

  /// Làng thợ xây (Builder Base): Đồng bộ theo màu tùy chỉnh của người dùng.
  static Color get accentBase => accent;
  static Color get accentBaseTint => accentTint;

  // ---- Trạng thái ----
  static Color get ok => _p(0xFF4CAF50, 0xFF34D399);
  static Color get okTint => _p(0x224CAF50, 0x2E34D399);
  static Color get warn => _p(0xFFE2B714, 0xFFFBBF24);
  static Color get danger => _p(0xFF8B2B2B, 0xFFFB7185);
  static Color get dangerTint => _p(0x228B2B2B, 0x2EFB7185);

  // ---- Khác ----
  static Color get settingsAccent => AppTheme.accentColor.primary;
  static Color get buttonBg => AppTheme.accentColor.primary;
  static Color get sponsor => _p(0xFFEA4AAA, 0xFFF472B6);
  static Color get sponsorTint => _p(0x22EA4AAA, 0x2EF472B6);

  // ---- Màu theo tài nguyên game ----
  static Color get builder => _p(0xFFE2B714, 0xFFFBBF24);
  static Color get lab => _p(0xFFB54545, 0xFFC084FC);
  static Color get pet => _p(0xFFB54545, 0xFF2DD4BF);
}

/// Bộ chọn nhanh 7 bảng màu nhấn (Hồng, Đỏ, Cam, Vàng, Xanh lá, Xanh dương, Tím).
class AccentColorPicker extends StatelessWidget {
  final String languageCode;
  final double swatchSize;
  final double spacing;

  const AccentColorPicker({
    super.key,
    required this.languageCode,
    this.swatchSize = 24,
    this.spacing = 8,
  });

  @override
  Widget build(BuildContext context) {
    final bool isModern = AppTheme.isModern;
    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: AppAccentColor.values.map((colorOption) {
        final bool isSelected = AppTheme.accentColor == colorOption;
        final Color c = colorOption.primary;
        final Color checkColor = c.computeLuminance() > 0.55 ? Colors.black : Colors.white;

        return Tooltip(
          message: colorOption.localizedName(languageCode),
          child: InkWell(
            borderRadius: BorderRadius.circular(isModern ? swatchSize : 0),
            onTap: () => AppTheme.setAccentColor(colorOption),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: swatchSize,
              height: swatchSize,
              decoration: BoxDecoration(
                color: c,
                shape: isModern ? BoxShape.circle : BoxShape.rectangle,
                border: Border.all(
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.28),
                  width: isSelected ? 2.2 : 1.0,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: c.withValues(alpha: 0.55),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(Icons.check_rounded, size: swatchSize * 0.58, color: checkColor)
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Nền có các quầng sáng màu (ambient orbs) phía sau để lớp kính mờ khúc xạ ánh sáng.
/// Ở chế độ Terminal, widget này trả thẳng [child] không can thiệp.
class GlassBackground extends StatelessWidget {
  final Widget child;
  final bool isBuilderBase;

  const GlassBackground({
    super.key,
    required this.child,
    this.isBuilderBase = false,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isTerminal) return child;

    final Color orb1 = AppColors.accentDeep;
    final Color orb2 = isBuilderBase ? const Color(0xFF2563EB) : const Color(0xFF7C3AED);
    final Color orb3 = isBuilderBase ? const Color(0xFF0D9488) : const Color(0xFFD97706);

    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF060A17),
                  Color(0xFF0F172A),
                  Color(0xFF13112C),
                ],
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -80,
                  left: -60,
                  child: _GlowOrb(color: orb1, size: 280, opacity: 0.34),
                ),
                Positioned(
                  top: 220,
                  right: -90,
                  child: _GlowOrb(color: orb2, size: 300, opacity: 0.28),
                ),
                Positioned(
                  bottom: -70,
                  left: 30,
                  child: _GlowOrb(color: orb3, size: 250, opacity: 0.22),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: opacity * 0.35),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
      ),
    );
  }
}

/// Khung thẻ kính mờ (Frosted Glass Container) tối ưu GPU (không dùng BackdropFilter
/// lặp lại trên từng thẻ để tránh tụt FPS khi cuộn và khi đồng hồ nhảy mỗi giây).
class GlassBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final Color? tintColor;
  final Color? borderColor;
  final double blur;
  final double opacity;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showShadow;

  const GlassBox({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.tintColor,
    this.borderColor,
    this.blur = 16.0,
    this.opacity = 0.10,
    this.onTap,
    this.onLongPress,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final BorderRadius br = borderRadius ?? AppTheme.brLg;
    final Color baseTint = tintColor ?? Colors.white;
    final Color effectiveBorder = borderColor ?? Colors.white.withValues(alpha: 0.20);
    final Color topSurface = Color.alphaBlend(
      baseTint.withValues(alpha: (opacity + 0.08).clamp(0.0, 1.0)),
      const Color(0x99162238),
    );
    final Color bottomSurface = Color.alphaBlend(
      Colors.white.withValues(alpha: (opacity * 0.35).clamp(0.0, 1.0)),
      const Color(0x800D1526),
    );

    Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: br,
        border: Border.all(color: effectiveBorder, width: 1.0),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            topSurface,
            bottomSurface,
          ],
        ),
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.24),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: br,
          onTap: onTap,
          onLongPress: onLongPress,
          splashColor: baseTint.withValues(alpha: 0.18),
          highlightColor: baseTint.withValues(alpha: 0.08),
          child: content,
        ),
      );
    }

    if (margin != null) {
      return Padding(padding: margin!, child: content);
    }
    return content;
  }
}

/// Hộp thoại tự động chuyển đổi giữa Terminal (viền vuông sắc cạnh)
/// và Glassmorphism (kính mờ xuyên thấu, viền phát sáng mảnh).
class AdaptiveDialog extends StatelessWidget {
  final Widget child;
  final Color? accentColor;
  final Color? borderColor;
  final Color? backgroundColor;
  final EdgeInsets insetPadding;
  final EdgeInsetsGeometry? padding;
  final double? terminalBorderWidth;
  final double? borderWidth;

  const AdaptiveDialog({
    super.key,
    required this.child,
    this.accentColor,
    this.borderColor,
    this.backgroundColor,
    this.insetPadding = const EdgeInsets.all(16),
    this.padding,
    this.terminalBorderWidth,
    this.borderWidth,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = accentColor ?? borderColor ?? AppColors.ok;
    final double termWidth = terminalBorderWidth ?? borderWidth ?? 1.5;
    final EdgeInsetsGeometry effectivePadding =
        padding ?? (accentColor != null ? const EdgeInsets.all(20) : EdgeInsets.zero);

    if (AppTheme.isTerminal) {
      return Dialog(
        backgroundColor: backgroundColor ?? AppColors.dialogBg,
        insetPadding: insetPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: BorderSide(color: color, width: termWidth),
        ),
        child: Padding(
          padding: effectivePadding,
          child: child,
        ),
      );
    }

    final BorderRadius br = AppTheme.brLg;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding,
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: effectivePadding,
            decoration: BoxDecoration(
              borderRadius: br,
              border: Border.all(
                color: color.withValues(alpha: 0.48),
                width: 1.2,
              ),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xF01C273E),
                  Color(0xF50F172A),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.55),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class GlassDialogSurface extends StatelessWidget {
  final Widget child;
  final Color? color;
  final BorderRadius? borderRadius;

  const GlassDialogSurface({
    super.key,
    required this.child,
    this.color,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (AppTheme.isTerminal) {
      return Material(
        color: color ?? AppColors.surfaceAlt,
        borderRadius: borderRadius ?? AppTheme.brLg,
        child: child,
      );
    }
    final BorderRadius br = borderRadius ?? AppTheme.brLg;
    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: br,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.24),
              width: 1.2,
            ),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xF01C273E),
                Color(0xF50F172A),
              ],
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}
