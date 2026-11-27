import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/providers/auth_provider.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/screens/auth/login_screen.dart';
import 'package:pulyn_app/services/api_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Servidor de mentira: responde a /auth/check-email e /auth/login como o backend, e anota o que foi pedido.
class _Servidor implements HttpClientAdapter {
  /// `available` do check-email: true = não existe conta com o e-mail.
  bool semConta = false;
  int statusLogin = 401;
  Map<String, dynamic> corpoLogin = {'error': 'Email ou senha incorretos'};
  DioException? falhaDeRede;
  Completer<void>? seguraLogin;
  final List<String> pedidos = [];

  ResponseBody _json(Object corpo, int status) => ResponseBody.fromString(
        jsonEncode(corpo),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    pedidos.add(options.path);
    if (falhaDeRede != null) throw falhaDeRede!.copyWith(requestOptions: options);
    if (options.path.contains('/auth/check-email')) return _json({'available': semConta}, 200);
    if (options.path.contains('/auth/login')) {
      if (seguraLogin != null) await seguraLogin!.future;
      return _json(corpoLogin, statusLogin);
    }
    return _json({'error': 'não esperado: ${options.path}'}, 404);
  }

  @override
  void close({bool force = false}) {}
}

Future<_Servidor> _abrir(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final api = ApiService();
  final servidor = _Servidor();
  api.dio.httpClientAdapter = servidor;
  await api.init();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [apiServiceProvider.overrideWithValue(api)],
      child: const MaterialApp(home: LoginScreen()),
    ),
  );
  await tester.pump();
  return servidor;
}

Future<void> _preencherEEntrar(WidgetTester tester, {String email = 'ana@email.com', String senha = 'segredo1'}) async {
  final campos = find.byType(TextFormField);
  await tester.enterText(campos.at(0), email);
  await tester.enterText(campos.at(1), senha);
  await tester.tap(find.text('Fazer Login'));
}

void main() {
  testWidgets('sem conta: a varredura avisa antes de tentar entrar e o botão volta ao normal', (tester) async {
    final servidor = await _abrir(tester);
    servidor.semConta = true;

    await _preencherEEntrar(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Não existe conta com este e-mail'), findsOneWidget);
    expect(servidor.pedidos.any((p) => p.contains('/auth/login')), isFalse, reason: 'não deve tentar entrar sem conta');
    expect(find.text('Fazer Login'), findsOneWidget);
    expect(find.text('Entrando...'), findsNothing);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('enquanto entra, o carregamento fica no próprio botão e os campos continuam na tela', (tester) async {
    final servidor = await _abrir(tester);
    servidor.seguraLogin = Completer<void>();

    await _preencherEEntrar(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Entrando...'), findsOneWidget);
    expect(find.descendant(of: find.byType(ElevatedButton), matching: find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2), reason: 'a tela de login não é trocada por uma tela de carregamento');
    // A sessão não vira "carregando": é isso que fazia o roteador trocar a tela de login pela splash
    final sessao = ProviderScope.containerOf(tester.element(find.byType(LoginScreen))).read(authProvider);
    expect(sessao.isLoading, isFalse);

    // Toque repetido durante o carregamento não dispara outro login
    await tester.tap(find.text('Entrando...'));
    await tester.pump();
    expect(servidor.pedidos.where((p) => p.contains('/auth/login')).length, 1);

    servidor.seguraLogin!.complete();
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('senha errada: mostra o alerta do servidor, mantém o que foi digitado e solta o botão', (tester) async {
    await _abrir(tester);

    await _preencherEEntrar(tester, senha: 'errada123');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Email ou senha incorretos'), findsOneWidget);
    expect(find.text('Fazer Login'), findsOneWidget);
    expect(find.text('ana@email.com'), findsOneWidget);
    // A falha vai para o alerta, não para o estado da sessão (que também trocaria a tela)
    final sessao = ProviderScope.containerOf(tester.element(find.byType(LoginScreen))).read(authProvider);
    expect(sessao.hasError, isFalse);
    expect(sessao.isLoading, isFalse);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('sem internet: alerta de conexão', (tester) async {
    final servidor = await _abrir(tester);
    servidor.falhaDeRede = DioException(
      requestOptions: RequestOptions(path: '/'),
      type: DioExceptionType.connectionError,
    );

    await _preencherEEntrar(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('Fazer Login'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 5));
  });

  testWidgets('e-mail inválido nem chega ao servidor', (tester) async {
    final servidor = await _abrir(tester);

    await _preencherEEntrar(tester, email: 'sem-arroba');
    await tester.pump();

    expect(find.text('Email inválido'), findsOneWidget);
    expect(servidor.pedidos, isEmpty);
  });
}
