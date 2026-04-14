import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess;
import '../main.dart';
import '../widgets/game_end_dialog.dart';

class GameScreen extends StatefulWidget {
  final String difficulty;
  final int timePerMove;
  final String playerColor;
  final bool isBot;

  const GameScreen({
    super.key,
    this.difficulty = 'Лёгкий',
    this.timePerMove = 600,
    this.playerColor = 'Белые',
    this.isBot = true,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  bool _didInitGame = false;
  bool _gameOverDialogShown = false;
  int _lastAnimationTick = 0;
  bool _isMoveAnimating = false;
  String? _animFrom;
  String? _animTo;
  chess.Piece? _animPiece;

  static const double _bottomActionsHeight = 56;

  void _showGameOverDialog(GameProvider game) {
    final reason = game.gameEndReason;
    if (reason == null || !mounted) {
      if (mounted) setState(() => _gameOverDialogShown = false);
      return;
    }
    showGameEndResultDialog(
      context,
      game: game,
      initialSeconds: widget.timePerMove,
      difficulty: widget.difficulty,
      onClosed: () {
        if (mounted) setState(() => _gameOverDialogShown = false);
      },
      exitToMenu: () {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
      },
    );
  }

  void _showProfileQuickMenu() {
    final game = Provider.of<GameProvider>(context, listen: false);
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.35),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text(
          'Профиль',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _menuStatRow('Всего матчей', game.totalGamesPlayed.toString()),
            const SizedBox(height: 10),
            _menuStatRow('Побед', game.totalWins.toString()),
            const SizedBox(height: 10),
            _menuStatRow('Поражений', game.totalLosses.toString()),
            const SizedBox(height: 10),
            _menuStatRow('Ничьих', game.totalDraws.toString()),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E2E2E),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text(
                'Закрыть',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menuStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 15)),
        Text(
          value,
          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  void _showPromotionDialog(GameProvider game) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Выбери фигуру',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  game.completeMoveWithPromotion(game.pendingPromotionFrom, game.pendingPromotionTo, 'q');
                  Future.delayed(const Duration(milliseconds: 50), () {
                    Navigator.pop(context);
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E2E2E)),
                child: const Text('Королева (Q)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  game.completeMoveWithPromotion(game.pendingPromotionFrom, game.pendingPromotionTo, 'r');
                  Future.delayed(const Duration(milliseconds: 50), () {
                    Navigator.pop(context);
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E2E2E)),
                child: const Text('Ладья (R)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  game.completeMoveWithPromotion(game.pendingPromotionFrom, game.pendingPromotionTo, 'b');
                  Future.delayed(const Duration(milliseconds: 50), () {
                    Navigator.pop(context);
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E2E2E)),
                child: const Text('Слон (B)', style: TextStyle(color: Colors.white)),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  game.completeMoveWithPromotion(game.pendingPromotionFrom, game.pendingPromotionTo, 'n');
                  Future.delayed(const Duration(milliseconds: 50), () {
                    Navigator.pop(context);
                  });
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2E2E2E)),
                child: const Text('Конь (N)', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorSelectDialog(GameProvider game) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.2),
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Выбери цвет',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  game.setPlayerColor('Белые');
                  game.resetGame(
                    initialSeconds: widget.timePerMove,
                    difficulty: widget.difficulty,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E8E8E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Белые',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  game.setPlayerColor('Чёрные');
                  game.resetGame(
                    initialSeconds: widget.timePerMove,
                    difficulty: widget.difficulty,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E2E2E),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                child: const Text(
                  'Чёрные',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF1C1C1C), Color(0xFF0B0B0B)],
            ),
          ),
          child: Stack(
            children: [
              Consumer<GameProvider>(
                builder: (context, game, child) {
                  // Показываем диалог промоции, если нужно
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (game.pendingPromotionFrom.isNotEmpty &&
                        game.pendingPromotionTo.isNotEmpty &&
                        !game.isPromoDialogShowing &&
                        mounted) {
                      game.setPromoDialogShowing(true);
                      _showPromotionDialog(game);
                    }
                  });

                  // Инициализируем игру при первом построении
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!_didInitGame) {
                      _didInitGame = true;
                      // Устанавливаем цвет игрока
                      game.setPlayerColor(widget.playerColor);
                      // Сбрасываем игру с новым временем
                      game.resetGame(
                        initialSeconds: widget.timePerMove,
                        isBot: true,
                        difficulty: widget.difficulty,
                      );
                    }
                  });
                  // После сдачи / ничьей / мата остаёмся на экране игры; в меню — только кнопка «Выйти» в окне.
                  if (game.gameEndReason != null && !_gameOverDialogShown) {
                    _gameOverDialogShown = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!mounted) return;
                      final g = Provider.of<GameProvider>(context, listen: false);
                      if (g.gameEndReason == null) {
                        setState(() => _gameOverDialogShown = false);
                        return;
                      }
                      _showGameOverDialog(g);
                    });
                  }
                  return Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final double size = constraints.maxWidth < constraints.maxHeight
                            ? constraints.maxWidth
                            : constraints.maxHeight;
                        final bool isBlackPlayer = widget.playerColor == 'Чёрные';
                        final int enemyTime = isBlackPlayer ? game.whiteTimeSeconds : game.blackTimeSeconds;
                        final int myTime = isBlackPlayer ? game.blackTimeSeconds : game.whiteTimeSeconds;
                        final chess.Color enemyColor = isBlackPlayer ? chess.Color.WHITE : chess.Color.BLACK;
                        final chess.Color myColor = isBlackPlayer ? chess.Color.BLACK : chess.Color.WHITE;
                        return SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Column(
                                  children: [
                                    const Text(
                                      'Враг',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E2E2E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: game.currentTurn == enemyColor
                                              ? const Color(0xFF5A5AA7)
                                              : const Color(0xFF2E2E2E),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        game.getFormattedTime(enemyTime),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 32),
                                Column(
                                  children: [
                                    const Text(
                                      'Мой',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF2E2E2E),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: game.currentTurn == myColor
                                              ? const Color(0xFF5A5AA7)
                                              : const Color(0xFF2E2E2E),
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        game.getFormattedTime(myTime),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: size,
                              height: size,
                              child: _buildBoard(size),
                            ),
                            const SizedBox(height: 24),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0),
                              child: SizedBox(
                                height: _bottomActionsHeight,
                                child: game.gameEndReason == null
                                    ? Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton(
                                            onPressed: () => game.resign(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2E2E2E),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                            ),
                                            child: const Text(
                                              'Сдаться',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          ElevatedButton(
                                            onPressed: () => game.offerDraw(),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(0xFF2E2E2E),
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 24,
                                                vertical: 12,
                                              ),
                                            ),
                                            child: const Text(
                                              'Ничья',
                                              style: TextStyle(color: Colors.white),
                                            ),
                                          ),
                                        ],
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ),
                            const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
              Positioned(
                top: 16,
                left: 16,
                child: ElevatedButton(
                  onPressed: () {
                    // Меню уже в стеке под GameScreen (открывали через push) — просто снимаем игру.
                    Provider.of<GameProvider>(context, listen: false).stopTimer();
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E2E2E),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text(
                    'Выйти',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: Consumer<GameProvider>(
                  builder: (context, game, child) => GestureDetector(
                    onTap: _showProfileQuickMenu,
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF5A5AA7),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          game.profileInitial,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBoard(double boardSize) {
    final double squareSize = boardSize / 8;
    final isBlackPlayer = widget.playerColor == 'Чёрные';
    final game = context.watch<GameProvider>();

    if (game.moveAnimationTick != _lastAnimationTick &&
        game.lastMoveFrom != null &&
        game.lastMoveTo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _lastAnimationTick = game.moveAnimationTick;
          _animFrom = game.lastMoveFrom;
          _animTo = game.lastMoveTo;
          _animPiece = game.getPieceAt(game.lastMoveTo!);
          _isMoveAnimating = _animPiece != null;
        });
        if (_isMoveAnimating) {
          Future.delayed(const Duration(milliseconds: 260), () {
            if (!mounted) return;
            setState(() {
              _isMoveAnimating = false;
              _animFrom = null;
              _animTo = null;
              _animPiece = null;
            });
          });
        }
      });
    }

    final allSquares = List<String>.generate(
      64,
      (i) => '${String.fromCharCode(97 + (i % 8))}${(i ~/ 8) + 1}',
    );

    return Stack(
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(8, (row) {
            final actualRow = isBlackPlayer ? 7 - row : row;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(8, (col) {
                final actualCol = isBlackPlayer ? 7 - col : col;
                String square = String.fromCharCode(97 + actualCol) + (8 - actualRow).toString();
                return SizedBox(
                  width: squareSize,
                  height: squareSize,
                  child: ChessSquare(square: square, showPiece: false),
                );
              }),
            );
          }),
        ),
        ...allSquares.map((square) {
          final piece = game.getPieceAt(square);
          if (piece == null) return const SizedBox.shrink();
          if (_isMoveAnimating && (_animFrom == square || _animTo == square)) {
            return const SizedBox.shrink();
          }
          final offset = _squareToOffset(square, squareSize, isBlackPlayer);
          return Positioned(
            left: offset.dx,
            top: offset.dy,
            width: squareSize,
            height: squareSize,
            child: IgnorePointer(
              child: Center(child: _pieceWidget(piece)),
            ),
          );
        }),
        ...allSquares.map((square) {
          final isTarget = game.legalDestinations.contains(square);
          if (!isTarget) return const SizedBox.shrink();
          final offset = _squareToOffset(square, squareSize, isBlackPlayer);
          return Positioned(
            left: offset.dx,
            top: offset.dy,
            width: squareSize,
            height: squareSize,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: Color(0xFF5A5AA7),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          );
        }),
        if (_isMoveAnimating && _animFrom != null && _animTo != null && _animPiece != null)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            builder: (context, t, child) {
              final from = _squareToOffset(_animFrom!, squareSize, isBlackPlayer);
              final to = _squareToOffset(_animTo!, squareSize, isBlackPlayer);
              final left = from.dx + (to.dx - from.dx) * t;
              final top = from.dy + (to.dy - from.dy) * t;
              return Positioned(
                left: left,
                top: top,
                width: squareSize,
                height: squareSize,
                child: IgnorePointer(
                  child: Center(child: _pieceWidget(_animPiece!)),
                ),
              );
            },
          ),
      ],
    );
  }

  Offset _squareToOffset(String square, double squareSize, bool isBlackPlayer) {
    final file = square.codeUnitAt(0) - 97;
    final rank = int.parse(square[1]) - 1;
    final col = isBlackPlayer ? 7 - file : file;
    final row = isBlackPlayer ? rank : 7 - rank;
    return Offset(col * squareSize, row * squareSize);
  }

  Widget _pieceWidget(chess.Piece piece) {
    const double size = 42.0;
    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final pieceType = piece.type.name;
    final assetPath = 'assets/pieces/$colorPrefix$pieceType.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }

}

