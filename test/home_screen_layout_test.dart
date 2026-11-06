import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/config/theme.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/screens/family/pre_register_child_screen.dart';
import 'package:pulyn_app/screens/home/home_screen.dart';

// Em outro evento que o ativo ('e1'): o mapa mostra só o aviso vazio (sem WebSocket nem polling
// no teste), e a lista "Seus Filhos" com o botão Vincular continua sendo desenhada.
Child _crianca() => Child(
      id: 'c1',
      eventoId: 'e2',
      nome: 'Lia',
      apelido: 'Lia',
      idade: 7,
      currentScore: 0,
      totalScore: 0,
      teamId: 't',
      teamName: 'T',
      teamColor: '#1E9BD7',
      rank: 1,
      achievements: const [],
    );

/// A home tem que desenhar sem erro de layout. O tema dá largura infinita aos botões
/// (Size.fromHeight): um botão solto numa Row quebrava o layout e o corpo da home ficava em branco
/// (em release o erro não aparece, só some o conteúdo).
void main() {
  Future<void> abreHome(WidgetTester tester, List<Child> filhos) async {
    tester.view.physicalSize = const Size(1500, 2400);
    tester.view.devicePixelRatio = 3.0; // 500 x 800 lógicos: folga para a fonte larga dos testes
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        // Sem rede e sem polling (os timers de 5/10 s deixariam o teste pendurado)
        childrenProvider.overrideWith((ref) => Stream.value(filhos)),
        childrenRankingProvider.overrideWith((ref) => Stream.value(filhos)),
        activeEventProvider.overrideWith((ref) => Stream.value({'id': 'e1', 'nome': 'Festa'})),
        activeGameProvider.overrideWith((ref) => Stream.value(null)),
        familyEventsProvider.overrideWith((ref) async => [
              {'id': 'e1', 'nome': 'Festa'},
            ]),
        preRegisteredChildrenProvider.overrideWith((ref) async => []),
        zonesProvider.overrideWith((ref) async => []),
      ],
      child: MaterialApp(theme: construirTema(), home: const HomeScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('com criança vinculada: a lista "Seus Filhos" e o botão Vincular aparecem', (tester) async {
    await abreHome(tester, [_crianca()]);

    expect(tester.takeException(), isNull);
    expect(find.text('Seus Filhos'), findsOneWidget);
    expect(find.text('Vincular'), findsOneWidget);
  });

  testWidgets('sem criança: a home desenha o vínculo sem erro', (tester) async {
    await abreHome(tester, const []);

    expect(tester.takeException(), isNull);
    expect(find.text('Meus eventos'), findsOneWidget);
  });
}
