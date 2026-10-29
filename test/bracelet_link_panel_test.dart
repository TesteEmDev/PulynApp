import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/services/api_service.dart';
import 'package:pulyn_app/services/nfc_reader.dart';
import 'package:pulyn_app/widgets/bracelet_link_panel.dart';
import 'package:pulyn_app/widgets/qr_link_panel.dart';

/// Leitor de NFC falso: sem aparelho, sem sessão do sistema.
class _FakeReader implements NfcReader {
  final NfcSupport supportValue;
  final List<Completer<String>> reads = [];
  int cancelCalls = 0;

  _FakeReader({this.supportValue = NfcSupport.enabled});

  @override
  Future<NfcSupport> support() async => supportValue;

  @override
  Future<String> readBraceletUid() {
    final completer = Completer<String>();
    reads.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancel() async => cancelCalls++;
}

/// ApiService falso que anota para qual evento a pulseira foi mandada.
class _FakeApi extends ApiService {
  final List<({String uid, String? eventoId})> chamadas = [];
  final List<Map<String, dynamic>> eventosDaConta;
  _FakeApi({this.eventosDaConta = const []});

  @override
  Future<void> init() async {}

  @override
  Future<List<Map<String, dynamic>>> getFamilyEvents() async => eventosDaConta;

  @override
  Future<Map<String, dynamic>> linkChildWithBracelet(String uid, {String? eventoId}) async {
    chamadas.add((uid: uid, eventoId: eventoId));
    return _linked;
  }
}

const _linked = <String, dynamic>{
  'success': true,
  'linkedChild': {'id': 'c1', 'nome': 'Lia Souza', 'apelido': 'Lia', 'idade': 6, 'evento': 'Festa da Lia'},
};

Widget _wrap(Widget child) => MaterialApp(
      theme: appTheme,
      home: Scaffold(body: SingleChildScrollView(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  group('uidToHex', () {
    test('NTAG213 (7 bytes) vira 14 caracteres hexadecimais em maiúsculas', () {
      expect(uidToHex([0x04, 0xE7, 0x2C, 0x1A, 0x89, 0x68, 0x80]), '04E72C1A896880');
    });

    test('mantém o zero à esquerda de cada byte', () {
      expect(uidToHex([0x00, 0x0A, 0x01]), '000A01');
    });

    test('byte negativo (vindo do Android) é tratado como sem sinal', () {
      expect(uidToHex([-1, -128]), 'FF80');
    });
  });

  group('BraceletLinkPanel: evento do vínculo', () {
    /// Abre o painel de verdade (sem `linkChild` de teste) dentro de um ProviderScope e lê uma pulseira.
    Future<void> lerPulseira(WidgetTester tester, _FakeApi api, {String? eventoEscolhido, String? eventoDoPainel}) async {
      final reader = _FakeReader();
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          if (eventoEscolhido != null) selectedEventIdProvider.overrideWith((ref) => eventoEscolhido),
        ],
        child: _wrap(BraceletLinkPanel(reader: reader, eventoId: eventoDoPainel)),
      ));
      await tester.pump();
      await tester.tap(find.text('Ler pulseira'));
      await tester.pump();
      reader.reads.single.complete('04E72C1A896880');
      await tester.pumpAndSettle();
    }

    testWidgets('manda o evento escolhido no app junto com a pulseira', (tester) async {
      final api = _FakeApi(eventosDaConta: [
        {'id': 'e1', 'nome': 'Festa A'},
        {'id': 'e2', 'nome': 'Festa B'},
      ]);
      await lerPulseira(tester, api, eventoEscolhido: 'e2');

      expect(api.chamadas, [(uid: '04E72C1A896880', eventoId: 'e2')]);
    });

    testWidgets('sem evento escolhido e com um único evento na conta, é esse', (tester) async {
      final api = _FakeApi(eventosDaConta: [
        {'id': 'e1', 'nome': 'Festa A'},
      ]);
      await lerPulseira(tester, api);

      expect(api.chamadas.single.eventoId, 'e1');
    });

    testWidgets('sem evento escolhido e com vários eventos, não chuta: segue o comportamento antigo', (tester) async {
      final api = _FakeApi(eventosDaConta: [
        {'id': 'e1', 'nome': 'Festa A'},
        {'id': 'e2', 'nome': 'Festa B'},
      ]);
      await lerPulseira(tester, api);

      expect(api.chamadas.single.eventoId, isNull);
    });

    testWidgets('o evento informado ao painel vale mais que o escolhido', (tester) async {
      final api = _FakeApi();
      await lerPulseira(tester, api, eventoEscolhido: 'e2', eventoDoPainel: 'e9');

      expect(api.chamadas.single.eventoId, 'e9');
    });
  });

