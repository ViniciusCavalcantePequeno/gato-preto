import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:chat_noir/core/constants.dart';
import 'package:chat_noir/features/jogo/modelo/modeloCelula.dart';

enum StatusJogo { jogando, jogadorVenceu, gatoVenceu }

class ResultadoMinimax {
  final double valor;
  final CellModel? movimento;
  ResultadoMinimax(this.valor, this.movimento);
}

class LogicaJogo extends ChangeNotifier {
  int _placarJogador = 0;
  int _placarGato = 0;
  StatusJogo _status = StatusJogo.jogando;

  late List<List<CellModel>> tabuleiro;
  late CellModel posicaoGato;
  final Random _aleatorio = Random();
  final Set<CellModel> _gatoVisitado = {};

  int get placarJogador => _placarJogador;
  int get placarGato => _placarGato;
  StatusJogo get status => _status;

  LogicaJogo() {
    reiniciarJogo();
  }

  void reiniciarJogo() {
    _status = StatusJogo.jogando;
    _gatoVisitado.clear();
    _inicializarTabuleiro();
    _colocarObstaculosIniciais();
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

    // Profundidade adaptativa do Minimax
    final depth = (_distanciaParaBorda(posicaoGato) <= 3) ? 5 : 3;

    final resultado = _minimax(posicaoGato, depth, true, -double.infinity, double.infinity);

    if (resultado.movimento == null) {
      _status = StatusJogo.jogadorVenceu;
      _placarJogador++;
      notifyListeners();
      return;
    }

    final proximo = resultado.movimento!;
    _gatoVisitado.add(posicaoGato);
    posicaoGato.state = CellState.empty;
    posicaoGato = proximo;
    posicaoGato.state = CellState.cat;

    if (_estaNaBorda(posicaoGato)) {
      _status = StatusJogo.gatoVenceu;
      _placarGato++;
    }

    notifyListeners();
  }

  ResultadoMinimax _minimax(CellModel celula, int depth, bool maximizando, double alpha, double beta) {
    if (depth == 0 || _estaNaBorda(celula) || _isCercado(celula)) {
      return ResultadoMinimax(_avaliarCelula(celula), null);
    }

    final vizinhos = _vizinhosDisponiveis(celula);
    if (vizinhos.isEmpty) return ResultadoMinimax(-1000.0, null);

    CellModel? melhorMovimento;
    double melhorValor = maximizando ? -double.infinity : double.infinity;

    for (final vizinho in vizinhos) {
      // Marca movimento temporariamente
      vizinho.state = CellState.cat;
      celula.state = CellState.empty;

      final resultado = _minimax(vizinho, depth - 1, !maximizando, alpha, beta);

      // Reverte o estado
      vizinho.state = CellState.empty;
      celula.state = CellState.cat;

      if (maximizando) {
        if (resultado.valor > melhorValor) {
          melhorValor = resultado.valor;
          melhorMovimento = vizinho;
        } else if (resultado.valor == melhorValor && _aleatorio.nextBool()) {
          melhorMovimento = vizinho;
        }
        alpha = max(alpha, melhorValor);
      } else {
        if (resultado.valor < melhorValor) {
          melhorValor = resultado.valor;
          melhorMovimento = vizinho;
        }
        beta = min(beta, melhorValor);
      }

      if (beta <= alpha) break;
    }

    return ResultadoMinimax(melhorValor, melhorMovimento);
  }

  double _avaliarCelula(CellModel celula) {
    if (_estaNaBorda(celula)) return 100.0;
    if (_isCercado(celula)) return -100.0;
    if (_gatoVisitado.contains(celula)) return -50.0;

    // BFS para estimar distância mínima até borda
    final queue = Queue<List<CellModel>>()..add([celula]);
    final visitado = {celula};
    int distancia = 0;

    while (queue.isNotEmpty) {
      distancia++;
      final caminho = queue.removeFirst();
      final atual = caminho.last;

      for (final vizinho in _vizinhosDisponiveis(atual)) {
        if (!visitado.contains(vizinho)) {
          if (_estaNaBorda(vizinho)) return 50.0 - distancia.toDouble();
          visitado.add(vizinho);
          queue.add([...caminho, vizinho]);
        }
      }
    }

    // Penaliza posições com menos opções
    return -10.0 * (_vizinhosDisponiveis(celula).length);
  }

  bool _estaNaBorda(CellModel celula) =>
      celula.row == 0 ||
      celula.row == numeroLinhas - 1 ||
      celula.col == 0 ||
      celula.col == numeroColunas - 1;

  bool _isCercado(CellModel celula) => _vizinhosDisponiveis(celula).isEmpty;

  List<CellModel> _vizinhosDisponiveis(CellModel celula) =>
      _obterVizinhos(celula).where((n) => n.state != CellState.blocked).toList();

  List<CellModel> _obterVizinhos(CellModel celula) {
    final r = celula.row;
    final c = celula.col;
    final par = r % 2 == 0;

    final direcoes = par
        ? [
            [-1, 0],
            [-1, -1],
            [0, -1],
            [0, 1],
            [1, 0],
            [1, -1]
          ]
        : [
            [-1, 1],
            [-1, 0],
            [0, -1],
            [0, 1],
            [1, 1],
            [1, 0]
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

  int _distanciaParaBorda(CellModel celula) {
    final top = celula.row;
    final bottom = numeroLinhas - 1 - celula.row;
    final left = celula.col;
    final right = numeroColunas - 1 - celula.col;
    return min(min(top, bottom), min(left, right));
  }
}
