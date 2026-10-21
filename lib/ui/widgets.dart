import 'package:flutter/material.dart';
import '../game/models.dart';
import '../game/economy.dart';

const Color kGreen = Color(0xFF1B5E20);
const Color kCard = Color(0xFF263238);

Color overallColor(int o) {
  if (o >= 82) return Colors.green;
  if (o >= 76) return Colors.orange;
  return Colors.red;
}

Widget overallAvatar(Player p, {double radius = 20}) => CircleAvatar(
      radius: radius,
      backgroundColor: overallColor(p.overall),
      child: Text(
        '${p.overall}',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7),
      ),
    );

Widget sectionTitle(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5),
      ),
    );

Widget infoRow(String label, String value, {Color? valueColor}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
          Text(value, style: TextStyle(color: valueColor ?? Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );

/// Barra de progresso 0-100 com rótulo (reputação, confiança...).
Widget meterBar(String label, int value, {Color? color}) {
  final c = color ?? (value >= 66 ? Colors.green : value >= 33 ? Colors.orange : Colors.red);
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
            Text('$value%', style: TextStyle(color: c, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value / 100,
            minHeight: 8,
            color: c,
            backgroundColor: Colors.white12,
          ),
        ),
      ],
    ),
  );
}

void showResult(BuildContext context, TransferResult r) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      backgroundColor: r.success ? Colors.green.shade800 : Colors.red.shade800,
      content: Text(r.message, style: const TextStyle(color: Colors.white)),
    ));
}

Future<bool> confirmDialog(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: kCard,
      title: Text(title, style: const TextStyle(color: Colors.white)),
      content: Text(message, style: const TextStyle(color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirmar')),
      ],
    ),
  );
  return ok ?? false;
}

/// Slider de valores em reais com rótulo formatado.
class MoneySlider extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const MoneySlider({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final lo = min.toDouble();
    final hi = max <= min ? min + step.toDouble() : max.toDouble();
    final divisions = ((hi - lo) / step).round().clamp(1, 400);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
            Text(formatMoney(value), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(lo, hi),
          min: lo,
          max: hi,
          divisions: divisions,
          onChanged: (v) => onChanged(((v / step).round() * step).clamp(min, hi.toInt()).toInt()),
        ),
      ],
    );
  }
}

/// Seletor de duração de contrato (1 a 5 temporadas).
class YearsPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final String label;

  const YearsPicker({super.key, required this.value, required this.onChanged, this.label = 'Contrato'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: Colors.white70))),
        DropdownButton<int>(
          value: value,
          dropdownColor: kCard,
          style: const TextStyle(color: Colors.white),
          items: [
            for (int y = 1; y <= 5; y++)
              DropdownMenuItem(value: y, child: Text('$y temporada${y > 1 ? 's' : ''}')),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ],
    );
  }
}
