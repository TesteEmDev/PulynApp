import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/widgets/brincadeira_selo.dart';

Widget _app(Map<String, dynamic> jogo) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 360,
        child: BrincadeiraSelo(jogo: jogo),
      ),
    ),
  );
}

void main() {
  testWidgets('brincadeira rodando: AO VIVO e o nome da brincadeira', (tester) async {
    await tester.pumpWidget(_app({'gameName': 'Caça ao Tesouro', 'hasActiveGame': true}));

    expect(find.text('AO VIVO'), findsOneWidget);
    expect(find.text('Caça ao Tesouro'), findsOneWidget);
    expect(find.text('SEM BRINCADEIRA'), findsNothing);
  });

  testWidgets('sem brincadeira ativa: SEM BRINCADEIRA, sem mostrar nome de jogo parado', (tester) async {
    await tester.pumpWidget(_app({'gameName': 'Nenhum jogo em andamento', 'hasActiveGame': false}));

    expect(find.text('SEM BRINCADEIRA'), findsOneWidget);
    expect(find.text('Nenhuma agora'), findsOneWidget);
    expect(find.text('Nenhum jogo em andamento'), findsNothing);
    expect(find.text('AO VIVO'), findsNothing);
  });
}
