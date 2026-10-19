import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/utils/top_snackbar.dart';

void main() {
  var tapped = 0;

  Widget host() => MaterialApp(
        theme: appTheme,
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showTopSnackBar(
                  context,
                  'Não consegui carregar suas crianças.',
                  kind: FeedbackKind.error,
                  actionLabel: 'Tentar de novo',
                  onAction: () => tapped++,
                ),
                child: const Text('mostrar'),
              ),
            ),
          ),
        ),
      );


  setUp(() => tapped = 0);

  testWidgets('mostra a mensagem no topo da tela e some sozinha', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    final message = find.text('Não consegui carregar suas crianças.');
    expect(message, findsOneWidget);
    expect(tester.getTopLeft(message).dy, lessThan(120), reason: 'fica no topo, não embaixo');

    await tester.pump(const Duration(seconds: 7));
    await tester.pumpAndSettle();
    expect(message, findsNothing);
  });

  testWidgets('o botão de ação executa a ação e fecha a mensagem', (tester) async {
    await tester.pumpWidget(host());
    await tester.tap(find.text('mostrar'));
    await tester.pump();

    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();

    expect(tapped, 1);
    expect(find.text('Não consegui carregar suas crianças.'), findsNothing);
  });
}
