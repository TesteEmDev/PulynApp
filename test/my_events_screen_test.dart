import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/screens/event/my_events_screen.dart';
import 'package:pulyn_app/services/api_service.dart';

class _FakeApi extends ApiService {
  List<Map<String, dynamic>> eventos;
  final Object? erroAoEntrar;
  final Map<String, dynamic>? respostaAoEntrar;
  final List<Map<String, dynamic>> eventosDepoisDeEntrar;
  final List<String> codigosEnviados = [];
  Object? erroAoListar;

  _FakeApi({
    this.eventos = const [],
    this.erroAoEntrar,
    this.respostaAoEntrar,
    this.eventosDepoisDeEntrar = const [],
    this.erroAoListar,
  });

  @override
  Future<void> init() async {}

  @override
  Future<List<Map<String, dynamic>>> getMyEvents() async {
    final erro = erroAoListar;
    if (erro != null) throw erro;
    return eventos;
  }

  @override
  Future<Map<String, dynamic>> joinEventWithInvite(String token) async {
    codigosEnviados.add(token);
    final erro = erroAoEntrar;
    if (erro != null) throw erro;
    eventos = eventosDepoisDeEntrar;
    return respostaAoEntrar ?? {'success': true, 'evento': {'id': 'novo', 'nome': 'Festa Nova'}, 'crianca': null, 'jaTinhaEvento': false};
  }
}

Map<String, dynamic> _evento(
  String id,
  String nome, {
  String data = '2026-10-05',
  String status = 'finished',
  bool encerrado = true,
  bool porConvite = false,
  List<Map<String, dynamic>> criancas = const [],
}) =>
    {
      'id': id,
      'nome': nome,
      'data': data,
      'status': status,
      'encerrado': encerrado,
      'buffetNome': 'Buffet ADV',
      'adicionadoPorConvite': porConvite,
      'criancas': criancas,
      'totalPontos': criancas.fold<int>(0, (soma, c) => soma + (c['pontos'] as int)),
    };

const _lia = {'id': 'c1', 'nome': 'Lia Souza', 'apelido': 'Lia', 'pontos': 30};

