import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responde as rotas com o que o teste combinou: caminho -> (status, corpo). Guarda o que foi pedido.
class _AdaptadorFalso implements HttpClientAdapter {
  final Map<String, (int, Object)> respostas;
  final List<String> pedidos = [];
  final List<Object?> corpos = [];
  final List<Map<String, dynamic>> consultas = [];
  _AdaptadorFalso(this.respostas);

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    pedidos.add('${options.method} ${options.path}');
    corpos.add(options.data);
    consultas.add(Map<String, dynamic>.from(options.queryParameters));
    final resposta = respostas[options.path] ?? (404, {'error': 'não existe'});
    return ResponseBody.fromString(
      jsonEncode(resposta.$2),
      resposta.$1,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Future<(ApiService, _AdaptadorFalso)> _api(Map<String, (int, Object)> respostas) async {
  SharedPreferences.setMockInitialValues({});
  final api = ApiService();
  final adaptador = _AdaptadorFalso(respostas);
  api.dio.httpClientAdapter = adaptador;
  await api.init();
  return (api, adaptador);
}

const _eventosDaConta = {
  'eventos': [
    {'id': 'e2', 'nome': 'Aniversário da Bia', 'data': '2026-10-20', 'status': 'scheduled', 'encerrado': false, 'criancas': []},
    {'id': 'e1', 'nome': 'Festa da Lia', 'data': '2026-10-01', 'status': 'finished', 'encerrado': true, 'criancas': [{'id': 'c1', 'nome': 'Lia', 'pontos': 30}]},
  ],
};

const _criancas = {
  'success': true,
  'children': [
    {'id': 'c1', 'eventoId': 'e1', 'eventoNome': 'Festa da Lia', 'nome': 'Lia'},
  ],
};

void main() {
  group('getFamilyEvents (seletor da home)', () {
    test('usa os eventos da conta, inclusive o adicionado por código sem criança', () async {
      final (api, _) = await _api({'/familias/eventos': (200, _eventosDaConta)});

      final eventos = await api.getFamilyEvents();

      expect(eventos, [
        {'id': 'e2', 'nome': 'Aniversário da Bia'},
        {'id': 'e1', 'nome': 'Festa da Lia'},
      ]);
    });

    test('back sem a rota nova (404): cai para os eventos das crianças', () async {
      final (api, adaptador) = await _api({'/familias/children': (200, _criancas)});

      final eventos = await api.getFamilyEvents();

      expect(eventos, [
        {'id': 'e1', 'nome': 'Festa da Lia'},
      ]);
      expect(adaptador.pedidos, ['GET /familias/eventos', 'GET /familias/children']);
    });
  });

  group('getActiveEvent', () {
    test('evento escolhido que só entrou por código (sem criança) também vale', () async {
      final (api, _) = await _api({'/familias/children': (200, _criancas), '/familias/eventos': (200, _eventosDaConta)});

      final evento = await api.getActiveEvent(eventoId: 'e2');

      expect(evento, {'id': 'e2', 'nome': 'Aniversário da Bia', 'status': 'active'});
    });

    test('evento encerrado escolhido vem como encerrado', () async {
      final (api, _) = await _api({
        '/familias/children': (200, {
          'children': [
            {'id': 'c9', 'eventoId': 'e9', 'eventoNome': 'Outro'},
          ],
        }),
        '/familias/eventos': (200, _eventosDaConta),
      });

      final evento = await api.getActiveEvent(eventoId: 'e1');

      expect(evento?['id'], 'e1');
      expect(evento?['status'], 'finished');
    });

    test('evento de criança continua saindo da lista das crianças, sem pedir a rota nova', () async {
      final (api, adaptador) = await _api({'/familias/children': (200, _criancas)});

      final evento = await api.getActiveEvent(eventoId: 'e1');

      expect(evento?['id'], 'e1');
      expect(adaptador.pedidos, ['GET /familias/children']);
    });

    test('id que não é da conta cai para o evento da primeira criança', () async {
      final (api, _) = await _api({'/familias/children': (200, _criancas), '/familias/eventos': (200, _eventosDaConta)});

      final evento = await api.getActiveEvent(eventoId: 'estranho');

      expect(evento?['id'], 'e1');
    });
  });

  group('planta e zonas do evento', () {
    test('a planta é pedida com o evento em exibição', () async {
      final (api, adaptador) = await _api({
        '/company-map/floor-plan': (200, {'floorPlan': {'dataUrl': 'data:image/png;base64,AAAA'}}),
      });

      final planta = await api.getFloorPlan(eventoId: 'e2');

      expect(planta, 'data:image/png;base64,AAAA');
      expect(adaptador.consultas.single, {'eventoId': 'e2'});
    });

    test('as zonas são pedidas com o evento em exibição', () async {
      final (api, adaptador) = await _api({
        '/company-map/zones': (200, [{'nome': 'Entrada', 'x': 0, 'y': 0}]),
      });

      final zonas = await api.getZones(eventoId: 'e2');

      expect(zonas.single['nome'], 'Entrada');
      expect(adaptador.consultas.single, {'eventoId': 'e2'});
    });

    test('sem evento, nada é acrescentado à consulta (comportamento antigo)', () async {
      final (api, adaptador) = await _api({
        '/company-map/floor-plan': (200, {'floorPlan': null}),
        '/company-map/zones': (200, <Object>[]),
      });

      await api.getFloorPlan();
      await api.getZones();

      expect(adaptador.consultas, [<String, dynamic>{}, <String, dynamic>{}]);
    });
  });

  group('linkChildWithBracelet', () {
    const resposta = {
      'success': true,
      'linkedChild': {'id': 'c1', 'nome': 'Lia'},
    };

    test('manda o evento escolhido junto com a pulseira', () async {
      final (api, adaptador) = await _api({'/family/bracelet/validate': (200, resposta)});

      await api.linkChildWithBracelet('04E72C1A896880', eventoId: 'e2');

      expect(adaptador.pedidos, ['POST /family/bracelet/validate']);
      expect(adaptador.corpos.single, {'uid': '04E72C1A896880', 'eventoId': 'e2'});
    });

    test('sem evento, manda só a pulseira (como antes)', () async {
      final (api, adaptador) = await _api({'/family/bracelet/validate': (200, resposta)});

      await api.linkChildWithBracelet('04E72C1A896880');

      expect(adaptador.corpos.single, {'uid': '04E72C1A896880'});
    });
  });

  group('joinEventWithInvite', () {
    test('envia o código na rota certa e devolve a resposta', () async {
      final (api, adaptador) = await _api({
        '/familias/invites/abc123/entrar': (201, {'success': true, 'evento': {'id': 'e2', 'nome': 'Aniversário da Bia'}, 'crianca': null, 'jaTinhaEvento': false}),
      });

      final resposta = await api.joinEventWithInvite('abc123');

      expect(adaptador.pedidos, ['POST /familias/invites/abc123/entrar']);
      expect((resposta['evento'] as Map)['nome'], 'Aniversário da Bia');
    });

    test('mostra a mensagem que o servidor mandou (convite usado, de outro e-mail...)', () async {
      final (api, _) = await _api({'/familias/invites/usado/entrar': (410, {'error': 'Convite já utilizado'})});

      await expectLater(
        api.joinEventWithInvite('usado'),
        throwsA(predicate((e) => e is Exception && e.toString() == 'Exception: Convite já utilizado')),
      );
    });

    test('sem mensagem do servidor, usa um texto padrão', () async {
      final (api, _) = await _api({'/familias/invites/x/entrar': (500, 'falha')});

      await expectLater(
        api.joinEventWithInvite('x'),
        throwsA(predicate((e) => e.toString() == 'Exception: Não foi possível adicionar o evento')),
      );
    });
  });
}
