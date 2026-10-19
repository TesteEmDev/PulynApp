import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';

import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/services/nfc_reader.dart';
import 'package:pulyn_app/widgets/link_child_hero.dart';

/// Leitor de NFC falso: sem aparelho, sem sessão do sistema.
class _FakeNfc implements NfcReader {
  final NfcSupport supportValue;
  final List<Completer<String>> reads = [];

  _FakeNfc(this.supportValue);

  @override
  Future<NfcSupport> support() async => supportValue;

  @override
  Future<String> readBraceletUid() {
    final completer = Completer<String>();
    reads.add(completer);
    return completer.future;
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  Widget host(Widget hero) => MaterialApp(
        theme: appTheme,
        home: Scaffold(body: SingleChildScrollView(child: hero)),
      );

  testWidgets('explica o próximo passo antes de abrir o leitor', (tester) async {
    await tester.pumpWidget(host(const LinkChildHero()));

    expect(find.text('Vincule seu filho'), findsOneWidget);
    expect(find.textContaining('QR Code na recepção'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsOneWidget);
  });

  testWidgets('tocar em "Escanear QR Code" abre o leitor DENTRO do cartão, sem trocar de tela', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(
      panelBuilder: (context, close) => Column(
        children: [
          const Text('LEITOR AQUI'),
          TextButton(onPressed: close, child: const Text('fechar leitor')),
        ],
      ),
    )));

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    // O leitor aparece no lugar da explicação, na mesma tela (o cartão continua o mesmo widget)
    expect(find.text('LEITOR AQUI'), findsOneWidget);
    expect(find.byType(LinkChildHero), findsOneWidget);
    expect(find.text('Vincule seu filho'), findsNothing);
    expect(find.byType(Navigator), findsOneWidget); // nenhuma rota/janela nova foi empilhada
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('fechar o leitor volta para a explicação', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(
      panelBuilder: (context, close) => TextButton(onPressed: close, child: const Text('fechar leitor')),
    )));

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('fechar leitor'));
    await tester.pumpAndSettle();

    expect(find.text('Vincule seu filho'), findsOneWidget);
    expect(find.text('fechar leitor'), findsNothing);
  });

  testWidgets('celular com NFC mostra "ou escaneie com NFC" e o botão embaixo do QR', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(nfcReader: _FakeNfc(NfcSupport.enabled))));
    await tester.pumpAndSettle();

    expect(find.text('ou escaneie com NFC'), findsOneWidget);
    expect(find.text('Escanear com NFC'), findsOneWidget);
  });

  testWidgets('celular sem NFC não mostra a opção de NFC', (tester) async {
    await tester.pumpWidget(host(LinkChildHero(nfcReader: _FakeNfc(NfcSupport.unsupported))));
    await tester.pumpAndSettle();

    expect(find.text('ou escaneie com NFC'), findsNothing);
    expect(find.text('Escanear com NFC'), findsNothing);
  });

  testWidgets('"Escanear com NFC" abre a leitura da pulseira dentro do cartão e já começa a ler', (tester) async {
    final reader = _FakeNfc(NfcSupport.enabled);
    await tester.pumpWidget(host(LinkChildHero(nfcReader: reader)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Escanear com NFC'));
    await tester.pumpAndSettle();

    expect(find.text('Vincular com a pulseira'), findsOneWidget);
    expect(find.text('Encoste a pulseira atrás do celular...'), findsOneWidget);
    expect(find.text('Vincule seu filho'), findsNothing);
    expect(reader.reads, hasLength(1), reason: 'já começa a ler ao abrir, sem outro toque');
  });
}
