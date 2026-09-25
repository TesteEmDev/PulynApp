import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../config/theme.dart';
import '../../providers/index.dart';

class RankingScreen extends ConsumerStatefulWidget {
  const RankingScreen({super.key});

  @override
  ConsumerState<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends ConsumerState<RankingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Offset _startPosition;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Detecta swipe da esquerda para direita
  void _handleHorizontalDragEnd(DragEndDetails details) {
    // Se o swipe foi da esquerda para direita (velocidade positiva no eixo X)
    if (details.velocity.pixelsPerSecond.dx > 0) {
      if (_startPosition.dx < 50) {
        // Só ativa swipe se começar perto da borda esquerda
        context.go('/home');
      }
    }
  }

  void _handleHorizontalDragStart(DragStartDetails details) {
    _startPosition = details.globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _handleHorizontalDragStart,
      onHorizontalDragEnd: _handleHorizontalDragEnd,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ranking'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/home'),
          ),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Crianças', icon: Icon(Icons.person_outline)),
              Tab(text: 'Times', icon: Icon(Icons.people_outline)),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildChildrenRankingTab(),
            _buildTeamsRankingTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenRankingTab() {
    final childrenState = ref.watch(childrenProvider);

    return childrenState.when(
      loading: () => _buildLoadingList(),
      error: (error, stack) => _buildErrorState('Erro ao carregar ranking de crianças'),
      data: (children) {
        if (children.isEmpty) {
          return _buildEmptyState('Nenhuma criança encontrada');
        }
        
        // Ordena por pontos (descendente)
        final sorted = [...children]..sort((a, b) => b.currentScore.compareTo(a.currentScore));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final child = sorted[index];
            final medal = _getMedalForPosition(index);
            return _buildRankingCard(
              position: index + 1,
              name: child.nickname.isNotEmpty ? child.nickname : child.name,
              score: child.currentScore,
              teamColor: child.teamColor,
              medal: medal,
              isTop: index < 3,
            );
          },
        );
      },
    );
  }

  Widget _buildTeamsRankingTab() {
    final childrenState = ref.watch(childrenProvider);

    return childrenState.when(
      loading: () => _buildLoadingList(),
      error: (error, stack) => _buildErrorState('Erro ao carregar ranking de times'),
      data: (children) {
        // Agrupa crianças por time e soma pontos
        final teamsMap = <String, (String, int, String)>{};
        for (final child in children) {
          if (teamsMap.containsKey(child.teamName)) {
            final (name, score, color) = teamsMap[child.teamName]!;
            teamsMap[child.teamName] = (name, score + child.currentScore, color);
          } else {
            teamsMap[child.teamName] = (child.teamName, child.currentScore, child.teamColor);
          }
        }

        if (teamsMap.isEmpty) {
          return _buildEmptyState('Nenhum time encontrado');
        }

        // Ordena por pontos (descendente)
        final sorted = teamsMap.entries.toList()
          ..sort((a, b) => b.value.$2.compareTo(a.value.$2));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final (teamName, totalScore, teamColor) = sorted[index].value;
            final medal = _getMedalForPosition(index);
            return _buildTeamRankingCard(
              position: index + 1,
              name: teamName,
              score: totalScore,
              teamColor: teamColor,
              medal: medal,
              isTop: index < 3,
            );
          },
        );
      },
    );
  }

  String _getMedalForPosition(int index) {
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

  Widget _buildRankingCard({
    required int position,
    required String name,
    required int score,
    required String teamColor,
    required String medal,
    required bool isTop,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isTop ? PulynColors.darkSurface : PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop ? PulynColors.primary : PulynColors.darkBorder,
          width: isTop ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Medal / Position
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Color(int.parse('0xFF${teamColor.replaceFirst('#', '')}')),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Text(
                medal,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Name
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Posição #$position',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: PulynColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$score pts',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: PulynColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamRankingCard({
    required int position,
    required String name,
    required int score,
    required String teamColor,
    required String medal,
    required bool isTop,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isTop ? PulynColors.darkSurface : PulynColors.darkCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTop ? PulynColors.primary : PulynColors.darkBorder,
          width: isTop ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Medal / Position
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color(int.parse('0xFF${teamColor.replaceFirst('#', '')}')),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                medal,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: PulynColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Pontos totais do time',
                  style: const TextStyle(
                    fontSize: 12,
                    color: PulynColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Score
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$score',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: PulynColors.accent,
                ),
              ),
              const Text(
                'pontos',
                style: TextStyle(
                  fontSize: 11,
                  color: PulynColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: PulynColors.darkCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: PulynColors.darkBorder),
          ),
          padding: const EdgeInsets.all(16),
          height: 80,
        );
      },
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: PulynColors.danger),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Tentar Novamente'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inbox_outlined, size: 64, color: PulynColors.textMuted),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

// Provider para carregar filhos com seus scores
final childrenProvider = FutureProvider.autoDispose((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  await apiService.init();
  return await apiService.getChildren();
});