  group('BraceletLinkPanel', () {
    testWidgets('lê a pulseira, envia o UID e confirma a criança vinculada', (tester) async {
      final reader = _FakeReader();
      final sent = <String>[];
      Child? linkedChild;

      await tester.pumpWidget(_wrap(BraceletLinkPanel(
        reader: reader,
        linkChild: (uid) async {
          sent.add(uid);
          return _linked;
        },
        onLinked: (child) => linkedChild = child,
      )));
      await tester.pump();

      expect(reader.reads, isEmpty, reason: 'não lê sozinho ao abrir (a câmera do QR pode estar fechando)');
      await tester.tap(find.text('Ler pulseira'));
      await tester.pump();
      expect(find.text('Encoste a pulseira atrás do celular...'), findsOneWidget);

      reader.reads.single.complete('04E72C1A896880');
      await tester.pump();
      await tester.pump();

      expect(sent, ['04E72C1A896880']);
      expect(find.text('Criança vinculada!'), findsOneWidget);
      expect(find.text('Lia · 6 anos · Festa da Lia'), findsOneWidget);
      expect(linkedChild?.id, 'c1');
    });

    testWidgets('com autoStart já começa a ler ao abrir, sem toque', (tester) async {
      final reader = _FakeReader();

      await tester.pumpWidget(_wrap(BraceletLinkPanel(reader: reader, autoStart: true)));
      await tester.pump();

      expect(reader.reads, hasLength(1));
      expect(find.text('Encoste a pulseira atrás do celular...'), findsOneWidget);
    });

    testWidgets('erro do servidor aparece na tela e permite tentar de novo', (tester) async {
      final reader = _FakeReader();
      var calls = 0;

      await tester.pumpWidget(_wrap(BraceletLinkPanel(
        reader: reader,
        linkChild: (uid) async {
          calls++;
          if (calls == 1) throw Exception('Pulseira não encontrada ou sem criança vinculada neste evento.');
          return _linked;
        },
      )));
      await tester.pump();
      await tester.tap(find.text('Ler pulseira'));
      await tester.pump();

      reader.reads.single.complete('04E72C1A896880');
      await tester.pump();
      await tester.pump();

      expect(find.text('Pulseira não encontrada ou sem criança vinculada neste evento.'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      expect(reader.reads, hasLength(2), reason: 'abre uma nova leitura');

      reader.reads.last.complete('04E72C1A896880');
      await tester.pump();
      await tester.pump();
      expect(find.text('Criança vinculada!'), findsOneWidget);
    });

    testWidgets('celular sem NFC: explica e oferece o QR Code', (tester) async {
      var usedQr = false;

      await tester.pumpWidget(_wrap(BraceletLinkPanel(
        reader: _FakeReader(supportValue: NfcSupport.unsupported),
        onUseQr: () => usedQr = true,
      )));
      await tester.pump();

      expect(find.text('Este celular não lê pulseiras'), findsOneWidget);
      await tester.tap(find.text('Usar o QR Code'));
      expect(usedQr, isTrue);
    });

    testWidgets('NFC desligado: orienta a ligar e permite tentar de novo', (tester) async {
      await tester.pumpWidget(_wrap(BraceletLinkPanel(
        reader: _FakeReader(supportValue: NfcSupport.disabled),
      )));
      await tester.pump();

      expect(find.text('O NFC está desligado'), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('cancelar a leitura (iPhone) volta ao botão, sem mostrar erro', (tester) async {
      final reader = _FakeReader();

      await tester.pumpWidget(_wrap(BraceletLinkPanel(reader: reader)));
      await tester.pump();
      await tester.tap(find.text('Ler pulseira'));
      await tester.pump();

      reader.reads.single.completeError(const NfcReadException('Leitura cancelada.', cancelled: true));
      await tester.pump();
      await tester.pump();

      expect(find.text('Encoste a pulseira'), findsOneWidget);
      expect(find.text('Ler pulseira'), findsOneWidget);
      expect(find.text('Leitura cancelada.'), findsNothing);
    });

    testWidgets('ao sair da tela encerra a leitura do sistema', (tester) async {
      final reader = _FakeReader();

      await tester.pumpWidget(_wrap(BraceletLinkPanel(reader: reader)));
      await tester.pump();
      await tester.pumpWidget(_wrap(const SizedBox()));

      expect(reader.cancelCalls, greaterThan(0));
    });
  });

  group('QrLinkPanel com a opção da pulseira', () {
    testWidgets('celular com NFC mostra "Usar a pulseira (NFC)" e troca para a leitura da pulseira', (tester) async {
      final reader = _FakeReader();
      final sent = <String>[];

      await tester.pumpWidget(_wrap(QrLinkPanel(
        permissionStatus: () async => PermissionStatus.granted,
        nfcReader: reader,
        cameraBuilder: (context, onCode) => const SizedBox(height: 10),
        linkBracelet: (uid) async {
          sent.add(uid);
          return _linked;
        },
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text('Usar a pulseira (NFC)'), findsOneWidget);

      await tester.tap(find.text('Usar a pulseira (NFC)'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Vincular com a pulseira'), findsOneWidget);
      await tester.tap(find.text('Ler pulseira'));
      await tester.pump();

      reader.reads.single.complete('04E72C1A896880');
      await tester.pump();
      await tester.pump();
      expect(sent, ['04E72C1A896880']);
      expect(find.text('Criança vinculada!'), findsOneWidget);
    });

    testWidgets('celular sem NFC não mostra a opção da pulseira', (tester) async {
      await tester.pumpWidget(_wrap(QrLinkPanel(
        permissionStatus: () async => PermissionStatus.granted,
        nfcReader: _FakeReader(supportValue: NfcSupport.unsupported),
        cameraBuilder: (context, onCode) => const SizedBox(height: 10),
      )));
      await tester.pump();
      await tester.pump();

      expect(find.text('Usar a pulseira (NFC)'), findsNothing);
    });
  });
}