void main() {
  late ProviderContainer container;

  Future<void> pumpTela(WidgetTester tester, _FakeApi api) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/my-events',
      routes: [
        GoRoute(path: '/my-events', builder: (_, _) => const MyEventsScreen()),
        GoRoute(path: '/home', builder: (_, _) => const Scaffold(body: Center(child: Text('TELA HOME')))),
      ],
    );

    container = ProviderContainer(overrides: [
      apiServiceProvider.overrideWithValue(api),
      // O evento ativo faz polling a cada 5 s; no teste fica parado
      activeEventProvider.overrideWith((ref) => Stream.value(null)),
    ]);
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(theme: appTheme, routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  // O aviso no topo some sozinho em alguns segundos: deixa passar para não sobrar timer
  Future<void> esperarAvisoSumir(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
  }

  testWidgets('lista os eventos com situação, data, buffet, crianças e pontos', (tester) async {
    await pumpTela(
      tester,
      _FakeApi(eventos: [
        _evento('e2', 'Festa do João', status: 'active', encerrado: false, data: '2026-10-20', criancas: [_lia]),
        _evento('e1', 'Aniversário da Bia', porConvite: true),
      ]),
    );

    expect(find.text('Festa do João'), findsOneWidget);
    expect(find.text('Em andamento'), findsOneWidget);
    expect(find.text('20/10/2026 · Buffet ADV'), findsOneWidget);
    expect(find.text('Lia'), findsOneWidget);
    expect(find.text('30 pts'), findsOneWidget);

    expect(find.text('Aniversário da Bia'), findsOneWidget);
    expect(find.text('Encerrado'), findsOneWidget);
    expect(find.text('Adicionado por código'), findsOneWidget);
    expect(find.text('Nenhuma criança vinculada neste evento'), findsOneWidget);
  });

  testWidgets('sem eventos explica como adicionar o primeiro', (tester) async {
    await pumpTela(tester, _FakeApi());

    expect(find.text('Você ainda não tem eventos'), findsOneWidget);
    expect(find.byKey(const Key('adicionar-evento')), findsOneWidget);
  });

  testWidgets('erro ao carregar oferece tentar de novo', (tester) async {
    final api = _FakeApi(erroAoListar: Exception('sem rede'));
    await pumpTela(tester, api);

    expect(find.text('Não foi possível carregar seus eventos'), findsOneWidget);

    api.erroAoListar = null;
    api.eventos = [_evento('e1', 'Festa da Lia', criancas: [_lia])];
    await tester.tap(find.text('Tentar de novo'));
    await tester.pumpAndSettle();
    expect(find.text('Festa da Lia'), findsOneWidget);
  });

  testWidgets('tocar num evento com criança mostra esse evento na home', (tester) async {
    await pumpTela(
      tester,
      _FakeApi(eventos: [
        _evento('e2', 'Festa do João', status: 'active', encerrado: false, criancas: [_lia]),
        _evento('e1', 'Festa da Bia', criancas: [_lia]),
      ]),
    );

    await tester.tap(find.text('Festa da Bia'));
    await tester.pumpAndSettle();

    expect(container.read(selectedEventIdProvider), 'e1');
    expect(find.text('TELA HOME'), findsOneWidget);
  });

  testWidgets('evento sem criança explica como vincular e não troca o evento da home', (tester) async {
    await pumpTela(tester, _FakeApi(eventos: [_evento('e1', 'Aniversário da Bia', porConvite: true)]));

    await tester.tap(find.text('Aniversário da Bia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Você ainda não tem criança neste evento'), findsOneWidget);
    expect(container.read(selectedEventIdProvider), isNull);
    expect(find.text('TELA HOME'), findsNothing);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Você ainda não tem criança neste evento'), findsNothing);
  });

  group('adicionar evento com código', () {
    testWidgets('campo vazio pede o código e não chama o servidor', (tester) async {
      final api = _FakeApi();
      await pumpTela(tester, api);

      await tester.tap(find.byKey(const Key('adicionar-evento')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirmar-adicionar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Cole o link ou o código do convite'), findsOneWidget);
      expect(api.codigosEnviados, isEmpty);
    });

    testWidgets('link completo: envia só o código, fecha, avisa e a lista ganha o evento', (tester) async {
      final api = _FakeApi(
        eventosDepoisDeEntrar: [_evento('novo', 'Festa Nova', status: 'scheduled', encerrado: false, porConvite: true)],
      );
      await pumpTela(tester, api);
      expect(find.text('Festa Nova'), findsNothing);

      await tester.tap(find.byKey(const Key('adicionar-evento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo-convite')), ' https://app.pulyn.com.br/family/invite/abc123def456/ ');
      await tester.tap(find.byKey(const Key('confirmar-adicionar-evento')));
      await tester.pumpAndSettle();

      expect(api.codigosEnviados, ['abc123def456']);
      expect(find.byKey(const Key('codigo-convite')), findsNothing, reason: 'a folha fecha');
      expect(find.text('Festa Nova adicionado à sua conta'), findsOneWidget);
      expect(find.text('Festa Nova'), findsOneWidget, reason: 'a lista foi recarregada');
      expect(find.text('Próximo'), findsOneWidget);
      await esperarAvisoSumir(tester);
    });

    testWidgets('convite de uma criança: avisa que ela foi vinculada', (tester) async {
      final api = _FakeApi(respostaAoEntrar: {
        'success': true,
        'evento': {'id': 'e1', 'nome': 'Festa da Lia'},
        'crianca': {'id': 'c1', 'nome': 'Lia Souza'},
        'jaTinhaEvento': false,
      });
      await pumpTela(tester, api);

      await tester.tap(find.byKey(const Key('adicionar-evento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo-convite')), 'codigo-da-lia');
      await tester.tap(find.byKey(const Key('confirmar-adicionar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Festa da Lia adicionado e Lia Souza vinculada'), findsOneWidget);
      await esperarAvisoSumir(tester);
    });

    testWidgets('evento que já estava na conta avisa em vez de dizer que adicionou', (tester) async {
      final api = _FakeApi(respostaAoEntrar: {
        'success': true,
        'evento': {'id': 'e1', 'nome': 'Festa da Lia'},
        'crianca': null,
        'jaTinhaEvento': true,
      });
      await pumpTela(tester, api);

      await tester.tap(find.byKey(const Key('adicionar-evento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo-convite')), 'repetido');
      await tester.tap(find.byKey(const Key('confirmar-adicionar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Festa da Lia já estava na sua conta'), findsOneWidget);
      await esperarAvisoSumir(tester);
    });

    testWidgets('erro do servidor aparece no campo e deixa tentar de novo', (tester) async {
      final api = _FakeApi(erroAoEntrar: Exception('Convite já utilizado'));
      await pumpTela(tester, api);

      await tester.tap(find.byKey(const Key('adicionar-evento')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('codigo-convite')), 'usado');
      await tester.tap(find.byKey(const Key('confirmar-adicionar-evento')));
      await tester.pumpAndSettle();

      expect(find.text('Convite já utilizado'), findsOneWidget);
      expect(find.byKey(const Key('codigo-convite')), findsOneWidget, reason: 'a folha continua aberta');
      expect(tester.widget<FilledButton>(find.byKey(const Key('confirmar-adicionar-evento'))).onPressed, isNotNull);
    });
  });
}
