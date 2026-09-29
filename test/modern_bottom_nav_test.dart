import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/widgets/modern_bottom_nav.dart';

void main() {
  Widget build(int index, ValueChanged<int> onTap) => MaterialApp(
        home: Scaffold(
          bottomNavigationBar: ModernBottomNav(
            currentIndex: index,
            onTap: onTap,
            items: const [
              ModernNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Início'),
              ModernNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Ranking'),
              ModernNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
            ],
          ),
        ),
      );

  testWidgets('mostra o nome só do item selecionado', (tester) async {
    await tester.pumpWidget(build(1, (_) {}));
    await tester.pumpAndSettle();

    expect(find.text('Ranking'), findsOneWidget);
    expect(find.text('Início'), findsNothing);
    expect(find.text('Perfil'), findsNothing);
  });

  testWidgets('toque em outro item chama onTap; no item atual não', (tester) async {
    final taps = <int>[];
    await tester.pumpWidget(build(0, taps.add));
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Perfil'));
    await tester.tap(find.bySemanticsLabel('Início'));

    expect(taps, [2]);
  });

  group('botão de ação (QR Code) no meio da barra', () {
    Widget buildWithAction({ModernNavAction? action, ValueChanged<int>? onTap, int index = 0}) => MaterialApp(
          home: Scaffold(
            bottomNavigationBar: ModernBottomNav(
              currentIndex: index,
              onTap: onTap ?? (_) {},
              action: action,
              items: const [
                ModernNavItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Início'),
                ModernNavItem(icon: Icons.emoji_events_outlined, activeIcon: Icons.emoji_events, label: 'Ranking'),
                ModernNavItem(icon: Icons.person_outline, activeIcon: Icons.person, label: 'Perfil'),
              ],
            ),
          ),
        );

    const qr = 'Vincular criança com QR Code';

    testWidgets('sem ação a barra é a de sempre (nenhum botão de QR)', (tester) async {
      await tester.pumpWidget(buildWithAction());
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(qr), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner_rounded), findsNothing);
    });

    testWidgets('com ação aparece o botão e o toque chama a ação (sem trocar de aba)', (tester) async {
      var actions = 0;
      final tabs = <int>[];
      await tester.pumpWidget(buildWithAction(
        action: ModernNavAction(icon: Icons.qr_code_scanner_rounded, label: qr, onTap: () => actions++),
        onTap: tabs.add,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel(qr));
      expect(actions, 1);
      expect(tabs, isEmpty, reason: 'o QR não é uma aba');
    });

    testWidgets('as abas continuam funcionando e o índice se refere só a elas', (tester) async {
      final tabs = <int>[];
      await tester.pumpWidget(buildWithAction(
        action: ModernNavAction(icon: Icons.qr_code_scanner_rounded, label: qr, onTap: () {}),
        onTap: tabs.add,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Ranking'));
      await tester.tap(find.bySemanticsLabel('Perfil'));

      expect(tabs, [1, 2]); // Ranking = 1 e Perfil = 2, mesmo com o botão entre as abas
    });

    testWidgets('o botão fica entre o Início e o Ranking, no meio da barra', (tester) async {
      await tester.pumpWidget(buildWithAction(
        action: ModernNavAction(icon: Icons.qr_code_scanner_rounded, label: qr, onTap: () {}),
      ));
      await tester.pumpAndSettle();

      final home = tester.getCenter(find.bySemanticsLabel('Início')).dx;
      final action = tester.getCenter(find.bySemanticsLabel(qr)).dx;
      final ranking = tester.getCenter(find.bySemanticsLabel('Ranking')).dx;
      final profile = tester.getCenter(find.bySemanticsLabel('Perfil')).dx;

      expect(home, lessThan(action));
      expect(action, lessThan(ranking));
      expect(ranking, lessThan(profile));
    });

    testWidgets('cabe em tela estreita sem estourar', (tester) async {
      tester.view.physicalSize = const Size(300, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(buildWithAction(
        action: ModernNavAction(icon: Icons.qr_code_scanner_rounded, label: qr, onTap: () {}),
        index: 1,
      ));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
