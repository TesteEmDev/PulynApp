import 'package:flutter/material.dart';
import '../config/theme.dart';

/// Selo da brincadeira do evento: "AO VIVO" + nome quando há brincadeira rodando,
/// ou "SEM BRINCADEIRA" em cinza quando o evento não tem uma ativa.
class BrincadeiraSelo extends StatelessWidget {
  final Map<String, dynamic> jogo;

  const BrincadeiraSelo({required this.jogo, super.key});

  @override
  Widget build(BuildContext context) {
    final ativa = jogo['hasActiveGame'] == true;
    final nome = (jogo['gameName'] as String?)?.trim() ?? '';
    final cor = ativa ? PulynColors.success : PulynColors.textMuted;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cor.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cor,
              boxShadow: ativa
                  ? [BoxShadow(color: cor.withValues(alpha: 0.6), blurRadius: 6)]
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ativa ? 'AO VIVO' : 'SEM BRINCADEIRA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: cor,
                  ),
                ),
                Text(
                  ativa && nome.isNotEmpty ? nome : 'Nenhuma agora',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: ativa ? PulynColors.textPrimary : PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
