import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:chat_noir/core/constants.dart';
import 'package:chat_noir/features/jogo/modelo/modeloCelula.dart';

enum StatusJogo { jogando, jogadorVenceu, gatoVenceu }

class LogicaJogo extends ChangeNotifier {
  int _placarJogador = 0;
  int _placarGato = 0;
  StatusJogo _status = StatusJogo.jogando;

  late List<List<CellModel>> tabuleiro;
  late CellModel posicaoGato;
  CellModel? _ultimaPosicaoGato; 
  final Random _aleatorio = Random();

  int get placarJogador => _placarJogador;
  int get placarGato => _placarGato;
  StatusJogo get status => _status;

  static const int CAT_WIN_SCORE = 10000;
  static const int FENCE_WIN_SCORE = -10000;

  LogicaJogo() {
    reiniciarJogo();
  }

  void reiniciarJogo() {
    _status = StatusJogo.jogando;
    _inicializarTabuleiro();
    _colocarObstaculosIniciais();
    _ultimaPosicaoGato = null;
    notifyListeners();
  }

  void zerarTudo() {
    _placarJogador = 0;
    _placarGato = 0;
    reiniciarJogo();
  }

  void _inicializarTabuleiro() {
    tabuleiro = List.generate(
      numeroLinhas,
      (linha) => List.generate(
        numeroColunas,
        (coluna) => CellModel(row: linha, col: coluna),
      ),
    );
    posicaoGato = tabuleiro[numeroLinhas ~/ 2][numeroColunas ~/ 2];
    posicaoGato.state = CellState.cat;
  }

  void _colocarObstaculosIniciais() {
    final quantidade = _aleatorio.nextInt(7) + 12;
    int colocados = 0;
    while (colocados < quantidade) {
      final linha = _aleatorio.nextInt(numeroLinhas);
      final coluna = _aleatorio.nextInt(numeroColunas);
      final celula = tabuleiro[linha][coluna];
      if (celula.state == CellState.empty) {
        celula.state = CellState.blocked;
        colocados++;
      }
    }
  }

  void jogadorClick(int row, int col) {
    if (_status != StatusJogo.jogando) return;
    final celula = tabuleiro[row][col];
    if (celula.state != CellState.empty) return;
    celula.state = CellState.blocked;
    notifyListeners();
    Future.delayed(const Duration(milliseconds: 300), _movimentoGato);
  }

  void _movimentoGato() {
    if (_status != StatusJogo.jogando) return;

    final baseDepth = 4;
    final depth = (_distanciaAteBordaGeometrica(posicaoGato) <= 3) ? 6 : baseDepth;

    final movimento = _findBestMove(depth);

    if (movimento == null) {
      _status = StatusJogo.jogadorVenceu;
      _placarJogador++;
      notifyListeners();
      return;
    }

    final anterior = posicaoGato;
    posicaoGato.state = CellState.empty;
    posicaoGato = movimento;
    posicaoGato.state = CellState.cat;
    _ultimaPosicaoGato = anterior;

    if (_estaNaBorda(posicaoGato)) {
      _status = StatusJogo.gatoVenceu;
      _placarGato++;
    }

    notifyListeners();
  }

