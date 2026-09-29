import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/widgets/link_child_hero.dart';

void main() {
  testWidgets('explica o próximo passo e o botão dispara o scanner', (tester) async {
    var scans = 0;
    await tester.pumpWidget(MaterialApp(
      theme: appTheme,
      home: Scaffold(body: SingleChildScrollView(child: LinkChildHero(onScan: () => scans++))),
    ));

    expect(find.text('Vincule seu filho'), findsOneWidget);
    expect(find.textContaining('QR Code na recepção'), findsOneWidget);

    await tester.tap(find.text('Escanear QR Code'));
    expect(scans, 1);
  });
}
