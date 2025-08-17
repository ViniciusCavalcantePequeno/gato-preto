import 'package:chat_noir/features/jogo/logica/logicaJogo.dart';
import 'package:chat_noir/features/jogo/apresentacao/componentes/celula.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class HexBoard extends StatelessWidget {
  const HexBoard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LogicaJogo>(
      builder: (context, jogo, child) {
        return FittedBox(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(jogo.tabuleiro.length, (rowIndex) {
              final row = jogo.tabuleiro[rowIndex];

              return Padding(
                padding: EdgeInsets.only(left: rowIndex.isOdd ? 26.0 : 0.0),
                child: Row(
                  children: List.generate(row.length, (colIndex) {
                    final celula = row[colIndex];
                    return HexCell(
                      cell: celula,
                      onTap: () => jogo.jogadorClick(celula.row, celula.col),
                    );
                  }),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
