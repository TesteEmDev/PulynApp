import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/widgets/event_map_widget.dart';

/// Reproduz a estrutura da home (PageView de abas > rolagem vertical > mapa) e
/// confere que arrastar o mapa não rola a página nem troca de aba — o motivo
/// de mover o mapa parecer "travado".
void main() {
  final child = Child(
    id: 'c1',
    name: 'Lia Souza',
    nickname: 'Lia',
    age: 7,
    currentScore: 0,
    totalScore: 0,
    teamId: 't1',
    teamName: 'Time Azul',
    teamColor: '#1E9BD7',
    rank: 1,
    achievements: const [],
  );

  /// [lockWhileTouchingMap]=false reproduz o comportamento antigo (a tela não
  /// trava a própria rolagem); true é como a HomeScreen se comporta agora.
  Widget harness({
    required bool lockWhileTouchingMap,
    required ScrollController scroll,
    required PageController pages,
  }) {
    return ProviderScope(
      overrides: [
        activeEventProvider.overrideWith((ref) => Stream.value({'id': 'e1'})),
        checkpointsByEventProvider.overrideWith((ref, id) async => [
              {'id': 'cp1', 'name': 'Torre', 'zone': 'Entrada', 'points': 10, 'status': 'online', 'map_x': 200, 'map_y': 150},
            ]),
        zonesByEventProvider.overrideWith((ref, id) async => <Map<String, dynamic>>[]),
        mapChildrenRealtimeProvider.overrideWith((ref) => Stream.value([child])),
        childLastCheckpointProvider.overrideWith((ref) => {}),
      ],
      child: MaterialApp(
        home: _Page(
          lockWhileTouchingMap: lockWhileTouchingMap,
          scroll: scroll,
          pages: pages,
          map: (onInteractionChanged) => EventMapWidget(
            childrenList: [child],
            onInteractionChanged: onInteractionChanged,
          ),
        ),
      ),
    );
  }

  Future<void> load(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 50));
  }

  Future<void> animate(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  /// Arrasto como num celular: entre o toque e os movimentos passam quadros
  /// (o tester.drag padrão manda tudo sem desenhar nenhum quadro).
  Future<void> dragLikeAFinger(WidgetTester tester, Offset from, Offset delta) async {
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 16));
    const steps = 10;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(delta / steps.toDouble());
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 50));
  }

  double mapTranslate(WidgetTester tester, int row) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.entry(row, 3);

  Future<({ScrollController scroll, PageController pages})> start(WidgetTester tester, {required bool lock}) async {
    final scroll = ScrollController();
    final pages = PageController();
    addTearDown(scroll.dispose);
    addTearDown(pages.dispose);
    await tester.pumpWidget(harness(lockWhileTouchingMap: lock, scroll: scroll, pages: pages));
    await load(tester);
    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    return (scroll: scroll, pages: pages);
  }

  testWidgets('SEM o bloqueio: arrastar o mapa rola a página (o problema original)', (tester) async {
    final s = await start(tester, lock: false);

    await dragLikeAFinger(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(0, -150));

    expect(s.scroll.offset, greaterThan(0), reason: 'a página roubou o arrasto vertical');
  });

  testWidgets('arrastar o mapa na vertical move o mapa e não rola a página', (tester) async {
    final s = await start(tester, lock: true);
    final tyBefore = mapTranslate(tester, 1);

    await dragLikeAFinger(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(0, -150));

    expect(s.scroll.offset, 0, reason: 'a página não deve rolar enquanto o dedo está no mapa');
    expect(mapTranslate(tester, 1), lessThan(tyBefore), reason: 'o mapa deve acompanhar o dedo');
  });

  testWidgets('arrastar o mapa na horizontal move o mapa e não troca de aba', (tester) async {
    final s = await start(tester, lock: true);
    final txBefore = mapTranslate(tester, 0);

    await dragLikeAFinger(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(-150, 0));
    await tester.pump(const Duration(milliseconds: 300));

    expect(s.pages.page, 0, reason: 'não deve trocar de aba ao arrastar o mapa');
    expect(mapTranslate(tester, 0), lessThan(txBefore));
  });

  testWidgets('a rolagem e a troca de aba voltam ao normal depois de soltar o dedo do mapa', (tester) async {
    final s = await start(tester, lock: true);

    await dragLikeAFinger(tester, tester.getCenter(find.byType(InteractiveViewer)), const Offset(0, -20));

    // Agora arrasta fora do mapa (na faixa acima dele): a página rola
    await dragLikeAFinger(tester, const Offset(200, 20), const Offset(0, -200));
    expect(s.scroll.offset, greaterThan(0));

    // E o deslize entre abas também volta a funcionar (fora do mapa, que subiu com a rolagem)
    await dragLikeAFinger(tester, const Offset(200, 700), const Offset(-300, 0));
    await tester.pump(const Duration(milliseconds: 600)); // termina a animação de troca de página
    expect(s.pages.page, greaterThan(0));
  });
}

/// Imita a HomeScreen: trava a rolagem enquanto o dedo está no mapa.
class _Page extends StatefulWidget {
  final bool lockWhileTouchingMap;
  final ScrollController scroll;
  final PageController pages;
  final Widget Function(ValueChanged<bool>? onInteractionChanged) map;

  const _Page({
    required this.lockWhileTouchingMap,
    required this.scroll,
    required this.pages,
    required this.map,
  });

  @override
  State<_Page> createState() => _PageState();
}

class _PageState extends State<_Page> {
  bool _mapInteracting = false;

  void _setMapInteracting(bool value) {
    if (!mounted || _mapInteracting == value) return;
    setState(() => _mapInteracting = value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: widget.pages,
        physics: _mapInteracting ? const NeverScrollableScrollPhysics() : null,
        children: [
          SingleChildScrollView(
            controller: widget.scroll,
            physics: _mapInteracting ? const NeverScrollableScrollPhysics() : null,
            child: Column(
              children: [
                const SizedBox(height: 60),
                widget.map(widget.lockWhileTouchingMap ? _setMapInteracting : null),
                const SizedBox(height: 1500),
              ],
            ),
          ),
          const Center(child: Text('Outra aba')),
        ],
      ),
    );
  }
}
