import 'package:flutter/material.dart';

/// Spotify authentic logo widget using the official Spotify logo image asset.
/// Clean black background container so the logo blends perfectly into Spotify dark UI.
class SpotifyLogo extends StatelessWidget {
  final double size;
  final bool showText;
  final double fontSize;

  const SpotifyLogo({
    super.key,
    this.size = 80,
    this.showText = true,
    this.fontSize = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Center logo
        SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            'assets/images/spotify_logo.png',
            width: size,
            height: size,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return CustomPaint(
                size: Size(size, size),
                painter: _SpotifyFallbackPainter(),
              );
            },
          ),
        ),
        if (showText) ...[
          const SizedBox(height: 14),
          Text(
            'MusicXSpot',
            style: TextStyle(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
            ),
          ),
        ],
      ],
    );
  }
}

/// Fallback vector painter matching the authentic Spotify logo geometry.
class _SpotifyFallbackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final radius = size.width / 2;
    final center = Offset(size.width / 2, size.height / 2);

    // Green circle
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF1ED760)
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    // Three sound-wave arcs in dark (#121212)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.209); // -12 degrees in radians
    canvas.translate(-center.dx, -center.dy);

    final wavePaint = Paint()
      ..color = const Color(0xFF121212)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    // Top arc (largest)
    wavePaint.strokeWidth = size.width * 0.088;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx, center.dy + size.height * 0.32), radius: size.width * 0.44),
      -2.419, 1.696, false, wavePaint,
    );

    // Middle arc
    wavePaint.strokeWidth = size.width * 0.080;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx, center.dy + size.height * 0.34), radius: size.width * 0.33),
      -2.388, 1.634, false, wavePaint,
    );

    // Bottom arc (smallest)
    wavePaint.strokeWidth = size.width * 0.072;
    canvas.drawArc(
      Rect.fromCircle(center: Offset(center.dx, center.dy + size.height * 0.36), radius: size.width * 0.22),
      -2.356, 1.571, false, wavePaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
