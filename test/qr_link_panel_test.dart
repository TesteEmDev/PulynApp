import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/widgets/qr_link_panel.dart';

const _okResponse = <String, dynamic>{
  'success': true,
  'linkedChild': {'id': 'c1', 'name': 'Lia Souza', 'nickname': 'Lia', 'age': 7, 'evento': 'Festa da Lia'},
};

void main() {
  /// Sobe o painel com permissão, câmera e rede simuladas. [emit] simula a câmera lendo um QR.
  Future<({void Function(String) emit, List<Child> linked, List<String> requests, List<int> counters})> pumpPanel(
    WidgetTester tester, {
    PermissionStatus status = PermissionStatus.granted,
    List<PermissionStatus> requestResults = const [PermissionStatus.granted],
    Future<Map<String, dynamic>> Function(String)? link,
    VoidCallback? onClose,
    Future<bool> Function()? openSettings,
  }) async {
    void Function(String)? emit;
    final linked = <Child>[];
    final requests = <String>[]; // códigos enviados para vincular
    final counters = <int>[0]; // [0] = quantas vezes a permissão foi pedida
    var requestIndex = 0;

    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: Scaffold(
        body: SingleChildScrollView(
          child: QrLinkPanel(
            onLinked: linked.add,
            onClose: onClose,
            permissionStatus: () async => status,
            requestPermission: () async {
              counters[0]++;
              final i = requestIndex < requestResults.length ? requestIndex : requestResults.length - 1;
              requestIndex++;
              return requestResults[i];
            },
            openSettings: openSettings,
            linkChild: (code) {
              requests.add(code);
              return (link ?? (_) async => _okResponse)(code);
            },
            cameraBuilder: (context, onCode) {
              emit = onCode;
              return const ColoredBox(color: Colors.black, child: Center(child: Text('CÂMERA')));
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    return (emit: (code) => emit!(code), linked: linked, requests: requests, counters: counters);
  }

  group('permissão da câmera', () {
    testWidgets('já pede a câmera ao abrir, sem botão "Abrir Câmera" no meio', (tester) async {
      final p = await pumpPanel(tester, status: PermissionStatus.denied, requestResults: [PermissionStatus.granted]);

      expect(p.counters[0], 1);
      expect(find.text('CÂMERA'), findsOneWidget);
      expect(find.text('Abrir Câmera'), findsNothing);
      expect(find.text('Aponte a câmera para o QR Code'), findsOneWidget);
    });

    testWidgets('com a permissão já dada não pede de novo', (tester) async {
      final p = await pumpPanel(tester, status: PermissionStatus.granted);

      expect(p.counters[0], 0);
      expect(find.text('CÂMERA'), findsOneWidget);
    });

    testWidgets('negada: explica e deixa pedir de novo dentro do próprio painel', (tester) async {
      final p = await pumpPanel(
        tester,
        status: PermissionStatus.denied,
        requestResults: [PermissionStatus.denied, PermissionStatus.granted],
      );

      expect(find.text('Precisamos da câmera'), findsOneWidget);
      expect(find.text('CÂMERA'), findsNothing);

      await tester.tap(find.text('Permitir câmera'));
      await tester.pumpAndSettle();

      expect(p.counters[0], 2);
      expect(find.text('CÂMERA'), findsOneWidget);
    });

    testWidgets('negada de vez: manda para as configurações e dá para tentar de novo ao voltar', (tester) async {
      var openedSettings = 0;
      final p = await pumpPanel(
        tester,
        status: PermissionStatus.permanentlyDenied,
        requestResults: [PermissionStatus.permanentlyDenied],
        openSettings: () async {
          openedSettings++;
          return true;
        },
      );

      expect(find.textContaining('Ative nas configurações'), findsOneWidget);
      expect(find.text('Permitir câmera'), findsNothing);

      await tester.tap(find.text('Abrir configurações'));
      expect(openedSettings, 1);
      expect(find.text('Já permiti, tentar de novo'), findsOneWidget);
      expect(p.counters[0], 1);
    });
  });

  group('vincular', () {
    testWidgets('lê o QR, valida e confirma no próprio painel', (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final p = await pumpPanel(tester, link: (_) => completer.future);

      p.emit('PULYN-ABC123');
      await tester.pump();
      expect(find.text('Validando QR Code...'), findsOneWidget);
      expect(find.text('CÂMERA'), findsNothing);

      completer.complete(_okResponse);
      await tester.pumpAndSettle();

      expect(p.requests, ['PULYN-ABC123']);
      expect(find.text('Criança vinculada!'), findsOneWidget);
      expect(find.text('Lia · 7 anos · Festa da Lia'), findsOneWidget);
      expect(p.linked, hasLength(1));
      expect(p.linked.single.id, 'c1');
      expect(p.linked.single.apelido, 'Lia');
    });

    testWidgets('leituras repetidas do mesmo QR enquanto valida não vinculam duas vezes', (tester) async {
      final completer = Completer<Map<String, dynamic>>();
      final p = await pumpPanel(tester, link: (_) => completer.future);

      p.emit('PULYN-ABC123');
      p.emit('PULYN-ABC123');
      p.emit('PULYN-OUTRO');
      await tester.pump();
      completer.complete(_okResponse);
      await tester.pumpAndSettle();

      expect(p.requests, ['PULYN-ABC123']);
      expect(p.linked, hasLength(1));
    });

    testWidgets('erro do servidor mostra a mensagem e deixa tentar de novo', (tester) async {
      var attempt = 0;
      final p = await pumpPanel(tester, link: (_) async {
        attempt++;
        if (attempt == 1) throw Exception('Código QR inválido ou expirado');
        return _okResponse;
      });

      p.emit('PULYN-RUIM');
      await tester.pumpAndSettle();

      expect(find.text('Código QR inválido ou expirado'), findsOneWidget); // sem o prefixo "Exception:"
      expect(p.linked, isEmpty);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pumpAndSettle();
      expect(find.text('CÂMERA'), findsOneWidget);

      p.emit('PULYN-BOM');
      await tester.pumpAndSettle();
      expect(find.text('Criança vinculada!'), findsOneWidget);
      expect(p.linked, hasLength(1));
    });

    testWidgets('resposta sem os dados da criança é tratada como erro', (tester) async {
      final p = await pumpPanel(tester, link: (_) async => {'success': true});

      p.emit('PULYN-X');
      await tester.pumpAndSettle();

      expect(find.text('Criança vinculada!'), findsNothing);
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(p.linked, isEmpty);
    });

    testWidgets('"Vincular outra criança" volta para a câmera', (tester) async {
      final p = await pumpPanel(tester);

      p.emit('PULYN-1');
      await tester.pumpAndSettle();
      expect(find.text('Criança vinculada!'), findsOneWidget);

      await tester.tap(find.text('Vincular outra criança'));
      await tester.pumpAndSettle();
      expect(find.text('CÂMERA'), findsOneWidget);

      p.emit('PULYN-2');
      await tester.pumpAndSettle();
      expect(p.requests, ['PULYN-1', 'PULYN-2']);
      expect(p.linked, hasLength(2));
    });
  });

  testWidgets('X, Cancelar e Concluir fecham o painel', (tester) async {
    var closes = 0;
    final p = await pumpPanel(tester, onClose: () => closes++);

    await tester.tap(find.byTooltip('Fechar'));
    await tester.tap(find.text('Cancelar'));
    expect(closes, 2);

    p.emit('PULYN-1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluir'));
    expect(closes, 3);
  });

  test('childFromLinkedChild converte a resposta do backend', () {
    final child = childFromLinkedChild({'id': 'c9', 'nome': 'Davi Lima', 'apelido': 'Davi', 'idade': 9, 'evento': 'Festa'});
    expect(child.id, 'c9');
    expect(child.idade, 9);
    expect(child.teamName, 'Festa');

    final vazio = childFromLinkedChild({});
    expect(vazio.id, '');
    expect(vazio.idade, 0);
    expect(vazio.teamName, 'Sem time');
  });
}
