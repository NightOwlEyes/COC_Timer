import '../theme/app_theme.dart';
import 'package:flutter/material.dart';

class TerminalFramePainter extends CustomPainter {
  // Ghi lại theme lúc tạo để biết khi nào cần vẽ lại.
  final AppThemeMode mode = AppTheme.mode;

  @override
  void paint(Canvas canvas, Size size) {
    // Theme Modern không dùng khung góc kiểu Terminal.
    if (mode != AppThemeMode.terminal) return;

    final paint = Paint()
      ..color = AppColors.borderStrong
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    const double lineLength = 20.0;

    canvas.drawLine(Offset(0, 0), Offset(lineLength, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(0, lineLength), paint);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - lineLength, 0), paint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, lineLength), paint);

    canvas.drawLine(Offset(0, size.height), Offset(lineLength, size.height), paint);
    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - lineLength), paint);

    canvas.drawLine(Offset(size.width, size.height), Offset(size.width - lineLength, size.height), paint);
    canvas.drawLine(Offset(size.width, size.height), Offset(size.width, size.height - lineLength), paint);
  }

  @override
  bool shouldRepaint(covariant TerminalFramePainter oldDelegate) => oldDelegate.mode != mode;
}
