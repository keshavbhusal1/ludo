import 'dart:async';

import 'package:flutter/material.dart';

/// Seconds left until [deadline], shown as a small timer chip that turns red
/// for the last few seconds.
class TurnCountdown extends StatefulWidget {
  final DateTime deadline;
  final Color color;

  const TurnCountdown({super.key, required this.deadline, required this.color});

  @override
  State<TurnCountdown> createState() => _TurnCountdownState();
}

class _TurnCountdownState extends State<TurnCountdown> {
  static const _warnBelowSeconds = 4;
  late final Timer _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _ticker.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining = widget.deadline.difference(DateTime.now());
    final seconds = (remaining.inMilliseconds / 1000).ceil().clamp(0, 999);
    final color = seconds <= _warnBelowSeconds ? const Color(0xFFF87171) : widget.color;

    return Semantics(
      label: '$seconds seconds left in this turn',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.timer_outlined, size: 13, color: color),
            const SizedBox(width: 3),
            Text(
              '${seconds}s',
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
