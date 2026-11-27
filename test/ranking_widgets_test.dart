import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/utils/data_curta.dart';
import 'package:pulyn_app/widgets/app_components.dart';
import 'package:pulyn_app/widgets/ranking_widgets.dart';

Widget _tela(Widget filho) => MaterialApp(home: Scaffold(body: SizedBox(width: 360, child: filho)));

void main() {
  test('medalha: ouro, prata, bronze e depois o número da posição', () {
    expect(medalhaDaPosicao(0), '🥇');
    expect(medalhaDaPosicao(1), '🥈');
    expect(medalhaDaPosicao(2), '🥉');
    expect(medalhaDaPosicao(3), '4');
  });

  test('dataCurta formata a data sem mudar o dia e ignora texto inválido', () {
    expect(dataCurta('2026-10-05'), '05/10/2026');
    expect(dataCurta('2026-10-05T00:00:00'), '05/10/2026');
    expect(dataCurta('não é data'), '');
    expect(dataCurta(null), '');
  });

  testWidgets('cartão de criança: versão completa e compacta mostram nome e pontos', (tester) async {
    await tester.pumpWidget(_tela(const CartaoRankingCrianca(
      position: 1, nome: 'Ana', score: 120, teamColor: '#FF0000', medal: '🥇', isTop: true,
    )));
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('120 pts'), findsOneWidget);
    expect(find.text('Posição #1'), findsOneWidget);

    await tester.pumpWidget(_tela(const CartaoRankingCrianca(
      position: 2, nome: 'Bia', score: 80, teamColor: '#00FF00', medal: '🥈', isTop: false, compacto: true,
    )));
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('pts'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cartão de time: texto do subtítulo muda na versão compacta', (tester) async {
    await tester.pumpWidget(_tela(const CartaoRankingTime(
      position: 1, nome: 'Azul', score: 300, teamColor: '#0000FF', medal: '🥇', isTop: true,
    )));
    expect(find.text('Pontos totais do time'), findsOneWidget);
    await tester.pumpWidget(_tela(const CartaoRankingTime(
      position: 1, nome: 'Azul', score: 300, teamColor: '#0000FF', medal: '🥇', isTop: true, compacto: true,
    )));
    expect(find.text('Pontos totais'), findsOneWidget);
  });

  testWidgets('erro centralizado só mostra o botão quando há o que refazer', (tester) async {
    await tester.pumpWidget(_tela(const ErroCentralizado(mensagem: 'Falhou')));
    expect(find.text('Tentar Novamente'), findsNothing);
    var tentou = false;
    await tester.pumpWidget(_tela(ErroCentralizado(mensagem: 'Falhou', onTentarNovamente: () => tentou = true)));
    await tester.tap(find.text('Tentar Novamente'));
    expect(tentou, isTrue);
  });
}
