import 'package:chat_noir/features/jogo/logica/logicaJogo.dart';
import 'package:chat_noir/features/jogo/%20apresentacao/componentes/tabuleiro.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TelaJogo extends StatefulWidget {
  const TelaJogo({super.key});

  @override
  State<TelaJogo> createState() => _TelaJogoState();
}

class _TelaJogoState extends State<TelaJogo> {
  @override
  void initState() {
    super.initState();
    context.read<GameLogic>().addListener(_verificarStatusJogo);
  }

  @override
  void dispose() {
    context.read<GameLogic>().removeListener(_verificarStatusJogo);
    super.dispose();
  }

  void _verificarStatusJogo() {
    final jogo = context.read<GameLogic>();
    if (jogo.gameStatus != GameStatus.playing) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _exibirDialogoFim(jogo.gameStatus);
      });
    }
  }

  void _exibirDialogoFim(GameStatus status) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  status == GameStatus.playerWon ? 'Você Venceu!' : 'Você Perdeu!',
                  style: const TextStyle(fontFamily: 'Pacifico', fontSize: 24),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                Text(
                  status == GameStatus.playerWon
                      ? 'Você capturou o gato'
                      : 'O gato escapou',
                  style: const TextStyle(fontFamily: 'Pacifico'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    context.read<GameLogic>().resetGame();
                  },
                  child: const Text(
                    'Reiniciar',
                    style: TextStyle(fontFamily: 'Pacifico'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barraStatus(GameLogic jogo) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Text('Jogador: ${jogo.jogador}', style: const TextStyle(fontFamily: 'Pacifico')),
        ElevatedButton(
          onPressed: () => context.read<GameLogic>().resetAll(),
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(100, 40),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          child: const Text('Zerar Placar', style: TextStyle(fontFamily: 'Pacifico')),
        ),
        Text('Gato: ${jogo.gatoJogada}', style: const TextStyle(fontFamily: 'Pacifico')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gato Preto',
          style: TextStyle(fontFamily: 'Pacifico', fontSize: 26),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Consumer<GameLogic>(builder: (_, jogo, __) => _barraStatus(jogo)),
              const SizedBox(height: 20),
              const Expanded(
                child: Center(
                  child: HexBoard(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
