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
}
