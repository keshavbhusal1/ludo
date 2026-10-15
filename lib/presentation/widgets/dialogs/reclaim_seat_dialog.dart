import 'package:flutter/material.dart';
import '../../../models/player.dart';

/// Asks whether to give [player]'s taken-over seat back to its human.
/// Returns true only if confirmed.
Future<bool> confirmReclaimSeat(BuildContext context, Player player) async {
  final color = Color(player.color.primaryColorValue);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: const Color(0xFF1E293B),
      title: Text(
        "Take back ${player.name}'s seat?",
        style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800),
      ),
      content: Text(
        'A bot has been playing for ${player.name} since they timed out. '
        'Taking the seat back lets ${player.name} play their own turns again, '
        'with strikes reset to 0.',
        style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: color),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Take back'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
