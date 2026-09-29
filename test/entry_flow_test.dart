import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/screens/auth/family_invite_screen.dart';
import 'package:pulyn_app/screens/auth/invite_entry_screen.dart';
import 'package:pulyn_app/screens/auth/register_screen.dart';
import 'package:pulyn_app/screens/onboarding/onboarding_screen.dart';
import 'package:pulyn_app/services/api_service.dart';

/// API falsa do convite: sem rede.
class _FakeInviteApi extends ApiService {
  final Map<String, dynamic>? invite; // null => convite inválido
  final Future<Map<String, dynamic>> Function()? onRegister;
  final List<String> validatedTokens = [];
  int registerCalls = 0;
  List<Map<String, dynamic>>? lastChildren;

  _FakeInviteApi({this.invite, this.onRegister});

  @override
  Future<void> init() async {}

  @override
  Future<Map<String, dynamic>> getFamilyInvite(String token) async {
    validatedTokens.add(token);
    final data = invite;
    if (data == null) throw Exception('410 convite inválido');
    return data;
  }

  @override
  Future<Map<String, dynamic>> registerWithInvite(
    String token,
    String email,
    String password,
    String parentName, {
    List<Map<String, dynamic>>? children,
  }) async {
    registerCalls++;
    lastChildren = children;
    final handler = onRegister;
    if (handler != null) return handler();
    return {'type': 'created', 'message': 'Conta criada! Entre no app e vincule seu filho pelo QR Code.'};
  }
}

