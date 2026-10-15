import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../features/ludo/presentation/bloc/ludo_bloc.dart';
import '../../../features/ludo/presentation/bloc/ludo_event.dart';
import '../../../features/ludo/presentation/bloc/ludo_state.dart';
import '../../../models/history_entry.dart';

/// Undo button tooltip: whose choice it returns to, or why it's locked.
String undoTooltip(LudoActiveState state) {
  final blockedBy = state.undoBlockedBy;
  final chooser = state.undoTarget?.state.activePlayer;
  if (blockedBy != null && chooser != null) {
    return "Undo locked: ${blockedBy.name} has played since ${chooser.name}'s last choice";
  }
  if (state.canUndo && chooser != null) return "Undo ${chooser.name}'s last choice";
  return 'Undo';
}

/// Bottom sheet listing every resolved roll this session, newest first.
/// Rebuilds live as the match continues, and offers undo when available.
class MoveHistorySheet extends StatelessWidget {
  const MoveHistorySheet({super.key});

  /// Opens the sheet over [context], which must have a [LudoBloc] above it.
  static Future<void> show(BuildContext context) {
    final bloc = context.read<LudoBloc>();
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(value: bloc, child: const MoveHistorySheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.6),
        child: BlocBuilder<LudoBloc, LudoState>(
          builder: (context, state) {
            final active = state is LudoActiveState ? state : null;
            final history = active?.history ?? const <HistoryEntry>[];

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                  child: Row(
                    children: [
                      const Icon(Icons.history, color: Colors.white70, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Move history',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: active?.canUndo == true
                            ? () => context.read<LudoBloc>().add(const LudoUndoRequested())
                            : null,
                        icon: const Icon(Icons.undo, size: 18),
                        label: const Text('UNDO'),
                      ),
                    ],
                  ),
                ),
                if (active?.undoBlockedBy != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline, size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            undoTooltip(active!),
                            style: const TextStyle(color: Colors.white54, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(height: 1, color: Color(0xFF334155)),
                if (history.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'No moves yet',
                      style: TextStyle(color: Colors.white54),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: history.length,
                      itemBuilder: (context, i) {
                        // Newest first
                        final index = history.length - 1 - i;
                        return _HistoryTile(entry: history[index], number: index + 1);
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryEntry entry;
  final int number;

  const _HistoryTile({required this.entry, required this.number});

  @override
  Widget build(BuildContext context) {
    final color = Color(entry.color.primaryColorValue);
    final emphasised = entry.move?.isCapture == true || entry.move?.isReachingHome == true;

    return ListTile(
      dense: true,
      leading: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text(
          '${entry.roll}',
          style: TextStyle(color: color, fontWeight: FontWeight.w900),
        ),
      ),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '${entry.playerName} ',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            TextSpan(text: entry.description),
          ],
        ),
        style: TextStyle(
          color: Colors.white,
          fontWeight: emphasised ? FontWeight.w700 : FontWeight.w400,
          fontSize: 13,
        ),
      ),
      trailing: Text(
        '#$number',
        style: const TextStyle(color: Colors.white38, fontSize: 11),
      ),
    );
  }
}
