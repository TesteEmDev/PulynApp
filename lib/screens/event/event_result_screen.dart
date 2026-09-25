import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

/// 🎯 FASE 4: EVENT RESULT SCREEN
/// Mostra quando: Evento tem status 'completed' (após encerramento)
/// Objetivo: Mostrar resultado, certificado, permitir compartilhamento

class EventResultScreen extends StatefulWidget {
  final Map<String, dynamic> event;

  const EventResultScreen({
    super.key,
    required this.event,
  });

  @override
  State<EventResultScreen> createState() => _EventResultScreenState();
}

class _EventResultScreenState extends State<EventResultScreen> with TickerProviderStateMixin {
  late AnimationController _confettiController;
  late Animation<double> _confettiAnimation;

  @override
  void initState() {
    super.initState();
    // Animação de confete/efeito
    _confettiController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _confettiAnimation = Tween<double>(begin: 0, end: 1).animate(_confettiController);
    _confettiController.forward();
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  void _shareResult() {
    // TODO: Implementar compartilhamento via share_plus
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Compartilhamento implementado em breve!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadCertificate() {
    // TODO: Implementar download de certificado (PDF ou imagem)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Certificado gerado em breve!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final eventName = widget.event['name'] as String? ?? 'Festa';
    final children = (widget.event['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rankings = widget.event['rankings'] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado Final'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Stack(
        children: [
          // Fundo com gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // Conteúdo
          SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header com animação
                  _ResultHeader(
                    eventName: eventName,
                    animation: _confettiAnimation,
                  ),
                  const SizedBox(height: 24),

                  // Seus filhos - resultado
                  Text(
                    '👦 SEUS FILHOS',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  if (children.isEmpty)
                    const _EmptyResult()
                  else
                    ...children.asMap().entries.map((entry) {
                      final index = entry.key;
                      return _ChildResultCard(
                        child: entry.value,
                        delay: Duration(milliseconds: index * 100),
                        key: ValueKey(entry.value['id']),
                      );
                    }),

                  const SizedBox(height: 24),

                  // Ranking final geral
                  Text(
                    '🏆 RANKING FINAL',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),

                  if (rankings.isEmpty)
                    const _EmptyRanking()
                  else
                    _FinalRankingWidget(rankings: rankings),

                  const SizedBox(height: 24),

                  // Botões de ação
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _shareResult,
                      icon: const Icon(Icons.share),
                      label: const Text('Compartilhar Resultado'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _downloadCertificate,
                      icon: const Icon(Icons.download),
                      label: const Text('Baixar Certificado'),
                    ),
                  ),
                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => context.go('/home'),
                      icon: const Icon(Icons.home),
                      label: const Text('Voltar Home'),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Header com animação de resultado
class _ResultHeader extends StatelessWidget {
  final String eventName;
  final Animation<double> animation;

  const _ResultHeader({
    required this.eventName,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).primaryColor,
                Theme.of(context).primaryColor.withValues(alpha: 0.7),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Emoji de confete com animação
              Transform.scale(
                scale: 0.8 + (animation.value * 0.3),
                child: const Align(
                  alignment: Alignment.center,
                  child: Text('🎉', style: TextStyle(fontSize: 60)),
                ),
              ),
              const SizedBox(height: 12),

              // Título
              Align(
                alignment: Alignment.center,
                child: Text(
                  'Festa Encerrada!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 8),

              // Subtítulo
              Align(
                alignment: Alignment.center,
                child: Text(
                  eventName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Card com resultado do filho
class _ChildResultCard extends StatelessWidget {
  final Map<String, dynamic> child;
  final Duration delay;

  const _ChildResultCard({
    required this.child,
    required this.delay,
    required Key key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final name = child['name'] as String? ?? 'Criança';
    final team = child['team'] as Map<String, dynamic>? ?? {};
    final teamName = team['name'] as String? ?? 'Sem time';
    final score = child['finalScore'] as int? ?? 0;
    final rank = child['finalRank'] as int? ?? 0;
    final badges = (child['badges'] as List?)?.cast<String>() ?? [];

    // Emojis de posição
    final rankEmoji = {
      1: '🥇',
      2: '🥈',
      3: '🥉',
    }[rank] ?? '$rankº';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Nome e team
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Team $teamName',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    rankEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$rank° lugar',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Score
          Row(
            children: [
              Text(
                '💰 $score pontos',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).primaryColor,
                    ),
              ),
            ],
          ),

          // Badges (se houver)
          if (badges.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: badges
                  .map((badge) => Chip(
                        label: Text(badge, style: const TextStyle(fontSize: 12)),
                        backgroundColor: Colors.grey.shade200,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

/// Widget para mostrar ranking final
class _FinalRankingWidget extends StatefulWidget {
  final Map<String, dynamic> rankings;

  const _FinalRankingWidget({required this.rankings});

  @override
  State<_FinalRankingWidget> createState() => _FinalRankingWidgetState();
}

class _FinalRankingWidgetState extends State<_FinalRankingWidget> {
  bool _showTeams = false;

  @override
  Widget build(BuildContext context) {
    final children = (widget.rankings['children'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final teams = (widget.rankings['teams'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Column(
      children: [
        // Tabs para alternar entre times e crianças
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('👦 Crianças'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('👥 Times'),
                  ),
                ],
                selected: {_showTeams},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() => _showTeams = newSelection.first);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Ranking de crianças
        if (!_showTeams)
          _ChildrenRankingList(children: children)
        else
          _TeamsRankingList(teams: teams),
      ],
    );
  }
}

/// Lista de ranking de crianças
class _ChildrenRankingList extends StatelessWidget {
  final List<Map<String, dynamic>> children;

  const _ChildrenRankingList({required this.children});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.take(10).length,
      itemBuilder: (context, index) {
        final child = children[index];
        final name = child['name'] as String? ?? 'Criança';
        final score = child['score'] as int? ?? 0;
        final rank = index + 1;

        final rankEmoji = {
          1: '🥇',
          2: '🥈',
          3: '🥉',
        }[rank] ?? '$rank';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(rankEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$score pts',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Lista de ranking de times
class _TeamsRankingList extends StatelessWidget {
  final List<Map<String, dynamic>> teams;

  const _TeamsRankingList({required this.teams});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: teams.length,
      itemBuilder: (context, index) {
        final team = teams[index];
        final name = team['name'] as String? ?? 'Time';
        final score = team['score'] as int? ?? team['points'] as int? ?? 0;
        final rank = index + 1;

        final rankEmoji = {
          1: '🥇',
          2: '🥈',
          3: '🥉',
        }[rank] ?? '$rank';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(rankEmoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$score pts',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Widget para resultado vazio
class _EmptyResult extends StatelessWidget {
  const _EmptyResult();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text('👶', style: Theme.of(context).textTheme.displayLarge),
          const SizedBox(height: 12),
          Text(
            'Nenhum resultado disponível',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

/// Widget para ranking vazio
class _EmptyRanking extends StatelessWidget {
  const _EmptyRanking();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Text(
          'Ranking não disponível',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
      ),
    );
  }
}
