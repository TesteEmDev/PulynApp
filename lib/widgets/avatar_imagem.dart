import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/avatar_utils.dart';

/// Imagem do avatar de uma criança, seja um do catálogo (SVG) ou um montado por ela (PNG feito pelo backend).
///
/// Enquanto a imagem carrega, se ela falhar ou se não houver avatar válido, aparece o que [fallbackBuilder]
/// devolver (normalmente a inicial do nome).
class AvatarImagem extends StatelessWidget {
  final String? avatarId;
  final double tamanho;
  final BoxFit fit;
  final WidgetBuilder fallbackBuilder;

  const AvatarImagem({
    required this.avatarId,
    required this.tamanho,
    required this.fallbackBuilder,
    this.fit = BoxFit.cover,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isAvatarMontado(avatarId)) {
      final pixels = tamanhoDeImagemDoAvatar(tamanho, MediaQuery.devicePixelRatioOf(context));
      return Image.network(
        getAvatarMontadoUrl(avatarId!, tamanho: pixels),
        width: tamanho,
        height: tamanho,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => fallbackBuilder(context),
        loadingBuilder: (context, child, progresso) => progresso == null ? child : fallbackBuilder(context),
      );
    }

    if (isValidAvatarId(avatarId)) {
      return SvgPicture.network(
        getAvatarUrl(avatarId),
        width: tamanho,
        height: tamanho,
        fit: fit,
        placeholderBuilder: fallbackBuilder,
        errorBuilder: (context, error, stackTrace) => fallbackBuilder(context),
      );
    }

    return fallbackBuilder(context);
  }
}
