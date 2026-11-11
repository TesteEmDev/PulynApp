import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulyn_app/widgets/duplo_voltar_para_sair.dart';

/// Botão voltar do celular: telas abertas a partir do login voltam para o login;
/// na tela raiz o app só fecha no segundo toque, em até 2 segundos.
void main() {
  Future<void> voltarDoCelular(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await tester.pump();
  }

  testWidgets('tela aberta com push volta para o login e não fecha o app', (tester) async {
    var saiu = false;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => DuploVoltarParaSair(
            aoSair: () => saiu = true,
            child: Scaffold(
              body: TextButton(
                onPressed: () => context.push('/esqueci-senha'),
                child: const Text('login'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/esqueci-senha',
          builder: (context, state) => const Scaffold(body: Text('esqueci')),
        ),
      ],
      initialLocation: '/login',
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('login'));
    await tester.pumpAndSettle();
    expect(find.text('esqueci'), findsOneWidget);

    await voltarDoCelular(tester);
    await tester.pumpAndSettle();

    expect(find.text('login'), findsOneWidget);
    expect(saiu, isFalse);
  });

  testWidgets('na tela raiz: primeiro toque avisa, segundo toque fecha o app', (tester) async {
    var saiu = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DuploVoltarParaSair(
          aoSair: () => saiu = true,
          child: const Scaffold(body: Text('raiz')),
        ),
      ),
    );

    await voltarDoCelular(tester);
    expect(saiu, isFalse);
    expect(find.text('Clique novamente para sair do app'), findsOneWidget);

    await voltarDoCelular(tester);
    expect(saiu, isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('segundo toque depois de mais de 2 segundos só avisa de novo', (tester) async {
    var saiu = false;
    await tester.pumpWidget(
      MaterialApp(
        home: DuploVoltarParaSair(
          aoSair: () => saiu = true,
          child: const Scaffold(body: Text('raiz')),
        ),
      ),
    );

    await voltarDoCelular(tester);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 2100)));
    await voltarDoCelular(tester);

    expect(saiu, isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });
}