class ChessSquare extends StatelessWidget {
  final String square;
  final bool showPiece;

  const ChessSquare({super.key, required this.square, this.showPiece = true});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameProvider>(
      builder: (context, game, child) {
        bool isLight = (square.codeUnitAt(0) - 97 + square.codeUnitAt(1) - 49) % 2 == 0;
        bool isSelected = game.selectedSquare == square;
        chess.Piece? piece = game.getPieceAt(square);
        final bool isMoveTarget = game.legalDestinations.contains(square);
        final bool isCheckedKingSquare = piece != null &&
            piece.type.name == 'k' &&
            piece.color == game.currentTurn &&
            game.isInCheck &&
            game.gameEndReason == null;

        // Траектории показываем только для скользящих фигур (ладья, слон, королева)
        chess.Piece? selectedPiece = game.selectedSquare != null ? game.getPieceAt(game.selectedSquare!) : null;
        bool showTrajectory = selectedPiece != null &&
            (selectedPiece.type.name == 'r' || selectedPiece.type.name == 'b' || selectedPiece.type.name == 'q');
        final bool isTrajectory = showTrajectory && !isMoveTarget && game.legalTrajectories.contains(square);
        // Клетка выбранной фигуры — фиолетовая заливка в тон обводке выбора.
        final bool isSelectedPieceSquare = isSelected && piece != null;
        const Color selectionTint = Color(0xFF5A5AA7);

        return GestureDetector(
          onTap: () {
            if (game.gameEndReason == null) {
              game.selectSquare(square);
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isCheckedKingSquare
                  ? Colors.red.withOpacity(0.35)
                  : isSelectedPieceSquare
                      ? selectionTint.withOpacity(0.45)
                      : (isTrajectory
                      ? const Color(0xFF3B5A3B).withOpacity(0.5)
                      : (isLight ? const Color(0xFF8E8E8E) : const Color(0xFF2E2E2E))),
            ),
            child: Stack(
              children: [
                if (showPiece)
                  Center(
                    child: piece != null ? _pieceWidget(piece) : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _pieceWidget(chess.Piece piece) {
    const double size = 42.0;
    final colorPrefix = piece.color == chess.Color.WHITE ? 'w' : 'b';
    final pieceType = piece.type.name;
    final assetPath = 'assets/pieces/$colorPrefix$pieceType.png';

    return Image.asset(
      assetPath,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}
