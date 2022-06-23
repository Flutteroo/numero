import 'package:flutter/material.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const defaultColor = Colors.blue;
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = defaultColor;
    double verticalLine = 1 / 2;
    double horizontalLine = 1 / 2;

    canvas.drawLine(Offset(size.width * verticalLine, 0),
        Offset(size.width * verticalLine, size.height), paint);

    canvas.drawLine(Offset(0, size.height * horizontalLine),
        Offset(size.width, size.height * horizontalLine), paint);
  }

  @override
  bool shouldRepaint(GridPainter oldDelegate) {
    return false;
  }
}
