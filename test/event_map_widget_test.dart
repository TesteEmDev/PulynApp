import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/widgets/event_map_widget.dart';

/// Testa o mapa com dados falsos (sem rede): encaixe na tela, avatar em cima
/// do checkpoint e aviso de chegada.
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

  final checkpoints = <Map<String, dynamic>>[
    {'id': 'cp1', 'name': 'Torre Encantada', 'zone': 'Entrada', 'points': 10, 'status': 'online', 'map_x': 90, 'map_y': 90},
    {'id': 'cp2', 'name': 'Caverna Misteriosa', 'zone': 'Entrada', 'points': 15, 'status': 'online', 'map_x': 330, 'map_y': 220},
  ];

  // Onde a criança está (muda durante o teste, como uma leitura de pulseira).
  final lastCheckpoint = StateProvider<Map<String, Map<String, dynamic>>>((ref) => {
        'c1': {'checkpointId': 'cp1', 'checkpointName': 'Torre Encantada'},
      });

  Widget app({ValueChanged<bool>? onInteraction}) => ProviderScope(
        overrides: [
          activeEventProvider.overrideWith((ref) => Stream.value({'id': 'e1', 'name': 'Festa'})),
          checkpointsByEventProvider.overrideWith((ref, id) async => checkpoints),
          zonesByEventProvider.overrideWith((ref, id) async => <Map<String, dynamic>>[]),
          mapChildrenRealtimeProvider.overrideWith((ref) => Stream.value([child])),
          childLastCheckpointProvider.overrideWith((ref) => ref.watch(lastCheckpoint)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: EventMapWidget(
                childrenList: [child],
                activeGame: const {'gameName': 'Caça ao Tesouro'},
                onInteractionChanged: onInteraction,
              ),
            ),
          ),
        ),
      );

  // O mapa tem animações infinitas (pulso), então pumpAndSettle nunca termina.
  Future<void> settle(WidgetTester tester, [int ms = 300]) async {
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(Duration(milliseconds: ms));
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('encaixa o mapa na tela e mostra avatar, nome e selo do jogo', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await settle(tester, 500);

    // Antes o mapa abria cortado em telas estreitas; agora encaixa (escala < 1 no celular)
    final viewer = tester.widget<InteractiveViewer>(find.byType(InteractiveViewer));
    // entry(0, 0) = escala em X (getMaxScaleOnAxis também conta o eixo Z, que é sempre 1)
    final scale = viewer.transformationController!.value.entry(0, 0);
    expect(scale, lessThan(1.0));
    expect(scale, greaterThan(0.5));

    expect(find.text('Lia'), findsOneWidget); // nome acima do avatar
    expect(find.text('Caça ao Tesouro'), findsOneWidget); // selo único (não repete no subtítulo)
    expect(find.text('Mapa do Evento'), findsOneWidget);
    expect(find.text('Torre Encantada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('avatar fica centralizado em cima do checkpoint', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await settle(tester, 500);

    // O nome do avatar e o rótulo do checkpoint são centralizados no mesmo x
    final avatarX = tester.getCenter(find.text('Lia')).dx;
    final checkpointX = tester.getCenter(find.text('Torre Encantada')).dx;
    expect((avatarX - checkpointX).abs(), lessThan(1.0));
  });

  testWidgets('leitura em outro checkpoint move o avatar e mostra o aviso de chegada', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await settle(tester, 500);
    final before = tester.getCenter(find.text('Lia'));
    expect(find.textContaining('chegou em'), findsNothing); // 1ª posição não gera aviso

    // Pulseira lida no checkpoint 2
    final container = ProviderScope.containerOf(tester.element(find.byType(EventMapWidget)));
    container.read(lastCheckpoint.notifier).state = {
      'c1': {'checkpointId': 'cp2', 'checkpointName': 'Caverna Misteriosa'},
    };
    await tester.pump(); // rebuild
    await tester.pump(); // post-frame: inicia a animação
    await tester.pump(const Duration(milliseconds: 900)); // 800ms de animação

    final after = tester.getCenter(find.text('Lia'));
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
    expect((after.dx - tester.getCenter(find.text('Caverna Misteriosa')).dx).abs(), lessThan(1.0));

    // Aviso aparece e depois some sozinho
    expect(find.text('Lia chegou em Caverna Misteriosa'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('chegou em'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('toque no rótulo do checkpoint continua funcionando com o avatar em cima', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app());
    await settle(tester, 500);

    await tester.tap(find.text('Torre Encantada'));
    await tester.pump(const Duration(milliseconds: 400));

    // Abre os detalhes do checkpoint (bottom sheet) — o avatar não bloqueia mais esse toque
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  // Animações do mapa (zoom) começam no 1º quadro: pump() inicia, pump(400ms) termina.
  Future<void> animate(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
  }

  double mapScale(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.entry(0, 0);

  double mapTranslateX(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.entry(0, 3);

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  testWidgets('não mostra os pontos do checkpoint (nem no mapa nem nos detalhes)', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);

    expect(find.textContaining('pts'), findsNothing);
    expect(find.textContaining('+10'), findsNothing);

    await tester.tap(find.text('Torre Encantada'));
    await animate(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.textContaining('pts'), findsNothing);
    expect(find.byIcon(Icons.star), findsNothing);
  });

  testWidgets('botões + e − dão zoom com limite, e Centralizar volta ao encaixe', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final fit = mapScale(tester);

    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    final zoomedIn = mapScale(tester);
    expect(zoomedIn, closeTo(fit * 1.6, 0.02));

    // Não passa do zoom máximo (4x o encaixe)
    for (var i = 0; i < 6; i++) {
      await tester.tap(find.byTooltip('Aproximar'));
      await animate(tester);
    }
    expect(mapScale(tester), closeTo(fit * 4.0, 0.02));

    // Não afasta além do mapa inteiro na tela
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.byTooltip('Afastar'));
      await animate(tester);
    }
    expect(mapScale(tester), closeTo(fit, 0.01));

    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    await tester.tap(find.byTooltip('Centralizar'));
    await animate(tester);
    expect(mapScale(tester), closeTo(fit, 0.01));
    expect(tester.takeException(), isNull);
  });

  testWidgets('duplo toque aproxima e o segundo duplo toque volta ao encaixe', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final fit = mapScale(tester);

    final spot = tester.getTopLeft(find.byType(InteractiveViewer)) + const Offset(30, 30);

    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(spot);
    await animate(tester);
    expect(mapScale(tester), closeTo(fit * 2.2, 0.03));

    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tapAt(spot);
    await animate(tester);
    expect(mapScale(tester), closeTo(fit, 0.01));

    // Dois toques espaçados não contam como duplo toque
    await tester.tapAt(spot);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tapAt(spot);
    await animate(tester);
    expect(mapScale(tester), closeTo(fit, 0.01));
  });

  testWidgets('arrastar o mapa tem limite: ele não some da tela', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);

    final fit = mapScale(tester);
    // Aproxima para poder arrastar
    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    final s = mapScale(tester);
    expect(s, greaterThan(fit));

    await tester.drag(find.byType(InteractiveViewer), const Offset(3000, 0));
    await tester.pump(const Duration(milliseconds: 100));
    final tx = mapTranslateX(tester);
    expect(tx, greaterThan(0)); // arrastou de fato
    expect(tx, lessThanOrEqualTo(24 * s + 1)); // mas parou na borda + folga, sem fugir da tela

    await tester.drag(find.byType(InteractiveViewer), const Offset(-6000, 0));
    await tester.pump(const Duration(milliseconds: 100));
    final viewportWidth = tester.getSize(find.byType(InteractiveViewer)).width;
    // Borda direita do mapa nunca passa da folga dentro da tela
    expect(mapTranslateX(tester) + 450 * s, greaterThanOrEqualTo(viewportWidth - 24 * s - 1));
  });

  testWidgets('avisa a tela quando o dedo entra e sai do mapa (para travar a rolagem)', (tester) async {
    phone(tester);
    final events = <bool>[];
    await tester.pumpWidget(app(onInteraction: events.add));
    await settle(tester, 500);

    final center = tester.getCenter(find.byType(InteractiveViewer));
    final g1 = await tester.startGesture(center);
    expect(events, [true]);

    // Segundo dedo (pinça) não repete o aviso
    final g2 = await tester.startGesture(center + const Offset(40, 0), pointer: 2);
    expect(events, [true]);

    await g1.up();
    expect(events, [true]); // ainda há um dedo no mapa
    await g2.up();
    expect(events, [true, false]);
  });
}
