import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/widgets/link_child_hero.dart';

void main() {
  Widget host(Widget hero) => MaterialApp(
        theme: appTheme,
        home: Scaffold(body: SingleChildScrollView(child: hero)),
      );

  testWidgets('explica o próximo passo antes de abrir o leitor', (tester) async {
    await tester.pumpWidget(host(const LinkChildHero()));

    expect(find.text('Vincule seu filho'), findsOneWidget);
    expect(find.textContaining('QR Code na recepção'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsOneWidget);
  });

  testWidgets('tocar em "Escanear QR Code" abre o leitor DENTRO do cartão, sem trocar de tela', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(
      panelBuilder: (context, close) => Column(
        children: [
          const Text('LEITOR AQUI'),
          TextButton(onPressed: close, child: const Text('fechar leitor')),
        ],
      ),
    )));

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    // O leitor aparece no lugar da explicação, na mesma tela (o cartão continua o mesmo widget)
    expect(find.text('LEITOR AQUI'), findsOneWidget);
    expect(find.byType(LinkChildHero), findsOneWidget);
    expect(find.text('Vincule seu filho'), findsNothing);
    expect(find.byType(Navigator), findsOneWidget); // nenhuma rota/janela nova foi empilhada
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('fechar o leitor volta para a explicação', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(
      panelBuilder: (context, close) => TextButton(onPressed: close, child: const Text('fechar leitor')),
    )));

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fechar leitor'));
    await tester.pumpAndSettle();

    expect(find.text('Vincule seu filho'), findsOneWidget);
    expect(find.text('fechar leitor'), findsNothing);
  });
}