const _invite = <String, dynamic>{
  'email': null,
  'event': {'name': 'Festa da Lia', 'date': '2026-10-05'},
};

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    required String initial,
    _FakeInviteApi? api,
  }) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: initial,
      routes: [
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(path: '/invite', builder: (_, _) => const InviteEntryScreen()),
        GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Center(child: Text('TELA DE LOGIN')))),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(
          path: '/family/invite/:token',
          builder: (_, state) => FamilyInviteScreen(token: state.pathParameters['token']!),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [if (api != null) apiServiceProvider.overrideWithValue(api)],
      child: MaterialApp.router(theme: appTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  group('onboarding', () {
    testWidgets('"Começar" leva para a tela de colar o link do convite, não para o login', (tester) async {
      await pumpApp(tester, initial: '/onboarding');

      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Começar'), findsOneWidget);

      await tester.tap(find.text('Começar'));
      await tester.pumpAndSettle();

      expect(find.text('Bem-vindo!'), findsOneWidget);
      expect(find.text('Link ou código do convite'), findsOneWidget);
      expect(find.text('TELA DE LOGIN'), findsNothing);
    });

    testWidgets('"Já tenho conta" continua levando para o login', (tester) async {
      await pumpApp(tester, initial: '/onboarding');
      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Já tenho conta'));
      await tester.pumpAndSettle();

      expect(find.text('TELA DE LOGIN'), findsOneWidget);
    });
  });

  group('tela do convite', () {
    testWidgets('colar o link completo extrai o token e abre o cadastro do convite', (tester) async {
      final api = _FakeInviteApi(invite: _invite);
      await pumpApp(tester, initial: '/invite', api: api);

      await tester.enterText(find.byType(TextField), 'https://app.pulyn.com/family/invite/tok123');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(api.validatedTokens, ['tok123']);
      expect(find.text('Cadastro da família'), findsOneWidget);
      expect(find.text('Festa da Lia'), findsOneWidget);
      expect(find.text('Data: 05/10/2026'), findsOneWidget); // data legível, não o texto cru da API
    });

    testWidgets('sem código não navega e avisa', (tester) async {
      await pumpApp(tester, initial: '/invite');

      await tester.tap(find.text('Continuar'));
      await tester.pump();

      expect(find.text('Cole o link ou o código do convite'), findsOneWidget);
      expect(find.text('Bem-vindo!'), findsOneWidget);
    });

    testWidgets('"Já tenho conta" leva para o login', (tester) async {
      await pumpApp(tester, initial: '/invite');

      await tester.tap(find.text('Já tenho conta'));
      await tester.pumpAndSettle();

      expect(find.text('TELA DE LOGIN'), findsOneWidget);
    });
  });

  group('cadastro pelo convite', () {
    Future<void> fillForm(WidgetTester tester, {String confirm = 'segredo123'}) async {
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Souza');
      await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'ana@email.com');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo123');
      await tester.enterText(find.widgetWithText(TextFormField, 'Confirmar senha'), confirm);
    }

    testWidgets('convite inválido mostra o erro e leva de volta ao código', (tester) async {
      await pumpApp(tester, initial: '/family/invite/ruim', api: _FakeInviteApi());

      expect(find.text('Convite inválido ou expirado'), findsOneWidget);

      await tester.tap(find.text('Digitar outro código'));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo!'), findsOneWidget);
    });

    testWidgets('não pede nem envia dados de crianças: só os dados do responsável', (tester) async {
      final api = _FakeInviteApi(invite: _invite);
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      // Nenhum campo/botão de cadastrar criança
      expect(find.text('Seus filhos'), findsNothing);
      expect(find.text('Adicionar outra criança'), findsNothing);
      expect(find.byTooltip('Remover criança'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Apelido'), findsNothing);
      expect(find.widgetWithText(TextFormField, 'Idade'), findsNothing);
      // Só os 4 campos do responsável
      expect(find.byType(TextFormField), findsNWidgets(4));
      // Explica como o filho é vinculado
      expect(find.text('Seu filho é vinculado depois'), findsOneWidget);

      await fillForm(tester);
      await tester.tap(find.text('Criar cadastro'));
      await tester.pumpAndSettle();

      expect(api.registerCalls, 1);
      expect(api.lastChildren, isNull, reason: 'o app não deve mais mandar crianças');
    });

    testWidgets('conta criada: explica o próximo passo (QR Code) e leva ao login', (tester) async {
      final api = _FakeInviteApi(invite: _invite);
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      await fillForm(tester);
      await tester.tap(find.text('Criar cadastro'));
      await tester.pumpAndSettle();

      expect(find.text('Conta criada!'), findsOneWidget);
      expect(find.text('Peça à recepção o QR Code do seu filho'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('Entrar'));
      await tester.pumpAndSettle();
      expect(find.text('TELA DE LOGIN'), findsOneWidget);
    });

    testWidgets('convite já vinculado a uma criança: cadastro pendente de aprovação, com tela própria', (tester) async {
      final api = _FakeInviteApi(
        invite: {..._invite, 'child': {'name': 'Pedro Lima'}},
        onRegister: () async => {'type': 'pending', 'message': 'Aguarde a aprovação da recepção.'},
      );
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      expect(find.text('Pedro Lima'), findsOneWidget);
      expect(find.text('Criança já vinculada ao seu convite'), findsOneWidget);
      expect(find.text('Seu filho é vinculado depois'), findsNothing);

      await fillForm(tester);
      await tester.tap(find.text('Criar cadastro'));
      await tester.pumpAndSettle();

      expect(find.text('Cadastro realizado!'), findsOneWidget);
      expect(find.text('Aguarde a aprovação da recepção.'), findsOneWidget);
      expect(find.text('A recepção do buffet vai revisar sua solicitação'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);

      await tester.tap(find.text('Ir para o login'));
      await tester.pumpAndSettle();
      expect(find.text('TELA DE LOGIN'), findsOneWidget);
    });

    testWidgets('senhas diferentes: mostra o erro no campo e não envia nada', (tester) async {
      final api = _FakeInviteApi(invite: _invite);
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      await fillForm(tester, confirm: 'outra-senha');
      await tester.tap(find.text('Criar cadastro'));
      await tester.pumpAndSettle();

      expect(find.text('As senhas não conferem'), findsOneWidget);
      expect(api.registerCalls, 0);
    });

    testWidgets('enquanto envia o botão mostra carregando e um segundo toque não envia de novo', (tester) async {
      final pending = Completer<Map<String, dynamic>>();
      final api = _FakeInviteApi(invite: _invite, onRegister: () => pending.future);
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      await fillForm(tester);
      await tester.tap(find.text('Criar cadastro'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Criar cadastro'), findsNothing);
      expect(api.registerCalls, 1);

      pending.complete({'type': 'created', 'message': 'ok'});
      await tester.pumpAndSettle();
      expect(find.text('Conta criada!'), findsOneWidget);
      expect(api.registerCalls, 1);
    });

    testWidgets('erro do servidor libera o botão para tentar de novo', (tester) async {
      final api = _FakeInviteApi(
        invite: _invite,
        onRegister: () async => throw Exception('409 already exists'),
      );
      await pumpApp(tester, initial: '/family/invite/ok', api: api);

      await fillForm(tester);
      await tester.tap(find.text('Criar cadastro'));
      await tester.pumpAndSettle();

      expect(find.text('Email já registrado'), findsOneWidget);
      expect(find.text('Criar cadastro'), findsOneWidget); // botão voltou (não ficou carregando)
    });
  });

  group('cadastro simples', () {
    testWidgets('valida os campos e oferece os caminhos de login e de convite', (tester) async {
      await pumpApp(tester, initial: '/register');

      expect(find.text('Criar conta'), findsWidgets);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Criar conta'));
      await tester.pump();
      expect(find.text('Nome é obrigatório'), findsOneWidget);
      expect(find.text('Email é obrigatório'), findsOneWidget);

      await tester.tap(find.text('Tenho um código de convite'));
      await tester.pumpAndSettle();
      expect(find.text('Bem-vindo!'), findsOneWidget);
    });
  });
}
