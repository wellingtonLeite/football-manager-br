import 'package:flutter/material.dart';

const Map<String, List<Color>> _kClubColors = {
  'FLA': [Color(0xFFE52521), Color(0xFF000000)],
  'PAL': [Color(0xFF006437), Color(0xFFFFFFFF)],
  'CRU': [Color(0xFF003DA5), Color(0xFF000000)],
  'BOT': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'BAH': [Color(0xFF005BAA), Color(0xFFE9242C)],
  'MIR': [Color(0xFFFFD700), Color(0xFF008000)],
  'SAO': [Color(0xFFE52521), Color(0xFFFFFFFF)],
  'FLU': [Color(0xFF870A28), Color(0xFF046A38)],
  'COR': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'GRE': [Color(0xFF0D80BF), Color(0xFF000000)],
  'CAM': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'RBB': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'VAS': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'INT': [Color(0xFFE52521), Color(0xFFFFFFFF)],
  'SAN': [Color(0xFFFFFFFF), Color(0xFF000000)],
  'CEA': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'CFC': [Color(0xFF00554E), Color(0xFFFFFFFF)],
  'CAP': [Color(0xFFE52521), Color(0xFF000000)],
  'CHA': [Color(0xFF00854A), Color(0xFFFFFFFF)],
  'REM': [Color(0xFF003C8F), Color(0xFFFFFFFF)],
};

class ClubShield extends StatelessWidget {
  final String shortName;
  final double size;
  const ClubShield({required this.shortName, this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    final colors = _kClubColors[shortName] ??
        const [Color(0xFF616161), Color(0xFF9E9E9E)];
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: CustomPaint(
        painter: _ShieldPainter(
          primary: colors[0],
          secondary: colors[1],
          label: shortName,
        ),
      ),
    );
  }
}

class _ShieldPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final String label;

  _ShieldPainter({
    required this.primary,
    required this.secondary,
    required this.label,
  });

  Path _shieldPath(Size s) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(s.width, 0)
      ..lineTo(s.width, s.height * 0.60)
      ..quadraticBezierTo(s.width, s.height * 0.86, s.width / 2, s.height)
      ..quadraticBezierTo(0, s.height * 0.86, 0, s.height * 0.60)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shieldPath(size);

    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width / 2, size.height),
      Paint()..color = primary,
    );
    canvas.drawRect(
      Rect.fromLTWH(size.width / 2, 0, size.width / 2, size.height),
      Paint()..color = secondary,
    );
    canvas.restore();

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontSize: size.width * 0.32,
          fontWeight: FontWeight.bold,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        (size.width - tp.width) / 2,
        (size.height - tp.height) / 2 - size.height * 0.06,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldPainter old) =>
      old.label != label || old.primary != primary || old.secondary != secondary;
}
