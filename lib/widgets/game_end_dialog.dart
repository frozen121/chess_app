import 'package:flutter/material.dart';
import '../main.dart';

Color gameEndMessageColor(String message) {
  final lower = message.toLowerCase();
  if (lower.contains('проиграли')) {
    return const Color(0xFFFF5252);
  }
  if (lower.contains('выиграли')) {
    return Colors.green;
  }
  return const Color(0xFFFFB74D);
}

/// Итог партии.
///
/// [exitToMenu] задан на экране игры: вторая кнопка «Выйти» → в меню.
/// На меню не задавать: вторая кнопка «Закрыть».
Future<void> showGameEndResultDialog(
  BuildContext context, {
  required GameProvider game,
  required int initialSeconds,
  required String difficulty,
  required VoidCallback onClosed,
  VoidCallback? exitToMenu,
}) {
  final reason = game.gameEndReason;
  if (reason == null) {
    onClosed();
    return Future.value();
  }

  final onGameScreen = exitToMenu != null;

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    barrierColor: Colors.black.withOpacity(0.55),
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text(
          reason,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: gameEndMessageColor(reason),
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Сделано ходов: ${game.movesPlayed}',
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              game.endReasonDebugInfo,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                    game.resetGame(
                      initialSeconds: initialSeconds,
                      difficulty: difficulty,
                      startTimerAfterReset: onGameScreen,
                    );
                    onClosed();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    'Новая игра',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    game.stopTimer();
                    Navigator.of(dialogContext, rootNavigator: true).pop();
                    game.clearGameEndReason();
                    onClosed();
                    if (exitToMenu != null) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        exitToMenu();
                      });
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text(
                    onGameScreen ? 'Выйти' : 'Закрыть',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
