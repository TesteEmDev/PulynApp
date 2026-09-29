import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/models/family_models.dart';
import 'package:pulyn_app/providers/index.dart';
import 'package:pulyn_app/services/api_service.dart';
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

  Widget app({
    ValueChanged<bool>? onInteraction,
    List<Map<String, dynamic>>? zones,
    List<Map<String, dynamic>>? extraCheckpoints,
    ApiService? api,
    String? eventoId,
  }) =>
      ProviderScope(
        overrides: [
          if (api != null) apiServiceProvider.overrideWithValue(api),
          activeEventProvider.overrideWith((ref) => Stream.value({'id': 'e1', 'name': 'Festa'})),
          checkpointsByEventProvider.overrideWith((ref, id) async => [...checkpoints, ...?extraCheckpoints]),
          zonesByEventProvider.overrideWith((ref, id) async => zones ?? <Map<String, dynamic>>[]),
          mapChildrenRealtimeProvider.overrideWith((ref) => Stream.value([child])),
          childLastCheckpointProvider.overrideWith((ref) => ref.watch(lastCheckpoint)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: EventMapWidget(
                childrenList: [child],
                eventoId: eventoId,
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

  double mapTranslateY(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer)).transformationController!.value.entry(1, 3);

  testWidgets('o mapa cobre toda a área visível, sem faixas cinza em volta', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);

    final viewport = tester.getSize(find.byType(InteractiveViewer));
    final scale = mapScale(tester);

    // A área do mapa tem a proporção exata do canvas 450x320…
    expect(viewport.width / viewport.height, closeTo(450 / 320, 0.01));
    // …e o mapa encaixado ocupa a área inteira: sem sobra em nenhum lado
    expect(450 * scale, closeTo(viewport.width, 1.0));
    expect(320 * scale, closeTo(viewport.height, 1.0));
    expect(mapTranslateX(tester), closeTo(0, 1.0));
    expect(mapTranslateY(tester), closeTo(0, 1.0));
  });

  testWidgets('arrastar o mapa nunca mostra o que está fora dele (borda do mapa nas bordas da área)', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final viewport = tester.getSize(find.byType(InteractiveViewer));

    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    final s = mapScale(tester);
    final txBefore = mapTranslateX(tester);

    // Puxa o mapa para a direita e para baixo: a borda esquerda/de cima do mapa para nas bordas da área
    await tester.drag(find.byType(InteractiveViewer), const Offset(3000, 3000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(mapTranslateX(tester), greaterThan(txBefore)); // arrastou de fato
    expect(mapTranslateX(tester), lessThanOrEqualTo(1.0));
    expect(mapTranslateY(tester), lessThanOrEqualTo(1.0));

    // Puxa para a esquerda e para cima: a borda direita/de baixo do mapa para nas bordas da área
    await tester.drag(find.byType(InteractiveViewer), const Offset(-6000, -6000));
    await tester.pump(const Duration(milliseconds: 100));
    expect(mapTranslateX(tester) + 450 * s, greaterThanOrEqualTo(viewport.width - 1.0));
    expect(mapTranslateY(tester) + 320 * s, greaterThanOrEqualTo(viewport.height - 1.0));
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

  testWidgets('zona que passa da borda do canvas aparece inteira (o mapa cresce para abranger)', (tester) async {
    phone(tester);
    // Zona salva pelo admin web com parte fora do canvas 450x320
    await tester.pumpWidget(app(zones: [
      {'id': 'z1', 'name': 'Zona Extra', 'color': '#22C55E', 'x': 330, 'y': 200, 'width': 300, 'height': 200},
    ]));
    await settle(tester, 500);

    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final zone = tester.getRect(find.byWidgetPredicate(
      (w) => w is Container && w.constraints == const BoxConstraints.tightFor(width: 300, height: 200),
    ));

    // Antes ela era cortada na borda do canvas; agora cabe inteira na área visível
    expect(zone.left, greaterThanOrEqualTo(viewport.left - 1));
    expect(zone.top, greaterThanOrEqualTo(viewport.top - 1));
    expect(zone.right, lessThanOrEqualTo(viewport.right + 1));
    expect(zone.bottom, lessThanOrEqualTo(viewport.bottom + 1));
    expect(viewport.contains(tester.getCenter(find.text('Zona Extra'))), isTrue);

    // O mapa cresceu (proporção maior que a do canvas) mas continua preenchendo a área toda
    expect(viewport.width / viewport.height, closeTo(632 / 402, 0.02));
    expect(mapTranslateX(tester), closeTo(0, 1.0));
    expect(mapTranslateY(tester), closeTo(0, 1.0));
  });

  testWidgets('checkpoint fora do canvas aparece e continua tocável', (tester) async {
    phone(tester);
    await tester.pumpWidget(app(extraCheckpoints: [
      {'id': 'cp3', 'name': 'Ponto Distante', 'zone': 'Entrada', 'points': 5, 'status': 'online', 'map_x': 520, 'map_y': 120},
    ]));
    await settle(tester, 500);

    final viewport = tester.getRect(find.byType(InteractiveViewer));
    expect(viewport.contains(tester.getCenter(find.text('Ponto Distante'))), isTrue);

    await tester.tap(find.text('Ponto Distante'));
    await animate(tester);
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('planta larga ocupa a altura toda, passa das laterais do canvas e o mapa a abrange inteira', (tester) async {
    phone(tester);
    // Planta 4x2 pixels (proporção 2:1), como a de um espaço largo
    await tester.pumpWidget(app(api: _FakeApi(_wideFloorPlan), eventoId: 'e1'));
    await settle(tester, 500);
    // Decodificar a imagem é assíncrono de verdade (fora do relógio simulado do teste)
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
    await settle(tester, 500);

    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final plan = tester.getRect(find.byType(Image));

    // Proporção 2:1 => 640x320 canvas-px, de x=-95 a x=545: o mapa cresceu para abranger tudo
    expect(viewport.width / viewport.height, closeTo(640 / 320, 0.03));
    // A planta aparece inteira, ocupando a área visível toda (nada dela fica de fora)
    expect(plan.left, closeTo(viewport.left, 1.5));
    expect(plan.right, closeTo(viewport.right, 1.5));
    expect(plan.top, closeTo(viewport.top, 1.5));
    expect(plan.bottom, closeTo(viewport.bottom, 1.5));
    expect(tester.takeException(), isNull);
  });

  /// Pinça com dois dedos: [from1]/[from2] vão até [to1]/[to2] em vários quadros,
  /// como num celular.
  Future<void> pinch(WidgetTester tester, Offset from1, Offset from2, Offset to1, Offset to2) async {
    final g1 = await tester.startGesture(from1, pointer: 11);
    final g2 = await tester.startGesture(from2, pointer: 12);
    await tester.pump(const Duration(milliseconds: 16));
    const steps = 12;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      await g1.moveTo(Offset.lerp(from1, to1, t)!);
      await g2.moveTo(Offset.lerp(from2, to2, t)!);
      await tester.pump(const Duration(milliseconds: 16));
    }
    await g1.up();
    await g2.up();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('afastar com os dedos (pinça) nunca passa do mapa inteiro nem mostra fundo cinza', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final fit = mapScale(tester);
    final c = viewport.center;

    // Aproxima um pouco (botão) e então pinça para afastar muito, várias vezes
    await tester.tap(find.byTooltip('Aproximar'));
    await animate(tester);
    expect(mapScale(tester), greaterThan(fit * 1.5));

    for (var i = 0; i < 3; i++) {
      await pinch(tester, c + const Offset(-90, 0), c + const Offset(90, 0), c + const Offset(-15, 0), c + const Offset(15, 0));
      expect(mapScale(tester), greaterThanOrEqualTo(fit - 0.001), reason: 'passou do zoom mínimo (pinça $i)');
    }

    // No zoom mínimo o mapa ocupa a área toda: sem sobra em nenhum lado
    final s = mapScale(tester);
    expect(450 * s, closeTo(viewport.width, 1.5));
    expect(mapTranslateX(tester), closeTo(0, 1.5));
    expect(mapTranslateY(tester), closeTo(0, 1.5));
  });

  testWidgets('pinça de afastar já no zoom mínimo não encolhe o mapa', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final fit = mapScale(tester);
    final c = viewport.center;

    await pinch(tester, c + const Offset(-90, 0), c + const Offset(90, 0), c + const Offset(-10, 0), c + const Offset(10, 0));

    expect(mapScale(tester), greaterThanOrEqualTo(fit - 0.001));
    expect(mapTranslateX(tester), closeTo(0, 1.5));
    expect(mapTranslateY(tester), closeTo(0, 1.5));
  });

  testWidgets('pinça de aproximar funciona e respeita o zoom máximo', (tester) async {
    phone(tester);
    await tester.pumpWidget(app());
    await settle(tester, 500);
    final viewport = tester.getRect(find.byType(InteractiveViewer));
    final fit = mapScale(tester);
    final c = viewport.center;

    for (var i = 0; i < 3; i++) {
      await pinch(tester, c + const Offset(-10, 0), c + const Offset(10, 0), c + const Offset(-110, 0), c + const Offset(110, 0));
    }

    expect(mapScale(tester), greaterThan(fit * 2));
    expect(mapScale(tester), lessThanOrEqualTo(fit * 4 + 0.001));
  });

  test('floorPlanRect: planta sempre com a altura do canvas, centralizada, com a proporção da imagem', () {
    // Larga (2:1): 640 de largura, passando 95px de cada lado do canvas de 450
    expect(floorPlanRect(2.0), const Rect.fromLTWH(-95, 0, 640, 320));
    // Mesma proporção do canvas: cobre exatamente o canvas
    final same = floorPlanRect(450 / 320);
    expect(same.left, closeTo(0, 0.001));
    expect(same.width, closeTo(450, 0.001));
    // Alta (1:2): mais estreita que o canvas, centralizada
    expect(floorPlanRect(0.5), const Rect.fromLTWH(145, 0, 160, 320));
    // Valores inválidos caem no canvas
    expect(floorPlanRect(0), const Rect.fromLTWH(0, 0, 450, 320));
    expect(floorPlanRect(double.nan), const Rect.fromLTWH(0, 0, 450, 320));
  });
}

/// Planta falsa: PNG 4x2 (proporção 2:1) em base64.
const _wideFloorPlan =
    'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAACCAYAAAB/qH1jAAAAEklEQVR4nGM4ceLEf2TMgC4AAMPVGrkYQwV4AAAAAElFTkSuQmCC';

class _FakeApi extends ApiService {
  final String floorPlan;
  _FakeApi(this.floorPlan);

  @override
  Future<String?> getFloorPlan(String eventoId) async => floorPlan;
}
