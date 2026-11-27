import 'package:flutter/material.dart';
import '../../widgets/app_components.dart';
import '../../widgets/ranking_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
  void _handleHorizontalDragEnd(DragEndDetails detalhes) {
    // Se o swipe foi da esquerda para direita (velocidade positiva no eixo X)
    if (detalhes.velocity.pixelsPerSecond.dx > 0) {
      if (_startPosition.dx < 50) {
        // Só ativa swipe se começar perto da borda esquerda
        context.go('/home');
      }
    }
  }

  void _handleHorizontalDragStart(DragStartDetails detalhes) {
    _startPosition = detalhes.globalPosition;
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
      loading: () => const CartoesCarregando(),
      error: (error, stack) => ErroCentralizado(mensagem: 'Erro ao carregar ranking de crianças', onTentarNovamente: () => setState(() {})),
      data: (children) {
        if (children.isEmpty) {
          return EmptyState(icon: Icons.inbox_outlined, title: 'Nenhuma criança encontrada');
        }
        
        // Ordena por pontos (descendente)
        final sorted = [...children]..sort((a, b) => b.currentScore.compareTo(a.currentScore));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final child = sorted[index];
            final medal = medalhaDaPosicao(index);
            return CartaoRankingCrianca(
              position: index + 1,
              nome: child.apelido.isNotEmpty ? child.apelido : child.nome,
              score: child.currentScore,
              teamColor: child.teamColor,
              avatarId: child.profileImage,
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
      loading: () => const CartoesCarregando(),
      error: (error, stack) => ErroCentralizado(mensagem: 'Erro ao carregar ranking de times', onTentarNovamente: () => setState(() {})),
      data: (children) {
        // Agrupa crianças por time e soma pontos
        final teamsMap = <String, (String, int, String)>{};
        for (final child in children) {
          if (teamsMap.containsKey(child.teamName)) {
            final (nome, score, color) = teamsMap[child.teamName]!;
            teamsMap[child.teamName] = (nome, score + child.currentScore, color);
          } else {
            teamsMap[child.teamName] = (child.teamName, child.currentScore, child.teamColor);
          }
        }

        if (teamsMap.isEmpty) {
          return EmptyState(icon: Icons.inbox_outlined, title: 'Nenhum time encontrado');
        }

        // Ordena por pontos (descendente)
        final sorted = teamsMap.entries.toList()
          ..sort((a, b) => b.value.$2.compareTo(a.value.$2));

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: sorted.length,
          itemBuilder: (context, index) {
            final (teamName, totalScore, teamColor) = sorted[index].value;
            final medal = medalhaDaPosicao(index);
            return CartaoRankingTime(
              position: index + 1,
              nome: teamName,
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

}

// Provider para carregar filhos com seus pontos
final childrenProvider = FutureProvider.autoDispose((ref) async {
  final apiService = ref.watch(apiServiceProvider);
  await apiService.init();
  return await apiService.getChildren();
});
