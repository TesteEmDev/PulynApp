import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/auth_provider.dart';
import 'package:pulyn_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Responde 401 a tudo ("Token inválido"), como o backend faz com um token que não é dele, e guarda os cabeçalhos pedidos.
class _Recusa401 implements HttpClientAdapter {
  final List<Map<String, dynamic>> cabecalhos = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    cabecalhos.add(Map<String, dynamic>.from(options.headers));
    return ResponseBody.fromString(
      jsonEncode({'error': 'Token inválido'}),
      401,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

final _usuario = User(id: 'u1', email: 'ana@email.com', nome: 'Ana Souza', perfil: 'family', empresaId: 'e1');

Future<(ApiService, _Recusa401)> _api(Map<String, Object> prefs) async {
  SharedPreferences.setMockInitialValues(prefs);
  final api = ApiService();
  final adaptador = _Recusa401();
  api.dio.httpClientAdapter = adaptador;
  await api.init();
  return (api, adaptador);
}

Future<void> _pedir(ApiService api, String caminho) async {
  try {
    await api.dio.get(caminho);
  } on DioException {
    // o 401 chega como exceção; o que importa aqui é o que o ApiService fez com ele
  }
}

void main() {
  group('ApiService com o token recusado', () {
    test('avisa uma vez, apaga o token e o usuário guardado, mesmo com vários pedidos recusados', () async {
      final (api, _) = await _api({'auth_token': 'token-de-outro-servidor', 'cached_user': jsonEncode(_usuario.toJson())});
      var avisos = 0;
      api.onSessionExpired = () => avisos += 1;

      await _pedir(api, '/familias/me');
      await _pedir(api, '/familias/eventos');
      await _pedir(api, '/familias/children');

      expect(avisos, 1);
      expect(api.prefs.getString('auth_token'), isNull);
      expect(api.prefs.getString('cached_user'), isNull);
    });

    test('um 401 sem token (senha errada no login) não derruba nada', () async {
      final (api, adaptador) = await _api({});
      var avisos = 0;
      api.onSessionExpired = () => avisos += 1;

      await _pedir(api, '/auth/login');

      expect(adaptador.cabecalhos.single.containsKey('Authorization'), isFalse);
      expect(avisos, 0);
    });

    test('depois de um novo login, a próxima recusa avisa de novo', () async {
      final (api, _) = await _api({'auth_token': 'velho'});
      var avisos = 0;
      api.onSessionExpired = () => avisos += 1;

      await _pedir(api, '/familias/me');
      expect(avisos, 1);

      await api.prefs.setString('auth_token', 'token-do-novo-login'); // é o que o login faz
      await _pedir(api, '/familias/me');
      expect(avisos, 2);
    });
  });

  test('AuthNotifier: com token recusado pelo servidor a conta volta ao login em vez de ficar logada sem dados', () async {
    final (api, _) = await _api({'auth_token': 'token-de-outro-servidor', 'cached_user': jsonEncode(_usuario.toJson())});
    final container = ProviderContainer(overrides: [apiServiceProvider.overrideWithValue(api)]);
    addTearDown(container.dispose);

    final estados = <User?>[];
    container.listen<AsyncValue<User?>>(authProvider, (_, novo) {
      if (novo.hasValue) estados.add(novo.value);
    }, fireImmediately: true);

    await container.read(authInitProvider.future);
    // o app abre logado com o usuário do cache e confere o perfil em segundo plano: o servidor responde 401
    for (var i = 0; i < 50 && container.read(authProvider).valueOrNull != null; i += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }

    expect(estados.first?.email, 'ana@email.com', reason: 'começou logado com o usuário do cache');
    expect(container.read(authProvider).valueOrNull, isNull, reason: 'voltou ao login');
    expect(api.prefs.getString('auth_token'), isNull);
    expect(api.prefs.getString('cached_user'), isNull);
  });
}
