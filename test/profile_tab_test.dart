import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/screens/profile/profile_tab.dart';

Child _child(String id, String nickname, {int score = 0, String team = 'Time Azul', String color = '#1E9BD7'}) => Child(
      id: id,
      name: '$nickname Souza',
      nickname: nickname,
      age: 7,
      currentScore: score,
      totalScore: score,
      teamId: 't-$id',
      teamName: team,
      teamColor: color,
      rank: 1,
      achievements: const [],
    );

final _user = User(
  id: 'u1',
  email: 'ana@email.com',
  name: 'Ana Souza',
  role: 'family',
  empresaId: 'e1',
);

void main() {
  Future<void> pumpTab(
    WidgetTester tester, {
    AsyncValue<User?>? auth,
    AsyncValue<List<Child>>? children,
    VoidCallback? onLogout,
    VoidCallback? onRetry,
  }) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => ProfileTab(
            auth: auth ?? AsyncValue.data(_user),
            children: children ?? AsyncValue.data([_child('c1', 'Lia', score: 30), _child('c2', 'Davi', score: 12, team: 'Time Verde', color: '#22C55E')]),
            onLogout: onLogout ?? () {},
            onRetry: onRetry,
          ),
        ),
        GoRoute(path: '/manage-children', builder: (_, _) => const Scaffold(body: Center(child: Text('TELA GERENCIAR')))),
        GoRoute(path: '/child/:id', builder: (_, s) => Scaffold(body: Center(child: Text('CRIANCA ${s.pathParameters['id']}')))),
      ],
    );

    await tester.pumpWidget(MaterialApp.router(theme: appTheme, routerConfig: router));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o responsável, o resumo e as crianças com time e pontos', (tester) async {
    await pumpTab(tester);

    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.text('ana@email.com'), findsOneWidget);
    expect(find.text('Responsável'), findsOneWidget); // não mais "FAMILY" em caixa alta

    // Resumo: 2 crianças e 42 pontos somados (30 + 12)
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Crianças vinculadas'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('Pontos somados'), findsOneWidget);

    expect(find.text('Lia'), findsOneWidget);
    expect(find.text('Time Azul · 30 pts'), findsOneWidget);
    expect(find.text('Davi'), findsOneWidget);
    expect(find.text('Time Verde · 12 pts'), findsOneWidget);
  });

  testWidgets('com uma criança o rótulo fica no singular', (tester) async {
    await pumpTab(tester, children: AsyncValue.data([_child('c1', 'Lia')]));

    expect(find.text('Criança vinculada'), findsOneWidget);
    expect(find.text('Crianças vinculadas'), findsNothing);
  });

  testWidgets('sem crianças mostra como vincular pelo QR Code', (tester) async {
    await pumpTab(tester, children: const AsyncValue.data(<Child>[]));

    expect(find.text('Nenhuma criança vinculada ainda'), findsOneWidget);
    expect(find.text('Vincular com QR Code'), findsOneWidget);
    expect(find.text('0'), findsNWidgets(2)); // 0 crianças, 0 pontos
  });

  testWidgets('enquanto carrega pela primeira vez não mostra "nenhuma criança"', (tester) async {
    await pumpTab(tester, children: const AsyncValue.loading());

    expect(find.text('Nenhuma criança vinculada ainda'), findsNothing);
    expect(find.text('–'), findsNWidgets(2));
  });

  testWidgets('ao recarregar mantém as crianças na tela (sem piscar a cada leitura)', (tester) async {
    final reloading = const AsyncLoading<List<Child>>().copyWithPrevious(AsyncData([_child('c1', 'Lia', score: 30)]));
    await pumpTab(tester, children: reloading);

    expect(find.text('Lia'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('–'), findsNothing);
  });

  testWidgets('tocar numa criança abre o perfil dela', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Lia'));
    await tester.pumpAndSettle();

    expect(find.text('CRIANCA c1'), findsOneWidget);
  });

  testWidgets('"Gerenciar crianças vinculadas" abre a tela de gerenciar', (tester) async {
    await pumpTab(tester);

    await tester.tap(find.text('Gerenciar crianças vinculadas'));
    await tester.pumpAndSettle();

    expect(find.text('TELA GERENCIAR'), findsOneWidget);
  });

  group('sair da conta', () {
    testWidgets('pede confirmação e cancelar não sai', (tester) async {
      var logouts = 0;
      await pumpTab(tester, onLogout: () => logouts++);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsOneWidget);
      expect(logouts, 0, reason: 'antes só saía direto, sem perguntar');

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(find.text('Sair da conta?'), findsNothing);
      expect(logouts, 0);
    });

    testWidgets('confirmar sai uma vez', (tester) async {
      var logouts = 0;
      await pumpTab(tester, onLogout: () => logouts++);

      await tester.tap(find.text('Sair da conta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();

      expect(logouts, 1);
    });
  });

  testWidgets('erro ao carregar o perfil oferece tentar de novo', (tester) async {
    var retries = 0;
    await pumpTab(tester, auth: AsyncValue.error(Exception('falhou'), StackTrace.empty), onRetry: () => retries++);

    expect(find.text('Não foi possível carregar seu perfil'), findsOneWidget);
    await tester.tap(find.text('Tentar de novo'));
    expect(retries, 1);
  });

  testWidgets('não tem controles que não fazem nada (interruptores, editar)', (tester) async {
    await pumpTab(tester);

    expect(find.byType(Switch), findsNothing);
    expect(find.byTooltip('Editar perfil'), findsNothing);
    expect(find.text('Tema Escuro'), findsNothing);
  });
}
