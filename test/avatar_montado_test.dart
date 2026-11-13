import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pulyn_app/utils/avatar_utils.dart';
import 'package:pulyn_app/widgets/avatar_imagem.dart';
import 'package:pulyn_app/widgets/child_avatar.dart';

const _montado = 'pulyn1-a1b2c3d4e5f6g7h';

void main() {
  group('isAvatarMontado', () {
    test('aceita só o formato pulyn1- + 15 letras minúsculas/dígitos', () {
      expect(isAvatarMontado(_montado), isTrue);
      expect(isAvatarMontado('pulyn1-000000000000000'), isTrue);
    });

    test('recusa o que não é um avatar montado', () {
      for (final ruim in <String?>[
        null,
        '',
        'adventurer-1787066874693',
        'pulyn1-',
        'pulyn1-a1b2c3d4e5f6g7', // curto
        'pulyn1-a1b2c3d4e5f6g7hh', // longo
        'pulyn1-A1B2C3D4E5F6G7H', // maiúsculas
        'pulyn2-a1b2c3d4e5f6g7h',
        '$_montado.png',
        '../$_montado',
        '👤',
      ]) {
        expect(isAvatarMontado(ruim), isFalse, reason: '$ruim');
      }
    });

    test('isAvatarImagem vale para o catálogo e para o montado, não para o resto', () {
      expect(isAvatarImagem(defaultAvatarId), isTrue);
      expect(isAvatarImagem(_montado), isTrue);
      expect(isAvatarImagem(null), isFalse);
      expect(isAvatarImagem('🙂'), isFalse);
      expect(isAvatarImagem('https://exemplo.com/foto.png'), isFalse);
    });
  });

  group('tamanhoDeImagemDoAvatar', () {
    test('escolhe o menor tamanho do backend que cobre os pixels da tela', () {
      expect(tamanhoDeImagemDoAvatar(34, 1.0), 64);
      expect(tamanhoDeImagemDoAvatar(34, 3.0), 128); // 102 px
      expect(tamanhoDeImagemDoAvatar(44, 3.0), 192); // 132 px
      expect(tamanhoDeImagemDoAvatar(46, 2.0), 96); // 92 px
      expect(tamanhoDeImagemDoAvatar(64, 3.0), 192); // 192 px: exatamente
      expect(tamanhoDeImagemDoAvatar(80, 3.0), 256); // 240 px
    });

    test('nunca passa do maior tamanho aceito, e todo resultado é aceito pelo backend', () {
      expect(tamanhoDeImagemDoAvatar(500, 3.0), 384);
      for (var logico = 10.0; logico <= 200; logico += 7) {
        for (final dpr in [1.0, 1.5, 2.0, 2.625, 3.0, 3.5]) {
          expect(tamanhosAvatarMontado, contains(tamanhoDeImagemDoAvatar(logico, dpr)));
        }
      }
    });
  });

  test('getAvatarMontadoUrl monta a rota de PNG do backend com o tamanho', () {
    final url = getAvatarMontadoUrl(_montado, tamanho: 192);
    expect(url, endsWith('/avatars/$_montado.png?tamanho=192'));
    expect(getAvatarMontadoUrl(_montado), endsWith('/avatars/$_montado.png?tamanho=128'));
  });

  group('AvatarImagem', () {
    Widget app(Widget filho) => MaterialApp(home: Scaffold(body: Center(child: filho)));
    Widget inicial(BuildContext context) => const Text('L');

    testWidgets('avatar montado pede o PNG do backend no tamanho certo para a tela', (tester) async {
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(app(AvatarImagem(avatarId: _montado, tamanho: 44, fallbackBuilder: inicial)));

      final imagem = tester.widget<Image>(find.byType(Image));
      final provider = imagem.image as NetworkImage;
      expect(provider.url, endsWith('/avatars/$_montado.png?tamanho=192')); // 44 x 3 = 132 px -> 192
      expect(imagem.width, 44);
      expect(imagem.height, 44);
      expect(find.byType(SvgPicture), findsNothing);
    });

    testWidgets('avatar do catálogo continua sendo o SVG', (tester) async {
      // Sem rede, o teste do Flutter devolve um corpo vazio e o flutter_svg lança "SVG inválido" de forma assíncrona.
      // No app isso cai no errorBuilder (a inicial); aqui o aviso é capturado para o teste não falhar por ele.
      final avisos = <Object>[];
      await runZonedGuarded(() async {
        await tester.pumpWidget(app(AvatarImagem(avatarId: defaultAvatarId, tamanho: 44, fallbackBuilder: inicial)));
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(Image), findsNothing);
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump();
      }, (erro, pilha) => avisos.add(erro));
    });

    testWidgets('sem avatar válido mostra o fallback e nenhuma imagem', (tester) async {
      for (final ruim in <String?>[null, '', '🙂', 'pulyn1-curto']) {
        await tester.pumpWidget(app(AvatarImagem(avatarId: ruim, tamanho: 44, fallbackBuilder: inicial)));
        expect(find.text('L'), findsOneWidget, reason: '$ruim');
        expect(find.byType(Image), findsNothing, reason: '$ruim');
        expect(find.byType(SvgPicture), findsNothing, reason: '$ruim');
      }
    });

    testWidgets('quando a imagem não carrega (rota fora do ar, 404) aparece o fallback', (tester) async {
      // O teste do Flutter responde 400 a qualquer chamada de rede: é o mesmo caminho de um 404/500 do backend.
      await tester.pumpWidget(app(AvatarImagem(avatarId: _montado, tamanho: 44, fallbackBuilder: inicial)));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      expect(find.text('L'), findsOneWidget);
    });
  });

  testWidgets('ChildAvatar com avatar montado usa o PNG; sem avatar mostra a inicial sobre a cor do time', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          ChildAvatar(avatarId: _montado, inicial: 'L', cor: Colors.blue),
          ChildAvatar(avatarId: null, inicial: 'M', cor: Colors.red),
        ]),
      ),
    ));

    expect(find.byType(Image), findsOneWidget);
    expect(find.text('M'), findsOneWidget);
  });
}
