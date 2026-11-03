import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/screens/auth/esqueci_senha_screen.dart';
import 'package:pulyn_app/screens/auth/confirmar_cadastro_screen.dart';
import 'package:pulyn_app/screens/auth/register_screen.dart';
import 'package:pulyn_app/screens/legal/politica_privacidade_screen.dart';
import 'package:pulyn_app/screens/profile/confirmar_email_screen.dart';

void main() {
  final telas = <String, Widget>{
    'esqueci senha': const EsqueciSenhaScreen(),
    'confirmar e-mail': const ConfirmarEmailScreen(),
    'cadastro': const RegisterScreen(),
    'politica': const PoliticaPrivacidadeScreen(),
    'confirmar cadastro': const ConfirmarCadastroScreen(email: 'familia.exemplo@gmail.com'),
  };
  for (final entrada in telas.entries) {
    for (final tamanho in [const Size(320, 640), const Size(360, 740)]) {
      testWidgets('${entrada.key} cabe em ${tamanho.width.toInt()}x${tamanho.height.toInt()}', (tester) async {
        tester.view.physicalSize = tamanho;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        await tester.pumpWidget(ProviderScope(
          child: MaterialApp(theme: ThemeData.dark(), home: entrada.value),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
