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
  'VIT': [Color(0xFFE30613), Color(0xFF000000)],
  // Série B
  'FOR': [Color(0xFF1C3F94), Color(0xFFE30613)],
  'SPT': [Color(0xFFE30613), Color(0xFF000000)],
  'GOI': [Color(0xFF006633), Color(0xFFFFFFFF)],
  'CRI': [Color(0xFFFFD100), Color(0xFF000000)],
  'JUV': [Color(0xFF009B3A), Color(0xFFFFFFFF)],
  'CUI': [Color(0xFF006B3F), Color(0xFFFFD100)],
  'ACG': [Color(0xFFE30613), Color(0xFF000000)],
  'AME': [Color(0xFF00843D), Color(0xFF000000)],
  'NOV': [Color(0xFFFFD100), Color(0xFF000000)],
  'PON': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'OPE': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'VIL': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'CRB': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'AVA': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'BSP': [Color(0xFFE30613), Color(0xFF000000)],
  'NAU': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'LON': [Color(0xFF41B6E6), Color(0xFFFFFFFF)],
  'SBE': [Color(0xFFFFD100), Color(0xFF000000)],
  'ATH': [Color(0xFF000000), Color(0xFFFFFFFF)],
  // Série C
  'PAY': [Color(0xFF6CACE4), Color(0xFFFFFFFF)],
  'STC': [Color(0xFFE30613), Color(0xFF000000)],
  'GUA': [Color(0xFF00843D), Color(0xFFFFFFFF)],
  'FIG': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'AMA': [Color(0xFFFFD100), Color(0xFF000000)],
  'VRE': [Color(0xFFFFD100), Color(0xFF000000)],
  'FER': [Color(0xFF7A1F2B), Color(0xFFFFFFFF)],
  'CAX': [Color(0xFF7A1F2B), Color(0xFFFFFFFF)],
  'YPI': [Color(0xFF00843D), Color(0xFFFFD100)],
  'BPB': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'BRU': [Color(0xFFE30613), Color(0xFFFFD100)],
  'CON': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'FLO': [Color(0xFF00843D), Color(0xFFFFFFFF)],
  'ILI': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'ITA': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'ITU': [Color(0xFFE30613), Color(0xFF000000)],
  'MAR': [Color(0xFF0050A0), Color(0xFFE30613)],
  'MGA': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'ANA': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'BAR': [Color(0xFF000000), Color(0xFFFFD100)],
  // Série D
  'POR': [Color(0xFFE30613), Color(0xFF00843D)],
  'JEC': [Color(0xFFE30613), Color(0xFF000000)],
  'SAM': [Color(0xFFFFD100), Color(0xFF00843D)],
  'BPE': [Color(0xFFE30613), Color(0xFF000000)],
  'ARN': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'XVP': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'NOR': [Color(0xFFE30613), Color(0xFF000000)],
  'AGS': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'SJO': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'MAD': [Color(0xFFFFD100), Color(0xFF0050A0)],
  'AMR': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'NIG': [Color(0xFFFF7A00), Color(0xFFFFFFFF)],
  'MOT': [Color(0xFFE30613), Color(0xFF000000)],
  'TRE': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'ASA': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'FRR': [Color(0xFF000000), Color(0xFFFFFFFF)],
  'BRA': [Color(0xFFFFD100), Color(0xFFE30613)],
  'APA': [Color(0xFF0050A0), Color(0xFFFFFFFF)],
  'UBE': [Color(0xFF00843D), Color(0xFFFFFFFF)],
  'JUA': [Color(0xFF00843D), Color(0xFFE30613)],
  // Estrangeiros (principais)
  'BOC': [Color(0xFF0033A0), Color(0xFFFFD100)],
  'RIV': [Color(0xFFFFFFFF), Color(0xFFE30613)],
  'RAC': [Color(0xFF6CACE4), Color(0xFFFFFFFF)],
  'EST': [Color(0xFFE30613), Color(0xFFFFFFFF)],
  'PEN': [Color(0xFFFFD100), Color(0xFF000000)],
  'NAC': [Color(0xFFFFFFFF), Color(0xFF0033A0)],
  'LDU': [Color(0xFFFFFFFF), Color(0xFF0033A0)],
  'IDV': [Color(0xFF000000), Color(0xFF0050A0)],
  'OLI': [Color(0xFFFFFFFF), Color(0xFF000000)],
  'CCP': [Color(0xFF0033A0), Color(0xFFE30613)],
  'LAN': [Color(0xFF7A1F2B), Color(0xFFFFFFFF)],
  'SLO': [Color(0xFF0033A0), Color(0xFFE30613)],
  'BOL': [Color(0xFF6CACE4), Color(0xFFFFFFFF)],
  'MIL': [Color(0xFF0033A0), Color(0xFFFFFFFF)],
  'RCE': [Color(0xFFFFD100), Color(0xFF0033A0)],
};

class ClubShield extends StatelessWidget {
  final String shortName;
  final double size;
  const ClubShield({required this.shortName, this.size = 40, super.key});

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = _kClubColors[shortName] ??
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
      old.label != label ||
      old.primary != primary ||
      old.secondary != secondary;
}