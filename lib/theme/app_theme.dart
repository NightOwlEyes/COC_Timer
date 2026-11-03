import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hai giao diện song song của ứng dụng.
/// - [terminal]: Phong cách Terminal Retro (giao diện gốc).
/// - [modern]: Phong cách Kính mờ (Glassmorphism).
enum AppThemeMode { terminal, modern }

/// Quản lý theme hiện tại, lưu cấu hình và cung cấp các token hình dạng/font + widget kính mờ.
class AppTheme {
  static const String _prefKey = 'app_theme_mode';

  static final ValueNotifier<AppThemeMode> notifier = ValueNotifier(AppThemeMode.terminal);

  static AppThemeMode get mode => notifier.value;
  static bool get isTerminal => notifier.value == AppThemeMode.terminal;
  static bool get isModern => notifier.value == AppThemeMode.modern;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    notifier.value = AppThemeMode.values.firstWhere(
      (m) => m.name == saved,
      orElse: () => AppThemeMode.terminal,
    );
  }

  static Future<void> setMode(AppThemeMode newMode) async {
    if (notifier.value == newMode) return;
    notifier.value = newMode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, newMode.name);
  }

  static Future<void> toggle() =>
      setMode(isTerminal ? AppThemeMode.modern : AppThemeMode.terminal);

  // ================= TOKEN HÌNH DẠNG & FONT =================

  /// Font chính: Terminal dùng monospace, Modern dùng font hệ thống (Roboto trên Android).
  static String? get font => isTerminal ? 'monospace' : null;

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
        fontFamily: 'monospace',
        textTheme: ThemeData.dark().textTheme.apply(fontFamily: 'monospace'),
      );
    }
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.text,
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
  /// Làng chính (Home Village): Xanh băng phát sáng (Cyan Glass).
  static Color get accent => _p(0xFFB54545, 0xFF38BDF8);
  static Color get accentTint => _p(0x33B54545, 0x2E38BDF8);
  /// Làng thợ xây (Builder Base): Tím ngân hà (Astral Violet).
  static Color get accentBase => _p(0xFFF8A4BD, 0xFFA78BFA);
  static Color get accentBaseTint => _p(0x22F8A4BD, 0x2EA78BFA);

  // ---- Trạng thái ----
  static Color get ok => _p(0xFF4CAF50, 0xFF34D399);
  static Color get okTint => _p(0x224CAF50, 0x2E34D399);
  static Color get warn => _p(0xFFE2B714, 0xFFFBBF24);
  static Color get danger => _p(0xFF8B2B2B, 0xFFFB7185);
  static Color get dangerTint => _p(0x228B2B2B, 0x2EFB7185);

  // ---- Khác ----
  static Color get settingsAccent => _p(0xFF97A87C, 0xFF60A5FA);
  static Color get buttonBg => _p(0xFFB0B3A6, 0xFF38BDF8);
  static Color get sponsor => _p(0xFFEA4AAA, 0xFFF472B6);
  static Color get sponsorTint => _p(0x22EA4AAA, 0x2EF472B6);

  // ---- Màu theo tài nguyên game ----
  static Color get builder => _p(0xFFE2B714, 0xFFFBBF24);
  static Color get lab => _p(0xFFB54545, 0xFFC084FC);
  static Color get pet => _p(0xFFB54545, 0xFF2DD4BF);
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

    final Color orb1 = isBuilderBase ? const Color(0xFF7C3AED) : const Color(0xFF0284C7);
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
