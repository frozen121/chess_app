import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:chess/chess.dart' as chess;
import 'dart:async';
import 'dart:math';
import 'screens/login_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  runApp(const MyApp());
}

Route<T> buildAppRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: const Duration(milliseconds: 280),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(0.03, 0),
        end: Offset.zero,
      ).chain(CurveTween(curve: Curves.easeOutCubic));
      final fade = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: fade,
        child: SlideTransition(
          position: animation.drive(slide),
          child: child,
        ),
      );
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => GameProvider(),
      child: MaterialApp(
        title: 'Шахматы',
        theme: ThemeData(
          primarySwatch: Colors.blue,
        ),
        debugShowCheckedModeBanner: false,
        home: const LoginScreen(),
      ),
    );
  }
}

class GameProvider extends ChangeNotifier {
  final chess.Chess _chess = chess.Chess();
  String _profileName = 'Аноним';
  String? selectedSquare;
  String? gameEndReason;
  int totalGamesPlayed = 0;
  int totalWins = 0;
  int totalLosses = 0;
  int totalDraws = 0;
  int movesPlayed = 0;
  int? lastWinDurationSeconds;
  String? lastMoveFrom;
  String? lastMoveTo;
  int _moveAnimationTick = 0;

  // Цвет игрока (белый или чёрный)
  chess.Color playerColor = chess.Color.WHITE;

  bool get isPlayerTurn => _chess.turn == playerColor;
  String get profileName => _profileName;
  String get profileInitial =>
      _profileName.trim().isEmpty ? 'А' : _profileName.trim().substring(0, 1).toUpperCase();

  // Бот
  bool isBotGame = true;
  String botDifficulty = 'Лёгкий';

  // Таймер
  int whiteTimeSeconds = 600; // 10 минут для белых
  int blackTimeSeconds = 600; // 10 минут для чёрных
  Timer? _timer;
  bool _timerRunning = false;
  DateTime? _lastTimerTickAt;
  int _whiteTimerRemainderMs = 0;
  int _blackTimerRemainderMs = 0;
  int _initialTimeSeconds = 600;
  bool _resultRecorded = false;

  Duration _botMoveDelayByDifficulty() {
    if (botDifficulty == 'Сложный') {
      return const Duration(seconds: 3);
    }
    if (botDifficulty == 'Средний') {
      return const Duration(milliseconds: 900);
    }
    return const Duration(milliseconds: 500);
  }

