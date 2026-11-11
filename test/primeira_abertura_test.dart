import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/main.dart';
import 'package:pulyn_app/screens/auth/login_screen.dart';
import 'package:pulyn_app/screens/onboarding/onboarding_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Primeira abertura do app (sem sessão): a leitura "é a primeira vez?" grava no disco antes de
/// responder, então costuma terminar DEPOIS de a sessão ficar pronta. O app precisa terminar
/// no onboarding, e não numa tela vazia, sem passar pelo login no meio do caminho.
void main() {
  Future<void> abrirApp(WidgetTester tester, {required Duration demoraPrimeiraVez}) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isFirstTimeProvider.overrideWith((ref) async {
            await Future<void>.delayed(demoraPrimeiraVez);
            return true;
          }),
        ],
        child: const MyApp(),
      ),
    );
    // O splash tem um indicador girando, então pumpAndSettle nunca assentaria.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets('primeira abertura com leitura lenta: termina no onboarding', (tester) async {
    await abrirApp(tester, demoraPrimeiraVez: const Duration(milliseconds: 300));

    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('primeira abertura com leitura rápida: termina no onboarding', (tester) async {
    await abrirApp(tester, demoraPrimeiraVez: Duration.zero);

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('a tela de login não aparece nem por um instante antes do onboarding', (tester) async {
    SharedPreferences.setMockInitialValues({});
    var loginApareceu = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isFirstTimeProvider.overrideWith((ref) async {
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return true;
          }),
        ],
        child: const MyApp(),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      if (find.byType(LoginScreen).evaluate().isNotEmpty) loginApareceu = true;
    }

    expect(loginApareceu, isFalse);
  });
}