  CellModel? _findBestMove(int depthLimit) {
    int bestScore = -0x3fffffff;
    CellModel? bestMove;

    final moves = _ordenarMovimentosGato(_vizinhosDisponiveis(posicaoGato), posicaoGato);

    if (moves.isEmpty) return null;

    for (final move in moves) {
      if (_ultimaPosicaoGato != null &&
          move.row == _ultimaPosicaoGato!.row &&
          move.col == _ultimaPosicaoGato!.col &&
          moves.length > 1) {
        continue;
      }

      final antigo = posicaoGato;
      antigo.state = CellState.empty;
      move.state = CellState.cat;

      final score = _minimax(
        move,
        depthLimit - 1,
        false,
        -0x3fffffff,
        0x3fffffff,
        1,
        antigo, 
      );

      move.state = CellState.empty;
      antigo.state = CellState.cat;

      if (score > bestScore ||
          (score == bestScore && _tiebreakMelhor(move, bestMove))) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  int _minimax(
    CellModel gato,
    int depth,
    bool isMaximizing,
    int alpha,
    int beta,
    int ply,
    CellModel? prev,
  ) {
    final semSaida = _vizinhosDisponiveis(gato).isEmpty;
    if (depth == 0 || _estaNaBorda(gato) || semSaida) {
      return _evaluate(gato, ply);
    }

    if (isMaximizing) {
      int maxEval = -0x3fffffff;

      final candidatos = _ordenarMovimentosGato(_vizinhosDisponiveis(gato), gato)
          .where((m) => !(prev != null && m.row == prev.row && m.col == prev.col && _vizinhosDisponiveis(gato).length > 1))
          .toList();

      for (final move in candidatos) {
        final antigo = gato;
        antigo.state = CellState.empty;
        move.state = CellState.cat;

        final eval = _minimax(
          move,
          depth - 1,
          false,
          alpha,
          beta,
          ply + 1,
          antigo,
        );

        move.state = CellState.empty;
        antigo.state = CellState.cat;

        if (eval > maxEval) maxEval = eval;
        if (eval > alpha) alpha = eval;
        if (beta <= alpha) break; 
      }
      return maxEval;
    } else {
      int minEval = 0x3fffffff;

      final fences = _ordenarCercasPorImpacto(_getPossibleFencePositions(gato))
          .take(12);

      for (final fence in fences) {
        fence.state = CellState.blocked;

        final eval = _minimax(
          gato,
          depth - 1,
          true,
          alpha,
          beta,
          ply + 1,
          prev,
        );

        fence.state = CellState.empty;

        if (eval < minEval) minEval = eval;
        if (eval < beta) beta = eval;
        if (beta <= alpha) break; 
      }
      return minEval;
    }
  }

  int _evaluate(CellModel gato, int ply) {
    if (_estaNaBorda(gato)) return CAT_WIN_SCORE - ply;
    final viz = _vizinhosDisponiveis(gato);
    if (viz.isEmpty) return FENCE_WIN_SCORE + ply; 

    final distBfs = _bfsDistAteBorda(gato); 
    if (distBfs == null) {
      return FENCE_WIN_SCORE ~/ 2 - 300 + viz.length * 5 - ply;
    }

    final mobilidade = viz.length;
    final perto = 1500 - distBfs * 180; 
    final bonusMobilidade = mobilidade * 30;

    final quaseCercado = mobilidade <= 1 ? -120 : 0;

    return (perto + bonusMobilidade + quaseCercado)
        .clamp(-2000, 2000)
        .toInt();
  }

  List<CellModel> _ordenarMovimentosGato(List<CellModel> moves, CellModel origem) {
    final itens = <_MoveRank>[];
    for (final m in moves) {
      final oldState = m.state;
      final oldOrig = origem.state;
      origem.state = CellState.empty;
      m.state = CellState.cat;

      final dist = _bfsDistAteBorda(m) ?? 1 << 20;
      final mob = _vizinhosDisponiveis(m).length;

      m.state = oldState;
      origem.state = oldOrig;

      itens.add(_MoveRank(cell: m, distBfs: dist, mobilidade: mob));
    }
    itens.sort((a, b) {
      if (a.distBfs != b.distBfs) return a.distBfs.compareTo(b.distBfs);
      return b.mobilidade.compareTo(a.mobilidade);
    });
    return itens.map((e) => e.cell).toList();
  }

  List<CellModel> _ordenarCercasPorImpacto(List<CellModel> positions) {
    positions.sort((a, b) {
      final da = _distGeom(posicaoGato, a);
      final db = _distGeom(posicaoGato, b);
      return da.compareTo(db);
    });
    return positions;
  }

  int _distGeom(CellModel a, CellModel b) =>
      (a.row - b.row).abs() + (a.col - b.col).abs();

  int? _bfsDistAteBorda(CellModel start) {
    final w = numeroColunas;
    final visited = List<bool>.filled(numeroLinhas * w, false);
    final q = Queue<_QNode>();
    q.add(_QNode(start.row, start.col, 0));
    visited[start.row * w + start.col] = true;

    while (q.isNotEmpty) {
      final n = q.removeFirst();

      if (_eBordaRC(n.r, n.c)) return n.d;

      for (final viz in _obterVizinhosRC(n.r, n.c)) {
        final idx = viz.r * w + viz.c;
        if (visited[idx]) continue;
        final cell = tabuleiro[viz.r][viz.c];
        if (cell.state == CellState.blocked) continue; 
        visited[idx] = true;
        q.add(_QNode(viz.r, viz.c, n.d + 1));
      }
    }
    return null; 
  }

  bool _eBordaRC(int r, int c) =>
      r == 0 || r == numeroLinhas - 1 || c == 0 || c == numeroColunas - 1;

  List<_RC> _obterVizinhosRC(int r, int c) {
    final par = r % 2 == 0;
    final direcoes = par
        ? const [
            [-1, -1],
            [-1, 0],
            [0, -1],
            [0, 1],
            [1, -1],
            [1, 0],
          ]
        : const [
            [-1, 0],
            [-1, 1],
            [0, -1],
            [0, 1],
            [1, 0],
            [1, 1],
          ];
    final res = <_RC>[];
    for (final d in direcoes) {
      final nr = r + d[0];
      final nc = c + d[1];
      if (nr >= 0 && nr < numeroLinhas && nc >= 0 && nc < numeroColunas) {
        res.add(_RC(nr, nc));
      }
    }
    return res;
  }

  int _distanciaAteBordaGeometrica(CellModel pos) {
    final top = pos.row;
    final bottom = numeroLinhas - 1 - pos.row;
    final left = pos.col;
    final right = numeroColunas - 1 - pos.col;
    return min(min(top, bottom), min(left, right));
  }

  List<CellModel> _getPossibleFencePositions(CellModel gato) {
    final positions = <CellModel>[];
    for (var r = 0; r < numeroLinhas; r++) {
      for (var c = 0; c < numeroColunas; c++) {
        final cell = tabuleiro[r][c];
        if (cell.state == CellState.empty) {
          positions.add(cell);
        }
      }
    }
    return positions;
  }

  bool _tiebreakMelhor(CellModel a, CellModel? b) {
    if (b == null) return true;
    final evitaVoltaA =
        !(_ultimaPosicaoGato != null && a.row == _ultimaPosicaoGato!.row && a.col == _ultimaPosicaoGato!.col);
    final evitaVoltaB =
        !(_ultimaPosicaoGato != null && b.row == _ultimaPosicaoGato!.row && b.col == _ultimaPosicaoGato!.col);
    if (evitaVoltaA != evitaVoltaB) return evitaVoltaA;

    final da = _bfsDistAteBorda(a) ?? 1 << 20;
    final db = _bfsDistAteBorda(b) ?? 1 << 20;
    if (da != db) return da < db;

    return _vizinhosDisponiveis(a).length > _vizinhosDisponiveis(b).length;
  }

  bool _estaNaBorda(CellModel celula) =>
      celula.row == 0 ||
      celula.row == numeroLinhas - 1 ||
      celula.col == 0 ||
      celula.col == numeroColunas - 1;

  List<CellModel> _vizinhosDisponiveis(CellModel celula) =>
      _obterVizinhos(celula).where((n) => n.state == CellState.empty).toList();

  List<CellModel> _obterVizinhos(CellModel celula) {
    final r = celula.row;
    final c = celula.col;
    final par = r % 2 == 0;

    final direcoes = par
        ? const [
            [-1, -1],
            [-1, 0],
            [0, -1],
            [0, 1],
            [1, -1],
            [1, 0],
          ]
        : const [
            [-1, 0],
            [-1, 1],
            [0, -1],
            [0, 1],
            [1, 0],
            [1, 1],
          ];

    final vizinhos = <CellModel>[];
    for (final dir in direcoes) {
      final nr = r + dir[0];
      final nc = c + dir[1];
      if (nr >= 0 && nr < numeroLinhas && nc >= 0 && nc < numeroColunas) {
        vizinhos.add(tabuleiro[nr][nc]);
      }
    }
    return vizinhos;
  }
}

class _MoveRank {
  final CellModel cell;
  final int distBfs;
  final int mobilidade;
  _MoveRank({required this.cell, required this.distBfs, required this.mobilidade});
}

class _QNode {
  final int r, c, d;
  _QNode(this.r, this.c, this.d);
}

class _RC {
  final int r, c;
  _RC(this.r, this.c);
}
