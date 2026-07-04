import 'package:flutter/material.dart';

import '../../services/audio_service.dart';
import '../../theme.dart';

/// Full-screen ruled notebook paper backdrop.
class NotebookPage extends StatelessWidget {
  const NotebookPage({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomPaint(
        painter: _PaperPainter(),
        child: SizedBox.expand(child: SafeArea(child: child)),
      ),
    );
  }
}

class _PaperPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = InkPalette.paper);
    final ruled = Paint()
      ..color = InkPalette.ruledLine.withValues(alpha: 0.55)
      ..strokeWidth = 1.2;
    for (var y = 36.0; y < size.height; y += 34) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), ruled);
    }
    canvas.drawLine(
        const Offset(56, 0),
        Offset(56, size.height),
        Paint()
          ..color = InkPalette.marginLine.withValues(alpha: 0.5)
          ..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// A hand-drawn-looking button with an ink border.
class InkButton extends StatefulWidget {
  const InkButton({
    super.key,
    required this.label,
    required this.onTap,
    this.color = InkPalette.ink,
    this.fontSize = 26,
    this.width,
  });

  final String label;
  final VoidCallback onTap;
  final Color color;
  final double fontSize;
  final double? width;

  @override
  State<InkButton> createState() => _InkButtonState();
}

class _InkButtonState extends State<InkButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) {
        setState(() => _pressed = false);
        AudioService.instance.click();
        widget.onTap();
      },
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          decoration: BoxDecoration(
            color: InkPalette.paper,
            border: Border.all(color: widget.color, width: 2.4),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(14),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(5),
              bottomRight: Radius.circular(16),
            ),
            boxShadow: [
              BoxShadow(
                color: InkPalette.ink.withValues(alpha: 0.18),
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: hand(widget.fontSize, color: widget.color),
          ),
        ),
      ),
    );
  }
}

class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 22});

  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Optimized: Generate icons without rebuilding on every render
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(
            i < stars ? Icons.star : Icons.star_border,
            size: size,
            color: i < stars ? InkPalette.gold : InkPalette.inkFaded,
          ),
      ],
    );
  }
}
