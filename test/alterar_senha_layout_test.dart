import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/screens/profile/alterar_senha_screen.dart';

void main() {
  for (final tamanho in [const Size(360, 740), const Size(320, 640), const Size(412, 915)]) {
    testWidgets('alterar senha cabe em ${tamanho.width.toInt()}x${tamanho.height.toInt()}', (tester) async {
      tester.view.physicalSize = tamanho;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: const AlterarSenhaScreen(),
        ),
      ));
      await tester.enterText(find.byType(TextFormField).at(1), 'abc123xyz!');
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
