import 'package:chess_app/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GameProvider chess logic', () {
    test('initial position has no check and no game end', () {
      final game = GameProvider();

      expect(game.isInCheck, isFalse);
      expect(game.gameEndReason, isNull);
    });

    test('detects check position', () {
      final game = GameProvider();

      game.completeMoveWithPromotion('e2', 'e4', 'q');
      game.completeMoveWithPromotion('f7', 'f5', 'q');
      game.completeMoveWithPromotion('d1', 'h5', 'q');

      expect(game.isInCheck, isTrue);
      expect(game.gameEndReason, isNull);
    });

    test('detects checkmate (Fool\'s mate)', () {
      final game = GameProvider();

      game.completeMoveWithPromotion('f2', 'f3', 'q');
      game.completeMoveWithPromotion('e7', 'e5', 'q');
      game.completeMoveWithPromotion('g2', 'g4', 'q');
      game.completeMoveWithPromotion('d8', 'h4', 'q');

      expect(game.gameEndReason, isNotNull);
      expect(game.gameEndReason, contains('Мат'));
    });

    test('detects stalemate from FEN', () {
      final game = GameProvider();

      game.loadFen('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');

      expect(game.isInCheck, isFalse);
      expect(game.gameEndReason, equals('Ничья. Пат!'));
    });

    test('trajectory does not include destination square', () {
      final game = GameProvider();

      game.completeMoveWithPromotion('a2', 'a4', 'q');
      game.completeMoveWithPromotion('h7', 'h6', 'q');
      game.selectSquare('a1');

      expect(game.legalDestinations, contains('a3'));
      expect(game.legalTrajectories, contains('a2'));
      expect(game.legalTrajectories, isNot(contains('a3')));
    });

    test('shows sliding piece trajectory through intermediate squares', () {
      final game = GameProvider();

      game.completeMoveWithPromotion('a2', 'a4', 'q');
      game.completeMoveWithPromotion('h7', 'h6', 'q');
      game.selectSquare('a1');

      expect(game.legalDestinations, contains('a3'));
      expect(game.legalTrajectories, contains('a2'));
    });

    test('does not allow selecting enemy piece on own turn', () {
      final game = GameProvider();

      game.selectSquare('a7');

      expect(game.selectedSquare, isNull);
      expect(game.legalDestinations, isEmpty);
    });
  });
}
