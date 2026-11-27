import 'package:flutter/material.dart';
import '../config/theme.dart';
import 'child_avatar.dart';

/// Medalha da posição no ranking (0 = primeiro lugar).
String medalhaDaPosicao(int index) {
  switch (index) {
    case 0:
      return '🥇';
    case 1:
      return '🥈';
    case 2:
      return '🥉';
    default:
      return '${index + 1}';
  }
}

Color _corDoTime(String teamColor) => Color(int.parse('0xFF${teamColor.replaceFirst('#', '')}'));

BoxDecoration _decoracaoDoCartao({required bool isTop, required double raio}) => BoxDecoration(
      color: isTop ? PulynColors.darkSurface : PulynColors.darkCard,
      borderRadius: BorderRadius.circular(raio),
      border: Border.all(
        color: isTop ? PulynColors.primary : PulynColors.darkBorder,
        width: isTop ? 2 : 1,
      ),
    );

/// Linha do ranking de crianças. `compacto` é a versão da prévia na home (sem avatar e sem margem, a lista já separa);
/// a tela de ranking usa a versão completa, com o avatar da criança.
class CartaoRankingCrianca extends StatelessWidget {
  final int position;
  final String nome;
  final int score;
  final String teamColor;
  final String medal;
  final bool isTop;
  final String? avatarId;
  final bool compacto;

  const CartaoRankingCrianca({
    super.key,
    required this.position,
    required this.nome,
    required this.score,
    required this.teamColor,
    required this.medal,
    required this.isTop,
    this.avatarId,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final cor = _corDoTime(teamColor);
    final tamanhoMedalha = compacto ? 54.0 : 50.0;

    return Container(
      margin: compacto ? null : const EdgeInsets.only(bottom: 12),
      decoration: _decoracaoDoCartao(isTop: isTop, raio: compacto ? 16 : 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: tamanhoMedalha,
            height: tamanhoMedalha,
            decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(tamanhoMedalha / 2)),
            child: Center(
              child: Text(medal, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          if (!compacto) ...[
            // Avatar da criança (o nome completo fica ao lado)
            ChildAvatar(
              avatarId: avatarId,
              inicial: nome.isNotEmpty ? nome[0].toUpperCase() : '?',
              cor: cor,
              tamanho: 44,
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PulynColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text('Posição #$position', style: TextStyle(fontSize: 12, color: PulynColors.textMuted)),
              ],
            ),
          ),
          compacto ? _pontosCompacto() : _pontosCompleto(),
        ],
      ),
    );
  }

  Widget _pontosCompleto() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: PulynColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$score pts',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: PulynColors.primaryTexto),
        ),
      );

  Widget _pontosCompacto() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: PulynColors.primary.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: PulynColors.primary.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('$score', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PulynColors.primaryTexto)),
            Text('pts', style: TextStyle(fontSize: 12, color: PulynColors.textMuted)),
          ],
        ),
      );
}

/// Linha do ranking de times. `compacto` é a versão da prévia na home.
class CartaoRankingTime extends StatelessWidget {
  final int position;
  final String nome;
  final int score;
  final String teamColor;
  final String medal;
  final bool isTop;
  final bool compacto;

  const CartaoRankingTime({
    super.key,
    required this.position,
    required this.nome,
    required this.score,
    required this.teamColor,
    required this.medal,
    required this.isTop,
    this.compacto = false,
  });

  @override
  Widget build(BuildContext context) {
    final tamanhoMedalha = compacto ? 54.0 : 60.0;

    return Container(
      margin: compacto ? null : const EdgeInsets.only(bottom: 12),
      decoration: _decoracaoDoCartao(isTop: isTop, raio: compacto ? 16 : 12),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: tamanhoMedalha,
            height: tamanhoMedalha,
            decoration: BoxDecoration(color: _corDoTime(teamColor), borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Text(medal, style: TextStyle(fontSize: compacto ? 24 : 28, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: PulynColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  compacto ? 'Pontos totais' : 'Pontos totais do time',
                  style: TextStyle(fontSize: 12, color: PulynColors.textMuted),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: TextStyle(fontSize: compacto ? 18 : 24, fontWeight: FontWeight.bold, color: PulynColors.accentTexto),
              ),
              Text('pontos', style: TextStyle(fontSize: 12, color: PulynColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}
