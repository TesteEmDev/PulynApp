import 'package:flutter/material.dart';
import 'avatar_imagem.dart';

/// Avatar da criança: a imagem do catálogo ou do personagem montado por ela quando o cadastro tem um avatar válido,
/// senão (ou enquanto carrega, ou se falhar) a inicial do nome sobre a cor do time.
class ChildAvatar extends StatelessWidget {
  final String? avatarId;
  final String inicial;
  final Color cor;
  final double tamanho;
  final bool circulo;

  const ChildAvatar({
    required this.avatarId,
    required this.inicial,
    required this.cor,
    this.tamanho = 46,
    this.circulo = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textoInicial = Text(
      inicial,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 18,
      ),
    );

    final conteudo = AvatarImagem(
      avatarId: avatarId,
      tamanho: tamanho,
      fallbackBuilder: (context) => Center(child: textoInicial),
    );

    return Container(
      width: tamanho,
      height: tamanho,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: circulo ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circulo ? null : BorderRadius.circular(10),
        color: cor,
      ),
      child: conteudo,
    );
  }
}
