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

  int get placarJogador => _placarJogador;
  int get placarGato => _placarGato;
  StatusJogo get status => _status;

  LogicaJogo() {
    reiniciarJogo();
  }

  void reiniciarJogo() {
    _status = StatusJogo.jogando;
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

    final path = _bfsRotaMaisCurta(posicaoGato);
    if (path.length < 2) {
      // Gato cercado → jogador vence
      _status = StatusJogo.jogadorVenceu;
      _placarJogador++;
      notifyListeners();
      return;
    }

    final proximo = path[1];
    posicaoGato.state = CellState.empty;
    posicaoGato = proximo;
    posicaoGato.state = CellState.cat;

    if (_estaNaBorda(posicaoGato)) {
      _status = StatusJogo.gatoVenceu;
      _placarGato++;
    }

    notifyListeners();
  }

  /// BFS para encontrar a rota mais curta até qualquer borda
  List<CellModel> _bfsRotaMaisCurta(CellModel start) {
    final queue = Queue<List<CellModel>>()..add([start]);
    final visitado = {start};

    while (queue.isNotEmpty) {
      final path = queue.removeFirst();
      final atual = path.last;

      if (_estaNaBorda(atual)) return path;

      for (final vizinho in _vizinhosDisponiveis(atual)) {
        if (!visitado.contains(vizinho)) {
          visitado.add(vizinho);
          queue.add([...path, vizinho]);
        }
      }
    }

    return [start]; // sem caminho disponível
  }

  bool _estaNaBorda(CellModel celula) {
    return celula.row == 0 || celula.row == numeroLinhas - 1 || celula.col == 0 || celula.col == numeroColunas - 1;
  }

  List<CellModel> _vizinhosDisponiveis(CellModel celula) =>
      _obterVizinhos(celula).where((n) => n.state != CellState.blocked).toList();

  List<CellModel> _obterVizinhos(CellModel celula) {
    final r = celula.row;
    final c = celula.col;
    final par = r % 2 == 0;

    final direcoes = par
        ? [[-1, 0], [-1, -1], [0, -1], [0, 1], [1, 0], [1, -1]]
        : [[-1, 1], [-1, 0], [0, -1], [0, 1], [1, 1], [1, 0]];

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