  String _resultMessageForWinner(chess.Color winnerColor) {
    return winnerColor == playerColor ? 'Вы выиграли!' : 'Вы проиграли!';
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void startTimer() {
    if (_timerRunning) return;
    _timerRunning = true;
    _lastTimerTickAt = DateTime.now();

    _timer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      final now = DateTime.now();
      final last = _lastTimerTickAt;
      if (last == null) {
        _lastTimerTickAt = now;
        return;
      }
      final elapsedMs = now.difference(last).inMilliseconds;
      if (elapsedMs <= 0) return;
      _lastTimerTickAt = now;

      _applyElapsedTime(elapsedMs);
      notifyListeners();
    });
  }

  void stopTimer() {
    _timerRunning = false;
    _timer?.cancel();
    _lastTimerTickAt = null;
  }

  void _applyElapsedTime(int elapsedMs) {
    if (_chess.turn == chess.Color.WHITE) {
      final totalMs = _whiteTimerRemainderMs + elapsedMs;
      final decrement = totalMs ~/ 1000;
      _whiteTimerRemainderMs = totalMs % 1000;
      if (decrement <= 0) return;

      if (whiteTimeSeconds > decrement) {
        whiteTimeSeconds -= decrement;
      } else {
        whiteTimeSeconds = 0;
        const winner = chess.Color.BLACK;
        gameEndReason = _resultMessageForWinner(winner);
        _recordResultIfNeeded(winnerColor: winner);
        stopTimer();
      }
      return;
    }

    final totalMs = _blackTimerRemainderMs + elapsedMs;
    final decrement = totalMs ~/ 1000;
    _blackTimerRemainderMs = totalMs % 1000;
    if (decrement <= 0) return;

    if (blackTimeSeconds > decrement) {
      blackTimeSeconds -= decrement;
    } else {
      blackTimeSeconds = 0;
      const winner = chess.Color.WHITE;
      gameEndReason = _resultMessageForWinner(winner);
      _recordResultIfNeeded(winnerColor: winner);
      stopTimer();
    }
  }

  String getFormattedTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  String get formattedLastWinDuration {
    if (lastWinDurationSeconds == null) return '-';
    return getFormattedTime(lastWinDurationSeconds!);
  }

  int get moveAnimationTick => _moveAnimationTick;

  void selectSquare(String square) {
    // Игра закончилась - не позволяем ходить
    if (gameEndReason != null) {
      return;
    }

    // Не твой ход - не позволяем ходить (для игры с ботом)
    if (!isPlayerTurn) {
      return;
    }

    final selectedPiece = _chess.get(square);

    // Если нажата уже выбранная фигура - отменяем выбор
    if (selectedSquare == square) {
      selectedSquare = null;
    }
    // Если нажата фигура своего цвета - выбираем её
    else if (selectedPiece != null && selectedPiece.color == _chess.turn) {
      // Отменяем предыдущий выбор и выбираем новую фигуру
      selectedSquare = square;
    }
    // Если нажата точка возможного хода - совершаем ход
    else if (selectedSquare != null && legalDestinations.contains(square)) {
      makeMove(selectedSquare!, square);
      selectedSquare = null;
    }
    // Если нажали на вражескую фигуру или пустую клетку - отменяем выбор
    else {
      selectedSquare = null;
    }

    notifyListeners();
  }

  void makeMove(String from, String to) {
    // Игра закончилась - не позволяем ходить
    if (gameEndReason != null) {
      return;
    }

    // Проверяем, это ли движение пешки на последний ряд (промоция)
    final piece = _chess.get(from);
    if (piece != null && piece.type.name == 'p') {
      final toRow = int.parse(to[1]);
      if ((piece.color == chess.Color.WHITE && toRow == 8) ||
          (piece.color == chess.Color.BLACK && toRow == 1)) {
        // Сохраняем информацию о промоции и ждем выбора
        pendingPromotionFrom = from;
        pendingPromotionTo = to;
        notifyListeners();
        return;
      }
    }

    completeMoveWithPromotion(from, to, 'q');
  }

  void completeMoveWithPromotion(String from, String to, String promotion) {
    final moveData = {'from': from, 'to': to, 'promotion': promotion};

    if (_chess.move(moveData)) {
      movesPlayed++;
      lastMoveFrom = from;
      lastMoveTo = to;
      _moveAnimationTick++;
      pendingPromotionFrom = '';
      pendingPromotionTo = '';
      _promoDialogShowing = false;

      _updateGameEndReason();

      if (!_timerRunning) {
        startTimer();
      }
      notifyListeners();

      // Если это игра против бота, делаем ход бота
      if (isBotGame && gameEndReason == null) {
        Future.delayed(_botMoveDelayByDifficulty(), () {
          _makeBotMove();
        });
      }
    }
  }

  void setPromoDialogShowing(bool showing) {
    _promoDialogShowing = showing;
  }

  bool get isPromoDialogShowing => _promoDialogShowing;

  String get board => _chess.board.toString();

  bool get isGameOver => _chess.game_over;

  chess.Color get currentTurn => _chess.turn;

  bool get isTimerRunning => _timerRunning;

  bool get isInCheck => _chess.in_check;

  int get legalMovesCount => _chess.moves().length;

  String get currentTurnLabel => _chess.turn == chess.Color.WHITE ? 'Белые' : 'Чёрные';

  String get endReasonDebugInfo =>
      'Ход: $currentTurnLabel | Шах: ${isInCheck ? 'да' : 'нет'} | Ходов в партии: $movesPlayed';

  String? get winner => _chess.in_checkmate ? (_chess.turn == chess.Color.WHITE ? 'Black' : 'White') : null;

  void loadFen(String fen) {
    _chess.load(fen);
    selectedSquare = null;
    pendingPromotionFrom = '';
    pendingPromotionTo = '';
    _promoDialogShowing = false;
    _updateGameEndReason();
    notifyListeners();
  }

  String pendingPromotionFrom = '';
  String pendingPromotionTo = '';
  bool _promoDialogShowing = false;

  chess.Piece? getPieceAt(String square) {
    return _chess.get(square);
  }

  List<String> get legalDestinations {
    if (selectedSquare == null) {
      return [];
    }
    final moves = _chess.moves({'square': selectedSquare, 'verbose': true});
    final destinations = <String>[];
    for (var move in moves) {
      if (move is Map && move.containsKey('to')) {
        final toSquare = move['to'] as String;
        final targetPiece = _chess.get(toSquare);

        // Исключаем ходы на поля со своими фигурами
        if (targetPiece == null || targetPiece.color != _chess.turn) {
          destinations.add(toSquare);
        }
      }
    }
    return destinations;
  }

  Set<String> get legalTrajectories {
    if (selectedSquare == null || selectedSquare!.isEmpty || selectedSquare!.length != 2) {
      return {};
    }
    final trajectories = <String>{};
    for (final destination in legalDestinations) {
      trajectories.addAll(_trajectoryPath(selectedSquare!, destination));
    }
    return trajectories;
  }

  List<String> _trajectoryPath(String from, String to) {
    try {
      if (from.isEmpty || from.length < 2 || to.isEmpty || to.length < 2) {
        return [];
      }
      final fromFile = from.codeUnitAt(0) - 97;
      final fromRank = int.parse(from[1]) - 1;
      final toFile = to.codeUnitAt(0) - 97;
      final toRank = int.parse(to[1]) - 1;

      final fileStep = (toFile - fromFile).sign;
      final rankStep = (toRank - fromRank).sign;

      if (fileStep == 0 && rankStep == 0) {
        return [];
      }

      final path = <String>[];
      var file = fromFile + fileStep;
      var rank = fromRank + rankStep;

      while (file != toFile || rank != toRank) {
        // Защита от некорректных значений
        if (file < 0 || file > 7 || rank < 0 || rank > 7) {
          break;
        }
        final charCode = 97 + file;
        if (charCode < 0 || charCode > 1114111) {
          break;
        }
        path.add(String.fromCharCode(charCode) + (rank + 1).toString());
        file += fileStep;
        rank += rankStep;
      }

      return path;
    } catch (e) {
      return [];
    }
  }

  void resign() {
    if (!isGameOver) {
      final winnerColor = _chess.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
      gameEndReason = _resultMessageForWinner(winnerColor);
      _recordResultIfNeeded(
        winnerColor: winnerColor,
      );
      stopTimer();
      notifyListeners();
    }
  }

  void offerDraw() {
    if (!isGameOver) {
      gameEndReason = 'Ничья по согласию';
      _recordResultIfNeeded(isDraw: true);
      stopTimer();
      notifyListeners();
    }
  }

  void setPlayerColor(String color) {
    playerColor = color == 'Белые' ? chess.Color.WHITE : chess.Color.BLACK;
    notifyListeners();
  }

  void setProfileName(String name) {
    final trimmed = name.trim();
    _profileName = trimmed.isEmpty ? 'Аноним' : trimmed;
    notifyListeners();
  }

  void setBotGame(bool isBot, String difficulty) {
    // В приложении поддерживается только игра против бота.
    isBotGame = true;
    botDifficulty = difficulty;
    notifyListeners();
  }

  void _makeBotMove() {
    if (!isBotGame || _chess.game_over || gameEndReason != null) return;

    // Бот ходит за противоположный цвет игрока
    chess.Color botColor = playerColor == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    if (_chess.turn != botColor) return;

    final moves = _chess.moves({'verbose': true});
    if (moves.isEmpty) return;

    // Выбираем ход в зависимости от сложности.
    final moveList = moves.cast<Map<String, dynamic>>();
    Map<String, dynamic>? selectedMove;

    if (botDifficulty == 'Лёгкий') {
      selectedMove = moveList[Random().nextInt(moveList.length)];
    } else if (botDifficulty == 'Средний') {
      selectedMove = _pickBestMoveMinimax(
        _chess,
        moveList,
        searchDepth: 2,
        botColor: botColor,
      );
    } else {
      selectedMove = _pickBestMoveMinimax(
        _chess,
        moveList,
        searchDepth: 3,
        botColor: botColor,
      );
    }

    if (selectedMove != null) {
      final moveSuccessful = _chess.move({
        'from': selectedMove['from'],
        'to': selectedMove['to'],
        'promotion': selectedMove['promotion'] ?? 'q',
      });

      if (moveSuccessful) {
        movesPlayed++;
        lastMoveFrom = selectedMove['from'] as String?;
        lastMoveTo = selectedMove['to'] as String?;
        _moveAnimationTick++;
        selectedSquare = null;
        _updateGameEndReason();

        notifyListeners();
      }
    }
  }

  Map<String, dynamic>? _pickBestMoveMinimax(
    chess.Chess position,
    List<Map<String, dynamic>> moves, {
    required int searchDepth,
    required chess.Color botColor,
  }) {
    final safeMoves = List<Map<String, dynamic>>.from(moves);
    if (safeMoves.isEmpty) return null;

    int bestScore = -1 << 30;
    final bestMoves = <Map<String, dynamic>>[];
    final ordered = _orderMoves(position, safeMoves);

    for (final move in ordered) {
      final sim = chess.Chess.fromFEN(position.fen);
      sim.move({
        'from': move['from'],
        'to': move['to'],
        'promotion': move['promotion'] ?? 'q',
      });
      final score = _minimax(
        sim,
        depth: searchDepth - 1,
        alpha: -1 << 30,
        beta: 1 << 30,
        botColor: botColor,
      );
      if (score > bestScore) {
        bestScore = score;
        bestMoves
          ..clear()
          ..add(move);
      } else if (score == bestScore) {
        bestMoves.add(move);
      }
    }

    if (bestMoves.isEmpty) {
      // Защита от любых редких случаев: возвращаем первый доступный ход без рандома по пустому списку.
      if (ordered.isNotEmpty) return ordered.first;
      return safeMoves.first;
    }

    return bestMoves[Random().nextInt(bestMoves.length)];
  }

  int _minimax(
    chess.Chess position, {
    required int depth,
    required int alpha,
    required int beta,
    required chess.Color botColor,
  }) {
    if (depth <= 0 || position.game_over) {
      return _evaluatePosition(position, botColor);
    }

    final moves = position.moves({'verbose': true}).cast<Map<String, dynamic>>();
    if (moves.isEmpty) {
      return _evaluatePosition(position, botColor);
    }

    final maximizing = position.turn == botColor;
    var localAlpha = alpha;
    var localBeta = beta;

    if (maximizing) {
      var best = -1 << 30;
      for (final move in _orderMoves(position, moves)) {
        final sim = chess.Chess.fromFEN(position.fen);
        sim.move({
          'from': move['from'],
          'to': move['to'],
          'promotion': move['promotion'] ?? 'q',
        });
        final score = _minimax(
          sim,
          depth: depth - 1,
          alpha: localAlpha,
          beta: localBeta,
          botColor: botColor,
        );
        if (score > best) best = score;
        if (best > localAlpha) localAlpha = best;
        if (localAlpha >= localBeta) break;
      }
      return best;
    } else {
      var best = 1 << 30;
      for (final move in _orderMoves(position, moves)) {
        final sim = chess.Chess.fromFEN(position.fen);
        sim.move({
          'from': move['from'],
          'to': move['to'],
          'promotion': move['promotion'] ?? 'q',
        });
        final score = _minimax(
          sim,
          depth: depth - 1,
          alpha: localAlpha,
          beta: localBeta,
          botColor: botColor,
        );
        if (score < best) best = score;
        if (best < localBeta) localBeta = best;
        if (localAlpha >= localBeta) break;
      }
      return best;
    }
  }

  List<Map<String, dynamic>> _orderMoves(
    chess.Chess position,
    List<Map<String, dynamic>> moves,
  ) {
    final scored = <MapEntry<Map<String, dynamic>, int>>[];
    for (final move in moves) {
      var score = 0;
      final flags = (move['flags'] ?? '').toString();
      if (flags.contains('c')) {
        score += 5000 + _pieceValue((move['captured'] ?? '').toString()) - (_pieceValue((move['piece'] ?? '').toString()) ~/ 8);
      }
      if (move['promotion'] != null) {
        score += 4000;
      }
      // Проверяем, дает ли ход шах (для упорядочивания, не для финальной оценки).
      final sim = chess.Chess.fromFEN(position.fen);
      sim.move({
        'from': move['from'],
        'to': move['to'],
        'promotion': move['promotion'] ?? 'q',
      });
      if (sim.in_checkmate) {
        score += 1000000;
      } else if (sim.in_check) {
        score += 1200;
      }
      scored.add(MapEntry(move, score));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.map((e) => e.key).toList();
  }

  int _evaluatePosition(chess.Chess position, chess.Color botColor) {
    if (position.in_checkmate) {
      // Если сейчас ход стороны в мате, значит предыдущий ход победил.
      return position.turn == botColor ? -1000000 : 1000000;
    }
    if (position.in_stalemate || position.game_over) {
      return 0;
    }

    var score = 0;
    final boardFen = position.fen.split(' ').first;
    for (final symbol in boardFen.split('')) {
      if (symbol == '/') continue;
      if (int.tryParse(symbol) != null) continue;
      final isWhite = symbol == symbol.toUpperCase();
      final pieceType = symbol.toLowerCase();
      final value = _pieceValue(pieceType);
      final pieceColor = isWhite ? chess.Color.WHITE : chess.Color.BLACK;
      if (pieceColor == botColor) {
        score += value;
      } else {
        score -= value;
      }
    }

    // Мобильность и активность.
    final botMovesCount = _movesCountForColor(position, botColor);
    final enemyColor = botColor == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
    final enemyMovesCount = _movesCountForColor(position, enemyColor);
    score += (botMovesCount - enemyMovesCount) * 4;

    // Небольшой бонус/штраф за шах.
    if (position.in_check) {
      score += position.turn == botColor ? -45 : 45;
    }

    return score;
  }

  int _movesCountForColor(chess.Chess position, chess.Color color) {
    if (position.turn == color) {
      return position.moves().length;
    }
    // Для подсчета мобильности соперника смотрим позицию после "нулевого" переключения хода через FEN.
    final fenParts = position.fen.split(' ');
    if (fenParts.length < 2) return 0;
    fenParts[1] = color == chess.Color.WHITE ? 'w' : 'b';
    final swapped = chess.Chess.fromFEN(fenParts.join(' '));
    return swapped.moves().length;
  }

  int _pieceValue(String type) {
    switch (type) {
      case 'p':
        return 100;
      case 'n':
      case 'b':
        return 320;
      case 'r':
        return 500;
      case 'q':
        return 900;
      case 'k':
        return 20000;
      default:
        return 0;
    }
  }

  void resetGame({
    int initialSeconds = 600,
    bool isBot = true,
    String difficulty = 'Лёгкий',
    bool startTimerAfterReset = true,
  }) {
    _chess.reset();
    selectedSquare = null;
    gameEndReason = null;
    whiteTimeSeconds = initialSeconds;
    blackTimeSeconds = initialSeconds;
    _whiteTimerRemainderMs = 0;
    _blackTimerRemainderMs = 0;
    isBotGame = true;
    botDifficulty = difficulty;
    _initialTimeSeconds = initialSeconds;
    _resultRecorded = false;
    movesPlayed = 0;
    lastMoveFrom = null;
    lastMoveTo = null;
    stopTimer();
    notifyListeners();

    if (startTimerAfterReset && isBotGame && playerColor == chess.Color.BLACK) {
      Future.delayed(_botMoveDelayByDifficulty(), () {
        _makeBotMove();
      });
    }

    if (startTimerAfterReset) {
      startTimer();
    }
  }

  /// Убрать текст окончания партии (например, после «Закрыть» в меню).
  void clearGameEndReason() {
    gameEndReason = null;
    notifyListeners();
  }

  void _updateGameEndReason() {
    if (_chess.in_checkmate) {
      final winnerColor = _chess.turn == chess.Color.WHITE ? chess.Color.BLACK : chess.Color.WHITE;
      gameEndReason = _resultMessageForWinner(winnerColor);
      _recordResultIfNeeded(
        winnerColor: winnerColor,
      );
      stopTimer();
    } else if (_chess.in_stalemate) {
      gameEndReason = 'Ничья. Пат!';
      _recordResultIfNeeded(isDraw: true);
      stopTimer();
    } else {
      gameEndReason = null;
    }
  }

  void _recordResultIfNeeded({chess.Color? winnerColor, bool isDraw = false}) {
    if (_resultRecorded) return;

    _resultRecorded = true;
    totalGamesPlayed++;

    if (isDraw || winnerColor == null) {
      totalDraws++;
      return;
    }

    if (winnerColor == playerColor) {
      totalWins++;
      final remainingSeconds = playerColor == chess.Color.WHITE ? whiteTimeSeconds : blackTimeSeconds;
      final spent = _initialTimeSeconds - remainingSeconds;
      lastWinDurationSeconds = spent < 0 ? 0 : spent;
    } else {
      totalLosses++;
    }
  }

  void resetSessionData() {
    stopTimer();
    _chess.reset();
    selectedSquare = null;
    gameEndReason = null;
    whiteTimeSeconds = 600;
    blackTimeSeconds = 600;
    _whiteTimerRemainderMs = 0;
    _blackTimerRemainderMs = 0;
    pendingPromotionFrom = '';
    pendingPromotionTo = '';
    _promoDialogShowing = false;
    lastMoveFrom = null;
    lastMoveTo = null;
    _moveAnimationTick = 0;
    _profileName = 'Аноним';
    totalGamesPlayed = 0;
    totalWins = 0;
    totalLosses = 0;
    totalDraws = 0;
    movesPlayed = 0;
    lastWinDurationSeconds = null;
    _resultRecorded = false;
    notifyListeners();
  }
}
